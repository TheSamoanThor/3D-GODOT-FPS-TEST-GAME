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
@onready var melee_area : Area3D = %MeleeArea
# MUST BE OFF IN THE SCENE TO AVOID UNNECESSARY LIGHT IN THE START OF LEVEL


var mouse_movement : Vector2
var random_sway_x
var random_sway_y
var random_sway_amount : float
var time : float = 0.0
var idle_sway_adjustment
var idle_sway_rotation_strength
var weapon_bob_amount: Vector2 = Vector2(0,0)

var bob_speed : float = 0.0
var bob_horizontal : float = 0.0
var bob_vertical : float = 0.0

var bullet_scene = preload("res://scripts/Weapons/bullet.tscn")


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


@rpc("call_local")
func _attack() -> void:
	if not WEAPON_TYPE.isMelee:
		if WEAPON_TYPE.isRayWeapon:
			weapon_fired.emit()
			var camera = global.player.CAMERA_CONTROLLER
			var space_state = camera.get_world_3d().direct_space_state
			
			# Берем центр видимой игровой области
			var screen_center = get_viewport().get_visible_rect().size / 2
			
			var origin = camera.project_ray_origin(screen_center)
			var end = origin + camera.project_ray_normal(screen_center) * WEAPON_TYPE.range
			
			var query = PhysicsRayQueryParameters3D.create(origin, end)
			query.collide_with_bodies = true
			
			# исключаем самого игрока из проверки коллизий, 
			# чтобы луч случайно не врезался в хитбокс персонажа изнутри
			#query.exclude = [global.player.get_rid()] 
			
			var result = space_state.intersect_ray(query)
			if result:
				if result.get("collider").has_method("recieve_damage"):
					result.get("collider").recieve_damage.rpc_id(result.get("collider").get_multiplayer_authority(), WEAPON_TYPE.damage)
				_bullet_hole(result.get("position"), result.get("normal"))
		if not WEAPON_TYPE.isRayWeapon:
			weapon_fired.emit()
			
			var camera = global.player.CAMERA_CONTROLLER
			var space_state = camera.get_world_3d().direct_space_state
			var screen_center = get_viewport().get_visible_rect().size / 2
			
			# 1. НАХОДИМ ТОЧКУ, КУДА СМОТРИТ ПРИЦЕЛ (Убираем параллакс) (рейкаст)
			var ray_origin = camera.project_ray_origin(screen_center)
			var ray_end = ray_origin + camera.project_ray_normal(screen_center) * WEAPON_TYPE.range
			
			var ray_query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
			ray_query.collide_with_bodies = true
			ray_query.exclude = [global.player.get_rid()]
			
			var ray_result = space_state.intersect_ray(ray_query)
			
			var target_point : Vector3
			if ray_result:
				# Если прицел наведен на стену или врага — пуля полетит строго в эту точку
				target_point = ray_result.get("position")
			else:
				# Если смотрим в пустоту/небо — пуля летит в далекую точку впереди
				target_point = ray_end
			
			# 2. РАСЧЕТ РАЗБРОСА ОТ СКОРОСТИ
			var player_speed = global.player.velocity.length()
			var current_spread = WEAPON_TYPE.base_spread + (player_speed * WEAPON_TYPE.movement_spread_factor)
			
			var random_angle = randf() * TAU
			var random_radius = randf() * current_spread
			var spread_offset = Vector2(cos(random_angle), sin(random_angle)) * random_radius
			
			# 3. ФОРМИРУЕМ НАПРАВЛЕНИЕ ПОЛЕТА ИЗ ДУЛА В ЦЕЛЬ
			# Вычисляем чистый вектор от дула оружия до точки прицеливания
			var raw_direction = (target_point - muzzle_flash_node.global_position).normalized()
			
			# Создаем базис вокруг этого направления, чтобы правильно применить разброс
			var base_transform = Transform3D(Basis.looking_at(raw_direction), Vector3.ZERO)
			# Смещаем траекторию пули по локальным X и Y относительно линии полета
			var final_direction = (base_transform.basis * Vector3(spread_offset.x, spread_offset.y, -1.0)).normalized()
			
			# 4. СПАВН ПУЛИ
			var bullet = bullet_scene.instantiate()
			get_tree().root.add_child(bullet)
			
			bullet.hit_registered.connect(_bullet_hole)
			bullet.global_position = muzzle_flash_node.global_position
			
			# Инициализируем пулю с новым, скорректированным вектором направления
			bullet.init_bullet(WEAPON_TYPE.bullet_data, WEAPON_TYPE.damage, final_direction)
			
			# Поворачиваем пулю носом по направлению полета
			bullet.look_at(bullet.global_position + final_direction)

	if WEAPON_TYPE.isMelee:
		if WEAPON_TYPE.isArealMelee:
			# Собираем всех врагов, которые оказались внутри зоны в этот момент
			var targets = melee_area.get_overlapping_bodies()
			
			for body in targets:
				# Игнорируем самого себя
				#if body == global.player or body.get_rid() == global.player.get_rid():
					#continue
				if body.has_method("recieve_damage"):
					body.recieve_damage.rpc_id(body.get_multiplayer_authority(), WEAPON_TYPE.damage)
				# Спавним искры или кровь в точке соприкосновения
				# (Для Area3D точную точку можно взять как global_position врага)
				_bullet_hole(body.global_position, Vector3.UP) # doesnt work :/
		elif not WEAPON_TYPE.isArealMelee:
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
			#query.exclude = [global.player.get_rid()] 
			
			var result = space_state.intersect_ray(query)
			if result:
				if result.get("collider").has_method("recieve_damage"):
					result.get("collider").recieve_damage.rpc_id(result.get("collider").get_multiplayer_authority(), WEAPON_TYPE.damage)
				_bullet_hole(result.get("position"), result.get("normal"))


func _bullet_hole(hit_position: Vector3, hit_normal: Vector3) -> void:
	# 1. Создаем чистый 3D-меш
	var instance = MeshInstance3D.new()
	
	# 2. Настраиваем форму
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(0.1, 0.1) # Размер дырки от пули (10х10 сантиметров)
	instance.mesh = quad_mesh
	
	# 3. Создаем и настраиваем материал
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.1, 0.1, 1.0) # Черный/темно-серый цвет дырки
	mat.cull_mode = StandardMaterial3D.CULL_DISABLED # Двусторонний режим
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA # Включаем прозрачность для будущего затухания
	
	mat.albedo_texture = preload("res://Textures/bullet_hole.png")
	
	instance.material_override = mat
	
	# 4. Добавляем объект на карту
	get_tree().root.add_child(instance)
	
	# 5. Позиционируем и сдвигаем от стены на полсантиметра (чтобы не было мерцания)
	instance.global_position = hit_position + (hit_normal * 0.005)
	
	# 6. Разворачиваем меш параллельно стене
	var up_direction = Vector3.UP if abs(hit_normal.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	instance.global_transform = Transform3D(
		Basis.looking_at(hit_normal, up_direction), 
		instance.global_position
	)
	
	# randf_range(0, TAU) сгенерирует угол от 0 до 360 градусов в радианах
	instance.rotate_object_local(Vector3.FORWARD, randf_range(0, TAU))
	
	# 7. Логика уничтожения: ждем 2 секунды, плавно растворяем за 1.5 сек и удаляем
	await get_tree().create_timer(2.0).timeout
	
	var tween = get_tree().create_tween()
	# Плавно уводим прозрачность материала в ноль
	tween.tween_property(mat, "albedo_color:a", 0.0, 1.5)
	
	await get_tree().create_timer(1.5).timeout
	instance.queue_free()
