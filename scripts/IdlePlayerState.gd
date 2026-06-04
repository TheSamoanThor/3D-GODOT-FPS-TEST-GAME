class_name IdlePlayerState
extends PlayerMovementState

func enter() -> void:
	ANIMATION.pause()

func update(delta: float) -> void:
	PLAYER.update_gravity(delta)
	PLAYER.update_input(0.0, 0.0, 0.0)
	PLAYER.update_velocity()
	
	# NEW LOGIC: Check if the player is trying to move using input vector
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if input_dir.length() > 0.0 and PLAYER.is_on_floor():
		transition.emit("WalkingPlayerState") # Make sure case sensitivity matches your StateMachine!
