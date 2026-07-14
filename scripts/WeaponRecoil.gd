extends Node3D

@export var recoil_amount : Vector3
@export var snap_amount : float = 10.0 # Оптимально для сглаживания подскока
@export var speed : float = 4.0        # Оптимально для возврата назад

@export var weapon : WeaponController

var current_rotation : Vector3
var target_rotation : Vector3

func _ready() -> void:
	# Находим оружие внутри SubViewport напрямую, чтобы исключить баги сигналов
	if not weapon:
		weapon = get_node_or_null("WeaponRig/Weapon") as WeaponController

func _process(delta: float) -> void:
	# Плавно возвращаем целевой угол к нулю
	target_rotation = target_rotation.lerp(Vector3.ZERO, speed * delta)
	# Плавно ведем текущее вращение к целевому
	current_rotation = current_rotation.lerp(target_rotation, snap_amount * delta)
	
	# ПРЯМОЕ ИСПРАВЛЕНИЕ: Вместо тяжелых кватернионов используем простые и надежные углы Godot
	rotation_degrees = current_rotation

func add_recoil() -> void:
	# Физический подскок: X идет в минус (ствол задирается вверх), Y и Z уходят в стороны
	target_rotation += Vector3(
		-recoil_amount.x, 
		randf_range(-recoil_amount.y, recoil_amount.y),
		randf_range(-recoil_amount.z, recoil_amount.z)
	)
