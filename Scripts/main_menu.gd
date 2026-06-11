extends Control

var initial_title_y: float

func _on_startbutton_pressed() -> void:
	GameManager.is_tutorial_mode = false
	print("开始游戏！")
	get_tree().change_scene_to_file("res://Scenes/character_selection.tscn")

func _on_tutorialbutton_pressed() -> void:
	GameManager.is_tutorial_mode = true
	get_tree().change_scene_to_file("res://Scenes/character_selection.tscn")

func _on_upgradebutton_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/upgrade_menu.tscn")

func _on_exitbutton_pressed() -> void:
	get_tree().quit()

func _ready():
	var bgm = preload("res://Assets/Music/Cubicle_Coffee.mp3")
	BgmManager.play_music(bgm)
	initial_title_y = $Label.position.y
	animate_title()
	_resize()

func _resize():
	var screen_size = get_viewport_rect().size
	var base_width = 1080.0
	var base_height = 1920.0
	var scale_factor = min(screen_size.x / base_width, screen_size.y / base_height)
	$Label.label_settings.font_size = int(120 * scale_factor)
	$VBoxContainer.add_theme_constant_override("separation", int(80 * scale_factor))
	_scale_falling_items(scale_factor)
	apply_css_to_buttons(scale_factor)

func _scale_falling_items(scale_factor: float):
	var base_data = {
		"FallingItem":  {"pos": Vector2(244, 391),  "scale": 0.29},
		"FallingItem2": {"pos": Vector2(206, 988),  "scale": 0.29},
		"FallingItem3": {"pos": Vector2(576, 880),  "scale": 0.29},
		"FallingItem4": {"pos": Vector2(581, 569),  "scale": 0.67},
		"FallingItem5": {"pos": Vector2(150, 582),  "scale": 0.60},
		"FallingItem6": {"pos": Vector2(623, 283),  "scale": 0.52},
	}
	for item_name in base_data:
		var node = get_node(item_name)
		var d = base_data[item_name]
		node.position = d["pos"] * scale_factor
		var s = d["scale"] * scale_factor
		node.scale = Vector2(s, s)

func apply_css_to_buttons(scale_factor: float = 1.0):
	var buttons = []
	for btn in $VBoxContainer.get_children():
		if btn is Button:
			buttons.append(btn)

	for btn in buttons:
		var font_size = int(55 * scale_factor)
		var btn_width = int(500 * scale_factor)
		var btn_height = int(130 * scale_factor)
		var icon_size = int(65 * scale_factor)
		var h_sep = int(20 * scale_factor)
		var margin_l = int(40 * scale_factor)
		var margin_r = int(20 * scale_factor)

		var style_normal = _create_style("#fdf5e6", 30, 8, margin_l, margin_r)
		var style_hover = _create_style("#a8d8ea", 30, 12, margin_l, margin_r)
		var style_pressed = _create_style("#7fb5c9", 30, 0, margin_l, margin_r)

		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_pressed)

		btn.add_theme_color_override("font_color", Color("#4a4a4a"))
		btn.add_theme_color_override("font_hover_color", Color("#ffffff"))
		btn.add_theme_font_size_override("font_size", font_size)

		btn.custom_minimum_size = Vector2(btn_width, btn_height)
		btn.pivot_offset = btn.custom_minimum_size / 2.0
		btn.add_theme_constant_override("icon_max_width", icon_size)
		btn.add_theme_constant_override("h_separation", h_sep)

		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.expand_icon = true

		btn.add_theme_color_override("icon_normal_color", Color("#4a4a4a"))
		btn.add_theme_color_override("icon_hover_color", Color("#ffffff"))

		btn.mouse_entered.connect(func():
			create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).tween_property(btn, "scale", Vector2(1.05, 1.05), 0.2)
		)
		btn.mouse_exited.connect(func():
			create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2)
		)

		if btn.name == "startbutton":
			btn.icon = preload("res://Assets/Icons/start.png")
		elif btn.name == "exitbutton":
			btn.icon = preload("res://Assets/Icons/exit.png")
		elif btn.name == "upgradebutton":
			btn.icon = preload("res://Assets/Icons/upgrade.png")
		elif btn.name == "tutorialbutton":
			btn.icon = preload("res://Assets/Icons/tutorial.png")

func _create_style(color_hex: String, radius: int, shadow: int, margin_l: int = 40, margin_r: int = 20) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(color_hex)
	sb.set_corner_radius_all(radius)
	sb.shadow_size = shadow
	sb.shadow_offset = Vector2(0, shadow / 2.0)
	sb.content_margin_left = margin_l
	sb.content_margin_right = margin_r
	return sb

func animate_title():
	var title = $Label
	await get_tree().process_frame
	title.pivot_offset = title.size / 2.0

	var tween_scale = create_tween().set_loops()
	tween_scale.tween_property(title, "scale", Vector2(1.08, 1.08), 2.0).set_trans(Tween.TRANS_SINE)
	tween_scale.tween_property(title, "scale", Vector2(1.0, 1.0), 2.0).set_trans(Tween.TRANS_SINE)

	var tween_rot = create_tween().set_loops()
	tween_rot.tween_property(title, "rotation_degrees", 3.0, 1.8).set_trans(Tween.TRANS_SINE)
	tween_rot.tween_property(title, "rotation_degrees", -3.0, 1.8).set_trans(Tween.TRANS_SINE)

func _process(_delta):
	var time = Time.get_ticks_msec() / 1000.0
	$Label.position.y = initial_title_y + sin(time * 1.5) * 15