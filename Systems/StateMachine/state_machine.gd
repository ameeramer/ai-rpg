class_name StateMachine
extends Node
## Generic Finite State Machine. Add State nodes as children.

## Emitted when the state changes.
signal state_changed(old_state, new_state)

@export var initial_state: NodePath

var current_state: Node
var states: Dictionary = {}


func _ready() -> void:
	FileLogger.log_msg("StateMachine._ready() states: %s, initial_state: %s" % [str(get_children().size()), str(initial_state)])

	# Register all child nodes as states.
	# All children of StateMachine are expected to be State scripts.
	# Avoid `is State` and `has_method()` — both fail on Android Godot 4.3.
	for child in get_children():
		states[child.name] = child
		child.set("state_machine", self)
		child.call("on_exit")  # Ensure all states start disabled

	# Enter initial state
	if initial_state != NodePath():
		var start_node := get_node_or_null(initial_state)
		if start_node and states.has(start_node.name):
			current_state = start_node
			current_state.on_enter()
			FileLogger.log_msg("StateMachine entered initial state: %s" % current_state.name)
		else:
			FileLogger.log_error("StateMachine: initial_state node '%s' is not a State" % str(initial_state))
	else:
		FileLogger.log_warning("StateMachine: no initial_state set")


func _process(delta: float) -> void:
	if current_state:
		current_state.on_update(delta)


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.on_physics_update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.on_input(event)


## Transition to a new state by name.
## If already in that state, exit and re-enter (allows interrupting actions).
func transition_to(state_name: String, msg: Dictionary = {}) -> void:
	if not states.has(state_name):
		push_warning("StateMachine: State '%s' not found." % state_name)
		return

	var new_state: Node = states[state_name]

	var old_state := current_state
	if current_state:
		current_state.on_exit()

	current_state = new_state
	current_state.on_enter(msg)
	state_changed.emit(old_state, new_state)
