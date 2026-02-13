extends Control

@onready var fullscreen_check = %FullscreenCheck
@onready var master_slider = %MasterSlider
@onready var master_value = %MasterValue
@onready var bgm_slider = %BgmSlider
@onready var bgm_value = %BgmValue
@onready var resolution_option = %ResolutionOption
@onready var save_button = %SaveButton
@onready var back_button = %BackButton

var resolution_values := [
	Vector2i(720, 1280),
	Vector2i(900, 1600),
	Vector2i(1080, 1920),
	Vector2i(1280, 720),
	Vector2i(1600, 900)
]

func _ready() -> void:
	_setup_style()
	_setup_options()
	_load_settings()
	_setup_signals()

func _setup_style() -> void:
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("#fff8e8")
	panel_style.set_corner_radius_all(26)
	panel_style.shadow_size = 12
	panel_style.shadow_offset = Vector2(0, 6)
	panel_style.shadow_color = Color(0, 0, 0, 0.18)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color("#e6d7b8")
	panel_style.content_margin_left = 30
	panel_style.content_margin_right = 30
	panel_style.content_margin_top = 26
	panel_style.content_margin_bottom = 26
	$Panel.add_theme_stylebox_override("panel", panel_style)

	_apply_button_style(save_button, Color("#8fb9aa"), Color("#6fa597"), Color("#4e8b7d"))
	_apply_button_style(back_button, Color("#f5c2c7"), Color("#f2a6ad"), Color("#e98993"))

	_apply_option_style(resolution_option)
	_apply_checkbox_style(fullscreen_check)
	_apply_slider_style(master_slider)
	_apply_slider_style(bgm_slider)
	_apply_label_style($Panel)

func _setup_options() -> void:
	resolution_option.clear()
	for res in resolution_values:
		resolution_option.add_item("%d x %d" % [res.x, res.y])

func _apply_button_style(button: Button, base: Color, hover: Color, pressed: Color) -> void:
	var normal = _create_button_style(base)
	var hover_style = _create_button_style(hover)
	var pressed_style = _create_button_style(pressed)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_color_override("font_color", Color("#3b3b3b"))
	button.add_theme_color_override("font_hover_color", Color.BLACK)

func _create_button_style(color: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(18)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	sb.shadow_color = Color(0, 0, 0, 0.2)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.border_width_bottom = 2
	sb.border_color = Color(0, 0, 0, 0.08)
	return sb

func _apply_option_style(option: OptionButton) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color("#ffffff7f")
	sb.set_corner_radius_all(12)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color("#d9c9a8")
	option.add_theme_stylebox_override("normal", sb)
	option.add_theme_stylebox_override("hover", sb)
	option.add_theme_stylebox_override("pressed", sb)
	option.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	option.add_theme_color_override("font_color", Color("#3b3b3b"))
	option.add_theme_color_override("font_hover_color", Color("#3b3b3b"))
	option.add_theme_color_override("font_pressed_color", Color("#3b3b3b"))
	option.add_theme_color_override("font_color_pressed", Color("#3b3b3b"))
	option.add_theme_color_override("font_color_hover_pressed", Color("#3b3b3b"))
	option.add_theme_color_override("font_focus_color", Color("#3b3b3b"))
	option.add_theme_color_override("font_disabled_color", Color("#3b3b3b"))
	option.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.6))
	option.add_theme_constant_override("outline_size", 1)
	option.add_theme_font_size_override("font_size", 22)
	_apply_option_popup_style(option)

func _apply_option_popup_style(option: OptionButton) -> void:
	var popup = option.get_popup()
	popup.transparent_bg = true
	popup.borderless = true
	var popup_panel = StyleBoxFlat.new()
	popup_panel.bg_color = Color("#fff8e8")
	popup_panel.set_corner_radius_all(10)
	popup_panel.border_width_left = 2
	popup_panel.border_width_top = 2
	popup_panel.border_width_right = 2
	popup_panel.border_width_bottom = 2
	popup_panel.border_color = Color("#e6d7b8")
	popup.add_theme_stylebox_override("panel", popup_panel)
	popup.add_theme_stylebox_override("panel_window", popup_panel)
	popup.add_theme_stylebox_override("popup", popup_panel)
	popup.add_theme_stylebox_override("focus", popup_panel)
	popup.add_theme_stylebox_override("panel_focus", popup_panel)
	popup.add_theme_stylebox_override("menu_panel", popup_panel)
	popup.add_theme_stylebox_override("menu_bg", popup_panel)
	popup.add_theme_stylebox_override("menu_panel_focus", popup_panel)

	var popup_hover = StyleBoxFlat.new()
	popup_hover.bg_color = Color("#f2e6cf")
	popup_hover.set_corner_radius_all(8)
	popup.add_theme_stylebox_override("hover", popup_hover)
	popup.add_theme_stylebox_override("checked", popup_hover)
	popup.add_theme_stylebox_override("checked_disabled", popup_hover)
	popup.add_theme_stylebox_override("radio_checked", popup_hover)
	popup.add_theme_stylebox_override("radio_checked_disabled", popup_hover)

	popup.add_theme_color_override("font_color", Color("#3b3b3b"))
	popup.add_theme_color_override("font_hover_color", Color("#3b3b3b"))
	popup.add_theme_color_override("font_pressed_color", Color("#3b3b3b"))
	popup.add_theme_color_override("font_disabled_color", Color("#3b3b3b"))
	popup.add_theme_color_override("font_color_accel", Color("#3b3b3b"))
	popup.add_theme_color_override("font_color_accel_hover", Color("#3b3b3b"))
	popup.add_theme_color_override("font_color_separator", Color("#3b3b3b"))

