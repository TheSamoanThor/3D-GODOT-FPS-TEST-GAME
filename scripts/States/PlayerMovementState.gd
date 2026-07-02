class_name PlayerMovementState
extends State

var PLAYER: Player
var ANIMATION: AnimationPlayer
var WEAPON : WeaponController

# Coyote Time settings
var coyote_timer: float = 0.0
@export var COYOTE_DURATION: float = 0.15 # Time window in seconds (150ms is standard)

func _ready() -> void:
	await owner.ready
	PLAYER = owner as Player
	ANIMATION = PLAYER.ANIMATIONPLAYER
	WEAPON = PLAYER.WEAPON_CONTROLLER

# Helper to process coyote time ticks
func process_coyote_time(delta: float) -> void:
	if PLAYER.is_on_floor():
		coyote_timer = COYOTE_DURATION
	else:
		coyote_timer -= delta

# Check if we can still execute a coyote jump
func can_coyote_jump() -> bool:
	return coyote_timer > 0.0
