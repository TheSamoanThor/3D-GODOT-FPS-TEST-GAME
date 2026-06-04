class_name WalkingPlayerState
extends PlayerMovementState

@export var SPEED : float = 5.0
@export var ACCELERATION : float = 0.1
@export var DECELERATION : float = 0.25
@export var TOP_ANIM_SPEED : float = 2.2

func enter() -> void:
	ANIMATION.play('walking', -1.0, 1.0)

func update(delta: float) -> void:
	PLAYER.update_gravity(delta)
	PLAYER.update_input(SPEED, ACCELERATION, DECELERATION)
	PLAYER.update_velocity()
	set_anim_speed(PLAYER.velocity.length())
	
	# Transition to Idle if player stops moving
	if PLAYER.velocity.length() == 0.0:
		transition.emit("IdlePlayerState")
		
	# OPTIMIZATION: Check for sprint input inside the physics update loop
	if Input.is_action_pressed("sprint") and PLAYER.is_on_floor():
		transition.emit("SprintingPlayerState")
	if Input.is_action_just_pressed("jump") and PLAYER.is_on_floor():
		transition.emit("JumpingPlayerState")

func set_anim_speed(spd: float) -> void:
	var alpha = remap(spd, 0.0, SPEED, 0.0, 1.0)
	ANIMATION.speed_scale = lerp(0.0, TOP_ANIM_SPEED, alpha)
