extends Node3D

signal kick(rot: Vector2)
signal shot_fired(hit: bool)
signal ammo_changed(mag: int, size: int)
signal reload_started

const FIRE_RATE := 0.09
const MAG_SIZE := 30
const RELOAD_TIME := 2.6
const BASE_SPREAD := 0.02
const AIM_SPREAD := 0.004
const AIM_POS := Vector3(0.0, -0.115, -0.3)
const HIP_POS := Vector3(0.26, -0.24, -0.5)
const AIM_FOV := 55.0
const HIP_FOV := 75.0
const RECOIL_STEP := 0.035

var ammo := MAG_SIZE
var reloading := false
var fire_cooldown := 0.0
var aiming := false
var recoil_z := 0.0
var base_pos := HIP_POS
var reload_stream: AudioStream

@onready var flash: Node3D = $Flash
@onready var flash_light: OmniLight3D = $Flash/Light
@onready var shot_sound: AudioStreamPlayer3D = $ShotSound
@onready var reload_sound: AudioStreamPlayer3D = $ReloadSound
@onready var camera: Camera3D = _find_camera()

func _find_camera() -> Camera3D:
	var node: Node = self
	while node != null:
		if node is Camera3D:
			return node
		node = node.get_parent()
	return null

func _find_player() -> CharacterBody3D:
	var node: Node = self
	while node != null:
		if node is CharacterBody3D:
			return node
		node = node.get_parent()
	return null

func _load_reload_stream() -> AudioStream:
	for path in ["res://hk416_reload.ogg", "res://hk416_reload.ogg.ogg", "res://reload.wav"]:
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			if stream != null:
				return stream
	return null

func _ready() -> void:
	flash.visible = false
	flash_light.visible = false
	reload_stream = _load_reload_stream()
	if reload_stream != null:
		reload_sound.stream = reload_stream

func _physics_process(delta: float) -> void:
	fire_cooldown -= delta
	recoil_z = move_toward(recoil_z, 0.0, 0.55 * delta)
	aiming = Input.is_action_pressed("aim") and not reloading
	var target_pos: Vector3 = AIM_POS if aiming else HIP_POS
	var t: float = minf(1.0, 10.0 * delta)
	base_pos = base_pos.lerp(target_pos, t)
	position = base_pos + Vector3(0.0, 0.0, recoil_z)
	if camera != null:
		camera.fov = lerpf(camera.fov, AIM_FOV if aiming else HIP_FOV, t)
	if Input.is_action_just_pressed("reload"):
		_start_reload()
	if Input.is_action_pressed("fire") and fire_cooldown <= 0.0 and not reloading:
		_shoot()

func _shoot() -> void:
	if ammo <= 0:
		_start_reload()
		return
	fire_cooldown = FIRE_RATE
	ammo -= 1
	ammo_changed.emit(ammo, MAG_SIZE)
	recoil_z = minf(recoil_z + RECOIL_STEP, 0.09)
	if aiming:
		kick.emit(Vector2(randf_range(-0.006, 0.006), 0.010))
	else:
		kick.emit(Vector2(randf_range(-0.012, 0.012), 0.016))
	shot_sound.pitch_scale = randf_range(0.94, 1.06)
	shot_sound.play()
	flash.rotation.z = randf() * TAU
	flash.visible = true
	flash_light.visible = true
	var hit := _ray_hit()
	shot_fired.emit(hit)
	await get_tree().create_timer(0.05).timeout
	flash.visible = false
	flash_light.visible = false

func _ray_hit() -> bool:
	if camera == null:
		return false
	var spread: float = AIM_SPREAD if aiming else BASE_SPREAD
	var dir: Vector3 = -camera.global_transform.basis.z
	dir = (dir + Vector3(randf_range(-spread, spread), randf_range(-spread, spread), randf_range(-spread, spread))).normalized()
	var from := camera.global_position
	var params := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0)
	var body := _find_player()
	if body != null:
		params.exclude = [body.get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(params)
	if result.is_empty():
		return false
	var collider: Object = result["collider"]
	if collider != null and collider.has_method("hit_target"):
		collider.hit_target()
		return true
	return false

func _start_reload() -> void:
	if reloading or ammo == MAG_SIZE:
		return
	reloading = true
	if reload_sound.stream != null:
		reload_sound.play()
	reload_started.emit()
	get_tree().create_timer(RELOAD_TIME).timeout.connect(_finish_reload)

func _finish_reload() -> void:
	ammo = MAG_SIZE
	reloading = false
	ammo_changed.emit(ammo, MAG_SIZE)
