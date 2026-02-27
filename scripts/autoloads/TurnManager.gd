## TurnManager.gd — Manages turn structure and phase sequencing.
## Starfire turns proceed: Movement Plot → Movement Execute → Weapons Fire → Damage Resolve
extends Node

enum Phase {
	MOVEMENT_PLOT,      # Human plots ship movement orders
	MOVEMENT_EXECUTE,   # Ships move simultaneously
	WEAPONS_FIRE,       # Human declares weapon attacks
	DAMAGE_RESOLVE,     # Damage is applied and ships are checked
	AI_TURN,            # AI takes its actions
	END_TURN            # Cleanup, check victory, advance turn counter
}

var current_turn: int = 1
var current_phase: Phase = Phase.MOVEMENT_PLOT
var _phase_names: Dictionary = {
	Phase.MOVEMENT_PLOT:    "Movement Plot",
	Phase.MOVEMENT_EXECUTE: "Movement Execute",
	Phase.WEAPONS_FIRE:     "Weapons Fire",
	Phase.DAMAGE_RESOLVE:   "Damage Resolve",
	Phase.AI_TURN:          "AI Turn",
	Phase.END_TURN:         "End Turn",
}


func get_phase_name() -> String:
	return _phase_names.get(current_phase, "Unknown")


func advance_phase() -> void:
	match current_phase:
		Phase.MOVEMENT_PLOT:
			current_phase = Phase.MOVEMENT_EXECUTE
		Phase.MOVEMENT_EXECUTE:
			current_phase = Phase.WEAPONS_FIRE
		Phase.WEAPONS_FIRE:
			current_phase = Phase.DAMAGE_RESOLVE
		Phase.DAMAGE_RESOLVE:
			current_phase = Phase.AI_TURN
		Phase.AI_TURN:
			current_phase = Phase.END_TURN
		Phase.END_TURN:
			_start_new_turn()
			return

	EventBus.turn_phase_changed.emit(current_phase)


func end_turn() -> void:
	## Called when the player presses "End Turn".
	## Advances through remaining phases automatically before starting the next turn.
	advance_phase()


func _start_new_turn() -> void:
	current_turn += 1
	current_phase = Phase.MOVEMENT_PLOT
	EventBus.turn_phase_changed.emit(current_phase)


func reset() -> void:
	current_turn = 1
	current_phase = Phase.MOVEMENT_PLOT
