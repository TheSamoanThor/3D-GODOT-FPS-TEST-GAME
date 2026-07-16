class_name Weapons extends Resource

@export var name : StringName

@export_category("Weapon Orientation")
@export var position : Vector3
@export var rotation : Vector3
@export var scale : Vector3

@export_category("Visual Settings")
@export var mesh : Mesh
@export var shadow : bool

@export_category("Weapon Sway")
@export var sway_min : Vector2 = Vector2(-20.0,-20.0)
@export var sway_max : Vector2 = Vector2(20.0,20.0)
@export_range(0,0.2,0.01) var sway_speed_position : float = 0.07
@export_range(0,0.2,0.01) var sway_speed_rotation : float = 0.1
@export_range(0,0.25,0.01) var sway_amount_position : float = 0.1
@export_range(0,50,0.1) var sway_amount_rotation : float = 30.0
@export var idle_sway_adjustment : float = 10.0
@export var idle_sway_rotation_strength : float = 300.0
@export_range(0.1,10.0,0.1) var random_sway_amount : float = 5.0

@export_category("Feature Settings")
@export var damage : float
@export var isMelee : bool
@export var range : float
@export var isRayWeapon: bool = false

@export_category("Weapon Accuracy")
@export var base_spread : float = 0.01 # Базовый разброс оружия (в радианах)
@export var movement_spread_factor : float = 0.05 # Насколько сильно разброс увеличивается от скорости хода
#@export var bullet_scene # MUST BE ADDED FOR DIFFERENT AMMO TYPES

@export_category("Muzzle Flash Settings")
@export var muzzle_flash_position : Vector3       # Индивидуальная позиция дула
@export var muzzle_flash_color : Color = Color(1, 0.6, 0) # Цвет вспышки (по умолчанию оранжевый)
@export var muzzle_flash_speed : float = 0.05     # Время горения вспышки
