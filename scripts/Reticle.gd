extends CenterContainer

@export var RETICLE_LINES : Array[Line2D]
@export var PLAYER_CONTROLLER : CharacterBody3D
@export var RETICLE_SPEED : float = 15.0     # Увеличена базовая скорость для плавного lerp
@export var RETICLE_DISTANCE : float = 2.0    # Множитель разлета от скорости
@export var RETICLE_BASE_GAP : float = 5.0    # Минимальный зазор прицела в покое (в пикселях)
@export var DOT_RADIUS : float = 1.0
@export var RETICLE_COLOR : Color = Color.WHITE
@export var DYNAMIC_RETICLE : bool = true

# Массив для хранения чистых векторов смещения каждой линии
var base_directions : Array[Vector2] = [
	Vector2(0, -1), # Top (вверх)
	Vector2(1, 0),  # Right (вправо)
	Vector2(0, 1),  # Bottom (вниз)
	Vector2(-1, 0)  # Left (влево)
]

func _ready() -> void:
	# Насильно сбрасываем позицию самого контейнера в локальный ноль
	for line in RETICLE_LINES:
		if line != null:
			line.default_color = RETICLE_COLOR
			line.position = Vector2.ZERO # Линии жестко привязываются к центру (0,0)
	queue_redraw()

func _process(delta: float) -> void:
	if DYNAMIC_RETICLE and PLAYER_CONTROLLER:
		adjust_reticle_lines(delta)

func _draw():
	# Находим реальный центр контейнера на основе его текущих размеров
	var center_pos = get_rect().size / 2
	# Рисуем точку строго в вычисленном центре
	draw_circle(center_pos, DOT_RADIUS, RETICLE_COLOR)

func adjust_reticle_lines(delta: float):
	if not PLAYER_CONTROLLER:
		return
		
	var vel = PLAYER_CONTROLLER.get_real_velocity()
	var speed = Vector2(vel.x, vel.z).length() 
	
	# Вычисляем целевой динамический зазор
	var target_dynamic_gap = RETICLE_BASE_GAP + (speed * RETICLE_DISTANCE)
	var lerp_factor = 1.0 - exp(-RETICLE_SPEED * delta)
	
	# Вычисляем центр, к которому должны привязываться линии
	var center_pos = get_rect().size / 2
	
	# Плавно двигаем линии, учитывая смещение центра координат
	for i in range(min(RETICLE_LINES.size(), base_directions.size())):
		var line = RETICLE_LINES[i]
		if line != null:
			# Целевая позиция = центр контейнера + смещение линии в сторону
			var target_pos = center_pos + (base_directions[i] * target_dynamic_gap)
			line.position = line.position.lerp(target_pos, lerp_factor)
