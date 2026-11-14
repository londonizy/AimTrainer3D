extends StaticBody3D

const RESPAWN_TIME := 2.5

var fallen := false
var timer := 0.0

@onready var pivot: Node3D = $PlatePivot
@onready var shape: CollisionShape3D = $Shape
@onready var sound: AudioStreamPlayer3D = $DingSound

func _physics_process(delta: float) -> void:
	if fallen:
		timer -= delta
		if timer <= 0.0:
			fallen = false
			pivot.rotation.x = 0.0
			shape.set_deferred("disabled", false)

func hit_target() -> void:
	if fallen:
		return
	fallen = true
	timer = RESPAWN_TIME
	pivot.rotation.x = deg_to_rad(-90.0)
	shape.set_deferred("disabled", true)
	sound.play()
