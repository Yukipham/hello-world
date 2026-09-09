extends Node2D

const SCREEN := Vector2(1280, 720)
const PLAYER_SPEED := 235.0
const VILLAGER_SPEED := 92.0
const GATHER_RANGE := 72.0
const JOYSTICK_RADIUS := 74.0
const DAY_SECONDS := 42.0
const RESOURCE_RESPAWN_SECONDS := 18.0
const SAVE_PATH := "user://save_v02.json"

var player_pos := Vector2(640, 360)
var move_vec := Vector2.ZERO
var resources: Array[Dictionary] = []
var buildings: Array[Dictionary] = []
var villagers: Array[Dictionary] = []
var inventory := {"wood": 6, "stone": 4, "food": 8}
var storage_bonus := 0
var message := "Dân làng sẽ tự đi thu thập. Hãy mở rộng khu định cư!"
var message_time := 5.0
var build_mode := ""
var day := 1
var day_timer := 0.0
var resource_respawn_timer := 0.0
var autosave_timer := 0.0
var territory_radius := 175.0
var starvation_days := 0

# Touch joystick
var left_touch_id := -1
var joy_origin := Vector2(145, 570)
var joy_knob := Vector2(145, 570)

# UI touch areas
var gather_rect := Rect2(1070, 455, 175, 58)
var house_rect := Rect2(1070, 523, 175, 58)
var storage_rect := Rect2(1070, 591, 175, 58)
var flag_rect := Rect2(885, 591, 175, 58)

func _ready() -> void:
    randomize()
    _spawn_world()
    _spawn_villagers()
    _load_game()
    queue_redraw()

func _spawn_world() -> void:
    resources.clear()
    var tree_positions := [
        Vector2(165,135),Vector2(260,185),Vector2(345,120),Vector2(940,135),
        Vector2(1050,225),Vector2(1130,330),Vector2(230,405),Vector2(870,430),
        Vector2(760,150),Vector2(485,570),Vector2(720,610),Vector2(100,520)
    ]
    for p in tree_positions:
        resources.append(_resource("wood", p, 4))
    var rock_positions := [Vector2(430,135),Vector2(1070,430),Vector2(810,540),Vector2(355,530),Vector2(1180,150),Vector2(600,610)]
    for p in rock_positions:
        resources.append(_resource("stone", p, 4))
    var food_positions := [Vector2(570,145),Vector2(1015,565),Vector2(665,525),Vector2(145,300),Vector2(915,285),Vector2(300,620)]
    for p in food_positions:
        resources.append(_resource("food", p, 4))

func _resource(kind: String, pos: Vector2, amount: int) -> Dictionary:
    return {"type":kind, "pos":pos, "amount":amount, "max":amount, "cooldown":0.0}

func _spawn_villagers() -> void:
    villagers.clear()
    villagers.append(_new_villager(Vector2(600, 405), "An", "food"))
    villagers.append(_new_villager(Vector2(680, 405), "Bình", "wood"))

func _new_villager(pos: Vector2, villager_name: String, preference: String) -> Dictionary:
    return {
        "pos": pos,
        "name": villager_name,
        "preference": preference,
        "target": -1,
        "work_timer": 0.0,
        "state": "search",
        "carrying": ""
    }

func _process(delta: float) -> void:
    _update_player(delta)
    _update_villagers(delta)
    _update_resource_respawn(delta)
    _update_day(delta)
    autosave_timer += delta
    if autosave_timer >= 15.0:
        autosave_timer = 0.0
        _save_game()
    if message_time > 0.0:
        message_time -= delta
    queue_redraw()

func _update_player(delta: float) -> void:
    var keyboard := Vector2.ZERO
    keyboard.x = float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
    keyboard.y = float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
    var input_vec := keyboard.normalized() if keyboard.length() > 0.01 else move_vec
    if input_vec.length() > 1.0:
        input_vec = input_vec.normalized()
    player_pos += input_vec * PLAYER_SPEED * delta
    player_pos.x = clamp(player_pos.x, 42.0, 1238.0)
    player_pos.y = clamp(player_pos.y, 86.0, 674.0)

