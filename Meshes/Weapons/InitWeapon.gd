@tool

extends Node3D

@export var WEAPON_TYPE : Weapons:
	set(value):
		WEAPON_TYPE = value
		if Engine.is_editor_hint():
			load_weapon
			
@onready var weapon_mesh : MeshInstance3D = %WeaponMesh
@onready var weapon_shadow : MeshInstance3D = %WeaponShadow

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	load_weapon()

func _input(event):
	if event.is_action_pressed("weapon1"):
		WEAPON_TYPE = load("res://Meshes/Weapons/Ranged/Colt1911/Colt1911Resource.tres")
		load_weapon()
	if event.is_action_pressed("weapon2"):
		WEAPON_TYPE = load("res://Meshes/Weapons/Melee/Crowbar/CrowbarResource.tres")
		load_weapon()

func load_weapon() -> void:
	weapon_mesh.mesh = WEAPON_TYPE.mesh # Set weapon mesh
	position = WEAPON_TYPE.position # Set weapon position
	rotation_degrees = WEAPON_TYPE.rotation # Set weapon rotation
	weapon_shadow.visible = WEAPON_TYPE.shadow # Turn shadow on/off
