class_name CrouchingPlayerState
extends PlayerMovementState

@export var SPEED : float = 3.0
@export var ACCELERATION : float = 0.1
@export var DECELERATION : float = 0.25
@export_range(1, 6, 0.1) var CROUCH_SPEED : float = 4.0
@onready var CROUCH_SHAPECAST : ShapeCast3D = %ShapeCast3D
@export var WEAPON_BOB_SPD : float = 2.0
@export var WEAPON_BOB_HORIS : float = 1.0
@export var WEAPON_BOB_VERT : float = 0.5

var RELEASED : bool = false

func enter(previous_state) -> void:
	ANIMATION.speed_scale = 1.0
	# FIXED: previous_state is an Object, it doesn't have a '.name' property. 
	# Checked using 'is' keyword or state class verification.
	if previous_state and not previous_state is SlidingPlayerState:
		ANIMATION.play("crouching", -1.0, CROUCH_SPEED)
	elif previous_state and previous_state is SlidingPlayerState:
		ANIMATION.current_animation = "crouching"
		ANIMATION.seek(1.0, true)

func exit() -> void:
	RELEASED = false

func update(delta) -> void:
	PLAYER.update_gravity(delta)
	PLAYER.update_input(SPEED, ACCELERATION, DECELERATION)
	PLAYER.update_velocity()
	
	WEAPON.sway_weapon(delta, false)
	WEAPON._weapon_bob(delta, WEAPON_BOB_SPD, WEAPON_BOB_HORIS, WEAPON_BOB_VERT)
	
	if Input.is_action_just_released("crouch"):
		uncrouch()
	elif Input.is_action_pressed("crouch") == false and RELEASED == false:
		RELEASED = true
		uncrouch()

func uncrouch():
	# Check if Shapecast detects low ceiling before standing up
	if CROUCH_SHAPECAST.is_colliding() == false and Input.is_action_pressed("crouch") == false:
		ANIMATION.play("crouching", -1.0, -CROUCH_SPEED * 1.5, true) # Ensure name matches your AnimationPlayer track ('Crouching')
		if ANIMATION.is_playing():
			await ANIMATION.animation_finished
		
		# FIXED: Instead of forcing Idle, detect if player is currently moving
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if input_dir.length() > 0.0:
			transition.emit("WalkingPlayerState")
		else:
			transition.emit("IdlePlayerState")
	
	elif CROUCH_SHAPECAST.is_colliding():
		# Ceiling blocked! Wait and try again cleanly without building stack frames
		await get_tree().create_timer(0.1).timeout
		if not Input.is_action_pressed("crouch"):
			uncrouch()
