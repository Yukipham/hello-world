extends Node2D

const SCREEN := Vector2(1280,720)
const WORLD := Vector2(2300,1500)
const HOME := Vector2(1120,760)
const SAVE_PATH := "user://save_v03.json"
const PLAYER_SPEED := 250.0
const VILLAGER_SPEED := 105.0
const JOY_R := 100.0
const DAY_SECONDS := 82.0

var rng := RandomNumberGenerator.new()
var player_pos := HOME + Vector2(-90,35)
var player_hp := 100.0
var player_hunger := 88.0
var player_facing := 0
var player_attack_cd := 0.0
var player_hit := 0.0
var player_dead := 0.0
var attack_fx := 0.0
var move_vec := Vector2.ZERO
var anim_time := 0.0
var day := 1
var day_time := 0.0
var respawn_time := 0.0
var spawn_time := 0.0
var autosave_time := 0.0
var territory := 220.0
var rally_time := 0.0
var storage_bonus := 0
var kills := 0
var inventory := {"wood":18,"stone":12,"food":12,"hide":0}
var resources: Array[Dictionary] = []
var villagers: Array[Dictionary] = []
var animals: Array[Dictionary] = []
var buildings: Array[Dictionary] = []
var message := "V0.3: xây làng, săn thú và bảo vệ dân làng."
var message_time := 6.0
var build_mode := ""
var build_menu := false
var joy_id := -1
var joy_origin := Vector2(145,575)
var joy_knob := Vector2(145,575)
var attack_rect := Rect2(1080,455,180,120)
var interact_rect := Rect2(910,555,150,100)
var build_rect := Rect2(1080,590,180,100)
var defend_rect := Rect2(910,440,150,100)
var build_rects := [Rect2(400,585,145,88),Rect2(555,585,145,88),Rect2(710,585,145,88),Rect2(865,585,145,88)]
var tower_tick := 0.0

func _ready() -> void:
    rng.seed = 30303
    _spawn_resources()
    buildings = [{"type":"campfire","pos":HOME}]
    villagers = [
        _villager(HOME+Vector2(-40,-25),"An","forager"),
        _villager(HOME+Vector2(55,-15),"Bình","lumber"),
        _villager(HOME+Vector2(15,70),"Cường","guard")
    ]
    _spawn_animal("boar",Vector2(520,980))
    _spawn_animal("boar",Vector2(1560,1050))
    _spawn_animal("wolf",Vector2(480,390))
    _spawn_animal("wolf",Vector2(1690,480))
    _spawn_animal("wolf",Vector2(1650,1220))
    _load_game()

func _spawn_resources() -> void:
    resources.clear()
    for i in range(28):
        resources.append(_resource("wood",_rand_pos(),5))
    for i in range(14):
        resources.append(_resource("stone",_rand_pos(),4))
    for i in range(14):
        resources.append(_resource("food",_rand_pos(),3))

func _rand_pos() -> Vector2:
    for _i in range(100):
        var p := Vector2(rng.randf_range(100.0,1880.0),rng.randf_range(100.0,WORLD.y-100.0))
        if p.distance_to(HOME) > 245.0:
            return p
    return Vector2(250,250)

func _resource(kind:String,pos:Vector2,amount:int) -> Dictionary:
    return {"type":kind,"pos":pos,"amount":amount,"max":amount}

func _villager(pos:Vector2,n:String,role:String) -> Dictionary:
    var hp := 88.0 if role=="guard" else 72.0
    var pref := "wood" if role=="lumber" else "food"
    return {"pos":pos,"name":n,"role":role,"pref":pref,"hp":hp,"max_hp":hp,"state":"patrol" if role=="guard" else "search","target":-1,"animal":-1,"timer":0.0,"attack":0.0,"down":0.0,"face":0,"moving":false,"hit":0.0,"angle":rng.randf_range(0.0,TAU)}

func _spawn_animal(kind:String,pos:Vector2) -> void:
    var hp := 55.0 if kind=="wolf" else 82.0
    animals.append({"type":kind,"pos":pos,"hp":hp,"max_hp":hp,"state":"roam","target_kind":"","target":-1,"attack":0.0,"roam":0.0,"roam_pos":pos,"face":0,"moving":false,"hit":0.0})

func _process(delta:float) -> void:
    anim_time += delta
    message_time = maxf(0.0,message_time-delta)
    player_attack_cd = maxf(0.0,player_attack_cd-delta)
    player_hit = maxf(0.0,player_hit-delta)
    attack_fx = maxf(0.0,attack_fx-delta)
    rally_time = maxf(0.0,rally_time-delta)
    if player_dead > 0.0:
        player_dead -= delta
        if player_dead <= 0.0:
            player_pos = HOME+Vector2(-90,35); player_hp = 100.0; player_hunger = 65.0
            inventory.food = maxi(0,int(inventory.food)-2)
            _say("Bạn đã hồi sinh tại trại.")
    else:
        _update_player(delta)
    _update_villagers(delta)
    _update_animals(delta)
    _update_towers(delta)
    _update_world(delta)
    autosave_time += delta
    if autosave_time >= 18.0:
        autosave_time = 0.0; _save_game()
    queue_redraw()

func _update_player(delta:float) -> void:
    var k := Vector2.ZERO
    k.x = float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))-float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
    k.y = float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))-float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
    var v := k.normalized() if k.length()>0.01 else move_vec
    if v.length()>1.0: v=v.normalized()
    if v.length()>0.04:
        player_facing = _face(v,player_facing)
        player_pos += v*PLAYER_SPEED*(0.78 if player_hunger<20.0 else 1.0)*delta
        player_pos.x = clampf(player_pos.x,35.0,WORLD.x-35.0)
        player_pos.y = clampf(player_pos.y,45.0,WORLD.y-35.0)
    player_hunger = maxf(0.0,player_hunger-delta*0.13)
    if player_hunger<=0.0: _damage_player(delta)
    elif player_pos.distance_to(HOME)<160.0 and player_hunger>55.0:
        player_hp=minf(100.0,player_hp+delta*0.3)

func _update_villagers(delta:float) -> void:
    for i in range(villagers.size()):
        var v:Dictionary=villagers[i]
        v.attack=maxf(0.0,float(v.attack)-delta); v.hit=maxf(0.0,float(v.hit)-delta); v.moving=false
        if float(v.hp)<=0.0 or String(v.state)=="down":
            v.state="down"; v.down=float(v.down)-delta
            if float(v.down)<=0.0:
                v.hp=float(v.max_hp)*0.55; v.pos=HOME+Vector2(rng.randf_range(-65,65),rng.randf_range(-55,55)); v.state="patrol" if v.role=="guard" else "search"
            villagers[i]=v; continue
        var threat := _nearest_animal(Vector2(v.pos),420.0 if v.role=="guard" and rally_time>0.0 else (310.0 if v.role=="guard" else 105.0))
        if threat>=0: v.animal=threat; v.state="fight"
