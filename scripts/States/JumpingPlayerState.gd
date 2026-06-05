class_name JumpingPlayerState
extends PlayerMovementState

@export var SPEED : float = 5.0
@export var ACCELERATION : float = 0.1
@export var DECELERATION : float = 0.25

@export var MAX_JUMPS : int = 2 # Total allowed jumps (1 = normal jump, 2 = double jump)
var current_jump_count : int = 0

func enter(previous_state) -> void:
	# Reset the counter and perform the first initial jump
	current_jump_count = 1
	ANIMATION.play("jumpStart")
	perform_jump()

func update(delta: float) -> void:
	PLAYER.update_gravity(delta)
	
	# Keep drifting/steering controls in the air
	PLAYER.update_input(SPEED, ACCELERATION, DECELERATION)
	PLAYER.update_velocity()
	
	# Look for additional jumps while already in mid-air
	if Input.is_action_just_pressed("jump") and current_jump_count < MAX_JUMPS:
		current_jump_count += 1
		perform_jump()
	
	# Transition back to ground states when landing
	if PLAYER.is_on_floor():
		ANIMATION.play("jumpEnd")
		coyote_timer = 0.0 
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if input_dir.length() > 0.0:
			if Input.is_action_pressed("sprint"):
				transition.emit("SprintingPlayerState")
			else:
				transition.emit("WalkingPlayerState")
		else:
			transition.emit("IdlePlayerState")

# Helper function to apply upward velocity and play audio/effects if needed
func perform_jump() -> void:
	PLAYER.velocity.y = PLAYER.JUMP_VELOCITY
