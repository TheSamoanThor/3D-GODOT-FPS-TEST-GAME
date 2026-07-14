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

var _speed : float
var _mouse_input : bool = false
var _mouse_rotation : Vector3
var _rotation_input : float
var _tilt_input : float

var _current_rotation : float

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("exit"):
		get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	_mouse_input = event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	if _mouse_input:
		_rotation_input = -event.relative.x * MOUSE_SENSITIVITY
		_tilt_input = -event.relative.y * MOUSE_SENSITIVITY

func _physics_process(delta: float) -> void:
	global.debug.add_property("RealSpeed", velocity.length(), 1)
	global.debug.add_property("RealSpeedVect", get_real_velocity(), 2)
	global.debug.add_property("Animation", ANIMATIONPLAYER.current_animation, 2)
	global.debug.add_property("Rotation", rotation, 2)
	#global.debug.add_property("Z tilt", CAMERA_CONTROLLER.rotation.z, 2)
	_update_camera()

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
	
	_rotation_input = 0.0
	_tilt_input = 0.0


func _ready() -> void:
	global.player = self
	
	# Wait one frame to let the Compatibility renderer initialize environment maps safely
	await get_tree().process_frame
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if CROUCH_SHAPECAST != null:
		CROUCH_SHAPECAST.add_exception(self)

func update_gravity(delta: float) -> void:
	velocity += get_gravity() * delta

# Movement logic optimized to receive physics parameters directly from states
func update_input(speed: float, acceleration: float, deceleration: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = lerp(velocity.x, direction.x * speed, acceleration)
		velocity.z = lerp(velocity.z, direction.z * speed, acceleration)
	else:
		velocity.x = move_toward(velocity.x, 0, deceleration)
		velocity.z = move_toward(velocity.z, 0, deceleration)

func update_velocity() -> void:
	move_and_slide()

func _process(delta: float) -> void:
	if WEAPON_CONTROLLER == null:
		return
		
	# 1. Определяем, стоит игрок или идет
	var is_idle: bool = velocity.length() < 0.2
	
	# 2. Если игрок идет, рассчитываем боббинг (покачивание шагов)
	if not is_idle:
		# Параметры: delta, скорость шагов, качание по X, качание по Y
		# Вы можете настроить эти цифры под ваш вкус
		WEAPON_CONTROLLER._weapon_bob(delta, 10.0, 0.04, 0.02)
	
	# 3. Передаем ввод мыши напрямую в оружие, используя закешированное значение!
	# Так как оригинальный инпут зануляется физикой, мы берем относительное движение камеры
	if _current_rotation != 0.0 or _tilt_input != 0.0:
		# Восстанавливаем вектор движения мыши для оружия
		# Делим на SENSITIVITY, чтобы вернуть чистые пиксели движения, которые ждет оружие
		WEAPON_CONTROLLER.mouse_movement = Vector2(
			-_current_rotation / MOUSE_SENSITIVITY, 
			-_tilt_input / MOUSE_SENSITIVITY
		)
	
	# 4. Вызываем свей оружия ОДИН раз для всех состояний прямо отсюда
	WEAPON_CONTROLLER.sway_weapon(delta, is_idle)
