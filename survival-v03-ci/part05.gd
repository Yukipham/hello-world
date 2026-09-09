    draw_rect(Rect2(14,12,305,112),Color(0.03,0.04,0.04,0.87)); _text(Vector2(28,37),"NHÂN VẬT",17,Color("#f1d993")); _bar(Rect2(28,48,270,18),player_hp/100.0,Color("#c84942"),"HP %d/100"%int(player_hp)); _bar(Rect2(28,76,270,16),player_hunger/100.0,Color("#d1a341"),"NO %d/100"%int(player_hunger)); _text(Vector2(28,113),"Dân %d/%d   Hạ thú %d"%[villagers.size(),_capacity(),kills],15)
    draw_rect(Rect2(340,12,520,58),Color(0.03,0.04,0.04,0.83)); _text(Vector2(360,48),"Gỗ %d   Đá %d   Thức ăn %d   Da %d"%[inventory.wood,inventory.stone,inventory.food,inventory.hide],19)
    var h:=fmod(6.0+(day_time/DAY_SECONDS)*24.0,24.0); var hh:=int(h); var mm:=int((h-hh)*60); draw_rect(Rect2(880,12,385,76),Color(0.03,0.04,0.04,0.86)); _text(Vector2(898,42),"Ngày %d   %02d:%02d   %s"%[day,hh,mm,"ĐÊM" if _night() else "BAN NGÀY"],20,Color("#f0dc9e")); _text(Vector2(898,70),"Vùng %dm • Kho +%d"%[int(territory),storage_bonus],16)
    draw_rect(Rect2(14,140,280,190),Color(0.03,0.04,0.04,0.77)); _text(Vector2(28,167),"MỤC TIÊU",17,Color("#f0d064")); _quest(Vector2(28,194),_count("house")>=1,"Xây 1 nhà"); _quest(Vector2(28,220),_count("tower")>=1,"Xây 1 tháp canh"); _quest(Vector2(28,246),kills>=2,"Săn 2 thú hoang"); _quest(Vector2(28,272),day>=3,"Sống tới ngày 3"); _quest(Vector2(28,298),territory>=300,"Mở vùng 300m")
    draw_circle(joy_origin,JOY_R,Color(0.02,0.02,0.02,0.4)); draw_circle(joy_origin,JOY_R,Color(1,1,1,0.25),false,4); draw_circle(joy_knob,44,Color(0.85,0.9,0.9,0.58)); _button(attack_rect,"TẤN CÔNG",Color("#9d4039"),true); _button(interact_rect,"TƯƠNG TÁC",Color("#4f7b55"),false); _button(build_rect,"XÂY DỰNG",Color("#a46f35"),build_menu or build_mode!=""); _button(defend_rect,"PHÒNG THỦ",Color("#41678f"),rally_time>0)
    if build_menu:
        draw_rect(Rect2(380,555,655,135),Color(0.02,0.025,0.025,0.92)); var labs=["NHÀ\n12G 6Đ","KHO\n14G 10Đ","THÁP\n18G 12Đ","CỜ\n15G 10Đ"]
        for i in range(build_rects.size()): draw_rect(build_rects[i],Color("#26382f")); _text(build_rects[i].position+Vector2(12,30),labs[i].split("\n")[0],16,Color("#f0d27b")); _text(build_rects[i].position+Vector2(12,58),labs[i].split("\n")[1],14)
    if message_time>0:
        var w:=minf(850.0,80.0+message.length()*9.0); var r:=Rect2(640-w/2,102,w,46); draw_rect(r,Color(0.02,0.025,0.025,0.88)); _text(r.position+Vector2(16,30),message,17)
func _bar(r:Rect2,val:float,c:Color,label:String) -> void: draw_rect(r,Color(0.08,0.08,0.08,0.9)); draw_rect(Rect2(r.position+Vector2(2,2),Vector2((r.size.x-4)*clampf(val,0,1),r.size.y-4)),c); _text(r.position+Vector2(8,r.size.y-4),label,13)
func _button(r:Rect2,label:String,c:Color,on:bool) -> void: draw_rect(r,c.lightened(0.12) if on else c); draw_rect(r,Color(1,1,1,0.35),false,3); _text(r.position+Vector2(16,r.size.y/2+6),label,17)
func _quest(p:Vector2,done:bool,label:String) -> void: _text(p,"✓" if done else "□",17,Color("#72dc7b") if done else Color.WHITE); _text(p+Vector2(25,0),label,15)
func _count(k:String) -> int:
    var n:=0
    for b in buildings:
        if b.type==k: n+=1
    return n
func _text(p:Vector2,t:String,size:int,c:=Color.WHITE) -> void: draw_string(ThemeDB.fallback_font,p,t,HORIZONTAL_ALIGNMENT_LEFT,-1,size,c)
