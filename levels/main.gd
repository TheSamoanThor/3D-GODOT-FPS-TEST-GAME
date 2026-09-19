extends Node

# Ссылки на контейнеры интерфейса
@onready var main_menu_buttons: Control = %MainMenuBtns
@onready var mode_menu_buttons: Control = %ModeMenuBtns
@onready var connection_menu: Control = %ConnectionMenuBtns
@onready var address_entry: LineEdit = %AddressEntry
@onready var ui_layer: CanvasLayer = %UI

const PLAYER_SCENE = preload("res://Controllers/PlayerScene.tscn")
const PORT = 9999
var enet_peer = ENetMultiplayerPeer.new()
var current_world: Node = null

func _ready() -> void:
	# Настраиваем стартовое отображение меню
	main_menu_buttons.show()
	mode_menu_buttons.hide()
	connection_menu.hide()
	
	# Подключаем сигналы базовых кнопок главного меню
	main_menu_buttons.get_node("VBoxContainer/Play").pressed.connect(_on_play_pressed)
	main_menu_buttons.get_node("VBoxContainer/Exit").pressed.connect(func(): get_tree().quit())
	
	# Подключаем сигналы меню выбора режима
	mode_menu_buttons.get_node("VBoxContainer/SingleplayerBtn").pressed.connect(_on_singleplayer_selected)
	mode_menu_buttons.get_node("VBoxContainer/MultiplayerBtn").pressed.connect(_on_multiplayer_selected)
	mode_menu_buttons.get_node("VBoxContainer/BackBtn").pressed.connect(_show_main_menu)
	
	# Подключаем сигналы сетевого меню
	connection_menu.get_node("VBoxContainer/HostBtn").pressed.connect(_on_host_pressed)
	connection_menu.get_node("VBoxContainer/JoinBtn").pressed.connect(_on_join_pressed)
	connection_menu.get_node("VBoxContainer/BackBtn").pressed.connect(_on_back_to_mode_pressed)
	
	# ГЛАВНЫЙ СЕТЕВОЙ СИГНАЛ ДЛЯ КЛИЕНТА:
	# Срабатывает автоматически, когда клиент успешно вошел на сервер
	multiplayer.connected_to_server.connect(_on_connected_to_server)

# Навигация по меню
func _on_play_pressed() -> void:
	main_menu_buttons.hide()
	mode_menu_buttons.show()

func _show_main_menu() -> void:
	mode_menu_buttons.hide()
	main_menu_buttons.show()

func _on_multiplayer_selected() -> void:
	mode_menu_buttons.hide()
	connection_menu.show()

func _on_back_to_mode_pressed() -> void:
	connection_menu.hide()
	mode_menu_buttons.show()

# Логика запуска ОДИНОЧНОЙ игры
func _on_singleplayer_selected() -> void:
	ui_layer.hide()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_load_world_scene("res://Levels/PVP/PVP_lvl/PvP_world.tscn")
	_spawn_player(1)

# Логика СЕТЕВОЙ игры (Хост)
func _on_host_pressed() -> void:
	ui_layer.hide()
	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	_load_world_scene("res://Levels/PVP/PVP_lvl/PvP_world.tscn")
	_spawn_player(1)

# Логика СЕТЕВОЙ игры (Клиент нажимает Кнопку)
func _on_join_pressed() -> void:
	ui_layer.hide()
	var ip = address_entry.text if address_entry.text != "" else "localhost"
	enet_peer.create_client(ip, PORT)
	multiplayer.multiplayer_peer = enet_peer
	
	# Просто загружаем карту локально
	_load_world_scene("res://Levels/PVP/PVP_lvl/PvP_world.tscn")

# Срабатывает на клиенте, когда сеть поднялась
func _on_connected_to_server() -> void:
	# Даем один кадр на финальное построение дерева сцены мира
	await get_tree().process_frame
	# Теперь пир гарантированно подключен, отправляем RPC запрос серверу
	_request_spawn_on_server.rpc_id(1)

# RPC запрос от клиента к серверу
@rpc("any_peer", "call_local", "reliable")
func _request_spawn_on_server() -> void:
	if multiplayer.is_server():
		var sender_id = multiplayer.get_remote_sender_id()
		_spawn_player(sender_id)

func _load_world_scene(scene_path: String) -> Node:
	if is_instance_valid(current_world):
		current_world.queue_free()
	
	var world_res = load(scene_path)
	current_world = world_res.instantiate()
	add_child(current_world)
	return current_world

func _on_peer_disconnected(peer_id: int) -> void:
	var player = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()

func _spawn_player(peer_id: int) -> void:
	if not multiplayer.is_server() and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
		
	var player_instance = PLAYER_SCENE.instantiate()
	player_instance.name = str(peer_id)
	
	# Важно: Выставляем владельца на сервере ДО добавления в дерево, 
	# чтобы MultiplayerSpawner передал правильные данные
	player_instance.set_multiplayer_authority(peer_id)
	
	add_child(player_instance)
	
	# Вычисляем позицию спавна
	var spawn_pos = Vector3(0, 2.5, 0)
	var points = get_tree().get_nodes_in_group("spawn_points")
	if points.size() > 0:
		spawn_pos = points.pick_random().global_position
		
	# ЖЕСТКИЙ ФИКС: Даем Godot один кадр (или физический кадр), 
	# чтобы MultiplayerSpawner успел создать этот узел на клиенте.
	# Только ПОСЛЕ этого rpc долетит до клиента!
	await get_tree().process_frame
	
	# Теперь узел на клиенте существует, вызываем инициализацию
	player_instance._reset_player_state.rpc(spawn_pos)
