class_name FallingPlayerState extends PlayerMovementState


@export var SPEED : float = 5.0
@export var ACCELERATION : float = 0.1
@export var DECELERATION : float = 0.25


func physics_update(delta: float) -> void:
	PLAYER.update_gravity(delta)
	PLAYER.update_input(SPEED, ACCELERATION, DECELERATION)
	PLAYER.update_velocity()
	
	# If the player presses jump in mid-air, they transition to JumpingPlayerState,
	# but it will count as an air-jump (losing the first ground jump charge)
	if Input.is_action_just_pressed("jump"):
		var jump_state = %JumpingPlayerState # Use get_node or unique name to access jump state data
		if jump_state:
			jump_state.current_jump_count = 1 # Consume the first jump charge
		transition.emit("JumpingPlayerState")
		return

	# Return to ground states upon landing safely
	if PLAYER.is_on_floor():
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if input_dir.length() > 0.0:
			if Input.is_action_pressed("sprint"):
				transition.emit("SprintingPlayerState")
			else:
				transition.emit("WalkingPlayerState")
		else:
			transition.emit("IdlePlayerState")
