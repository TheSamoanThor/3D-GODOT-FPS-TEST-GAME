class_name SlidingPlayerState 
extends PlayerMovementState

@export var SPEED: float = 6.0
@export var ACCELERATION : float = 0.1
@export var DECELERATION : float = 0.25
@export var TILT_AMOUNT : float = 0.09
@export_range(1, 6, 0.1) var SLIDE_ANIM_SPEED : float = 4.0
@onready var CROUCH_SHAPECAST : ShapeCast3D = %ShapeCast3D

func enter(previous_state) -> void:
	set_tilt(PLAYER._rotation_input) # Fixed variable name to match mouse controller
	
	# SAFE APPROACH: Dynamically find the track index instead of hardcoding "4"
	var anim = ANIMATION.get_animation("sliding")
	# Change "Player/CameraController:position" to the exact path of your track if it differs
	var speed_track = anim.find_track("CameraController:position", Animation.TYPE_VALUE) 
	if speed_track != -1:
		anim.track_set_key_value(speed_track, 0, PLAYER.velocity.length())
		
	ANIMATION.speed_scale = 1.0
	ANIMATION.play("sliding", -1.0, SLIDE_ANIM_SPEED)
	
func update(delta):
	PLAYER.update_gravity(delta)
	# Disabling or low values here help maintain direction while sliding
	PLAYER.update_input(SPEED, ACCELERATION, DECELERATION) 
	PLAYER.update_velocity()
	
func set_tilt(player_rotation) -> void:
	var tilt = Vector3.ZERO
	# Use rotation input to calculate lateral camera tilt during slide
	tilt.z = clamp(TILT_AMOUNT * player_rotation, -0.1, 0.1)
	
	if tilt.z == 0.0:
		tilt.z = 0.05
		
		var anim = ANIMATION.get_animation("sliding")
		# SAFE APPROACH: Dynamically find the camera rotation track instead of hardcoding "8"
		var rotation_track = anim.find_track("CameraController:rotation", Animation.TYPE_VALUE)
		if rotation_track != -1:
			anim.track_set_key_value(rotation_track, 1, tilt)
			anim.track_set_key_value(rotation_track, 2, tilt)

func finish():
	# Clean transition back to crouching once the slide function track triggers this method
	transition.emit("CrouchingPlayerState")

func exit() -> void:
	# RESET CAMERA TILT: Ensures the camera returns to perfectly straight alignment
	# when transitioning to Crouching or Walking states
	if PLAYER and PLAYER.CAMERA_CONTROLLER:
		PLAYER.CAMERA_CONTROLLER.rotation.z = 0.0
