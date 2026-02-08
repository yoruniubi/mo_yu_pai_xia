extends Control

var is_skipping = false

func _ready():
	print("!!! Splash screen started !!!")
	$Logo.modulate.a = 0
	
	var tween = create_tween()
	# 淡入
	tween.tween_property($Logo, "modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE)
	# 停留
	tween.tween_interval(1.0)
	# 淡出
	tween.tween_property($Logo, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE)
	
	tween.finished.connect(_on_splash_finished)

func _on_splash_finished():
	if is_skipping: return
	is_skipping = true
	print("!!! Splash finished, changing to main_menu !!!")
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

func _input(event):
	if event is InputEventMouseButton or event is InputEventKey:
		if event.pressed and not is_skipping:
			_on_splash_finished()
