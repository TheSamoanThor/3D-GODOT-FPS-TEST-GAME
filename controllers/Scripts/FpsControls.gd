class_name Player extends CharacterBody3D


@export var JUMP_VELOCITY : float = 4.5
# Mouse sensitivity (low value like 0.002 is best since we don't multiply by delta)
@export var MOUSE_SENSITIVITY : float = 0.005
@export var TILT_LOWER_LIMIT := deg_to_rad(-90.0)
@export var TILT_UPPER_LIMIT := deg_to_rad(90.0)

@export var CAMERA_CONTROLLER : Camera3D
@export var ANIMATIONPLAYER : AnimationPlayer
@export var CROUCH_SHAPECAST : ShapeCast3D
@export var WEAPON_CONTROLLER : WeaponController
@export var interact_distance : float = 2.0
@export var grapple_distance : float = 100.0
@export var can_grapple : bool = true
@export var grapple_speed : float = 15.0

@export var max_health : int = 100
@export var health : int = 3


@export var sync_weapon_path: String = "res://Meshes/Weapons/Ranged/Colt1911/Colt1911Resource.tres":
	set(value):
		sync_weapon_path = value
		# Если игрок уже на карте и пушка создана — мгновенно применяем изменения
		if is_node_ready() and WEAPON_CONTROLLER != null:
			_apply_weapon_change_locally()



var is_grappling : bool = false
var grapple_target_point : Vector3

var _speed : float
var _mouse_input : bool = false
var _mouse_rotation : Vector3
var _rotation_input : float
var _tilt_input : float

var _current_rotation : float

var interaction_cast_result
var current_cast_result


func _enter_tree() -> void:
	# Проверяем, запущен ли мультиплеерный пир
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		var peer_id = str(name).to_int()
		if peer_id > 0:
			if get_multiplayer_authority() != peer_id:
				set_multiplayer_authority(peer_id)
	else:
		# Если играем в сингл-плеер, принудительно ставим стандартный ID сервера (1)
		if get_multiplayer_authority() != 1:
			set_multiplayer_authority(1)


func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	
	if event.is_action_pressed("exit"):
		get_tree().quit()
	if event.is_action_pressed("interact"):
		interact()
	# Находим этот кусок в func _input(event) в FpsControls.gd:
	if event.is_action_pressed("attack"):
		# Просим сервер выполнить атаку (вместо call_local шлем запрос на сервер)
		WEAPON_CONTROLLER._rpc_request_attack.rpc()
	if event.is_action_pressed("special_ability") and can_grapple:
		grapple()


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	
	_mouse_input = event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	if _mouse_input:
		_rotation_input -= event.relative.x * MOUSE_SENSITIVITY
		_tilt_input -= event.relative.y * MOUSE_SENSITIVITY


func _physics_process(delta: float) -> void:
	if not is_inside_tree() or multiplayer.multiplayer_peer == null:
		return
	if not is_multiplayer_authority():
		return

	
	if global.debug and is_instance_valid(global.debug):
		global.debug.add_property("RealSpeed", velocity.length(), 1)
		global.debug.add_property("RealSpeedVect", get_real_velocity(), 2)
		global.debug.add_property("Animation", ANIMATIONPLAYER.current_animation, 2)
		global.debug.add_property("Rotation", rotation, 2)
	
	if is_grappling:
		# Вычисляем направление от игрока к точке зацепа
		var direction = (grapple_target_point - global_position).normalized()
		
		# Плавно разгоняем velocity в сторону точки
		velocity = velocity.lerp(direction * grapple_speed, 10.0 * delta)
		
		# ПРЕДОХРАНИТЕЛЬ: Если мы подлетели вплотную к точке (ближе чем на 1.5 метра), отключаем крюк
		if global_position.distance_to(grapple_target_point) < 1.5:
			is_grappling = false
			dissconect_grapple()
		# В режиме крюка мы игнорируем стандартную гравитацию, чтобы лететь ровно в цель
	else:
		update_gravity(delta)
		# Сюда стейт-машина будет передавать обычный ход (update_input)

	# Двигаем персонажа с учетом коллизий со стенами
	update_velocity()