func _update_villagers(delta: float) -> void:
    for i in range(villagers.size()):
        var v: Dictionary = villagers[i]
        if v.state == "search":
            v.target = _pick_resource_for_villager(v.preference, v.pos)
            if v.target >= 0:
                v.state = "move"
        elif v.state == "move":
            var ti: int = v.target
            if ti < 0 or ti >= resources.size() or int(resources[ti].amount) <= 0:
                v.state = "search"
                v.target = -1
            else:
                var target_pos: Vector2 = resources[ti].pos
                var dist: float = v.pos.distance_to(target_pos)
                if dist <= 30.0:
                    v.state = "work"
                    v.work_timer = 0.85
                else:
                    v.pos = v.pos.move_toward(target_pos, VILLAGER_SPEED * delta)
        elif v.state == "work":
            v.work_timer -= delta
            if v.work_timer <= 0.0:
                var ti: int = v.target
                if ti >= 0 and ti < resources.size() and int(resources[ti].amount) > 0:
                    var kind: String = resources[ti].type
                    resources[ti].amount = int(resources[ti].amount) - 1
                    inventory[kind] = int(inventory[kind]) + 1
                    v.carrying = kind
                v.state = "return"
                v.target = -1
        elif v.state == "return":
            var home := Vector2(640, 360)
            if v.pos.distance_to(home) <= 62.0:
                v.state = "rest"
                v.work_timer = 0.55
                v.carrying = ""
            else:
                v.pos = v.pos.move_toward(home, VILLAGER_SPEED * delta)
        elif v.state == "rest":
            v.work_timer -= delta
            if v.work_timer <= 0.0:
                v.state = "search"
        villagers[i] = v

func _pick_resource_for_villager(preference: String, from_pos: Vector2) -> int:
    var preferred: Array[int] = []
    var fallback: Array[int] = []
    for i in range(resources.size()):
        if int(resources[i].amount) <= 0:
            continue
        if not _inside_work_territory(resources[i].pos):
            continue
        if resources[i].type == preference:
            preferred.append(i)
        else:
            fallback.append(i)
    var pool: Array[int] = preferred if not preferred.is_empty() else fallback
    if pool.is_empty():
        return -1
    var best := pool[0]
    var best_dist: float = from_pos.distance_to(resources[best].pos)
    for idx in pool:
        var d: float = from_pos.distance_to(resources[idx].pos)
        if d < best_dist:
            best_dist = d
            best = idx
    return best

func _inside_work_territory(pos: Vector2) -> bool:
    if pos.distance_to(Vector2(640, 360)) <= territory_radius + 130.0:
        return true
    for b in buildings:
        if b.type == "flag" and pos.distance_to(b.pos) <= 210.0:
            return true
    return false

func _update_resource_respawn(delta: float) -> void:
    resource_respawn_timer += delta
    if resource_respawn_timer < RESOURCE_RESPAWN_SECONDS:
        return
    resource_respawn_timer = 0.0
    for i in range(resources.size()):
        if int(resources[i].amount) < int(resources[i].max):
            resources[i].amount = int(resources[i].amount) + 1
            break

func _update_day(delta: float) -> void:
    day_timer += delta
    if day_timer < DAY_SECONDS:
        return
    day_timer = 0.0
    day += 1
    var food_need := 1 + villagers.size()
    if int(inventory.food) >= food_need:
        inventory.food = int(inventory.food) - food_need
        starvation_days = 0
        _say("Ngày %d: cả làng dùng %d thức ăn." % [day, food_need])
    else:
        inventory.food = 0
        starvation_days += 1
        _say("Ngày %d: thiếu thức ăn! Dân làng sẽ ưu tiên hái lượm." % day)
        for i in range(villagers.size()):
            villagers[i].preference = "food"
    _save_game()

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_E or event.keycode == KEY_SPACE:
            _gather_nearest()
            return
        if event.keycode == KEY_1:
            _toggle_build("house")
            return
        if event.keycode == KEY_2:
            _toggle_build("storage")
            return
        if event.keycode == KEY_3:
            _toggle_build("flag")
            return
        if event.keycode == KEY_F5:
            _save_game()
            _say("Đã lưu game")
            return
    if event is InputEventScreenTouch:
        if event.pressed:
            if gather_rect.has_point(event.position):
                _gather_nearest()
                return
            if house_rect.has_point(event.position):
                _toggle_build("house")
                return
            if storage_rect.has_point(event.position):
                _toggle_build("storage")
                return
            if flag_rect.has_point(event.position):
                _toggle_build("flag")
                return
            if build_mode != "" and event.position.x > 330 and event.position.y > 92:
                _try_build(event.position)
                return
            if event.position.x < 430:
                left_touch_id = event.index
                joy_origin = event.position
                joy_knob = event.position
                move_vec = Vector2.ZERO
        elif event.index == left_touch_id:
            left_touch_id = -1
            move_vec = Vector2.ZERO
            joy_origin = Vector2(145, 570)
            joy_knob = joy_origin
    elif event is InputEventScreenDrag and event.index == left_touch_id:
        var drag_delta := event.position - joy_origin
        if drag_delta.length() > JOYSTICK_RADIUS:
            drag_delta = drag_delta.normalized() * JOYSTICK_RADIUS
        joy_knob = joy_origin + drag_delta
        move_vec = drag_delta / JOYSTICK_RADIUS
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if build_mode != "" and event.position.y > 92 and event.position.x < 1050:
            _try_build(event.position)

