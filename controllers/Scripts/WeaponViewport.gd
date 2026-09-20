extends SubViewport

var screen_size : Vector2

# путь к ГЛАВНОЙ камере игрока
@onready var main_camera: Node3D = %CameraController

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_size = get_window().size
	size = screen_size


func _process(delta: float) -> void:
	if not is_inside_tree() or multiplayer.multiplayer_peer == null or not is_multiplayer_authority(): 
		return
	if has_node("%WeaponRig") and %WeaponRig != null:
		%WeaponRig.global_transform = main_camera.global_transform
