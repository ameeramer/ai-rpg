class_name StateMachine
extends Node
## Generic Finite State Machine. Add State nodes as children.

## Emitted when the state changes.
signal state_changed(old_state: State, new_state: State)

@export var initial_state: NodePath

var current_state: State
var states: Dictionary = {}


func _ready() -> void:
	# Register all child State nodes
	for child in get_children():
		if child is State:
			states[child.name] = child
			child.state_machine = self
			child.on_exit()  # Ensure all states start disabled

	# Enter initial state
	if initial_state != NodePath():
		var start_node := get_node_or_null(initial_state)
		if start_node is State:
			current_state = start_node
			current_state.on_enter()


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
func transition_to(state_name: String, msg: Dictionary = {}) -> void:
	if not states.has(state_name):
		push_warning("StateMachine: State '%s' not found." % state_name)
		return

	var new_state: State = states[state_name]
	if new_state == current_state:
		return

	var old_state := current_state
	if current_state:
		current_state.on_exit()

	current_state = new_state
	current_state.on_enter(msg)
	state_changed.emit(old_state, new_state)
