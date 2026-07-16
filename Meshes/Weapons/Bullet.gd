extends Area3D

signal hit_registered(position: Vector3, normal: Vector3)

var speed : float = 150.0
var damage : float = 25.0
var velocity : Vector3 = Vector3.ZERO
var bullet_hole = preload("res://Meshes/Weapons/bullet_hole.tscn")

func _ready() -> void:
	# Подключаем проверку столкновений
	body_entered.connect(_on_body_entered)
	# Удаляем пулю через 4 секунды, если она никуда не попала
	get_tree().create_timer(4.0).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	# Двигаем пулю вперед по её собственному вектору направления
	global_position += velocity * delta
	
	# Небольшая гравитация ( +- физика полета )
	velocity.y -= 9.8 * delta

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
