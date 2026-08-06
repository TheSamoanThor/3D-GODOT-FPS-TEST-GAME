extends Node

signal exit()

@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry

const PlayerScene = preload("res://Controllers/PlayerScene.tscn")
const PORT = 9999
var enet_peer = ENetMultiplayerPeer.new()


func _on_host_button_pressed():
	main_menu.hide()
	
	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)
	
	add_player(multiplayer.get_unique_id())


func _on_join_button_pressed() -> void:
	main_menu.hide()
	
	var ip = address_entry.text if address_entry.text != "" else "localhost"
	enet_peer.create_client(ip, PORT)
	multiplayer.multiplayer_peer = enet_peer


func add_player(peer_id: int) -> void:
	# Только сервер имеет право спавнить физические узлы в дерево
	if not multiplayer.is_server():
		return
		
	var player_instance = PlayerScene.instantiate()
	player_instance.name = str(peer_id)
	
	player_instance.global_position = get_random_spawn_position()
	# Добавляем на карту (MultiplayerSpawner автоматически 
	# создаст его у клиентов относительно указонного в нем пути +-)
	add_child(player_instance)
	
	player_instance.set_multiplayer_authority(peer_id)
	
	

func get_random_spawn_position() -> Vector3:
	var points = get_tree().get_nodes_in_group("spawn_points")
	
	if points.size() > 0:
		var random_marker = points.pick_random() as Marker3D
		return random_marker.global_position
		
	# Если забыли расставить маркеры, возвращаем нулевые координаты, чтобы не было вылета
	return Vector3(0, 2.5, 0)


# Удаление игрока при выходе
func remove_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var player = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()
