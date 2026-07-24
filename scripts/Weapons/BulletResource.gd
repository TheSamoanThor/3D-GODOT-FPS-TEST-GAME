class_name BulletData extends Resource

@export_category("Bullet Visuals")
@export var model_mesh : Mesh # 3D-модель (капсула, стрела или ракета)
@export var trail_color : Color = Color(1, 0.6, 0) # Цвет светящегося следа
@export var trail_size : Vector3 = Vector3(0.05, 0.05, 0.4) # Размеры меша пули

@export_category("Bullet Physics")
@export var speed : float = 100.0           # Скорость полета снаряда
@export var gravity_modifier : float = 1.0  # Насколько сильно падает пуля (0 - летит прямо)
