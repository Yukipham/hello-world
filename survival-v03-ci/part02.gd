        if event.keycode==KEY_F5: _save_game(); _say("Đã lưu game."); return
    if event is InputEventScreenTouch:
        if event.pressed:
            if attack_rect.has_point(event.position): _attack(); return
            if interact_rect.has_point(event.position): _interact(); return
            if build_rect.has_point(event.position): build_menu=not build_menu; build_mode=""; return
            if defend_rect.has_point(event.position): _defend(); return
            if build_menu:
                for i in range(build_rects.size()):
                    if build_rects[i].has_point(event.position): build_mode=["house","storage","tower","flag"][i]; build_menu=false; _say("Chạm mặt đất để đặt công trình."); return
            if build_mode!="" and event.position.x>320 and event.position.y>100: _build(_screen_world(event.position)); return
            if event.position.x<420 and event.position.y>330: joy_id=event.index; joy_origin=event.position; joy_knob=event.position; move_vec=Vector2.ZERO
        elif event.index==joy_id: joy_id=-1; move_vec=Vector2.ZERO; joy_origin=Vector2(145,575); joy_knob=joy_origin
    elif event is InputEventScreenDrag and event.index==joy_id:
        var d:=event.position-joy_origin
        if d.length()>JOY_R: d=d.normalized()*JOY_R
        joy_knob=joy_origin+d; move_vec=d/JOY_R
    elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and build_mode!="": _build(_screen_world(event.position))

func _attack() -> void:
    if player_dead>0.0 or player_attack_cd>0.0: return
    player_attack_cd=0.48; attack_fx=0.2
    var ai:=_nearest_animal(player_pos,120.0)
    if ai>=0:
        player_facing=_face(player_pos.direction_to(Vector2(animals[ai].pos)),player_facing); _damage_animal(ai,24.0,"player")
    else: _say("Không có thú trong tầm đánh.")

func _interact() -> void:
    var best:=-1; var dist:=92.0
    for i in range(resources.size()):
        if int(resources[i].amount)<=0: continue
        var d:=player_pos.distance_to(Vector2(resources[i].pos))
        if d<dist: dist=d; best=i
    if best>=0:
        var kind:=String(resources[best].type); resources[best].amount=int(resources[best].amount)-1; var gain:=2 if kind=="wood" else 1; inventory[kind]=int(inventory.get(kind,0))+gain; _say("Thu thập +%d %s"%[gain,_res_name(kind)]); return
    if player_pos.distance_to(HOME)<145.0 and player_hunger<92.0 and int(inventory.food)>0:
        inventory.food=int(inventory.food)-1; player_hunger=minf(100.0,player_hunger+32.0); player_hp=minf(100.0,player_hp+7.0); _say("Ăn ở lửa trại: hồi đói và sức khỏe."); return
    _say("Lại gần tài nguyên hoặc lửa trại.")

func _defend() -> void:
    rally_time=16.0; _say("PHÒNG THỦ: lính gác tập trung quanh bạn 16 giây.")

func _build(pos:Vector2) -> void:
    if not _owned(pos): _say("Chỉ xây được trong lãnh thổ."); return
    if pos.x>1900.0: _say("Không thể xây dưới sông."); return
    var cost:=_cost(build_mode)
    if int(inventory.wood)<cost.wood or int(inventory.stone)<cost.stone: _say("Thiếu gỗ hoặc đá."); return
    for b in buildings:
        if Vector2(b.pos).distance_to(pos)<95.0: _say("Vị trí quá chật."); return
    inventory.wood=int(inventory.wood)-cost.wood; inventory.stone=int(inventory.stone)-cost.stone; buildings.append({"type":build_mode,"pos":pos})
    if build_mode=="storage": storage_bonus+=25
    if build_mode=="flag": territory=minf(520.0,territory+65.0)
    if build_mode=="house" and villagers.size()<_capacity() and villagers.size()<7 and int(inventory.food)>=3:
        inventory.food=int(inventory.food)-3; var roles=["forager","lumber","guard"]; var names=["Dũng","Lan","Mai","Hải","Linh"]; villagers.append(_villager(pos+Vector2(30,30),names[villagers.size()%names.size()],roles[villagers.size()%roles.size()]))
    _say("Đã xây "+_build_name(build_mode)); build_mode=""; _save_game()

func _cost(kind:String) -> Dictionary:
    if kind=="house": return {"wood":12,"stone":6}
    if kind=="storage": return {"wood":14,"stone":10}
    if kind=="tower": return {"wood":18,"stone":12}
    return {"wood":15,"stone":10}

func _damage_player(dmg:float) -> void:
    if player_hit>0.0 or player_dead>0.0: return
    player_hp=maxf(0.0,player_hp-dmg); player_hit=0.4
    if player_hp<=0.0: player_dead=4.0; move_vec=Vector2.ZERO; _say("Bạn bị hạ. Dân làng đang đưa bạn về trại.")

func _damage_villager(i:int,dmg:float) -> void:
    if i<0 or i>=villagers.size(): return
    var v:Dictionary=villagers[i]
    if v.state=="down": return
    v.hp=maxf(0.0,float(v.hp)-dmg); v.hit=0.18
    if float(v.hp)<=0.0: v.state="down"; v.down=12.0; _say(String(v.name)+" bị thương nặng!")
    villagers[i]=v

func _damage_animal(i:int,dmg:float,source:String) -> void:
    if not _animal_alive(i): return
    var a:Dictionary=animals[i]; a.hp=maxf(0.0,float(a.hp)-dmg); a.hit=0.16
    if float(a.hp)<=0.0:
        kills+=1; inventory.food=int(inventory.food)+(3 if a.type=="boar" else 2); inventory.hide=int(inventory.hide)+1; a.state="dead"; _say("Săn được %s: +thức ăn +da"%("heo rừng" if a.type=="boar" else "sói"))
    elif source=="player": a.state="attack"; a.target_kind="player"; a.target=-1
    animals[i]=a

func _animal_target(pos:Vector2,radius:float) -> Dictionary:
    var best:=radius+1.0; var out:Dictionary={}
    if player_dead<=0.0:
        var d:=pos.distance_to(player_pos)
        if d<best: best=d; out={"kind":"player","index":-1}
    for i in range(villagers.size()):
        if float(villagers[i].hp)<=0.0: continue
        var d:=pos.distance_to(Vector2(villagers[i].pos))
        if d<best: best=d; out={"kind":"villager","index":i}
    return out

func _target_pos(a:Dictionary) -> Vector2:
    if a.target_kind=="player" and player_dead<=0.0: return player_pos
    var i:=int(a.target)
