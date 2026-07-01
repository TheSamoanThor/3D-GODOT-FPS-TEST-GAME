extends Node3D

# путь к ГЛАВНОЙ камере игрока
@onready var main_camera: Node3D = %CameraController

func _process(delta: float) -> void:
	# Полностью копируем позицию и поворот главной камеры в пространстве мира
	global_transform = main_camera.global_transform
