## GameManager.gd — Global game state: scenario data, fleet lists, victory checks.
extends Node

var human_fleet: Array[Node] = []
var ai_fleet: Array[Node] = []
var current_scenario: Resource = null
var battle_active: bool = false

## Set by FleetBuilder before loading BattleScene. Each entry: {res_path, faction}.
## BattleScene reads this, uses it if non-empty, then clears it.
var fleet_config: Array[Dictionary] = []

## Accumulates per-ship records as ships are destroyed during the battle.
var _battle_records: Array[Dictionary] = []


func start_battle(scenario: Resource) -> void:
	current_scenario = scenario
	human_fleet.clear()
	ai_fleet.clear()
	_battle_records.clear()
	battle_active = true
	TurnManager.reset()


func register_ship(ship: Node, faction: String) -> void:
	if faction == "human":
		human_fleet.append(ship)
	elif faction == "ai":
		ai_fleet.append(ship)


func unregister_ship(ship: Node) -> void:
	human_fleet.erase(ship)
	ai_fleet.erase(ship)


## Record a ship's stats just before it is freed (called from Ship._on_destroyed).
func record_ship_destroyed(ship: Node) -> void:
	var s := ship as Ship
	if s == null:
		return
	var total := s.ship_data.system_boxes.size() if s.ship_data != null else 0
	_battle_records.append({
		"ship_name":       s.ship_name,
		"faction":         s.faction,
		"ship_class":      s.ship_data.ship_class if s.ship_data != null else "?",
		"total_boxes":     total,
		"destroyed_boxes": s.destroyed_box_count,
		"survived":        false,
	})


## Returns the full battle record: destroyed ships + currently alive ships.
func get_battle_results() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	# Already-destroyed ships (recorded before queue_free)
	for rec in _battle_records:
		results.append(rec)
	# Still-alive ships
	for fleet in [human_fleet, ai_fleet]:
		for ship in fleet:
			var s := ship as Ship
			if s != null and is_instance_valid(s):
				var total := s.ship_data.system_boxes.size() if s.ship_data != null else 0
				results.append({
					"ship_name":       s.ship_name,
					"faction":         s.faction,
					"ship_class":      s.ship_data.ship_class if s.ship_data != null else "?",
					"total_boxes":     total,
					"destroyed_boxes": s.destroyed_box_count,
					"survived":        true,
				})
	return results


func check_victory() -> String:
	## Returns "human", "ai", "draw", or "" if the battle is still ongoing.
	if not battle_active:
		return ""
	var human_alive = human_fleet.any(func(s): return is_instance_valid(s))
	var ai_alive = ai_fleet.any(func(s): return is_instance_valid(s))
	if not human_alive and not ai_alive:
		return "draw"
	if not human_alive:
		return "ai"
	if not ai_alive:
		return "human"
	return ""


func end_battle(winner: String) -> void:
	battle_active = false
	EventBus.battle_ended.emit(winner)
