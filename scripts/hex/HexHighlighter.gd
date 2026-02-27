## HexHighlighter.gd — Manages visual overlays on the hex map.
## Communicates with HexMap to show movement range and weapon arcs.
class_name HexHighlighter
extends RefCounted

var _hex_map: HexMap = null


func setup(hex_map: HexMap) -> void:
	_hex_map = hex_map


## Show movement range overlay for a ship.
func show_movement_range(hexes: Array[Vector2i]) -> void:
	if _hex_map:
		_hex_map.set_movement_highlight(hexes)


## Show weapon arc overlay.
func show_attack_range(hexes: Array[Vector2i]) -> void:
	if _hex_map:
		_hex_map.set_attack_highlight(hexes)


## Clear all overlays.
func clear_all() -> void:
	if _hex_map:
		_hex_map.set_movement_highlight([])
		_hex_map.set_attack_highlight([])
