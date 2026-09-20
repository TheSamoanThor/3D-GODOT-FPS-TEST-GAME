extends Node

# Ссылки на контейнеры интерфейса
@onready var main_menu_buttons: Control = %MainMenuBtns
@onready var mode_menu_buttons: Control = %ModeMenuBtns
@onready var connection_menu: Control = %ConnectionMenuBtns
@onready var address_entry: LineEdit = %AddressEntry
@onready var ui_layer: CanvasLayer = %UI
@onready var levels_menu_btns: Control = %LevelsMenuBtns
@onready var global_player_spawner: MultiplayerSpawner = $GlobalPlayerSpawner

const PLAYER_SCENE = preload("res://Controllers/PlayerScene.tscn")
const PORT = 9999
var enet_peer = ENetMultiplayerPeer.new()
var current_world: Node = null

# Путь к выбранной карте
var selected_level_path: String = "" 
var _target_mode: String = ""

func _ready() -> void:
	main_menu_buttons.show()
	mode_menu_buttons.hide()
	connection_menu.hide()
	levels_menu_btns.hide()
	
	# Переопределяем функцию спавна для встроенного спавнера игроков
	global_player_spawner.spawn_function = _custom_player_spawn

	# Автоматически сканируем папки уровней
	_build_levels_menu()

# 1. РЕКУРСИВНОЕ СКАНЕН И ЗАПОЛНЕНИЕ МЕНЮ (Работает идеально)
func _build_levels_menu() -> void:
	var container = levels_menu_btns.get_node("VBoxContainer")
	for child in container.get_children():
		if not child.name.begins_with("System"):
			child.queue_free()
	
	var base_levels_dir = "res://Levels/"
	_scan_dir_recursive(base_levels_dir, container)

func _scan_dir_recursive(path: String, container: Node) -> void:
	var dir = DirAccess.open(path)
	if not dir: return
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
			
		var full_item_path = path.path_join(file_name)
		
		if dir.current_is_dir():
			_scan_dir_recursive(full_item_path, container)
		else:
			if file_name.ends_with(".tscn") and file_name != "main.tscn" and "Map" in file_name:
				if not file_name.ends_with(".remap"):
					_create_level_button(file_name, full_item_path, container)
					
		file_name = dir.get_next()

func _create_level_button(file_name: String, full_path: String, container: Node) -> void:
	var btn = Button.new()
	btn.text = file_name.get_basename().replace("_", " ")
	btn.custom_minimum_size = Vector2(250, 50)
	
	btn.pressed.connect(func(): 
		selected_level_path = full_path
		print("Игрок выбрал карту по пути: ", selected_level_path)
		_start_selected_game()
	)
	container.add_child(btn)
	
	if selected_level_path == "":
		selected_level_path = full_path

# 2. ЛОГИКА ИНТЕРФЕЙСА КНОПОК
func _on_play_pressed() -> void:
	main_menu_buttons.hide()
	mode_menu_buttons.show()

func _show_main_menu() -> void:
	mode_menu_buttons.hide()
	levels_menu_btns.hide()
	main_menu_buttons.show()

func _on_multiplayer_selected() -> void:
	mode_menu_buttons.hide()
	connection_menu.show()

func _on_back_to_mode_pressed() -> void:
	connection_menu.hide()
	levels_menu_btns.hide()
	mode_menu_buttons.show()

func _on_singleplayer_selected() -> void:
	mode_menu_buttons.hide()
	_target_mode = "singleplayer"
	levels_menu_btns.show()

func _on_host_pressed() -> void:
	connection_menu.hide()
	_target_mode = "host"
	levels_menu_btns.show()

# КЛИЕНТ: Нажал Join
func _on_join_pressed() -> void:
	ui_layer.hide()
	var ip = address_entry.text if address_entry.text != "" else "localhost"
	enet_peer.create_client(ip, PORT)
	multiplayer.multiplayer_peer = enet_peer
	print("Клиент пытается подключиться к серверу...")
	
	# Настраиваем сигналы на клиенте
	multiplayer.connected_to_server.connect(_on_connected_to_server)

