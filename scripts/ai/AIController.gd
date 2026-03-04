## AIController.gd — Stub AI controller for the AI fleet.
## Runs during the AI_TURN phase: moves ships toward enemies, then fires weapons.
class_name AIController
extends Node

var battle_scene: Node = null


func take_turn() -> void:
	_plan_launches()
	_plan_movement()
	_execute_movement()
	await _plan_fire()
	TurnManager.advance_phase()


func _plan_movement() -> void:
	for node in GameManager.ai_fleet:
		var ai_ship := node as Ship
		if ai_ship == null or not is_instance_valid(ai_ship):
			continue
		var target := _find_nearest_human_ship(ai_ship)
		if target == null:
			continue
		# Move greedily toward the target one step at a time, using all available move points.
		while ai_ship.moves_remaining > 0:
			var neighbors := HexGrid.offset_neighbors(ai_ship.hex_position)
			var best_hex: Vector2i = ai_ship.hex_position
			var best_dist: int = HexGrid.offset_distance(ai_ship.hex_position, target.hex_position)
			for neighbor in neighbors:
				var d: int = HexGrid.offset_distance(neighbor, target.hex_position)
				if d < best_dist:
					best_dist = d
					best_hex = neighbor
			if best_hex == ai_ship.hex_position:
				break  # No closer hex reachable — already optimal
			ai_ship.move_to_hex(best_hex)


func _execute_movement() -> void:
	pass  # Movement is applied in _plan_movement for now


func _plan_fire() -> void:
	for node in GameManager.ai_fleet:
		var ai_ship := node as Ship
		if ai_ship == null or not is_instance_valid(ai_ship):
			continue
		var target := _find_nearest_human_ship(ai_ship)
		if target == null:
			continue
		var dist: int = HexGrid.offset_distance(ai_ship.hex_position, target.hex_position)
		if dist <= 6:
			await ai_ship.fire_at(target)


func _plan_launches() -> void:
	if battle_scene == null:
		return
	for node in GameManager.ai_fleet.duplicate():
		var ship := node as Ship
		if ship == null or not is_instance_valid(ship) or not ship.can_launch():
			continue
		# Find nearest human ship
		var nearest: Ship = null
		var best_dist := 99999
		for hn in GameManager.human_fleet:
			var hs := hn as Ship
			if hs == null or not is_instance_valid(hs):
				continue
			var d := HexGrid.offset_distance(ship.hex_position, hs.hex_position)
			if d < best_dist:
				best_dist = d
				nearest = hs
		if nearest == null:
			continue
		# Pick adjacent hex closest to target; launch one group per carrier per turn
		var best_hex := Vector2i(-1, -1)
		var best_d2 := 99999
		var cube := HexGrid.offset_to_cube(ship.hex_position.x, ship.hex_position.y)
		var bounds := Rect2i(0, 0, GameManager.map_cols, GameManager.map_rows)
		for nc in HexGrid.cube_ring(cube, 1):
			var off := HexGrid.cube_to_offset(nc)
			if bounds.has_point(off):
				var d2 := HexGrid.offset_distance(off, nearest.hex_position)
				if d2 < best_d2:
					best_d2 = d2
					best_hex = off
		if best_hex.x >= 0:
			battle_scene.launch_group(ship, best_hex)


func _find_nearest_human_ship(from_ship: Ship) -> Ship:
	var nearest: Ship = null
	var nearest_dist: int = 9999
	for node in GameManager.human_fleet:
		var human_ship := node as Ship
		if human_ship == null or not is_instance_valid(human_ship):
			continue
		var d: int = HexGrid.offset_distance(from_ship.hex_position, human_ship.hex_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = human_ship
	return nearest
