class_name State
extends Node
## Base class for all states in a StateMachine.
## Override the virtual methods to implement state behavior.

var state_machine: StateMachine


## Called when entering this state. msg is optional data from the transition.
func on_enter(_msg: Dictionary = {}) -> void:
	pass


## Called when exiting this state.
func on_exit() -> void:
	pass


## Called every frame while this state is active.
func on_update(_delta: float) -> void:
	pass


## Called every physics frame while this state is active.
func on_physics_update(_delta: float) -> void:
	pass


## Called for unhandled input while this state is active.
func on_input(_event: InputEvent) -> void:
	pass