# 3. СЕТЕВАЯ ЛОГИКА ЗАПУСКА И СИНХРОНИЗАЦИИ
func _start_selected_game() -> void:
	if selected_level_path == "": return
	ui_layer.hide()
	
	if _target_mode == "singleplayer":
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		_load_map_local(selected_level_path)
		_spawn_player_native(1)
		
	elif _target_mode == "host":
		enet_peer.create_server(PORT)
		multiplayer.multiplayer_peer = enet_peer
		
		enet_peer.peer_connected.connect(_on_peer_connected)
		enet_peer.peer_disconnected.connect(_on_peer_disconnected)
		
		# Хост грузит карту у себя локально
		_load_map_local(selected_level_path)
		# Хост спавнит себя любимого
		_spawn_player_native(1)

# Вызывается на СЕРВЕРЕ, когда заходит новый Клиент
func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		print("Сервер заметил пира: ", peer_id)
		# ШАГ 1: Говорим зашедшему клиенту: «Загрузи вот эту карту из своих файлов!»
		_rpc_client_must_load_map.rpc_id(peer_id, selected_level_path)

# ВЫПОЛНЯЕТСЯ НА КЛИЕНТЕ: Сервер принудительно заставил нас загрузить карту
@rpc("any_peer", "reliable")
func _rpc_client_must_load_map(map_path: String) -> void:
	print("Получен приказ от сервера! Загружаем карту: ", map_path)
	_load_map_local(map_path)
	
	# ШАГ 2: Карта готова, пол под ногами есть. Шлём запрос серверу: «Я готов, спавнь меня!»
	_rpc_client_ready_to_spawn.rpc_id(1)

# ВЫПОЛНЯЕТСЯ НА СЕРВЕРЕ: Клиент отчитался, что карта у него загружена
@rpc("any_peer", "reliable")
func _rpc_client_ready_to_spawn() -> void:
	if multiplayer.is_server():
		var sender_id = multiplayer.get_remote_sender_id()
		print("Пир ", sender_id, " готов к спавну. Спавним!")
		# ШАГ 3: Теперь безопасно спавним игрока через MultiplayerSpawner
		_spawn_player_native(sender_id)

# 4. ФУНКЦИИ ИНСТАНЦИРОВАНИЯ (ЧИСТАЯ ЛОГИКА)

# Локальная загрузка карты (Одинаково для Хоста и для Клиента)
func _load_map_local(map_path: String) -> void:
	if is_instance_valid(current_world):
		current_world.queue_free()
		
	var pvp_manager = Node.new()
	pvp_manager.name = "PVP_World"
	add_child(pvp_manager)
	current_world = pvp_manager
	
	# Инстанцируем геометрию карты внутрь PVP_World
	var map_res = load(map_path)
	var map_instance = map_res.instantiate()
	map_instance.name = "LevelObjs"
	pvp_manager.add_child(map_instance)

# Нативный спавн игрока через MultiplayerSpawner (Только сервер!)
func _spawn_player_native(peer_id: int) -> void:
	if multiplayer.is_server() or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		# Вызов метода .spawn() заставит GlobalPlayerSpawner автоматически 
		# создать игрока и у себя, и у всех клиентов, вызвав функцию _custom_player_spawn
		global_player_spawner.spawn(peer_id)

# Внутренний метод, который Godot автоматически дергает при вызове .spawn()
func _custom_player_spawn(peer_id: int) -> Node:
	var player_instance = PLAYER_SCENE.instantiate()
	player_instance.name = str(peer_id)
	player_instance.set_multiplayer_authority(peer_id)
	
	# Добавляем в корень main, чтобы на 100% совпало с настройкой спавнера в редакторе
	# (Игрок появится в дереве, и узел MultiplayerSynchronizer соберется без ошибок)
	_finalize_player_spawn(player_instance)
	return player_instance

func _finalize_player_spawn(player_node: Node) -> void:
	if not player_node.is_node_ready():
		await player_node.ready
	
	# Даем физике Jolt один кадр встать на место
	await get_tree().physics_frame
	
	# Теперь точки спавна гарантированно существуют на карте у всех
	var spawn_pos = Vector3(0, 2.5, 0)
	var points = get_tree().get_nodes_in_group("spawn_points")
	if points.size() > 0:
		spawn_pos = points.pick_random().global_position
		
	player_node.global_position = spawn_pos
	if player_node.has_method("_reset_player_state"):
		player_node._reset_player_state.rpc(spawn_pos)

func _on_connected_to_server() -> void:
	print("Успешное соединение с сервером! Ожидаем карту...")

func _on_peer_disconnected(peer_id: int) -> void:
	var p_node = get_node_or_null(str(peer_id))
	if p_node:
		p_node.queue_free()

func _on_exit_pressed() -> void:
	get_tree().quit()