func _on_resolution_popup_opened() -> void:
	resolution_option.add_theme_color_override("font_color", Color("#3b3b3b"))
	resolution_option.add_theme_color_override("font_color_pressed", Color("#3b3b3b"))
	resolution_option.add_theme_color_override("font_color_hover_pressed", Color("#3b3b3b"))

func _on_resolution_popup_closed() -> void:
	resolution_option.add_theme_color_override("font_color", Color("#3b3b3b"))

func _apply_checkbox_style(checkbox: CheckBox) -> void:
	checkbox.add_theme_color_override("font_color", Color("#3b3b3b"))
	checkbox.add_theme_font_size_override("font_size", 22)

func _apply_slider_style(slider: HSlider) -> void:
	var grab = StyleBoxFlat.new()
	grab.bg_color = Color("#8fb9aa")
	grab.set_corner_radius_all(8)
	grab.content_margin_left = 6
	grab.content_margin_right = 6
	grab.content_margin_top = 6
	grab.content_margin_bottom = 6

	var track = StyleBoxFlat.new()
	track.bg_color = Color("#e7dbc4")
	track.set_corner_radius_all(6)
	track.content_margin_left = 6
	track.content_margin_right = 6
	track.content_margin_top = 4
	track.content_margin_bottom = 4

	slider.add_theme_stylebox_override("grabber", grab)
	slider.add_theme_stylebox_override("grabber_highlight", grab)
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("slider_focus", track)

func _apply_label_style(root: Node) -> void:
	for child in root.get_children():
		if child is Label:
			child.add_theme_color_override("font_color", Color("#3b3b3b"))
			child.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.45))
			child.add_theme_constant_override("outline_size", 1)
		_apply_label_style(child)

func _setup_signals() -> void:
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	master_slider.value_changed.connect(_on_master_volume_changed)
	bgm_slider.value_changed.connect(_on_bgm_volume_changed)
	resolution_option.item_selected.connect(_on_resolution_selected)
	resolution_option.get_popup().about_to_popup.connect(_on_resolution_popup_opened)
	resolution_option.get_popup().popup_hide.connect(_on_resolution_popup_closed)
	save_button.pressed.connect(_on_save_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _load_settings() -> void:
	var cfg = SettingsManager.settings
	fullscreen_check.button_pressed = cfg["fullscreen"]
	master_slider.value = cfg["master_volume_db"]
	bgm_slider.value = cfg["bgm_volume_db"]
	_update_volume_labels()

	var res_idx = resolution_values.find(cfg["resolution"])
	if res_idx == -1:
		res_idx = 0
	resolution_option.select(res_idx)

	if OS.has_feature("mobile"):
		resolution_option.disabled = true
		fullscreen_check.disabled = true

func _update_volume_labels() -> void:
	master_value.text = "%d dB" % int(master_slider.value)
	bgm_value.text = "%d dB" % int(bgm_slider.value)

func _on_fullscreen_toggled(pressed: bool) -> void:
	SettingsManager.settings["fullscreen"] = pressed
	SettingsManager.apply_display_settings()

func _on_master_volume_changed(value: float) -> void:
	SettingsManager.settings["master_volume_db"] = value
	SettingsManager.apply_audio_settings()
	_update_volume_labels()

func _on_bgm_volume_changed(value: float) -> void:
	SettingsManager.settings["bgm_volume_db"] = value
	SettingsManager.apply_audio_settings()
	_update_volume_labels()

func _on_resolution_selected(idx: int) -> void:
	if idx >= 0 and idx < resolution_values.size():
		SettingsManager.settings["resolution"] = resolution_values[idx]
		SettingsManager.apply_display_settings()

func _on_save_pressed() -> void:
	SettingsManager.save_settings()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")