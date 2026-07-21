extends Node3D

@export var weapon : WeaponController

@export var light : OmniLight3D
@export var emitter : GPUParticles3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	weapon.weapon_fired.connect(add_muzzle_flash)

func add_muzzle_flash() -> void:
	# Безопасно получаем текущий ресурс активного оружия
	var current_weapon = weapon.WEAPON_TYPE
	
	light.light_color = current_weapon.muzzle_flash_color
	
	# 2. Включаем свет и эмиттер
	light.visible = true
	emitter.emitting = true
	
	# 3. Ждем ровно столько секунд, сколько прописано в ресурсе этого оружия
	await get_tree().create_timer(current_weapon.muzzle_flash_speed).timeout
	
	# 4. Выключаем свет обратно
	light.visible = false
