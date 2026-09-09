    if a.target_kind=="villager" and i>=0 and i<villagers.size() and float(villagers[i].hp)>0.0: return Vector2(villagers[i].pos)
    return Vector2(-1,-1)

func _pick_resource(pref:String,pos:Vector2) -> int:
    var best:=-1; var score:=999999.0
    for i in range(resources.size()):
        if not _resource_ok(i): continue
        var p:=Vector2(resources[i].pos)
        if not _owned_work(p): continue
        var s:=pos.distance_to(p)+(0.0 if resources[i].type==pref else 350.0)
        if s<score: score=s; best=i
    return best

func _resource_ok(i:int) -> bool: return i>=0 and i<resources.size() and int(resources[i].amount)>0
func _animal_alive(i:int) -> bool: return i>=0 and i<animals.size() and float(animals[i].hp)>0.0
func _nearest_animal(pos:Vector2,r:float) -> int:
    var best:=-1; var bd:=r
    for i in range(animals.size()):
        if not _animal_alive(i): continue
        var d:=pos.distance_to(Vector2(animals[i].pos))
        if d<bd: bd=d; best=i
    return best
func _owned(pos:Vector2) -> bool:
    if pos.distance_to(HOME)<=territory+110.0: return true
    for b in buildings:
        if b.type=="flag" and Vector2(b.pos).distance_to(pos)<310.0: return true
    return false
func _owned_work(pos:Vector2) -> bool:
    if pos.distance_to(HOME)<=territory+210.0: return true
    for b in buildings:
        if b.type=="flag" and Vector2(b.pos).distance_to(pos)<350.0: return true
    return false
func _capacity() -> int:
    var n:=4
    for b in buildings:
        if b.type=="house": n+=2
    return n
func _face(v:Vector2,fallback:int) -> int:
    if v.length()<0.01: return fallback
    if absf(v.x)>absf(v.y): return 2 if v.x>0 else 1
    return 0 if v.y>0 else 3
func _night() -> bool:
    var h:=fmod(6.0+(day_time/DAY_SECONDS)*24.0,24.0); return h>=19.0 or h<5.0
func _cam() -> Vector2: return Vector2(clampf(player_pos.x-640,0,WORLD.x-1280),clampf(player_pos.y-360,0,WORLD.y-720))
func _screen(p:Vector2) -> Vector2: return p-_cam()
func _screen_world(p:Vector2) -> Vector2: return p+_cam()
func _visible(p:Vector2,m:=120.0) -> bool:
    var s:=_screen(p); return s.x>-m and s.x<SCREEN.x+m and s.y>-m and s.y<SCREEN.y+m
func _say(t:String) -> void: message=t; message_time=4.0
func _res_name(k:String) -> String: return "gỗ" if k=="wood" else ("đá" if k=="stone" else "thức ăn")
func _build_name(k:String) -> String: return "nhà" if k=="house" else ("kho" if k=="storage" else ("tháp canh" if k=="tower" else "cờ chiếm vùng"))

func _save_game() -> void:
    var data={"player":[player_pos.x,player_pos.y],"hp":player_hp,"hunger":player_hunger,"inventory":inventory,"day":day,"day_time":day_time,"territory":territory,"kills":kills,"storage":storage_bonus,"buildings":[]}
    for b in buildings: data.buildings.append({"type":b.type,"x":b.pos.x,"y":b.pos.y})
    var f:=FileAccess.open(SAVE_PATH,FileAccess.WRITE)
    if f: f.store_string(JSON.stringify(data))
func _load_game() -> void:
    if not FileAccess.file_exists(SAVE_PATH): return
    var f:=FileAccess.open(SAVE_PATH,FileAccess.READ)
    if not f: return
    var d=JSON.parse_string(f.get_as_text())
    if typeof(d)!=TYPE_DICTIONARY: return
    if d.has("player") and d.player.size()>=2: player_pos=Vector2(float(d.player[0]),float(d.player[1]))
    player_hp=float(d.get("hp",100)); player_hunger=float(d.get("hunger",88)); inventory=d.get("inventory",inventory); day=int(d.get("day",1)); day_time=float(d.get("day_time",0)); territory=float(d.get("territory",220)); kills=int(d.get("kills",0)); storage_bonus=int(d.get("storage",0))
    if d.has("buildings"):
        buildings.clear()
        for b in d.buildings: buildings.append({"type":String(b.type),"pos":Vector2(float(b.x),float(b.y))})
    _say("Đã tải tiến trình V0.3")

func _draw() -> void:
    _draw_map(); _draw_territory()
    for r in resources: _draw_resource(r)
    for b in buildings: _draw_building(b)
    for a in animals: _draw_animal(a)
    for v in villagers: _draw_villager(v)
    _draw_player(); _draw_night(); _draw_hud()

func _draw_map() -> void:
    draw_rect(Rect2(Vector2.ZERO,SCREEN),Color("#6e9f51"),true)
    var c:=_cam()
    for x in range(int(c.x/100)*100,int(c.x+SCREEN.x)+100,100):
        for y in range(int(c.y/100)*100,int(c.y+SCREEN.y)+100,100):
            var s:=Vector2(x,y)-c; draw_circle(s+Vector2(24,30),14,Color(0.1,0.3,0.12,0.07)); draw_line(s+Vector2(60,68),s+Vector2(64,56),Color(0.15,0.35,0.16,0.15),2)
    var road:=PackedVector2Array([_screen(Vector2(100,1300)),_screen(Vector2(480,1140)),_screen(Vector2(800,960)),_screen(HOME),_screen(Vector2(1450,650)),_screen(Vector2(1880,420))])
    draw_polyline(road,Color("#94784d"),110,true); draw_polyline(road,Color("#b79a63"),82,true)
    var river:=PackedVector2Array([_screen(Vector2(1900,-50)),_screen(Vector2(2050,230)),_screen(Vector2(1940,480)),_screen(Vector2(2090,760)),_screen(Vector2(1950,1050)),_screen(Vector2(2100,1550)),_screen(Vector2(2400,1550)),_screen(Vector2(2400,-50))])
    draw_colored_polygon(river,Color("#418ba1"))
    for y in range(80,1500,120):
        var p:=_screen(Vector2(2020+sin(y*0.01)*30,y)); draw_line(p+Vector2(-35,0),p+Vector2(35,0),Color(0.8,0.95,1,0.25),2)
    var wall:=PackedVector2Array([_screen(Vector2(330,510)),_screen(Vector2(520,470)),_screen(Vector2(710,500)),_screen(Vector2(880,455))]); draw_polyline(wall,Color("#555b58"),24,true); draw_polyline(wall,Color("#90928a"),14,true)

func _draw_territory() -> void:
    var s:=_screen(HOME); draw_circle(s,territory,Color(0.2,0.55,1,0.035)); draw_arc(s,territory,0,TAU,80,Color(0.7,0.87,1,0.25),2)

func _draw_resource(r:Dictionary) -> void:
    if int(r.amount)<=0 or not _visible(Vector2(r.pos)): return
    var s:=_screen(Vector2(r.pos)); var k:=String(r.type)
    if k=="wood":
        draw_rect(Rect2(s+Vector2(-7,5),Vector2(14,34)),Color("#6f4a2f")); draw_circle(s,27,Color("#2d6d3b")); draw_circle(s+Vector2(-18,-8),17,Color("#397f48")); draw_circle(s+Vector2(18,-6),16,Color("#397f48"))
    elif k=="stone":
