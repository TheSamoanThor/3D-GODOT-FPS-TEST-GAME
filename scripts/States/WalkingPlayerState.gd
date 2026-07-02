class_name WalkingPlayerState
extends PlayerMovementState

@export var SPEED : float = 5.0
@export var ACCELERATION : float = 0.1
@export var DECELERATION : float = 0.25
@export var TOP_ANIM_SPEED : float = 2.2
@export var WEAPON_BOB_SPD : float = 4.0
@export var WEAPON_BOB_HORIS : float = 1.5
@export var WEAPON_BOB_VERT : float = 0.75

func enter(previous_state) -> void:
	if ANIMATION.is_playing() and ANIMATION.current_animation == "jumpEnd":
		await ANIMATION.animation_finished
	ANIMATION.play('walking', -1.0, 1.0)
	
func exit() -> void:
	ANIMATION.speed_scale = 1.0


func update(delta: float) -> void:
	# 1. Tick the coyote clock inherited from PlayerMovementState
	process_coyote_time(delta)
	
	# 2. Physics and movement processing
	PLAYER.update_gravity(delta)
	PLAYER.update_input(SPEED, ACCELERATION, DECELERATION)
	PLAYER.update_velocity()
	set_anim_speed(PLAYER.velocity.length())
	
	WEAPON.sway_weapon(delta, false)
	WEAPON._weapon_bob(delta, WEAPON_BOB_SPD, WEAPON_BOB_HORIS, WEAPON_BOB_VERT)
	
	# 3. Transition to Idle if the player stops moving entirely on the floor
	if PLAYER.velocity.length() == 0.0 and PLAYER.is_on_floor():
		transition.emit("IdlePlayerState")
		return
		
	# 4. Jump input handling using the active coyote time window
	if Input.is_action_just_pressed("jump") and can_coyote_jump():
		transition.emit("JumpingPlayerState")
		return

	# 5. Slipped off the edge: if coyote time expires, transition to Falling state smoothly
	if not PLAYER.is_on_floor() and not can_coyote_jump():
		transition.emit("FallingPlayerState")
		return

	# OPTIMIZATION: Check for sprint input inside the physics update loop
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
