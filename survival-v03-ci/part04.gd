        var pts:=PackedVector2Array([s+Vector2(-26,16),s+Vector2(-15,-16),s+Vector2(13,-23),s+Vector2(28,8),s+Vector2(8,25)]); draw_colored_polygon(pts,Color("#777d7d")); draw_polyline(PackedVector2Array([pts[0],pts[1],pts[2],pts[3],pts[4],pts[0]]),Color("#4d5253"),3)
    else:
        draw_circle(s,22,Color("#326b39"));
        for o in [Vector2(-10,-7),Vector2(8,-10),Vector2(6,8),Vector2(-8,9)]: draw_circle(s+o,5,Color("#b93645"))

func _draw_building(b:Dictionary) -> void:
    if not _visible(Vector2(b.pos),160): return
    var s:=_screen(Vector2(b.pos)); var k:=String(b.type)
    if k=="campfire":
        draw_line(s+Vector2(-18,16),s+Vector2(18,-8),Color("#674329"),6); draw_line(s+Vector2(-18,-8),s+Vector2(18,16),Color("#674329"),6); draw_colored_polygon(PackedVector2Array([s+Vector2(0,-32),s+Vector2(-16,10),s,s+Vector2(18,10)]),Color("#ef6b2f")); draw_colored_polygon(PackedVector2Array([s+Vector2(0,-20),s+Vector2(-7,9),s+Vector2(9,8)]),Color("#ffd04a"))
    elif k=="house": _house(s,Color("#a85f42"))
    elif k=="storage": _house(s,Color("#6f5139"))
    elif k=="tower":
        draw_rect(Rect2(s-Vector2(35,48),Vector2(70,58)),Color("#815b3b")); draw_rect(Rect2(s-Vector2(43,57),Vector2(86,16)),Color("#a67a4c")); draw_line(s+Vector2(-24,10),s+Vector2(-24,45),Color("#66452e"),7); draw_line(s+Vector2(24,10),s+Vector2(24,45),Color("#66452e"),7)
    else:
        draw_line(s+Vector2(0,25),s+Vector2(0,-48),Color("#564331"),6); draw_colored_polygon(PackedVector2Array([s+Vector2(3,-46),s+Vector2(48,-35),s+Vector2(3,-18)]),Color("#e0ad3d"))
func _house(s:Vector2,roof:Color) -> void:
    draw_rect(Rect2(s-Vector2(42,30),Vector2(84,60)),Color("#c39b63")); draw_colored_polygon(PackedVector2Array([s+Vector2(-50,-30),s+Vector2(0,-65),s+Vector2(50,-30)]),roof); draw_rect(Rect2(s+Vector2(-9,4),Vector2(18,26)),Color("#654730"))

func _draw_player() -> void:
    var s:=_screen(player_pos)
    if player_dead>0.0: _text(s+Vector2(-45,-20),"Hồi sinh %.1f"%player_dead,16,Color("#ffd0b0")); return
    _human(s,player_facing,move_vec.length()>0.04,Color("#376596"),Color("#5b3b2c"),player_hit>0.0,true); _hpbar(s+Vector2(-30,-48),60,player_hp/100.0,Color("#d64d43"))
    if attack_fx>0.0:
        var dirs=[Vector2(0,1),Vector2(-1,0),Vector2(1,0),Vector2(0,-1)]; draw_arc(s+dirs[player_facing]*46,36,-1.5,1.5,16,Color(1,0.9,0.6,0.9),5)

func _draw_villager(v:Dictionary) -> void:
    if not _visible(Vector2(v.pos),80): return
    var s:=_screen(Vector2(v.pos))
    if v.state=="down": draw_rect(Rect2(s-Vector2(22,8),Vector2(44,16)),Color("#69584a")); _text(s+Vector2(-25,-16),"bị thương",11); return
    var col:=Color("#3f6f9e") if v.role=="guard" else (Color("#8b6f3e") if v.role=="lumber" else Color("#765542")); _human(s,int(v.face),bool(v.moving),col,Color("#5a4335"),float(v.hit)>0.0,v.role=="guard"); _hpbar(s+Vector2(-24,-42),48,float(v.hp)/float(v.max_hp),Color("#5fc36d")); _text(s+Vector2(-24,-48),String(v.name),11)

