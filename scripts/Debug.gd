extends PanelContainer

@onready var property_container = %VBoxContainer

#var property
var frames_per_second : String

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# set global references to self in Global Singleton
	global.debug = self
	# hide debug panel on load
	visible = false

func _input(event: InputEvent) -> void:
	#Toggle debug panel
	if event.is_action_pressed("debug"):
		visible = !visible

# callable func to add new debug property (legacy :) )
#func add_debug_property(title: String, value):
	#property = Label.new() #create new label node
	#property_container.add_child(property) #add new node as child to vbox container
	#property.name = title # set name to title
	#property.text = property.name + ": " + value

func add_property(title: String, value, order):
	var target
	target = property_container.find_child(title, true, false) # try to find label node with same name
	if !target: # if no curr label for this prop
		target = Label.new() # create new label node
		property_container.add_child(target) # add new node as child to vbox container
		target.name = title # set name to title
		target.text = target.name + ": " + str(value) # set txt value
	elif visible:
		target.text = title + ": " + str(value) # update text value
		property_container.move_child(target, order) #reorder prop based on given order value


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if visible:
		# use delta time to get approx frames per sec and round to 2 decimal places
		# !DISABLE VSYNC IF FPS IS STUCK AT 60!
		#frames_per_second = "%.2f" % (1.0/delta) # gets fps every frame
		frames_per_second = ("%.2f" % Engine.get_frames_per_second()) #ges fps every sec
		global.debug.add_property("FPS", frames_per_second, 3)