func _update_camera():
	_mouse_rotation.x += _tilt_input
	_mouse_rotation.x = clamp(_mouse_rotation.x, TILT_LOWER_LIMIT, TILT_UPPER_LIMIT)
	_mouse_rotation.y += _rotation_input
	
	# FIXED: Cache the rotation input so other states can read it before reset
	_current_rotation = _rotation_input
	
	transform.basis = Basis.from_euler(Vector3(0, _mouse_rotation.y, 0))
	CAMERA_CONTROLLER.transform.basis = Basis.from_euler(Vector3(_mouse_rotation.x, 0, 0))
	
	# WARNING: Do NOT explicitly force CAMERA_CONTROLLER.rotation.z = 0.0 here
	# if you want animation track keys (tilting) to work smoothly. 
	# The AnimationPlayer will override it, but it's cleaner to handle reset in exit()
	rotation.z = 0.0


func _ready() -> void:
	if not is_multiplayer_authority():
		%SubViewportContainer.hide() 
		return
	
	global.player = self
	
	# Если при спавне от сервера уже прилетел путь к оружию — обновляем его
	if sync_weapon_path != "":
		_apply_weapon_change_locally()
	
	await get_tree().process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if CROUCH_SHAPECAST != null:
		CROUCH_SHAPECAST.add_exception(self)
	
	CAMERA_CONTROLLER.current = true

func update_gravity(delta: float) -> void:
	velocity += get_gravity() * delta

