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
		# Если модели нет, генерируем стандартный светящийся лазерный трассер
		var default_box = BoxMesh.new()
		default_box.size = data.trail_size
		mesh_instance.mesh = default_box
		
		# Создаем яркий несгораемый материал (Unshaded)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = data.trail_color
		mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		mesh_instance.material_override = mat


func _ready() -> void:
	# Подключаем проверку столкновений
	body_entered.connect(_on_body_entered)
	# Удаляем пулю через 4 секунды, если она никуда не попала
	get_tree().create_timer(4.0).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	if not data: return
	
	# Двигаем пулю
	global_position += velocity * delta
	# Применяем гравитацию с учетом модификатора из ресурса (например, стрела падает быстрее лазера)
	velocity.y -= (9.8 * data.gravity_modifier) * delta


func _on_body_entered(body: Node) -> void:
	# Игнорируем игрока, если пуля вылетела из него
	if body == global.player:
		return
		
	# Нанесение урона
	#if body.has_method("take_damage"):
		#body.take_damage(damage)
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
