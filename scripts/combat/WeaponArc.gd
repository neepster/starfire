## WeaponArc.gd — Firing arc geometry for flat-top hexes.
## Uses world-space angles so arcs align correctly with ship visual facing.
##
## Facing convention (matches Ship._apply_facing):
##   facing=0 → East (0°),  facing=1 → NE (60°),  facing=2 → NW (120°)
##   facing=3 → West (180°), facing=4 → SW (240°), facing=5 → SE (300°)
##   Angles increase counter-clockwise in screen space (standard math).
class_name WeaponArc
extends RefCounted


## Half arc width in degrees for each arc type (total coverage = 2× this value).
static func _half_width(arc_type: WeaponData.ArcType) -> float:
	match arc_type:
		WeaponData.ArcType.FORWARD:         return 60.0   # 120° total (3 hex sectors)
		WeaponData.ArcType.FORWARD_WIDE:    return 120.0  # 240° total (5 hex sectors)
		WeaponData.ArcType.BROADSIDE_LEFT:  return 60.0   # 120° centred on port
		WeaponData.ArcType.BROADSIDE_RIGHT: return 60.0   # 120° centred on starboard
		WeaponData.ArcType.AFT:             return 60.0   # 120° centred on aft
		_:                                  return 180.0  # ALL_ROUND — handled separately


## Offset of arc center from ship's forward direction, in degrees.
##   Positive = counter-clockwise (port / left side).
##
## In a flat-top hex grid the perpendicular port/starboard face is 120° from the
## bow face (not 90°), because each hex face spans exactly 60° and the three
## forward faces (bow ±1) already consume 120° either side of the bow direction.
static func _center_offset(arc_type: WeaponData.ArcType) -> float:
	match arc_type:
		WeaponData.ArcType.BROADSIDE_LEFT:  return  120.0  # port  (3 port hexes)
		WeaponData.ArcType.BROADSIDE_RIGHT: return -120.0  # starboard (3 starboard hexes)
		WeaponData.ArcType.AFT:             return  180.0  # aft
		_:                                  return  0.0    # FORWARD / FORWARD_WIDE / ALL_ROUND


## Return all hexes within a weapon's arc and range, clipped to map_bounds.
static func get_arc_hexes(
		ship_hex: Vector2i,
		facing: int,
		weapon: WeaponData,
		map_bounds: Rect2i) -> Array[Vector2i]:

	var arc_type := weapon.arc
	var ship_cube := HexGrid.offset_to_cube(ship_hex.x, ship_hex.y)
	var in_arc: Array[Vector2i] = []

	# ALL_ROUND: skip angle check entirely
	if arc_type == WeaponData.ArcType.ALL_ROUND:
		for r in range(1, weapon.range_hexes + 1):
			for hex_cube in HexGrid.cube_ring(ship_cube, r):
				var offset := HexGrid.cube_to_offset(hex_cube)
				if map_bounds.has_point(offset):
					in_arc.append(offset)
		return in_arc

	# Compute arc center angle in world space.
	# In flat-top "odd-q" offset coords the East neighbor sits at 330° in math
	# angles (atan2 convention), not 0°, because of the half-row stagger.
	# Each facing step is still 60° CCW, so the formula is facing*60 - 30.
	var forward_deg := float(facing) * 60.0 - 30.0
	var arc_center  := fmod(forward_deg + _center_offset(arc_type) + 720.0, 360.0)
	var half_w      := _half_width(arc_type)

	var ship_world := HexGrid.offset_to_world(ship_hex, 1.0)

	for r in range(1, weapon.range_hexes + 1):
		for hex_cube in HexGrid.cube_ring(ship_cube, r):
			var offset := HexGrid.cube_to_offset(hex_cube)
			if not map_bounds.has_point(offset):
				continue
			if _in_arc_angle(ship_world, HexGrid.offset_to_world(offset, 1.0), arc_center, half_w):
				in_arc.append(offset)

	return in_arc


## Returns true when target_world falls within ±half_width_deg of arc_center_deg
## relative to ship_world, using atan2 in standard math orientation (0°=East, CCW+).
static func _in_arc_angle(
		ship_world: Vector2,
		target_world: Vector2,
		arc_center_deg: float,
		half_width_deg: float) -> bool:

	var diff := target_world - ship_world
	if diff.length_squared() < 0.001:
		return false

	# atan2(-y, x) converts from Godot screen-space (+Y down) to math angles (+Y up).
	var target_deg := rad_to_deg(atan2(-diff.y, diff.x))
	if target_deg < 0.0:
		target_deg += 360.0

	# Shortest angular distance on the circle.
	var delta := fmod(abs(target_deg - arc_center_deg + 540.0), 360.0) - 180.0
	return abs(delta) <= half_width_deg
