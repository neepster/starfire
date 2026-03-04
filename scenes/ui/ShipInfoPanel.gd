## ShipInfoPanel.gd — Displays full stats for the currently selected ship.
extends PanelContainer

@onready var info_text: RichTextLabel = $VBox/MarginContainer/InfoText
@onready var _vbox: VBoxContainer = $VBox

const ARC_NAMES := ["Forward", "Fwd Wide", "Port", "Stbd", "Aft", "All-Round"]

var _current_ship: Ship = null
var _launch_btn: Button
var _recover_btn: Button


func _ready() -> void:
	EventBus.ship_selected.connect(_on_ship_selected)
	EventBus.ship_deselected.connect(_on_ship_deselected)
	EventBus.turn_phase_changed.connect(func(_p: int) -> void: _update_carrier_buttons())

	_launch_btn = Button.new()
	_launch_btn.text = "Launch Fighter Group"
	_launch_btn.hide()
	_launch_btn.pressed.connect(func() -> void: EventBus.launch_fighters_requested.emit(_current_ship))
	_vbox.add_child(_launch_btn)

	_recover_btn = Button.new()
	_recover_btn.text = "Recover to Carrier"
	_recover_btn.hide()
	_recover_btn.pressed.connect(func() -> void: EventBus.recover_fighters_requested.emit(_current_ship))
	_vbox.add_child(_recover_btn)

	hide()


func _on_ship_selected(ship: Node) -> void:
	_current_ship = ship as Ship
	var s := _current_ship
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

	if s.is_strike_group:
		t += "Fighters: [color=%s][b]%d[/b][/color]/6" % [hull_color, s.current_hull]
	else:
		t += "Hull: [color=%s][b]%d[/b][/color]" % [hull_color, s.current_hull]

	# Turn status
	t += "   Move pts: [b]%d[/b]" % s.moves_remaining
	if s.has_fired:
		t += "  [color=gray]Fired[/color]"
	t += "\n"

	# Carrier fighter group count
	if s.ship_data.fighter_capacity > 0:
		t += "Fighter groups: [b]%d[/b]/%d  (launched: %d)\n" % [
			s.available_groups, s.ship_data.fighter_capacity, s.launched_groups.size()
		]

	# Weapons
	if s.ship_data.weapons.size() > 0:
		t += "\n[b]Weapons:[/b]\n"
		for i in s.ship_data.weapons.size():
			if s.is_strike_group and i >= s.current_hull:
				break   # skip dead fighter slots
			var w := s.ship_data.weapons[i] as WeaponData
			if w == null:
				continue
			var arc_label: String = ARC_NAMES[w.arc] if w.arc < ARC_NAMES.size() else "?"
			var disabled: bool = s._is_weapon_destroyed(i)
			if disabled:
				t += "  [color=gray][s]%s  Dmg %d  Rng %d  %s[/s] [DESTROYED][/color]\n" % [
					w.weapon_name,
					WeaponData.max_damage_for_name(w.weapon_name),
					WeaponData.max_range_for_name(w.weapon_name),
					arc_label
				]
			else:
				t += "  [b]%s[/b]  Dmg %d  Rng %d  %s\n" % [
					w.weapon_name,
					WeaponData.max_damage_for_name(w.weapon_name),
					WeaponData.max_range_for_name(w.weapon_name),
					arc_label
				]
	else:
		t += "[color=gray]No weapons[/color]\n"

	# System box strip
	t += _build_box_strip(s)

	info_text.text = t
	_update_carrier_buttons()
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
	_current_ship = null
	_launch_btn.hide()
	_recover_btn.hide()
	hide()


func _update_carrier_buttons() -> void:
	_launch_btn.hide()
	_recover_btn.hide()
	if _current_ship == null or _current_ship._is_destroyed:
		return
	var in_move: bool = TurnManager.current_phase == TurnManager.Phase.MOVEMENT_PLOT
	if in_move and _current_ship.can_launch():
		_launch_btn.show()
	if (in_move and _current_ship.is_strike_group
			and _current_ship.parent_carrier != null
			and is_instance_valid(_current_ship.parent_carrier)
			and HexGrid.offset_distance(
				_current_ship.hex_position,
				(_current_ship.parent_carrier as Ship).hex_position) == 1):
		_recover_btn.show()
