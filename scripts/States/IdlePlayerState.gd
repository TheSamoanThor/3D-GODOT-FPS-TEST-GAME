class_name IdlePlayerState
extends PlayerMovementState

func enter(previous_state) -> void:
	if ANIMATION.is_playing() and ANIMATION.current_animation == "jumpEnd":
		await ANIMATION.animation_finished
	ANIMATION.pause()

func update(delta: float) -> void:
	PLAYER.update_gravity(delta)
	PLAYER.update_input(0.0, 0.0, 0.0)
	PLAYER.update_velocity()
	
	WEAPON.sway_weapon(delta, true)
	
	# Check if the player is trying to move using input vector
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if input_dir.length() > 0.0 and PLAYER.is_on_floor():
		transition.emit("WalkingPlayerState")
	if Input.is_action_just_pressed("crouch") and PLAYER.is_on_floor():
		transition.emit("CrouchingPlayerState")
	if Input.is_action_just_pressed("jump") and PLAYER.is_on_floor():
		transition.emit("JumpingPlayerState")
