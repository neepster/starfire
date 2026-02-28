## ShipInfoPanel.gd — Displays full stats for the currently selected ship.
extends PanelContainer

@onready var info_text: RichTextLabel = $MarginContainer/InfoText

const ARC_NAMES := ["Forward", "Fwd Wide", "Port", "Stbd", "Aft", "All-Round"]


func _ready() -> void:
	EventBus.ship_selected.connect(_on_ship_selected)
	EventBus.ship_deselected.connect(_on_ship_deselected)
	hide()


func _on_ship_selected(ship: Node) -> void:
	var s := ship as Ship
	if s == null or s.ship_data == null:
		return

	var hull_pct: float = 0.0
	if s.ship_data.system_boxes.size() > 0:
		var total_h := 0
		for box in s.ship_data.system_boxes:
			if box == "H":
				total_h += 1
		hull_pct = float(s.current_hull) / float(maxi(total_h, 1))
	else:
		hull_pct = float(s.current_hull) / float(maxi(s.ship_data.hull_points, 1))

	var hull_color := "green"
	if hull_pct <= 0.25:
		hull_color = "red"
	elif hull_pct <= 0.5:
		hull_color = "yellow"

	var faction_color := "cyan" if s.faction == "human" else "tomato"

	# Use per-instance name if set, else class name
	var display_name: String = s.ship_name if s.ship_name != "" else s.ship_data.ship_name

	var t := ""
	t += "[b]%s[/b]  [color=%s][i]%s[/i][/color]\n" % [
		display_name, faction_color, s.faction.capitalize()
	]
	t += "Class: %s   Drive: %d\n" % [s.ship_data.ship_class, s.ship_data.drive_rating]
	t += "Hull: [color=%s][b]%d[/b][/color]" % [hull_color, s.current_hull]

	# Turn status
	t += "   Move pts: [b]%d[/b]" % s.moves_remaining
	if s.has_fired:
		t += "  [color=gray]Fired[/color]"
	t += "\n"

	# Weapons
	if s.ship_data.weapons.size() > 0:
		t += "\n[b]Weapons:[/b]\n"
		for i in s.ship_data.weapons.size():
			var w := s.ship_data.weapons[i] as WeaponData
			if w == null:
				continue
			var arc_label: String = ARC_NAMES[w.arc] if w.arc < ARC_NAMES.size() else "?"
			var disabled: bool = s._is_weapon_destroyed(i)
			if disabled:
				t += "  [color=gray][s]%s  Dmg %d  Rng %d  %s[/s] [DESTROYED][/color]\n" % [
					w.weapon_name, w.damage, w.range_hexes, arc_label
				]
			else:
				t += "  [b]%s[/b]  Dmg %d  Rng %d  %s\n" % [
					w.weapon_name, w.damage, w.range_hexes, arc_label
				]
	else:
		t += "[color=gray]No weapons[/color]\n"

	# System box strip
	t += _build_box_strip(s)

	info_text.text = t
	show()


func _build_box_strip(s: Ship) -> String:
	if s.ship_data.system_boxes.is_empty():
		return ""
	var t := "\n[b]Systems:[/b]\n"
	for i in s.ship_data.system_boxes.size():
		var box: String = s.ship_data.system_boxes[i]
		var dead: bool = i < s.destroyed_box_count
		if dead:
			t += "[color=gray][✗][/color]"
		else:
			var col: String
			if box == "H":
				col = "lime"
			elif box == "S":
				col = "lightblue"
			elif box == "A":
				col = "yellow"
			elif box == "D":
				col = "cyan"
			else:
				col = "orange"
			t += "[color=%s][%s][/color]" % [col, box]
	t += "\n"
	return t


func _on_ship_deselected() -> void:
	hide()