func _gather_nearest() -> void:
    var best_i := -1
    var best_dist := INF
    for i in range(resources.size()):
        if int(resources[i].amount) <= 0:
            continue
        var d: float = player_pos.distance_to(resources[i].pos)
        if d < best_dist:
            best_dist = d
            best_i = i
    if best_i == -1 or best_dist > GATHER_RANGE:
        _say("Hãy đứng gần cây, đá hoặc bụi quả")
        return
    var kind: String = resources[best_i].type
    inventory[kind] = int(inventory[kind]) + 1
    resources[best_i].amount = int(resources[best_i].amount) - 1
    var label := "gỗ" if kind == "wood" else ("đá" if kind == "stone" else "thức ăn")
    _say("+1 %s" % label)

func _toggle_build(kind: String) -> void:
    build_mode = "" if build_mode == kind else kind
    if build_mode == "house":
        _say("Đặt NHÀ: 6 gỗ + 3 đá • tăng vùng và sức chứa dân")
    elif build_mode == "storage":
        _say("Đặt KHO: 8 gỗ + 5 đá • tăng sức chứa tài nguyên")
    elif build_mode == "flag":
        _say("Đặt CỜ: 10 gỗ + 8 đá + 2 thức ăn • chiếm vùng mới")
    else:
        _say("Đã tắt chế độ xây")

func _try_build(pos: Vector2) -> void:
    if pos.x < 75.0 or pos.x > 1035.0 or pos.y < 105.0 or pos.y > 650.0:
        _say("Không thể xây ở vị trí này")
        return
    for b in buildings:
        if pos.distance_to(b.pos) < 95.0:
            _say("Quá gần công trình khác")
            return
    if build_mode == "house":
        if not _pay_cost(6, 3, 0):
            _say("Nhà cần 6 gỗ + 3 đá")
            return
        buildings.append({"type":"house", "pos":pos})
        territory_radius = min(330.0, territory_radius + 28.0)
        if villagers.size() < _housing_capacity():
            villagers.append(_new_villager(pos + Vector2(0, 52), "Dân %d" % (villagers.size()+1), "food"))
        _say("Đã xây nhà và đón thêm dân!")
    elif build_mode == "storage":
        if not _pay_cost(8, 5, 0):
            _say("Kho cần 8 gỗ + 5 đá")
            return
        buildings.append({"type":"storage", "pos":pos})
        storage_bonus += 40
        _say("Đã xây kho. Sức chứa +40")
    elif build_mode == "flag":
        if not _pay_cost(10, 8, 2):
            _say("Cờ cần 10 gỗ + 8 đá + 2 thức ăn")
            return
        if not _near_owned_area(pos):
            inventory.wood = int(inventory.wood) + 10
            inventory.stone = int(inventory.stone) + 8
            inventory.food = int(inventory.food) + 2
            _say("Cờ phải đặt sát vùng đang kiểm soát")
            return
        buildings.append({"type":"flag", "pos":pos})
        territory_radius = min(420.0, territory_radius + 20.0)
        _say("Đã chiếm một vùng mới!")
    build_mode = ""
    _save_game()

func _pay_cost(wood: int, stone: int, food: int) -> bool:
    if int(inventory.wood) < wood or int(inventory.stone) < stone or int(inventory.food) < food:
        return false
    inventory.wood = int(inventory.wood) - wood
    inventory.stone = int(inventory.stone) - stone
    inventory.food = int(inventory.food) - food
    return true

func _housing_capacity() -> int:
    var houses := 1
    for b in buildings:
        if b.type == "house":
            houses += 1
    return houses * 2

func _near_owned_area(pos: Vector2) -> bool:
    if pos.distance_to(Vector2(640, 360)) <= territory_radius + 80.0:
        return true
    for b in buildings:
        if b.type == "flag" and pos.distance_to(b.pos) <= 250.0:
            return true
    return false

func _say(text: String) -> void:
    message = text
    message_time = 3.8

