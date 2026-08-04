class_name StateMachine

extends Node

@export var CURR_STATE : State
var states: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for child in get_children():
		if child is State:
			states[child.name] = child
			child.transition.connect(on_child_transition)
		else:
			push_warning("State machine contains incompatible child node")
	
	await owner.ready
	CURR_STATE.enter(null)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not is_multiplayer_authority():
		return # Выходим, если это чужой игрок на нашем экране
	
	CURR_STATE.update(delta)
	global.debug.add_property("Curr State", CURR_STATE.name, 1)

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	CURR_STATE.physics_update(delta)

func on_child_transition(new_state_name: StringName) -> void:
	var new_state = states.get(new_state_name)
	if new_state != null:
		if new_state != CURR_STATE:
			CURR_STATE.exit()
			
			# ЗАЩИТА: Если мы приземляемся и переходим в Idle, 
			# мгновенно гасим горизонтальную скорость, чтобы исключить скольжение по инерции
			if new_state_name == &"IdlePlayerState" and owner is CharacterBody3D:
				owner.velocity.x = 0.0
				owner.velocity.z = 0.0
			
			new_state.enter(CURR_STATE)
			CURR_STATE = new_state
	else:
		push_warning("State does not exist")