# Movement logic optimized to receive physics parameters directly from states
func update_input(speed: float, acceleration: float, deceleration: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Используем встроенный в Godot метод get_physics_process_delta_time()
	var p_delta = get_physics_process_delta_time()
	
	if direction:
		velocity.x = lerp(velocity.x, direction.x * speed, acceleration * 60.0 * p_delta)
		velocity.z = lerp(velocity.z, direction.z * speed, acceleration * 60.0 * p_delta)
	else:
		velocity.x = move_toward(velocity.x, 0, deceleration * 60.0 * p_delta)
		velocity.z = move_toward(velocity.z, 0, deceleration * 60.0 * p_delta)

func update_velocity() -> void:
	if not is_multiplayer_authority(): return
	move_and_slide()

func _process(delta: float) -> void:
	if not is_inside_tree() or multiplayer.multiplayer_peer == null:
		return
	if not is_multiplayer_authority():
		return
	
	if WEAPON_CONTROLLER == null:
		return
		
	# 1. Проверяем движение персонажа прямо в графическом кадре через инпут
	var is_idle: bool = velocity.length() < 0.2
	
	# 2. Если игрок идет, стейт-машина сама настроит параметры WEAPON_CONTROLLER
	if not is_idle:
		WEAPON_CONTROLLER._weapon_bob(delta, WEAPON_CONTROLLER.bob_speed, WEAPON_CONTROLLER.bob_horizontal, WEAPON_CONTROLLER.bob_vertical)
	
	# 3. Передаем ввод мыши для увода оружия (Sway)
	if _current_rotation != 0.0 or _tilt_input != 0.0:
		WEAPON_CONTROLLER.mouse_movement = Vector2(
			-_current_rotation / MOUSE_SENSITIVITY, 
			-_tilt_input / MOUSE_SENSITIVITY
		)
	
	# 4. Вызываем обновление положения оружия
	WEAPON_CONTROLLER.sway_weapon(delta, is_idle)
	
	interact_cast()
	_update_camera()
	
	_rotation_input = 0.0
	_tilt_input = 0.0

func interact() -> void:
	if interaction_cast_result and interaction_cast_result.has_user_signal("interacted"):
		interaction_cast_result.emit_signal("interacted")

func interact_cast() -> void:
	# ФИКС: Чужие игроки не должны пускать лучи взаимодействия!
	if not is_multiplayer_authority():
		return

	# Дополнительный барьер безопасности: проверяем, существует ли локальный игрок
	if global.player == null or CAMERA_CONTROLLER == null:
		return
		
	var camera = CAMERA_CONTROLLER # Используем собственную камеру ноды, а не через глобал
	var space_state = camera.get_world_3d().direct_space_state
	var screen_center = get_viewport().get_visible_rect().size / 2
	
	var origin = camera.project_ray_origin(screen_center)
	var end = origin + camera.project_ray_normal(screen_center) * interact_distance
	
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_bodies = true
	query.exclude = [get_rid()] # Исключаем свой собственный RID напрямую
	
	var result = space_state.intersect_ray(query)
	current_cast_result = null 
	
	if result:
		current_cast_result = result.get("collider")
	
	if current_cast_result != interaction_cast_result:
		if interaction_cast_result and is_instance_valid(interaction_cast_result) and interaction_cast_result.has_user_signal("unfocused"):
			interaction_cast_result.emit_signal("unfocused")
		interaction_cast_result = current_cast_result
		if interaction_cast_result and is_instance_valid(interaction_cast_result):
			if interaction_cast_result.has_method("has_user_safe_signal") if has_method("has_user_safe_signal") else interaction_cast_result.has_user_signal("focused"):
				interaction_cast_result.emit_signal("focused")


func grapple() -> void:
	if is_grappling:
		is_grappling = false
		dissconect_grapple()
		return

	var camera = CAMERA_CONTROLLER
	var space_state = camera.get_world_3d().direct_space_state
	var screen_center = get_viewport().get_visible_rect().size / 2
	
	var origin = camera.project_ray_origin(screen_center)
	var end = origin + camera.project_ray_normal(screen_center) * grapple_distance
	
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	
	var result = space_state.intersect_ray(query)
	if result:
		grapple_target_point = result.get("position")
		is_grappling = true

func dissconect_grapple(boost : bool = false) -> void:
	velocity = Vector3.ZERO

@rpc("any_peer")
func recieve_damage(damage_value : int = 0) -> void:
	if not is_multiplayer_authority():
		return
	health -= damage_value
	if health <= 0:
		_die()

@rpc("any_peer", "call_local", "reliable")
func request_respawn() -> void:
	if not multiplayer.is_server():
		return
	health = max_health 
	var spawn_pos = Vector3(0, 2.5, 0)
	var points = get_tree().get_nodes_in_group("spawn_points")
	if points.size() > 0:
		spawn_pos = points.pick_random().global_position
	_reset_player_state.rpc(spawn_pos)

@rpc("any_peer", "call_local", "reliable")
func _reset_player_state(spawn_position: Vector3) -> void:
	process_mode = PROCESS_MODE_INHERIT
	show()
	velocity = Vector3.ZERO
	global_position = spawn_position
	health = max_health 
	await get_tree().physics_frame

func _die() -> void:
	process_mode = PROCESS_MODE_DISABLED 
	hide() 
	if is_multiplayer_authority():
		request_respawn.rpc()


# RPC-метод смены оружия: вызывается клиентом, выполняется на Сервере
# RPC-метод смены оружия: вызывается клиентом, выполняется на Сервере
@rpc("any_peer", "call_local", "reliable")
func request_weapon_change(new_weapon_path: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	
	# Проверяем, что ID отправителя совпадает с именем ноды этого игрока
	if name == str(sender_id):
		sync_weapon_path = new_weapon_path
		print("Сервер авторитетно сменил оружие для игрока ", sender_id, " на: ", new_weapon_path)
		
		# ФИКС ОШИБКИ: Если отправитель — это сам Сервер (Хост, ID = 1), 
		# не шлем RPC самому себе, а просто вызываем функцию локально.
		if sender_id == 1:
			_apply_weapon_change_locally()
		else:
			# Если это обычный клиент (не хост), принудительно отправляем команду назад
			_rpc_force_weapon_update_on_client.rpc_id(sender_id, new_weapon_path)


# Новый RPC-метод: выполняется строго на целевом клиенте
@rpc("any_peer", "reliable")
func _rpc_force_weapon_update_on_client(new_path: String) -> void:
	sync_weapon_path = new_path
	_apply_weapon_change_locally()


func _apply_weapon_change_locally() -> void:
	var weapon_node = get_node_or_null("CameraController/Recoil/SubViewportContainer/SubViewport/WeaponCameraController/WeaponCamera/WeaponRig/Weapon") as WeaponController
	if weapon_node == null:
		call_deferred("_apply_weapon_change_locally")
		return
		
	var weapon_resource = load(sync_weapon_path)
	if weapon_resource == null:
		return
		
	weapon_node.WEAPON_TYPE = weapon_resource
	weapon_node.load_weapon()
	_update_states_weapon_link(weapon_node)

# Вспомогательный метод для обновления ссылок во всех стейтах
func _update_states_weapon_link(weapon_node: WeaponController) -> void:
	var state_machine = get_node_or_null("PlayerStateMachine")
	if state_machine:
		for child in state_machine.get_children():
			if "WEAPON" in child:
				child.WEAPON = weapon_node
