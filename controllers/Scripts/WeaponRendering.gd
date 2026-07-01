extends Camera3D

@export var MAIN_CAMERA : Node3D

func _ready() -> void:
	get_viewport().handle_input_locally = true


# Match Weapon Camera to Player Camera
func _process(delta: float) -> void:
	global_transform = MAIN_CAMERA.global_transform
	
	# СИНХРОНИЗАЦИЯ ОРУЖИЯ: Принудительно передаем глобальные координаты 
	# головы игрока на узел с монтировкой, вытаскивая его из изоляции вьюпорта
	%WeaponRig.global_transform = MAIN_CAMERA.global_transform
