extends Area3D

signal hit_registered(position: Vector3, normal: Vector3)

# Сюда мы передадим настройки из оружия в момент спавна
var data : BulletData
var damage : float = 0.0
var velocity : Vector3 = Vector3.ZERO

@onready var mesh_instance : MeshInstance3D = %MeshInstance3D

func init_bullet(bullet_settings: BulletData, weapon_damage: float, direction: Vector3) -> void:
	data = bullet_settings
	damage = weapon_damage
	
	# Считаем вектор стартовой скорости на основе ресурса
	velocity = direction * data.speed
	
	# Перестраиваем визуал пули "на лету" под требования ресурса
	if data.model_mesh:
		# Если в ресурсе есть готовая 3D-модель (например, стрела), используем её
		mesh_instance.mesh = data.model_mesh
	else:
		# Генерируем желтый шар радиусом 0.1
		var default_sphere = SphereMesh.new()
		default_sphere.radius = 0.01
		default_sphere.height = 0.02 # Высота шара (диаметр) равна radius * 2
		mesh_instance.mesh = default_sphere
		
		# Создаем яркий желтый материал
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1, 1, 0) # Желтый цвет (RGB)
		mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		mesh_instance.material_override = mat


func _ready() -> void:
	# Подключаем проверку столкновений
	body_entered.connect(_on_body_entered)
	# Удаляем пулю через 4 секунды, если она никуда не попала
	get_tree().create_timer(4.0).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	if not data: return
	
	var movement = velocity * delta
	var space_state = get_world_3d().direct_space_state
	
	# Пускаем луч на расстояние, которое пуля пролетит в этом кадре
	var query = PhysicsRayQueryParameters3D.create(global_position, global_position + movement)
	query.collide_with_bodies = true
	query.exclude = [get_rid(), global.player.get_rid()]
	
	var result = space_state.intersect_ray(query)
	
	if result:
		# Нашли точную стену ДО того, как физически пролетели её
		hit_registered.emit(result.get("position"), result.get("normal"))
		
		# Если это игрок, наносим урон через RPC на сервере
		var collider = result.get("collider")
		if collider.has_method("recieve_damage"):
			collider.recieve_damage.rpc_id(collider.get_multiplayer_authority(), damage)
			
		queue_free()
		return

	# Если препятствий нет — двигаем пулю дальше
	global_position += movement
	velocity.y -= (9.8 * data.gravity_modifier) * delta


func _on_body_entered(body: Node) -> void:
	# Игнорируем игрока, если пуля вылетела из него
	#if body == global.player:
		#return
	
	# Нанесение урона
	#if body.has_method("recieve_damage"):
		#print("take damage")
		#body.recieve_damage(damage)
		#body.recieve_damage.rpc_id(body.get_multiplayer_authority(), damage)
	# Спавним след от пули на месте столкновения
	# Выпускаем короткий луч из текущей позиции назад/вперед, чтобы найти точную поверхность стены
	var space_state = get_world_3d().direct_space_state
	# Берем точку чуть позади пули и чуть впереди пули по вектору её скорости
	var dir = velocity.normalized()
	var origin = global_position - (dir * 2.0)
	var end = global_position + (dir * 2.0)
	
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_bodies = true
	# Игнорируем пулю и игрока
	query.exclude = [get_rid(), global.player.get_rid()]
	
	var result = space_state.intersect_ray(query)
	
	if result:
		# Передаем абсолютно точные координаты поверхности и честную нормаль стены из рейкаста!
		hit_registered.emit(result.get("position"), result.get("normal"))
	else:
		# Если луч почему-то не попал (редкий баг), передаем дефолтные значения
		hit_registered.emit(global_position, -dir)
	
	# Переносим удаление пули на конец кадра через call_deferred.
	# Это дает 100% гарантию, что сигнал успеет обработаться скриптом оружия
	call_deferred("queue_free")
