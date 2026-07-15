@tool

class_name WeaponController extends Node3D

signal weapon_fired

@export var WEAPON_TYPE : Weapons:
	set(value):
		WEAPON_TYPE = value
		if Engine.is_editor_hint():
			load_weapon()

@export var sway_noise : NoiseTexture2D
@export var sway_speed : float = 1.2
@export var reset : bool = false:
	set(value):
		reset = value
		if Engine.is_editor_hint():
			load_weapon()

@onready var weapon_mesh : MeshInstance3D = %WeaponMesh
@onready var weapon_shadow : MeshInstance3D = %WeaponShadow
@onready var muzzle_flash_node : Node3D = %MuzzleFlash
@onready var muzzle_light : OmniLight3D = %OmniLight3D
# MUST BE OFF IN THE SCENE TO AVOID UNNECESSARY LIGHT IN THE START OF LEVEL

var mouse_movement : Vector2
var random_sway_x
var random_sway_y
var random_sway_amount : float
var time : float = 0.0
var idle_sway_adjustment
var idle_sway_rotation_strength
var weapon_bob_amount: Vector2 = Vector2(0,0)

var raycast_test = preload("res://Meshes/Weapons/raycast_test.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await owner.ready
	load_weapon()

func _input(event):
	if event.is_action_pressed("weapon1"):
		WEAPON_TYPE = load("res://Meshes/Weapons/Ranged/Colt1911/Colt1911Resource.tres")
		load_weapon()
	if event.is_action_pressed("weapon2"):
		WEAPON_TYPE = load("res://Meshes/Weapons/Melee/Crowbar/CrowbarResource.tres")
		load_weapon()
#	For swaying weapon
	if event is InputEventMouseMotion:
		mouse_movement = event.relative

func load_weapon() -> void:
	weapon_mesh.mesh = WEAPON_TYPE.mesh # Set weapon mesh
	weapon_shadow.mesh = WEAPON_TYPE.mesh
	position = WEAPON_TYPE.position # Set wespon position
	rotation_degrees = WEAPON_TYPE.rotation # Set weapon rotation
	scale = WEAPON_TYPE.scale # Set weapon scale
	weapon_shadow.visible = WEAPON_TYPE.shadow # Turn shadow on/off
	idle_sway_adjustment = WEAPON_TYPE.idle_sway_adjustment
	idle_sway_rotation_strength = WEAPON_TYPE.idle_sway_rotation_strength
	random_sway_amount = WEAPON_TYPE.random_sway_amount
	# Перемещаем узел прямо к дулу конкретной модели
	muzzle_flash_node.position = WEAPON_TYPE.muzzle_flash_position
	# Меняем цвет источника света
	muzzle_light.light_color = WEAPON_TYPE.muzzle_flash_color

func sway_weapon(delta, isIdle: bool) -> void:
	
	# Clamp mouse movement
	mouse_movement = mouse_movement.clamp(WEAPON_TYPE.sway_min,WEAPON_TYPE.sway_max)
	
	if isIdle:
		# Get random sway value from 2D noise
		var sway_random : float = get_sway_noise()
		var sway_random_adjusted : float = sway_random * idle_sway_adjustment # Adjust sway strengtn
		
		# Create time with delta and set two sine values for x and y sway movement
		time += delta * (sway_speed + sway_random)
		random_sway_x = sin(time + 1.5 + sway_random_adjusted) / random_sway_amount
		random_sway_y = sin(time - sway_random_adjusted) / random_sway_amount
		
		# Lerp weapon position based on mouse movement
		position.x = lerp(position.x, WEAPON_TYPE.position.x - 
		(mouse_movement.x * WEAPON_TYPE.sway_amount_position * random_sway_x) * delta, WEAPON_TYPE.sway_speed_position)
		
		position.y = lerp(position.y, WEAPON_TYPE.position.y + 
		(mouse_movement.y * WEAPON_TYPE.sway_amount_position * random_sway_y) * delta, WEAPON_TYPE.sway_speed_position)
		# Lerp weapon rotation based on mouse movement
		rotation_degrees.y = lerp(rotation_degrees.y, WEAPON_TYPE.rotation.y + 
		(mouse_movement.y * WEAPON_TYPE.sway_amount_rotation + 
		(random_sway_y * idle_sway_rotation_strength)) * delta, WEAPON_TYPE.sway_speed_rotation)
		
		rotation_degrees.x = lerp(rotation_degrees.x, WEAPON_TYPE.rotation.x - 
		(mouse_movement.x * WEAPON_TYPE.sway_amount_rotation + 
		(random_sway_x * idle_sway_rotation_strength)) * delta, WEAPON_TYPE.sway_speed_rotation)
	
	
	
	else:
		# Lerp weapon position based on mouse movement
		position.x = lerp(position.x, WEAPON_TYPE.position.x - 
		(mouse_movement.x * WEAPON_TYPE.sway_amount_position + weapon_bob_amount.x) * delta, WEAPON_TYPE.sway_speed_position)
		position.y = lerp(position.y, WEAPON_TYPE.position.y + 
		(mouse_movement.y * WEAPON_TYPE.sway_amount_position + weapon_bob_amount.y) * delta, WEAPON_TYPE.sway_speed_position)
		# Lerp weapon rotation based on mouse movement
		rotation_degrees.y = lerp(rotation_degrees.y, WEAPON_TYPE.rotation.y + 
		(mouse_movement.y * WEAPON_TYPE.sway_amount_rotation) * delta, WEAPON_TYPE.sway_speed_rotation)
		rotation_degrees.x = lerp(rotation_degrees.x, WEAPON_TYPE.rotation.x - 
		(mouse_movement.x * WEAPON_TYPE.sway_amount_rotation) * delta, WEAPON_TYPE.sway_speed_rotation)

func get_sway_noise() -> float:
	var player_position : Vector3 = Vector3(0,0,0)
	# Only access global variable when in-game to avoid constant errors
	if not Engine.is_editor_hint():
		player_position = global.player.global_position
	var noise_location : float = sway_noise.noise.get_noise_2d(player_position.x,player_position.y)
	return noise_location


func _weapon_bob(delta, bob_speed: float, horis_bob_amount: float, vertic_bob_amount : float) -> void:
	time += delta
	
	weapon_bob_amount.x = sin(time * bob_speed) * horis_bob_amount
	weapon_bob_amount.y = abs(cos(time * bob_speed) * vertic_bob_amount)

func _attack() -> void:
	if !WEAPON_TYPE.isMelee:
		weapon_fired.emit()
		var camera = global.player.CAMERA_CONTROLLER
		var space_state = camera.get_world_3d().direct_space_state
		
		# Берем центр видимой игровой области, а не физического окна
		var screen_center = get_viewport().get_visible_rect().size / 2
		
		var origin = camera.project_ray_origin(screen_center)
		var end = origin + camera.project_ray_normal(screen_center) * WEAPON_TYPE.range
		
		var query = PhysicsRayQueryParameters3D.create(origin, end)
		query.collide_with_bodies = true
		
		# Дополнительно исключаем самого игрока из проверки коллизий, 
		# чтобы луч случайно не врезался в хитбокс персонажа изнутри
		query.exclude = [global.player.get_rid()] 
		
		var result = space_state.intersect_ray(query)
		if result:
			_bullet_hole(result.get("position"), result.get("normal"))



#func _bullet_hole(position: Vector3, normal: Vector3) -> void:
	#var instance = raycast_test.instantiate()
	#get_tree().root.add_child(instance)
	#instance.global_position = position
	#instance.look_at(instance.global_transform.origin + normal, Vector3.UP)
	#await get_tree().create_timer(3).timeout
	#instance.queue_free()
	
func _bullet_hole(hit_position: Vector3, hit_normal: Vector3) -> void:
	var instance = raycast_test.instantiate()
	get_tree().root.add_child(instance)
	
	# 1. Сдвигаем пулю на половину сантиметра ОТ стены по вектору нормали.
	# Это убирает мерцание без необходимости включать просвечивающий No Depth Test
	instance.global_position = hit_position + (hit_normal * 0.005)
	
	# ЛУЧШЕ ВРАЩАТЬ "ДЕКАЛЬ", ИНАЧЕ ПРОИЗВОДИТЕЛЬНОСТЬ СИЛЬНО СТРАДАЕТ
	# но разраб не все знает, потому пока что так
	# 2. Математически заставляем материал пули рендериться с двух сторон (Двусторонний режим)
	# Ищем MeshInstance3D внутри созданной пули
	var mesh_node = instance.get_node_or_null("MeshInstance3D") as MeshInstance3D
	
	var mat = mesh_node.get_active_material(0) as StandardMaterial3D
	if mat:
		# CULL_DISABLED = 2 (Отключает отсечение задних граней, делая меш двусторонним)
		mat.cull_mode = StandardMaterial3D.CULL_DISABLED 
	
	# 3. Вычисляем точное вращение: ось Z плоскости теперь строго смотрит на нормаль стены
	var up_direction = Vector3.UP if abs(hit_normal.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	instance.global_transform = Transform3D(
		Basis.looking_at(hit_normal, up_direction), 
		instance.global_position
	)
	
	# Ждем 2 секунды перед началом растворения
	await get_tree().create_timer(2.0).timeout
	
	# Создаем уникальную копию материала для этой конкретной пули
	var original_mat = mesh_node.get_active_material(0)
	if original_mat:
		var unique_mat = original_mat.duplicate() as StandardMaterial3D
		mesh_node.material_override = unique_mat # Применяем уникальный материал
		
		# Запускаем плавное растворение альфа-канала материала (с 1.0 до 0.0 за 1.5 секунды)
		var tween = get_tree().create_tween()
		tween.tween_property(unique_mat, "albedo_color:a", 0.0, 1.5)
	
	# Ждем окончания анимации (1.5 секунды) и удаляем объект из памяти
	await get_tree().create_timer(1.5).timeout
	instance.queue_free()
