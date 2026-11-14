extends CharacterBody3D

const SPEED := 5.0
const RUN_SPEED := 8.5
const CROUCH_SPEED := 3.0
const JUMP_VELOCITY := 4.8
const MOUSE_SENS_BASE := 0.0025
const STEP_INTERVAL := 0.42
const STEP_INTERVAL_RUN := 0.3

# Руки из бесплатной модели (CC0). Скачайте GLB с руками и положите
# в папку проекта под именем arms.glb. Если файла нет — включаются
# запасные руки из примитивов ниже.
const ARMS_PATH := "res://arms.glb"
const ARMS_POS := Vector3(0.0, -0.02, 0.0)
const ARMS_ROT := Vector3(0.0, 0.0, 0.0)
const ARMS_SCALE := 1.0

# Запасные руки: позиции в локальных координатах оружия (ствол смотрит в -Z).
const HAND_R_POS := Vector3(0.0, -0.1, 0.12)
const HAND_L_POS := Vector3(-0.005, -0.08, -0.3)
const ELBOW_R := Vector3(0.4, -0.58, 0.48)
const ELBOW_L := Vector3(-0.46, -0.6, 0.28)
const GLOVE_COLOR := Color(0.13, 0.13, 0.15)
const SLEEVE_COLOR := Color(0.31, 0.35, 0.21)

var recoil := Vector2.ZERO
var step_timer := 0.0
var mouse_sens := MOUSE_SENS_BASE
var crouching := false
var head_base_y := 1.6
var arms_model: Node3D = null

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var weapon: Node3D = $Head/Camera/Weapon
@onready var step_sound: AudioStreamPlayer3D = $StepSound

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	head_base_y = head.position.y
	weapon.kick.connect(_on_kick)
	if not _try_load_arms_model():
		_build_hands()
	var menu: CanvasLayer = preload("res://pause_menu.gd").new()
	menu.setup(self)
	add_child(menu)

func _try_load_arms_model() -> bool:
	if not ResourceLoader.exists(ARMS_PATH):
		print("arms.glb не найден: включены запасные руки из примитивов")
		return false
	var packed: PackedScene = load(ARMS_PATH)
	if packed == null:
		print("arms.glb найден, но не загрузился: включены запасные руки")
		return false
	var inst: Node = packed.instantiate()
	if inst == null or not (inst is Node3D):
		print("arms.glb загрузился, но внутри нет 3D-содержимого: включены запасные руки")
		if inst != null:
			inst.free()
		return false
	arms_model = inst
	weapon.add_child(arms_model)
	arms_model.position = ARMS_POS
	arms_model.rotation_degrees = ARMS_ROT
	arms_model.scale = Vector3.ONE * ARMS_SCALE
	_play_arms_idle()
	print("Руки загружены из arms.glb")
	return true

func _play_arms_idle() -> void:
	if arms_model == null:
		return
	var players: Array[Node] = arms_model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	var anim: AnimationPlayer = players[0]
	if anim.has_animation("idle"):
		anim.play("idle")
	else:
		var names := anim.get_animation_list()
		if names.size() > 0:
			anim.play(names[0])

func _on_kick(rot: Vector2) -> void:
	recoil += rot

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sens)
		head.rotate_x(-event.relative.y * mouse_sens)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))
	# Esc обрабатывает pause_menu.gd: так меню работает и когда игра на паузе

func _physics_process(delta: float) -> void:
	crouching = Input.is_action_pressed("crouch") and is_on_floor()
	if not is_on_floor():
		velocity += get_gravity() * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var moving := input_dir.length() > 0.1
	var running := moving and Input.is_action_pressed("run") and not crouching
	var speed := RUN_SPEED if running else SPEED
	if crouching:
		speed = CROUCH_SPEED
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	if moving:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * 12.0 * delta)
	move_and_slide()
	var head_target := head_base_y - 0.6 if crouching else head_base_y
	head.position.y = lerpf(head.position.y, head_target, minf(1.0, 10.0 * delta))
	if is_on_floor() and moving:
		step_timer -= delta
		if step_timer <= 0.0:
			step_timer = STEP_INTERVAL_RUN if running else STEP_INTERVAL
			step_sound.pitch_scale = randf_range(0.9, 1.1)
			step_sound.play()
	else:
		step_timer = 0.08
	recoil = recoil.lerp(Vector2.ZERO, minf(1.0, 9.0 * delta))
	camera.rotation = Vector3(recoil.y, recoil.x, 0.0)

## Запасные руки -------------------------------------------------------

func _build_hands() -> void:
	_make_hand(HAND_R_POS, ELBOW_R, true)
	_make_hand(HAND_L_POS, ELBOW_L, false)

func _make_hand(hand_pos: Vector3, elbow: Vector3, right: bool) -> void:
	var side := 1.0 if right else -1.0
	# Ладонь
	var glove := MeshInstance3D.new()
	var palm := BoxMesh.new()
	palm.size = Vector3(0.075, 0.08, 0.11)
	palm.material = _mat(GLOVE_COLOR)
	glove.mesh = palm
	glove.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	weapon.add_child(glove)
	glove.position = hand_pos
	glove.rotation_degrees = Vector3(-10.0, 0.0, -18.0 * side)
	# Пальцы, обхватывающие рукоять/цевье
	var fingers := MeshInstance3D.new()
	var fingers_mesh := BoxMesh.new()
	fingers_mesh.size = Vector3(0.08, 0.045, 0.075)
	fingers_mesh.material = _mat(GLOVE_COLOR)
	fingers.mesh = fingers_mesh
	fingers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	weapon.add_child(fingers)
	fingers.position = hand_pos + Vector3(0.0, 0.045, 0.02 if right else -0.03)
	fingers.rotation_degrees = Vector3(-10.0, 0.0, -18.0 * side)
	# Большой палец
	var thumb := MeshInstance3D.new()
	var thumb_mesh := BoxMesh.new()
	thumb_mesh.size = Vector3(0.028, 0.028, 0.07)
	thumb_mesh.material = _mat(GLOVE_COLOR)
	thumb.mesh = thumb_mesh
	thumb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	weapon.add_child(thumb)
	thumb.position = hand_pos + Vector3(0.035 * side, 0.02, -0.02)
	thumb.rotation_degrees = Vector3(-15.0, 25.0 * side, 0.0)
	# Предплечье: от кисти к локтю
	_limb(hand_pos, elbow, 0.038, GLOVE_COLOR)
	# Рукав: продолжение за локтем, уходит за край экрана
	var dir := (elbow - hand_pos).normalized()
	_limb(elbow, elbow + dir * 0.5, 0.055, SLEEVE_COLOR)
	# Часы на левом запястье
	if not right:
		var watch := MeshInstance3D.new()
		var watch_mesh := BoxMesh.new()
		watch_mesh.size = Vector3(0.055, 0.022, 0.05)
		watch_mesh.material = _mat(Color(0.1, 0.1, 0.12))
		watch.mesh = watch_mesh
		watch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		weapon.add_child(watch)
		watch.position = hand_pos + dir * 0.13 + Vector3(0.0, 0.032, 0.0)
		watch.rotation_degrees = Vector3(0.0, 0.0, -20.0)

func _limb(from: Vector3, to: Vector3, radius: float, color: Color) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = from.distance_to(to) + radius * 2.0
	mesh.material = _mat(color)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	weapon.add_child(mi)
	var dir := (to - from).normalized()
	var basis := Basis.looking_at(dir, Vector3.UP) * Basis(Vector3(1.0, 0.0, 0.0), -PI / 2.0)
	mi.transform = Transform3D(basis, (from + to) * 0.5)

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m
