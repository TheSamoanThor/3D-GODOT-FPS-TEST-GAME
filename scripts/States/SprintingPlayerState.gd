class_name SprintingPlayerState 
extends PlayerMovementState

@export var SPEED : float = 7.0
@export var ACCELERATION : float = 0.15
@export var DECELERATION : float = 0.25
@export var TOP_ANIM_SPEED : float = 1.6
@export var WEAPON_BOB_SPD : float = 6.0
@export var WEAPON_BOB_HORIS : float = 1.5
@export var WEAPON_BOB_VERT : float = 0.75

func enter(previous_state) -> void:
	if ANIMATION.is_playing() and ANIMATION.current_animation == "jumpEnd":
		await ANIMATION.animation_finished
	ANIMATION.play('sprinting', 0.5, 1.0)

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
	
	# 3. Jump input handling using the active coyote time window during sprint
	if Input.is_action_just_pressed("jump") and can_coyote_jump():
		transition.emit("JumpingPlayerState")
		return

	# 4. Slipped off the edge while sprinting: transition to Falling state smoothly
	if not PLAYER.is_on_floor() and not can_coyote_jump():
		transition.emit("FallingPlayerState")
		return

	# 5. Standard sprint exit transitions on the floor
	if PLAYER.is_on_floor():
		# Return to walking if the sprint key is released
		if Input.is_action_just_released("sprint"):
			transition.emit("WalkingPlayerState")
			return
		# Directly slide or crouch from sprint if key is pressed
		if Input.is_action_just_pressed("crouch") and PLAYER.velocity.length() > 6.0:
			transition.emit("SlidingPlayerState")
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
