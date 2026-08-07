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
	if event.is_action_pressed("attack"):
		WEAPON_CONTROLLER._attack.rpc()
	if event.is_action_pressed("special_ability") and can_grapple:
		grapple()


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	
	_mouse_input = event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	if _mouse_input:
		_rotation_input -= event.relative.x * MOUSE_SENSITIVITY
		_tilt_input -= event.relative.y * MOUSE_SENSITIVITY


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	
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
		# --- СТАНДАРТНАЯ ЛОГИКА ДВИЖЕНИЯ ---
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
		# Отключаем камеру оружия и весь WeaponRig для чужих игроков
		# Укажи точный путь до твоего узла WeaponRig или WeaponViewport
		%SubViewportContainer.hide() 
		# Если WeaponRig лежит в камере, выключаем его процесс:
		%WeaponRig.set_process(false)
		%WeaponRig.set_physics_process(false)
		return
	
	global.player = self
	
	# Wait one frame to let the Compatibility renderer initialize environment maps safely
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
	if not is_multiplayer_authority(): return
	
	if WEAPON_CONTROLLER == null:
		return
		
	# 1. Проверяем движение персонажа прямо в графическом кадре через инпут
	var is_idle: bool = velocity.length() < 0.2
	
	# 2. Если игрок идет, стейт-машина сама настроит параметры WEAPON_CONTROLLER
	# А этот код просто плавно крутит счетчик времени анимации оружия
	if not is_idle:
		# Вызываем ОДИН раз для всех состояний ходьбы/приседа/бега
		WEAPON_CONTROLLER._weapon_bob(delta, WEAPON_CONTROLLER.bob_speed, WEAPON_CONTROLLER.bob_horizontal, WEAPON_CONTROLLER.bob_vertical)
	
	# 3. Передаем ввод мыши для увода оружия (Sway)
	if _current_rotation != 0.0 or _tilt_input != 0.0:
		WEAPON_CONTROLLER.mouse_movement = Vector2(
			-_current_rotation / MOUSE_SENSITIVITY, 
			-_tilt_input / MOUSE_SENSITIVITY
		)
	
	# 4. Вызываем обновление положения оружия
	WEAPON_CONTROLLER.sway_weapon(delta, is_idle)
	
	# Оставляем ваш рейкаст интеракта
	interact_cast()
	_update_camera()
	
	_rotation_input = 0.0
	_tilt_input = 0.0


func interact() -> void:
	if interaction_cast_result and interaction_cast_result.has_user_signal("interacted"):
		interaction_cast_result.emit_signal("interacted")


func interact_cast() -> void:
	# stole raycast code from attack func
	var camera = global.player.CAMERA_CONTROLLER
	var space_state = camera.get_world_3d().direct_space_state
	
	# Берем центр видимой игровой области, а не физического окна
	var screen_center = get_viewport().get_visible_rect().size / 2
	
	var origin = camera.project_ray_origin(screen_center)
	var end = origin + camera.project_ray_normal(screen_center) * interact_distance
	
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_bodies = true
	
	query.exclude = [global.player.get_rid()]
	
	var result = space_state.intersect_ray(query)
	
	# to get rid of highlight when obj is not "selected"
	current_cast_result = null 
	
	if result:
		current_cast_result = result.get("collider")
	
	if current_cast_result != interaction_cast_result:
		if interaction_cast_result and interaction_cast_result.has_user_signal("unfocused"):
			interaction_cast_result.emit_signal("unfocused")
		interaction_cast_result = current_cast_result
		if interaction_cast_result and interaction_cast_result.has_user_signal("focused"):
			interaction_cast_result.emit_signal("focused")


func grapple() -> void:
	# Если мы уже летим на крюке, повторное нажатие отключает его (тоггл)
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
	query.exclude = [get_rid()] # Игнорируем себя
	
	var result = space_state.intersect_ray(query)
	
	if result:
		# Нашли точку! Запоминаем её и переводим игрока в режим полета
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


# Запрос на респавн отправляется на сервер
@rpc("any_peer", "call_local", "reliable")
func request_respawn() -> void:
	# Безопасность: только сервер имеет право перемещать игроков и менять им здоровье
	if not multiplayer.is_server():
		return
	# 1. Сбрасываем здоровье до максимума
	health = max_health 
	
	# 2. Находим новую случайную точку через метод менеджера (или прямо здесь)
	var spawn_pos = Vector3(0, 2.5, 0)
	var points = get_tree().get_nodes_in_group("spawn_points")
	if points.size() > 0:
		spawn_pos = points.pick_random().global_position
	
	# 3. Уведомляем клиентов, что игрок снова живой (например, включаем видимость)
	_reset_player_state.rpc(spawn_pos)


# Выполняется на клиенте, который владеет этим персонажем
# почему-то отрабатывает дважды. Но не сильно важно. Наверное)))
# вероятно, один раз на сервере, один на клиенте
@rpc("any_peer", "call_local", "reliable")
func _reset_player_state(spawn_position: Vector3) -> void:
	# Включаем обратно обработку физики и видимость
	process_mode = PROCESS_MODE_INHERIT
	show()
	print('reset')
	# Сбрасываем скорость, чтобы не "лететь" по инерции после возрождения
	velocity = Vector3.ZERO
	# Устанавливаем позицию (теперь клиент делает это сам, и синхронизатор не будет спорить)
	global_position = spawn_position
	
	health = max_health 
	
	# Даем Godot один физический кадр, чтобы MultiplayerSynchronizer зафиксировал 
	# новые координаты и не пытался утянуть игрока обратно в точку смерти
	await get_tree().physics_frame


func _die() -> void:
	# Выключаем обработку физики и ввода на время смерти
	process_mode = PROCESS_MODE_DISABLED 
	hide() # Прячем игрока
	
	# Если это наш локальный игрок, просим сервер нас возродить
	if is_multiplayer_authority():
		request_respawn.rpc()
