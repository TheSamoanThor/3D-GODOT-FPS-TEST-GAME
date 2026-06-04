class_name PlayerMovementState
extends State

var PLAYER: Player
var ANIMATION: AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await owner.ready
	PLAYER = owner as Player
	ANIMATION = PLAYER.ANIMATIONPLAYER
