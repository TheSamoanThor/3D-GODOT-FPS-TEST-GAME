class_name InteractionComponent extends Node

@export var highlight_mesh : MeshInstance3D

var parent
var highlight_material = preload("res://Materials/Highlight.tres")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	parent = get_parent() # must be immediate child
	connect_parent()
	set_default_mesh()
	highlight_mesh.material_overlay = null

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func in_range() -> void:
	highlight_mesh.material_overlay = highlight_material

func not_in_range() -> void:
	highlight_mesh.material_overlay = null

func on_interact() -> void:
	print(parent.name)

func connect_parent() -> void:
	parent.add_user_signal("focused")
	parent.add_user_signal("unfocused")
	parent.add_user_signal("interacted")
	parent.connect("focused", Callable(self, "in_range"))
	parent.connect("unfocused", Callable(self, "not_in_range"))
	parent.connect("interacted", Callable(self, "on_interact"))

func set_default_mesh() -> void:
	if highlight_mesh:
		pass
	else:
		for i in parent.get_children():
			if i is MeshInstance3D:
				highlight_mesh = i
