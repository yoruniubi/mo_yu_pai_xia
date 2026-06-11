# SteamWisp.gd
extends Node2D

func _draw() -> void:
    # 画一条波浪形热气线
    var points = PackedVector2Array()
    for i in range(40):
        var t = float(i) / 39.0
        var x = sin(t * PI * 2.5) * 18.0   # 左右摆动幅度
        var y = -t * 120.0                   # 向上120px
        points.append(Vector2(x, y))
    draw_polyline(points, Color("#e8a84a", 0.88), 6.0, true)