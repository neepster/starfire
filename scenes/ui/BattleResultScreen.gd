## BattleResultScreen.gd — Post-battle scoreboard overlay.
## Instantiated and shown by BattleScene when a victor is determined.
class_name BattleResultScreen
extends Control

var _winner: String = ""
var _records: Array[Dictionary] = []


func setup(winner: String, records: Array[Dictionary]) -> void:
	_winner = winner
	_records = records


func _ready() -> void:
	# Fill viewport
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Semi-transparent dark backdrop
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.02, 0.08, 0.88)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Centre panel
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(660, 0)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# ── Title ──────────────────────────────────────────────────────────────
	var title := Label.new()
	title.text = "BATTLE RESULT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	vbox.add_child(title)

	# ── Winner line ────────────────────────────────────────────────────────
	var winner_label := Label.new()
	match _winner:
		"human": winner_label.text = "VICTORY  —  Human Fleet Wins!"
		"ai":    winner_label.text = "DEFEAT  —  AI Fleet Wins!"
		"draw":  winner_label.text = "DRAW  —  Both Fleets Destroyed!"
		_:       winner_label.text = "Battle Over"
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(winner_label)

	vbox.add_child(HSeparator.new())

	# ── Stats table ────────────────────────────────────────────────────────
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.custom_minimum_size = Vector2(640, 0)

	var text := "[font_size=13]"
	text += "[b]%-22s %-16s %-9s %-14s %s[/b]\n" % [
		"Ship Name", "Class", "Faction", "Damage", "Status"
	]
	text += "─".repeat(72) + "\n"

	# Human ships first, then AI
	var sorted: Array[Dictionary] = []
	for rec in _records:
		if rec.get("faction", "") == "human":
			sorted.append(rec)
	for rec in _records:
		if rec.get("faction", "") == "ai":
			sorted.append(rec)

	for rec in sorted:
		var total: int    = rec.get("total_boxes", 0)
		var dead: int     = rec.get("destroyed_boxes", 0)
		var survived: bool = rec.get("survived", false)
		var dmg_str := "%d / %d" % [dead, total] if total > 0 else "n/a"
		var status_color := "green" if survived else "red"
		var status_str   := "Survived" if survived else "Destroyed"
		var name_str: String  = rec.get("ship_name", "?")
		var class_str: String = rec.get("ship_class", "?")
		var faction_str: String = rec.get("faction", "?").capitalize()

		text += "%-22s %-16s %-9s %-14s [color=%s]%s[/color]\n" % [
			name_str, class_str, faction_str, dmg_str, status_color, status_str
		]

	text += "[/font_size]"
	rtl.text = text
	vbox.add_child(rtl)

	vbox.add_child(HSeparator.new())

	# ── Return button ──────────────────────────────────────────────────────
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var btn := Button.new()
	btn.text = "Return to Main Menu"
	btn.custom_minimum_size = Vector2(220, 44)
	btn.pressed.connect(_on_return_pressed)
	btn_row.add_child(btn)


func _on_return_pressed() -> void:
	SceneLoader.load_scene("res://scenes/menus/MainMenu.tscn")