func _human(s:Vector2,face:int,moving:bool,shirt:Color,hair:Color,hit:bool,weapon:bool) -> void:
    var frame:=int(anim_time*8)%4 if moving else 0; var bob:float=[0.0,1.5,0.0,-1.5][frame]; var step:float=[-3.0,2.0,3.0,-2.0][frame]
    draw_ellipse_shadow(s+Vector2(0,25)); var skin:=Color("#dfb982") if not hit else Color("#ff7770")
    draw_rect(Rect2(s+Vector2(-10+step,12+bob),Vector2(7,20)),Color("#3f4142")); draw_rect(Rect2(s+Vector2(4-step,12+bob),Vector2(7,20)),Color("#3f4142")); draw_rect(Rect2(s+Vector2(-13,0+bob),Vector2(26,22)),shirt); draw_circle(s+Vector2(0,-12+bob),13,skin); draw_arc(s+Vector2(0,-13+bob),13,PI,TAU,16,hair,6)
    if face==1: draw_circle(s+Vector2(-8,-12+bob),2,Color("#252525"))
    elif face==2: draw_circle(s+Vector2(8,-12+bob),2,Color("#252525"))
    elif face==0: draw_circle(s+Vector2(-5,-10+bob),1.8,Color("#252525")); draw_circle(s+Vector2(5,-10+bob),1.8,Color("#252525"))
    if weapon: draw_line(s+Vector2(13,5+bob),s+Vector2(26,-12+bob),Color("#e9eded"),4); draw_line(s+Vector2(11,7+bob),s+Vector2(18,12+bob),Color("#795033"),3)
func draw_ellipse_shadow(s:Vector2) -> void:
    draw_set_transform(s,0,Vector2(1.7,0.65)); draw_circle(Vector2.ZERO,12,Color(0,0,0,0.2)); draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func _draw_animal(a:Dictionary) -> void:
    if float(a.hp)<=0.0 or not _visible(Vector2(a.pos),80): return
    var s:=_screen(Vector2(a.pos)); var frame:=int(anim_time*(9 if a.type=="wolf" else 7))%4 if bool(a.moving) else 0; var bob:float=[0.0,1.0,0.0,-1.0][frame]; var base:=Color("#70777c") if a.type=="wolf" else Color("#754b38"); if float(a.hit)>0.0: base=Color("#e46b63")
    draw_set_transform(s+Vector2(0,16),0,Vector2(1.7,0.6)); draw_circle(Vector2.ZERO,13,Color(0,0,0,0.2)); draw_set_transform(Vector2.ZERO,0,Vector2.ONE); draw_ellipse_body(s+Vector2(0,bob),base,a.type=="wolf",int(a.face)); _hpbar(s+Vector2(-28,-32),56,float(a.hp)/float(a.max_hp),Color("#d05b4e"))
func draw_ellipse_body(s:Vector2,c:Color,wolf:bool,face:int) -> void:
    draw_set_transform(s,0,Vector2(1.55,0.85)); draw_circle(Vector2.ZERO,15,c); draw_set_transform(Vector2.ZERO,0,Vector2.ONE); var hx:=0.0; var hy:=0.0
    if face==1: hx=-24
    elif face==2: hx=24
    elif face==0: hy=14
    else: hy=-14
    draw_circle(s+Vector2(hx,hy),10,c.darkened(0.08)); if wolf: draw_colored_polygon(PackedVector2Array([s+Vector2(hx-7,hy-5),s+Vector2(hx-4,hy-16),s+Vector2(hx,hy-5)]),c.darkened(0.2)); draw_colored_polygon(PackedVector2Array([s+Vector2(hx+2,hy-5),s+Vector2(hx+5,hy-16),s+Vector2(hx+9,hy-5)]),c.darkened(0.2))

func _hpbar(p:Vector2,w:float,r:float,c:Color) -> void: draw_rect(Rect2(p,Vector2(w,6)),Color(0.03,0.03,0.03,0.8)); draw_rect(Rect2(p+Vector2(1,1),Vector2((w-2)*clampf(r,0,1),4)),c)
func _draw_night() -> void:
    var h:=fmod(6.0+(day_time/DAY_SECONDS)*24.0,24.0); var a:=0.0
    if h>=19: a=minf(0.30,(h-19)/3.0*0.30)
    elif h<5: a=0.30
    elif h<7: a=(7-h)/2*0.30
    if a>0: draw_rect(Rect2(Vector2.ZERO,SCREEN),Color(0.03,0.06,0.16,a))

func _draw_hud() -> void:
