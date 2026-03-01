## HexMap.gd — Renders the hex grid and handles hex interaction.
## Uses _draw() for the terrain, overlays for movement/attack ranges.
class_name HexMap
extends Node2D

const HEX_SIZE := 48.0           # Circumradius: center to vertex
var map_cols: int = 20
var map_rows: int = 15

# Hex colors
const COLOR_TERRAIN     := Color(0.05, 0.05, 0.15, 1.0)   # deep space
const COLOR_GRID_LINE   := Color(0.20, 0.25, 0.50, 0.8)   # hex grid lines
const COLOR_MOVE_FILL   := Color(0.10, 0.40, 0.80, 0.35)  # blue movement overlay
const COLOR_MOVE_LINE   := Color(0.30, 0.70, 1.00, 0.80)
const COLOR_ATTACK_FILL := Color(0.80, 0.10, 0.10, 0.30)  # red attack overlay
const COLOR_ATTACK_LINE := Color(1.00, 0.30, 0.30, 0.80)
const COLOR_SELECTED    := Color(1.00, 0.90, 0.20, 0.90)  # yellow selected hex

# State
var _passable: Dictionary = {}           # Vector2i -> bool
var _movement_hexes: Array[Vector2i] = []
var _attack_hexes: Array[Vector2i] = []
var _selected_hex: Vector2i = Vector2i(-1, -1)

# Precomputed vertex offsets for flat-top hexes (6 vertices at 0°,60°,...,300°)
var _hex_verts: PackedVector2Array


func _ready() -> void:
	map_cols = GameManager.map_cols
	map_rows = GameManager.map_rows
	_precompute_verts()
	_generate_map()
	EventBus.hex_clicked.connect(_on_hex_clicked)


func _precompute_verts() -> void:
	_hex_verts = PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * i)   # 0°=East → flat-top in Y-down
		_hex_verts.append(Vector2(cos(angle), sin(angle)) * HEX_SIZE)


func _generate_map() -> void:
	_passable.clear()
	for col in map_cols:
		for row in map_rows:
			_passable[Vector2i(col, row)] = true


func _draw() -> void:
	# 1. Draw terrain hexes
	for col in map_cols:
		for row in map_rows:
			var center := HexGrid.offset_to_world(Vector2i(col, row), HEX_SIZE)
			_draw_hex(center, COLOR_TERRAIN, COLOR_GRID_LINE)

	# 2. Movement range overlay
	for hex in _movement_hexes:
		var center := HexGrid.offset_to_world(hex, HEX_SIZE)
		_draw_hex(center, COLOR_MOVE_FILL, COLOR_MOVE_LINE)

	# 3. Attack range overlay
	for hex in _attack_hexes:
		var center := HexGrid.offset_to_world(hex, HEX_SIZE)
		_draw_hex(center, COLOR_ATTACK_FILL, COLOR_ATTACK_LINE)

	# 4. Selected hex highlight
	if _selected_hex != Vector2i(-1, -1):
		var center := HexGrid.offset_to_world(_selected_hex, HEX_SIZE)
		_draw_hex(center, Color(COLOR_SELECTED, 0.2), COLOR_SELECTED, 2.0)


func _draw_hex(center: Vector2, fill: Color, outline: Color, line_width: float = 1.0) -> void:
	var pts := PackedVector2Array()
	for v in _hex_verts:
		pts.append(center + v)
	draw_colored_polygon(pts, fill)
	for i in 6:
		draw_line(center + _hex_verts[i], center + _hex_verts[(i + 1) % 6], outline, line_width)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var local_pos := get_local_mouse_position()
			var hex := HexGrid.world_to_offset(local_pos, HEX_SIZE)
			if _passable.has(hex):
				_selected_hex = hex
				EventBus.hex_clicked.emit(hex)
				queue_redraw()


func _on_hex_clicked(_hex: Vector2i) -> void:
	pass  # BattleScene handles game logic; this is just for visual feedback


## Called by HexHighlighter to update movement overlay.
func set_movement_highlight(hexes: Array[Vector2i]) -> void:
	_movement_hexes = hexes
	queue_redraw()


## Called by HexHighlighter to update attack overlay.
func set_attack_highlight(hexes: Array[Vector2i]) -> void:
	_attack_hexes = hexes
	queue_redraw()


func is_hex_passable(hex: Vector2i) -> bool:
	return _passable.get(hex, false)


func get_passable_dict() -> Dictionary:
	return _passable


func get_map_bounds() -> Rect2i:
	return Rect2i(0, 0, map_cols, map_rows)
