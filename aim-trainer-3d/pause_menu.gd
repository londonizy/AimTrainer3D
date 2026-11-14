extends CanvasLayer
## Меню паузы: Esc открывает и закрывает, внутри — настройка
## чувствительности мыши и громкости. Живёт в режиме ALWAYS,
## поэтому работает и когда дерево на паузе.

var player: CharacterBody3D
var root: Control
var sens_slider: HSlider
var vol_slider: HSlider
var sens_label: Label
var vol_label: Label

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

func setup(p: CharacterBody3D) -> void:
	player = p
	_build_ui()
	visible = false

func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "ПАУЗА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)
	sens_label = Label.new()
	vbox.add_child(sens_label)
	sens_slider = HSlider.new()
	sens_slider.min_value = 0.1
	sens_slider.max_value = 3.0
	sens_slider.step = 0.05
	sens_slider.value = 1.0
	sens_slider.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(sens_slider)
	sens_slider.value_changed.connect(_on_sens_changed)
	vol_label = Label.new()
	vbox.add_child(vol_label)
	vol_slider = HSlider.new()
	vol_slider.min_value = 0.0
	vol_slider.max_value = 1.0
	vol_slider.step = 0.05
	vol_slider.value = 1.0
	vol_slider.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(vol_slider)
	vol_slider.value_changed.connect(_on_vol_changed)
	var resume := Button.new()
	resume.text = "Продолжить (Esc)"
	resume.pressed.connect(close)
	vbox.add_child(resume)
	var quit := Button.new()
	quit.text = "Выход из игры"
	quit.pressed.connect(_on_quit)
	vbox.add_child(quit)
	_update_labels()

func _update_labels() -> void:
	sens_label.text = "Чувствительность мыши: %d%%" % roundi(sens_slider.value * 100.0)
	vol_label.text = "Громкость: %d%%" % roundi(vol_slider.value * 100.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()

func open() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_sens_changed(_value: float) -> void:
	if player != null:
		player.mouse_sens = player.MOUSE_SENS_BASE * sens_slider.value
	_update_labels()

func _on_vol_changed(value: float) -> void:
	if value <= 0.001:
		AudioServer.set_bus_mute(0, true)
	else:
		AudioServer.set_bus_mute(0, false)
		AudioServer.set_bus_volume_db(0, linear_to_db(value))
	_update_labels()

func _on_quit() -> void:
	get_tree().quit()
