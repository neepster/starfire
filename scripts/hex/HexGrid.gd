## HexGrid.gd — Pure hex math utilities using cube coordinates.
## All functions are static; no node instance needed.
##
## Coordinate system: flat-top hexes with "odd-q" offset layout.
## Cube coords use (x, y, z) where x + y + z = 0.
class_name HexGrid
extends Node

# Flat-top hex: 6 cube-coordinate directions
const CUBE_DIRECTIONS: Array[Vector3i] = [
	Vector3i(1, -1, 0),   # 0: East
	Vector3i(1, 0, -1),   # 1: North-East
	Vector3i(0, 1, -1),   # 2: North-West
	Vector3i(-1, 1, 0),   # 3: West
	Vector3i(-1, 0, 1),   # 4: South-West
	Vector3i(0, -1, 1),   # 5: South-East
]


## Convert offset (col, row) to cube coordinates (odd-q layout).
static func offset_to_cube(col: int, row: int) -> Vector3i:
	var x := col
	var z := row - (col - (col & 1)) / 2
	var y := -x - z
	return Vector3i(x, y, z)


## Convert cube coordinates to offset (col, row) in odd-q layout.
static func cube_to_offset(cube: Vector3i) -> Vector2i:
	var col := cube.x
	var row := cube.z + (cube.x - (cube.x & 1)) / 2
	return Vector2i(col, row)


## Hex distance between two cube-coordinate hexes.
static func cube_distance(a: Vector3i, b: Vector3i) -> int:
	return (abs(a.x - b.x) + abs(a.y - b.y) + abs(a.z - b.z)) / 2


## Hex distance using offset coordinates.
static func offset_distance(a: Vector2i, b: Vector2i) -> int:
	return cube_distance(offset_to_cube(a.x, a.y), offset_to_cube(b.x, b.y))


## Return the 6 cube-coordinate neighbors of a hex.
static func cube_neighbors(cube: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for dir in CUBE_DIRECTIONS:
		result.append(cube + dir)
	return result


## Return the 6 offset-coordinate neighbors of a hex.
static func offset_neighbors(hex: Vector2i) -> Array[Vector2i]:
	var cube := offset_to_cube(hex.x, hex.y)
	var result: Array[Vector2i] = []
	for neighbor_cube in cube_neighbors(cube):
		result.append(cube_to_offset(neighbor_cube))
	return result


## Return all hexes on the ring at 'radius' distance from 'center'.
static func cube_ring(center: Vector3i, radius: int) -> Array[Vector3i]:
	var results: Array[Vector3i] = []
	if radius == 0:
		results.append(center)
		return results
	var current := center + CUBE_DIRECTIONS[4] * radius
	for i in 6:
		for _j in radius:
			results.append(current)
			current = current + CUBE_DIRECTIONS[i]
	return results


## Return all hexes within 'radius' distance from 'center' (filled disk).
static func cube_disk(center: Vector3i, radius: int) -> Array[Vector3i]:
	var results: Array[Vector3i] = []
	for r in range(radius + 1):
		results.append_array(cube_ring(center, r))
	return results


## Convert a flat-top hex offset coord to world position (pixel center).
## hex_size is the circumradius (center-to-vertex distance).
static func offset_to_world(hex: Vector2i, hex_size: float) -> Vector2:
	var col := hex.x
	var row := hex.y
	var x := hex_size * 1.5 * col
	var y := hex_size * sqrt(3.0) * (row + 0.5 * (col & 1))
	return Vector2(x, y)


## Convert a world position to the nearest flat-top hex offset coord.
static func world_to_offset(world_pos: Vector2, hex_size: float) -> Vector2i:
	# Inverse of offset_to_world for flat-top hexes
	var col_approx := world_pos.x / (hex_size * 1.5)
	var col := roundi(col_approx)
	var row_approx := world_pos.y / (hex_size * sqrt(3.0)) - 0.5 * (col & 1)
	var row := roundi(row_approx)
	# Snap to nearest hex using cube distance
	var best := Vector2i(col, row)
	var best_dist := 9999.0
	for dc in [-1, 0, 1]:
		for dr in [-1, 0, 1]:
			var candidate := Vector2i(col + dc, row + dr)
			var cw := offset_to_world(candidate, hex_size)
			var d := world_pos.distance_to(cw)
			if d < best_dist:
				best_dist = d
				best = candidate
	return best


## Facing direction index (0–5) for flat-top hexes.
## Returns the cube direction index most aligned with 'facing_degrees'.
static func degrees_to_facing(degrees: float) -> int:
	# Flat-top: facing 0 = East (0°), increments of 60° clockwise
	var normalized := fmod(degrees + 360.0, 360.0)
	return roundi(normalized / 60.0) % 6


## Return the cube direction vector for a facing index (0–5).
static func facing_to_cube_dir(facing: int) -> Vector3i:
	return CUBE_DIRECTIONS[facing % 6]