func _save_game() -> void:
    var data := {
        "player": [player_pos.x, player_pos.y],
        "inventory": inventory,
        "buildings": [],
        "day": day,
        "territory": territory_radius,
        "storage_bonus": storage_bonus
    }
    for b in buildings:
        data.buildings.append({"type":b.type, "x":b.pos.x, "y":b.pos.y})
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data))

func _load_game() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if not file:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    if parsed.has("player") and parsed.player is Array and parsed.player.size() >= 2:
        player_pos = Vector2(float(parsed.player[0]), float(parsed.player[1]))
    if parsed.has("inventory") and parsed.inventory is Dictionary:
        inventory = parsed.inventory
    day = int(parsed.get("day", 1))
    territory_radius = float(parsed.get("territory", 175.0))
    storage_bonus = int(parsed.get("storage_bonus", 0))
    buildings.clear()
    if parsed.has("buildings") and parsed.buildings is Array:
        for b in parsed.buildings:
            if b is Dictionary:
                buildings.append({"type":str(b.get("type", "house")), "pos":Vector2(float(b.get("x", 640)), float(b.get("y", 360)))})
    _say("Đã tải tiến trình V0.2")

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("#78a75b"))
    for x in range(0, 1281, 64):
        draw_line(Vector2(x, 0), Vector2(x, 720), Color(1,1,1,0.045), 1)
    for y in range(0, 721, 64):
        draw_line(Vector2(0, y), Vector2(1280, y), Color(1,1,1,0.045), 1)

    # Territory layers
    draw_circle(Vector2(640, 360), territory_radius, Color(0.25,0.6,1.0,0.075))
    draw_arc(Vector2(640, 360), territory_radius, 0, TAU, 100, Color(0.7,0.87,1.0,0.48), 3)
    for b in buildings:
        if b.type == "flag":
            draw_circle(b.pos, 210, Color(0.25,0.6,1.0,0.045))
            draw_arc(b.pos, 210, 0, TAU, 80, Color(0.55,0.78,1.0,0.26), 2)

    for r in resources:
        _draw_resource(r)
    for b in buildings:
        _draw_building(b)
    for v in villagers:
        _draw_villager(v)
    _draw_player()

    if build_mode != "":
        draw_rect(Rect2(0,0,1280,720), Color(0.3,0.6,1,0.025))

    _draw_hud()

func _draw_resource(r: Dictionary) -> void:
    var p: Vector2 = r.pos
    var alpha := 1.0 if int(r.amount) > 0 else 0.20
    if r.type == "wood":
        draw_rect(Rect2(p + Vector2(-7, 9), Vector2(14, 28)), Color(0.46,0.32,0.23,alpha))
        draw_circle(p, 25, Color(0.18,0.44,0.26,alpha))
        draw_circle(p + Vector2(-12,-8), 15, Color(0.23,0.53,0.32,alpha))
        draw_circle(p + Vector2(13,-6), 14, Color(0.23,0.53,0.32,alpha))
    elif r.type == "stone":
        var pts := PackedVector2Array([p+Vector2(-24,15),p+Vector2(-13,-17),p+Vector2(14,-22),p+Vector2(27,8),p+Vector2(7,24)])
        draw_colored_polygon(pts, Color(0.47,0.50,0.53,alpha))
        draw_polyline(PackedVector2Array([pts[0],pts[1],pts[2],pts[3],pts[4],pts[0]]), Color(0.33,0.36,0.38,alpha), 3)
    else:
        draw_circle(p, 21, Color(0.20,0.43,0.22,alpha))
        for off in [Vector2(-10,-7),Vector2(8,-11),Vector2(4,7),Vector2(-8,9)]:
            draw_circle(p+off, 5, Color(0.72,0.17,0.30,alpha))
    if int(r.amount) > 0:
        _text(p + Vector2(-6,-31), str(r.amount), 14, Color(1,1,1,0.75))

