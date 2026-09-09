        if v.state=="fight":
            var ai:=int(v.animal)
            if not _animal_alive(ai): v.state="patrol" if v.role=="guard" else "search"
            else:
                var ap:=Vector2(animals[ai].pos); var d:=Vector2(v.pos).distance_to(ap)
                if d<62.0:
                    if float(v.attack)<=0.0:
                        _damage_animal(ai,13.0 if v.role=="guard" else 7.0,"villager"); v.attack=0.85 if v.role=="guard" else 1.2
                else:
                    var dir:=Vector2(v.pos).direction_to(ap); v.pos=Vector2(v.pos)+dir*(VILLAGER_SPEED+(20 if v.role=="guard" else 0))*delta; v.face=_face(dir,int(v.face)); v.moving=true
        elif v.role=="guard":
            v.angle=float(v.angle)+delta*0.25
            var center:=player_pos if rally_time>0.0 else HOME
            var dest:=center+Vector2(cos(float(v.angle)),sin(float(v.angle)))*105.0
            if Vector2(v.pos).distance_to(dest)>18.0:
                var dir:=Vector2(v.pos).direction_to(dest); v.pos=Vector2(v.pos)+dir*VILLAGER_SPEED*delta; v.face=_face(dir,int(v.face)); v.moving=true
        else:
            _worker(v,delta)
        if Vector2(v.pos).distance_to(HOME)<160.0: v.hp=minf(float(v.max_hp),float(v.hp)+delta*0.25)
        villagers[i]=v

func _worker(v:Dictionary,delta:float) -> void:
    if v.state=="search":
        v.target=_pick_resource(String(v.pref),Vector2(v.pos)); v.state="move" if int(v.target)>=0 else "rest"; v.timer=0.8
    elif v.state=="move":
        var ti:=int(v.target)
        if not _resource_ok(ti): v.state="search"
        else:
            var p:=Vector2(resources[ti].pos)
            if Vector2(v.pos).distance_to(p)<34.0: v.state="work"; v.timer=0.9
            else:
                var dir:=Vector2(v.pos).direction_to(p); v.pos=Vector2(v.pos)+dir*VILLAGER_SPEED*delta; v.face=_face(dir,int(v.face)); v.moving=true
    elif v.state=="work":
        v.timer=float(v.timer)-delta
        if float(v.timer)<=0.0:
            var ti:=int(v.target)
            if _resource_ok(ti):
                var kind:=String(resources[ti].type); resources[ti].amount=int(resources[ti].amount)-1; inventory[kind]=int(inventory.get(kind,0))+1
            v.state="return"
    elif v.state=="return":
        if Vector2(v.pos).distance_to(HOME)<75.0: v.state="rest"; v.timer=0.7
        else:
            var dir:=Vector2(v.pos).direction_to(HOME); v.pos=Vector2(v.pos)+dir*VILLAGER_SPEED*delta; v.face=_face(dir,int(v.face)); v.moving=true
    else:
        v.timer=float(v.timer)-delta
        if float(v.timer)<=0.0: v.state="search"

func _update_animals(delta:float) -> void:
    for i in range(animals.size()):
        var a:Dictionary=animals[i]
        if float(a.hp)<=0.0: continue
        a.attack=maxf(0.0,float(a.attack)-delta); a.hit=maxf(0.0,float(a.hit)-delta); a.moving=false
        var radius:=420.0 if a.type=="wolf" and _night() else (260.0 if a.type=="wolf" else 125.0)
        if float(a.hp)<float(a.max_hp): radius=480.0
        var t:=_animal_target(Vector2(a.pos),radius)
        if not t.is_empty(): a.target_kind=t.kind; a.target=t.index; a.state="attack"
        if a.state=="attack":
            var tp:=_target_pos(a)
            if tp.x<0.0: a.state="roam"
            elif Vector2(a.pos).distance_to(tp)<48.0:
                if float(a.attack)<=0.0:
                    if a.target_kind=="player": _damage_player(10.0 if a.type=="wolf" else 14.0)
                    else: _damage_villager(int(a.target),10.0 if a.type=="wolf" else 14.0)
                    a.attack=1.05 if a.type=="wolf" else 1.35
            else:
                var dir:=Vector2(a.pos).direction_to(tp); a.pos=Vector2(a.pos)+dir*(128.0 if a.type=="wolf" else 92.0)*delta; a.face=_face(dir,int(a.face)); a.moving=true
        else:
            a.roam=float(a.roam)-delta
            if float(a.roam)<=0.0 or Vector2(a.pos).distance_to(Vector2(a.roam_pos))<15.0:
                a.roam=rng.randf_range(2.0,4.5); a.roam_pos=Vector2(clampf(float(a.pos.x)+rng.randf_range(-220,220),70,WORLD.x-70),clampf(float(a.pos.y)+rng.randf_range(-180,180),70,WORLD.y-70))
                if a.roam_pos.x>1900.0: a.roam_pos.x=1880.0
            var dir:=Vector2(a.pos).direction_to(Vector2(a.roam_pos)); a.pos=Vector2(a.pos)+dir*(62.0 if a.type=="wolf" else 50.0)*delta; a.face=_face(dir,int(a.face)); a.moving=true
        animals[i]=a

func _update_towers(delta:float) -> void:
    tower_tick += delta
    if tower_tick<1.3: return
    tower_tick=0.0
    for b in buildings:
        if b.type=="tower":
            var ai:=_nearest_animal(Vector2(b.pos),255.0)
            if ai>=0: _damage_animal(ai,10.0,"tower")

func _update_world(delta:float) -> void:
    respawn_time+=delta
    if respawn_time>=14.0:
        respawn_time=0.0
        for r in resources:
            if int(r.amount)<int(r.max): r.amount=int(r.amount)+1; break
    day_time+=delta
    if day_time>=DAY_SECONDS:
        day_time-=DAY_SECONDS; day+=1
        var need:=1+villagers.size()
        if int(inventory.food)>=need: inventory.food=int(inventory.food)-need; _say("Ngày %d: cả làng dùng %d thức ăn."%[day,need])
        else:
            inventory.food=0; _say("Thiếu lương thực! Dân làng mất sức khỏe.")
            for i in range(villagers.size()): _damage_villager(i,7.0)
    spawn_time+=delta
    if spawn_time>=(18.0 if _night() else 30.0):
        spawn_time=0.0
        var living:=0
        for a in animals:
            if float(a.hp)>0.0: living+=1
        if living<8: _spawn_animal("wolf" if _night() or rng.randf()<0.55 else "boar",Vector2(rng.randf_range(120,1800),rng.randf_range(100,WORLD.y-100)))

func _input(event:InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode==KEY_SPACE: _attack(); return
        if event.keycode==KEY_E: _interact(); return
        if event.keycode==KEY_B: build_menu=not build_menu; return
        if event.keycode==KEY_Q: _defend(); return
