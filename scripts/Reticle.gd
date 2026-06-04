extends CenterContainer

@export var RETICLE_LINES : Array[Line2D]
@export var PLAYER_CONTROLLER : CharacterBody3D
@export var RETICLE_SPEED : float = 0.25
@export var RETICLE_DISTANCE : float = 2.0
@export var DOT_RADIUS : float = 1.0
@export var RETICLE_COLOR : Color = Color.WHITE
@export var DYNAMIC_RETICLE : bool = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Loop through each line and set its color to match DOT_COLOR
	for line in RETICLE_LINES:
		if line != null:
			line.default_color = RETICLE_COLOR
	queue_redraw()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if DYNAMIC_RETICLE:
		# Pass delta into the function for frame-rate independent movement
		adjust_reticle_lines(delta)

func _draw():
	draw_circle(Vector2(0,0), DOT_RADIUS, RETICLE_COLOR)


func adjust_reticle_lines(delta: float):
	var vel = PLAYER_CONTROLLER.get_real_velocity()
	var origin = Vector3(0,0,0)
	var pos = Vector2(0,0)
	var speed = origin.distance_to(vel)
	
	# Multiply RETICLE_SPEED by delta to get consistent smoothing on any FPS
	var lerp_step = RETICLE_SPEED * delta * 60.0 # Normalized around 60 FPS
	
	# Adjust reticle lines position smoothly
	RETICLE_LINES[0].position = lerp(RETICLE_LINES[0].position, pos + Vector2(0, -speed * RETICLE_DISTANCE), lerp_step) # Top
	RETICLE_LINES[1].position = lerp(RETICLE_LINES[1].position, pos + Vector2(speed * RETICLE_DISTANCE, 0), lerp_step)  # Right
	RETICLE_LINES[2].position = lerp(RETICLE_LINES[2].position, pos + Vector2(0, speed * RETICLE_DISTANCE), lerp_step)  # Bottom
	RETICLE_LINES[3].position = lerp(RETICLE_LINES[3].position, pos + Vector2(-speed * RETICLE_DISTANCE, 0), lerp_step) # Left





#func adjust_reticle_lines(): # old ver
	#var vel = PLAYER_CONTROLLER.get_real_velocity()
	#var origin = Vector3(0,0,0)
	#var pos = Vector2(0,0)
	#var speed = origin.distance_to(vel)
	#
	## adjust reticle lines position
	#RETICLE_LINES[0].position = lerp(RETICLE_LINES[0].position, pos + Vector2(0, -speed*RETICLE_DISTANCE), RETICLE_SPEED) #Top
	#RETICLE_LINES[1].position = lerp(RETICLE_LINES[1].position, pos + Vector2(speed*RETICLE_DISTANCE, 0), RETICLE_SPEED) #Right
	#RETICLE_LINES[2].position = lerp(RETICLE_LINES[2].position, pos + Vector2(0, speed*RETICLE_DISTANCE), RETICLE_SPEED) #Bottom
	#RETICLE_LINES[3].position = lerp(RETICLE_LINES[3].position, pos + Vector2(-speed*RETICLE_DISTANCE, 0), RETICLE_SPEED) #Left
	