func _draw_building(b: Dictionary) -> void:
    var p: Vector2 = b.pos
    if b.type == "house":
        draw_rect(Rect2(p-Vector2(36,28),Vector2(72,56)), Color("#d6b276"))
        var roof := PackedVector2Array([p+Vector2(-43,-28),p+Vector2(0,-58),p+Vector2(43,-28)])
        draw_colored_polygon(roof, Color("#944f43"))
        draw_rect(Rect2(p+Vector2(-9,3),Vector2(18,25)), Color("#674835"))
    elif b.type == "storage":
        draw_rect(Rect2(p-Vector2(42,31),Vector2(84,62)), Color("#ad8757"))
        draw_rect(Rect2(p-Vector2(46,38),Vector2(92,14)), Color("#73563d"))
        for xx in [-25.0, 2.0]:
            draw_rect(Rect2(p+Vector2(xx,-10),Vector2(22,26)), Color("#6b4c33"), false, 3)
    elif b.type == "flag":
        draw_line(p+Vector2(0,28), p+Vector2(0,-48), Color("#4d4036"), 6)
        var flag_pts := PackedVector2Array([p+Vector2(3,-46),p+Vector2(46,-35),p+Vector2(3,-20)])
        draw_colored_polygon(flag_pts, Color("#e4b640"))
        draw_circle(p+Vector2(0,31), 16, Color(0.28,0.25,0.22,0.35))

func _draw_villager(v: Dictionary) -> void:
    var p: Vector2 = v.pos
    draw_circle(p + Vector2(0,13), 13, Color(0,0,0,0.18))
    draw_circle(p, 14, Color("#e5c18e"))
    draw_rect(Rect2(p+Vector2(-11,11),Vector2(22,22)), Color("#7b573d"))
    draw_circle(p+Vector2(0,-4), 10, Color("#544036"), false, 4)
    var state_label := "đi" if v.state == "move" else ("làm" if v.state == "work" else ("về" if v.state == "return" else ""))
    if state_label != "":
        _text(p+Vector2(-12,-24), state_label, 12, Color(1,1,1,0.7))

func _draw_player() -> void:
    draw_set_transform(player_pos + Vector2(0,15), 0.0, Vector2(1.8, 0.8))
    draw_circle(Vector2.ZERO, 10.0, Color(0,0,0,0.23))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    draw_circle(player_pos, 18, Color("#ead0a0"))
    draw_rect(Rect2(player_pos+Vector2(-14,14),Vector2(28,28)), Color("#355c8a"))
    draw_circle(player_pos+Vector2(0,-4), 13, Color("#5d3b2d"), false, 5)

func _draw_hud() -> void:
    draw_rect(Rect2(18,16,580,64), Color(0.06,0.09,0.10,0.84), true)
    _text(Vector2(34,43), "Ngày %d   Dân: %d/%d   Vùng: %dm" % [day, villagers.size(), _housing_capacity(), int(territory_radius)], 20)
    _text(Vector2(34,68), "Gỗ %d   Đá %d   Thức ăn %d   Kho +%d" % [inventory.wood, inventory.stone, inventory.food, storage_bonus], 19, Color(0.93,0.95,0.91,0.94))

    draw_rect(Rect2(615,16,645,64), Color(0.06,0.09,0.10,0.76), true)
    _text(Vector2(633,43), "V0.2: dân tự thu thập • xây nhà/kho • cắm cờ chiếm vùng", 19)
    _text(Vector2(633,68), "Mỗi ngày cần %d thức ăn. Tài nguyên sẽ mọc lại." % (1 + villagers.size()), 17, Color(1,1,1,0.76))

    draw_circle(joy_origin, JOYSTICK_RADIUS, Color(0.04,0.06,0.06,0.28))
    draw_circle(joy_origin, JOYSTICK_RADIUS, Color(1,1,1,0.23), false, 3)
    draw_circle(joy_knob, 31, Color(0.9,0.94,0.96,0.50))

    _button(gather_rect, "THU THẬP", build_mode == "")
    _button(house_rect, "NHÀ 6G 3Đ", build_mode == "house")
    _button(storage_rect, "KHO 8G 5Đ", build_mode == "storage")
    _button(flag_rect, "CỜ CHIẾM VÙNG", build_mode == "flag")

    if message_time > 0:
        var w := min(850.0, 34.0 + message.length() * 11.0)
        var rr := Rect2(640-w/2, 96, w, 48)
        draw_rect(rr, Color(0.03,0.04,0.05,0.82), true)
        _text(Vector2(rr.position.x+18,rr.position.y+32), message, 19)

    _text(Vector2(20,706), "PC: WASD • E thu thập • 1 nhà • 2 kho • 3 cờ • F5 lưu | Android: joystick + nút", 16, Color(1,1,1,0.70))

func _button(rect: Rect2, label: String, active: bool) -> void:
    var c := Color("#d18632") if active else Color("#3975a8")
    draw_rect(rect, Color(c,0.90), true)
    draw_rect(rect, Color(1,1,1,0.36), false, 2)
    _text(rect.position + Vector2(12,37), label, 17)

func _text(pos: Vector2, text: String, size: int, color := Color.WHITE) -> void:
    draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
