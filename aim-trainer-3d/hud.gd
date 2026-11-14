extends CanvasLayer

@onready var hits_label: Label = $Hits
@onready var acc_label: Label = $Accuracy
@onready var ammo_label: Label = $Ammo

var shots := 0
var hits := 0

func _ready() -> void:
	var weapon: Node = get_tree().get_first_node_in_group("weapon")
	if weapon != null:
		weapon.shot_fired.connect(_on_shot)
		weapon.ammo_changed.connect(_on_ammo)
		weapon.reload_started.connect(_on_reload)
	_on_ammo(30, 30)

func _on_shot(hit: bool) -> void:
	shots += 1
	if hit:
		hits += 1
	hits_label.text = "Попаданий: %d" % hits
	if shots > 0:
		acc_label.text = "Точность: %d%%" % roundi(100.0 * float(hits) / float(shots))
	else:
		acc_label.text = "Точность: —"

func _on_ammo(mag: int, size: int) -> void:
	ammo_label.text = "%d / %d" % [mag, size]

func _on_reload() -> void:
	ammo_label.text = "ПЕРЕЗАРЯДКА"
