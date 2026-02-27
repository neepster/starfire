## HexPathfinder.gd — Finds movement paths on the hex grid using A*.
class_name HexPathfinder
extends RefCounted

var _passable_hexes: Dictionary = {}   # Vector2i -> true
var _hex_size: float = 48.0


func setup(passable: Dictionary, hex_size: float) -> void:
	_passable_hexes = passable
	_hex_size = hex_size


## Find the shortest path from 'start' to 'goal' offset coords.
## Returns an array of Vector2i hex coords (including start and goal),
## or an empty array if no path exists.
func find_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	if not _passable_hexes.get(goal, false):
		return []

	# A* on cube coordinates
	var start_cube := HexGrid.offset_to_cube(start.x, start.y)
	var goal_cube  := HexGrid.offset_to_cube(goal.x, goal.y)

	var open_set: Array[Vector3i] = [start_cube]
	var came_from: Dictionary = {}
	var g_score: Dictionary = { start_cube: 0 }
	var f_score: Dictionary = { start_cube: HexGrid.cube_distance(start_cube, goal_cube) }

	while not open_set.is_empty():
		# Find node in open_set with lowest f_score
		var current := open_set[0]
		for cube in open_set:
			if (f_score.get(cube, 9999) as int) < (f_score.get(current, 9999) as int):
				current = cube

		if current == goal_cube:
			return _reconstruct_path(came_from, current)

		open_set.erase(current)

		for neighbor_cube in HexGrid.cube_neighbors(current):
			var neighbor_offset := HexGrid.cube_to_offset(neighbor_cube)
			if not _passable_hexes.get(neighbor_offset, false):
				continue

			var tentative_g: int = (g_score.get(current, 9999) as int) + 1
			if tentative_g < (g_score.get(neighbor_cube, 9999) as int):
				came_from[neighbor_cube] = current
				g_score[neighbor_cube] = tentative_g
				f_score[neighbor_cube] = tentative_g + HexGrid.cube_distance(neighbor_cube, goal_cube)
				if neighbor_cube not in open_set:
					open_set.append(neighbor_cube)

	return []  # No path found


func _reconstruct_path(came_from: Dictionary, current: Vector3i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var cur := current
	while came_from.has(cur):
		path.push_front(HexGrid.cube_to_offset(cur))
		cur = came_from[cur]
	path.push_front(HexGrid.cube_to_offset(cur))
	return path


## Return all hexes reachable within 'max_moves' steps from 'start'.
func reachable_hexes(start: Vector2i, max_moves: int) -> Array[Vector2i]:
	var visited: Dictionary = {}
	var frontier: Array[Vector2i] = [start]
	visited[start] = 0

	while not frontier.is_empty():
		var next_frontier: Array[Vector2i] = []
		for hex in frontier:
			var cost: int = visited[hex]
			if cost >= max_moves:
				continue
			for neighbor in HexGrid.offset_neighbors(hex):
				if not _passable_hexes.get(neighbor, false):
					continue
				if not visited.has(neighbor):
					visited[neighbor] = cost + 1
					next_frontier.append(neighbor)
		frontier = next_frontier

	var result: Array[Vector2i] = []
	for hex in visited:
		if hex != start:
			result.append(hex)
	return result
