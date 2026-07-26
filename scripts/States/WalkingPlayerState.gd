class_name WalkingPlayerState extends PlayerMovementState


@export var SPEED : float = 5.0
@export var ACCELERATION : float = 0.1
@export var DECELERATION : float = 0.25
@export var TOP_ANIM_SPEED : float = 2.2
@export var WEAPON_BOB_SPD : float = 4.0
@export var WEAPON_BOB_HORIS : float = 1.5
@export var WEAPON_BOB_VERT : float = 0.75


func enter(previous_state) -> void:
	WEAPON.bob_speed = WEAPON_BOB_SPD
	WEAPON.bob_horizontal = WEAPON_BOB_HORIS
	WEAPON.bob_vertical = WEAPON_BOB_VERT
	ANIMATION.play('walking', -1.0, 1.0)


func exit() -> void:
	ANIMATION.speed_scale = 1.0


func update(delta: float) -> void:
	set_anim_speed(PLAYER.velocity.length())


func physics_update(delta: float) -> void:
	process_coyote_time(delta)
	
	PLAYER.update_gravity(delta)
	PLAYER.update_input(SPEED, ACCELERATION, DECELERATION)
	PLAYER.update_velocity()
	# Получаем вектор нажатых клавиш
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	
	if input_dir.length() == 0.0 and PLAYER.is_on_floor():
		transition.emit("IdlePlayerState")
		return
		
	if Input.is_action_just_pressed("jump") and can_coyote_jump():
		transition.emit("JumpingPlayerState")
		return

	if not PLAYER.is_on_floor() and not can_coyote_jump():
		transition.emit("FallingPlayerState")
		return

	if PLAYER.is_on_floor():
		if Input.is_action_pressed("sprint"):
			transition.emit("SprintingPlayerState")
			return
		if Input.is_action_just_pressed("crouch"):
			transition.emit("CrouchingPlayerState")
			return


func set_anim_speed(spd: float) -> void:
	# If the AnimationPlayer is still blending or processing 'jumpEnd',
	# do NOT override the speed_scale with locomotion speed. Keep it normal (1.0).
	if ANIMATION.current_animation == "jumpEnd":
		ANIMATION.speed_scale = 1.0
		return
		
	# Otherwise, scale walking/sprinting pace normally
	var alpha = remap(spd, 0.0, SPEED, 0.0, 1.0)
	ANIMATION.speed_scale = lerp(0.0, TOP_ANIM_SPEED, alpha)
