extends Node2D

func _draw() -> void:
    # ── 碟子 ──
    draw_ellipse(Vector2(0, 100), Vector2(90, 13), Color("#ddd5c8"), true)
    draw_ellipse(Vector2(0, 100), Vector2(90, 13), Color("#3a3530"), false, 2.5)

    # ── 杯身（上窄下宽） ──
    var cup = PackedVector2Array([
        Vector2(-65, -38),   # 左上
        Vector2( 65, -38),   # 右上
        Vector2( 90,  92),   # 右下
        Vector2(-90,  92),   # 左下
    ])
    draw_colored_polygon(cup, Color("#eee8df"))
    draw_polyline(cup, Color("#3a3530"), 3.0, true)

    # ── 杯口椭圆 ──
    draw_ellipse(Vector2(0, -38), Vector2(65, 10), Color("#d4c9bc"), true)
    draw_ellipse(Vector2(0, -38), Vector2(65, 10), Color("#3a3530"), false, 2.5)

    # ── 把手（贴着杯右侧） ──
    draw_arc(Vector2(112, 28), 40, deg_to_rad(-80), deg_to_rad(80), 32, Color("#3a3530"), 9.0)
    draw_arc(Vector2(112, 28), 32, deg_to_rad(-75), deg_to_rad(75), 32, Color("#b5a898"), 5.0)

    # ── 杯身高光 ──
    draw_line(Vector2(-58, -20), Vector2(-50, 55), Color(1, 1, 1, 0.65), 5.0, true)
    draw_line(Vector2(-46, -28), Vector2(-42, -10), Color(1, 1, 1, 0.45), 3.0, true)

func draw_ellipse(center: Vector2, radius: Vector2, color: Color, filled: bool, width: float = 1.0) -> void:
    var points = PackedVector2Array()
    for i in range(49):
        var angle = (float(i) / 48) * TAU
        points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
    if filled:
        draw_colored_polygon(points, color)
    else:
        draw_polyline(points, color, width, true)