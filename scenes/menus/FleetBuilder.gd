## FleetBuilder.gd — Compose human and AI fleets from the ship database before battle.
extends CanvasLayer

const DATA_DIR := "res://data/ships/"
const DEFAULT_HUMAN_PATH := "res://data/ships/escort_dd.tres"
const DEFAULT_AI_PATH    := "res://data/ships/cruiser_ca.tres"

# Parallel arrays for the available-ships list
var _db_paths: Array[String] = []

# Fleet lists — each entry is a res_path string
var _human_fleet: Array[String] = []
var _ai_fleet: Array[String] = []

# UI refs
var _db_list: ItemList
var _preview_rtl: RichTextLabel
var _add_human_btn: Button
var _add_ai_btn: Button
var _human_list: ItemList
var _ai_list: ItemList
var _remove_human_btn: Button
var _remove_ai_btn: Button
var _start_btn: Button
var _status_lbl: Label


func _ready() -> void:
	_build_ui()
	_load_db_list()
	_prepopulate_defaults()


# ── UI Construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.08, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# ── Title bar ────────────────────────────────────────────────────────────
	var title_bar := HBoxContainer.new()
	title_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_bar.custom_minimum_size = Vector2(0, 52)
	title_bar.add_theme_constant_override("separation", 8)
	root.add_child(title_bar)

	var back_btn := Button.new()
	back_btn.text = "← Back"
	back_btn.custom_minimum_size = Vector2(110, 44)
	back_btn.pressed.connect(_on_back_pressed)
	title_bar.add_child(back_btn)

	var title_lbl := Label.new()
	title_lbl.text = "FLEET BUILDER"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_bar.add_child(title_lbl)

	_start_btn = Button.new()
	_start_btn.text = "Start Battle  →"
	_start_btn.custom_minimum_size = Vector2(160, 44)
	_start_btn.disabled = true
	_start_btn.pressed.connect(_on_start_pressed)
	title_bar.add_child(_start_btn)

	# ── Three-column body ────────────────────────────────────────────────────
	var body := HBoxContainer.new()
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.offset_top = 56
	body.add_theme_constant_override("separation", 8)
	root.add_child(body)

	# ── Left: available ships ────────────────────────────────────────────────
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	left.add_theme_constant_override("separation", 6)
	body.add_child(left)

	var db_hdr := Label.new()
	db_hdr.text = "Ship Database"
	db_hdr.add_theme_font_size_override("font_size", 16)
	left.add_child(db_hdr)

	_db_list = ItemList.new()
	_db_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_db_list.item_selected.connect(_on_db_selected)
	left.add_child(_db_list)

	_preview_rtl = RichTextLabel.new()
	_preview_rtl.bbcode_enabled = true
	_preview_rtl.fit_content = true
	_preview_rtl.scroll_active = false
	_preview_rtl.custom_minimum_size = Vector2(0, 120)
	left.add_child(_preview_rtl)

	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 6)
	left.add_child(add_row)

	_add_human_btn = Button.new()
	_add_human_btn.text = "+ Human"
	_add_human_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_human_btn.disabled = true
	_add_human_btn.pressed.connect(_on_add_human_pressed)
	add_row.add_child(_add_human_btn)

	_add_ai_btn = Button.new()
	_add_ai_btn.text = "+ AI"
	_add_ai_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_ai_btn.disabled = true
	_add_ai_btn.pressed.connect(_on_add_ai_pressed)
	add_row.add_child(_add_ai_btn)

	# ── Divider ──────────────────────────────────────────────────────────────
	var div := VSeparator.new()
	body.add_child(div)

	# ── Center: human fleet ──────────────────────────────────────────────────
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 6)
	body.add_child(center)

	var human_hdr := Label.new()
	human_hdr.text = "Human Fleet"
	human_hdr.add_theme_font_size_override("font_size", 16)
	human_hdr.modulate = Color(0.5, 0.85, 1.0)
	center.add_child(human_hdr)

	_human_list = ItemList.new()
	_human_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_human_list.item_selected.connect(func(_i: int) -> void: _update_remove_buttons())
	center.add_child(_human_list)

	_remove_human_btn = Button.new()
	_remove_human_btn.text = "Remove Selected"
	_remove_human_btn.disabled = true
	_remove_human_btn.pressed.connect(_on_remove_human_pressed)
	center.add_child(_remove_human_btn)

	# ── Divider ──────────────────────────────────────────────────────────────
	var div2 := VSeparator.new()
	body.add_child(div2)

	# ── Right: AI fleet ──────────────────────────────────────────────────────
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	body.add_child(right)

	var ai_hdr := Label.new()
	ai_hdr.text = "AI Fleet"
	ai_hdr.add_theme_font_size_override("font_size", 16)
	ai_hdr.modulate = Color(1.0, 0.5, 0.4)
	right.add_child(ai_hdr)

	_ai_list = ItemList.new()
	_ai_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ai_list.item_selected.connect(func(_i: int) -> void: _update_remove_buttons())
	right.add_child(_ai_list)

	_remove_ai_btn = Button.new()
	_remove_ai_btn.text = "Remove Selected"
	_remove_ai_btn.disabled = true
	_remove_ai_btn.pressed.connect(_on_remove_ai_pressed)
	right.add_child(_remove_ai_btn)

	# ── Status bar ───────────────────────────────────────────────────────────
	_status_lbl = Label.new()
	_status_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_status_lbl)


# ── Data ─────────────────────────────────────────────────────────────────────

func _load_db_list() -> void:
	_db_paths.clear()
	_db_list.clear()

	var dir := DirAccess.open(DATA_DIR)
	if not dir:
		return

	var names: Array[String] = []
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".tres"):
			names.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	names.sort()

	for name in names:
		var path := DATA_DIR + name
		var data := load(path) as ShipData
		if data:
			_db_paths.append(path)
			_db_list.add_item("%s  [%s]" % [data.ship_name, data.ship_class])


func _prepopulate_defaults() -> void:
	# Start with a sensible default fleet so users can jump straight to battle
	_try_add_to_fleet(DEFAULT_HUMAN_PATH, "human")
	_try_add_to_fleet(DEFAULT_HUMAN_PATH, "human")
	_try_add_to_fleet(DEFAULT_AI_PATH, "ai")
	_try_add_to_fleet(DEFAULT_AI_PATH, "ai")
	_update_start_button()


func _try_add_to_fleet(path: String, faction: String) -> void:
	var data := load(path) as ShipData
	if data == null:
		return
	var label := data.ship_name
	if faction == "human":
		_human_fleet.append(path)
		_human_list.add_item(label)
	else:
		_ai_fleet.append(path)
		_ai_list.add_item(label)


# ── Signal handlers ──────────────────────────────────────────────────────────

func _on_db_selected(index: int) -> void:
	var data := load(_db_paths[index]) as ShipData
	if data == null:
		return

	var t := "[b]%s[/b]  (class: %s)\n" % [data.ship_name, data.ship_class]
	t += "Drive: %d   Hull: %d   Weapons: %d\n" % [
		data.drive_rating, data.hull_points, data.weapons.size()
	]
	t += "Boxes: "
	for box in data.system_boxes:
		var col: String = {"H": "lime", "S": "lightblue", "A": "yellow", "D": "cyan"}.get(box, "orange")
		t += "[color=%s][%s][/color]" % [col, box]
	t += "\n"
	if data.description != "":
		t += "[i]%s[/i]\n" % data.description
	_preview_rtl.text = t

	_add_human_btn.disabled = false
	_add_ai_btn.disabled = false


func _on_add_human_pressed() -> void:
	var sel := _db_list.get_selected_items()
	if sel.is_empty():
		return
	var path := _db_paths[sel[0]]
	var data := load(path) as ShipData
	_human_fleet.append(path)
	_human_list.add_item(data.ship_name if data else path.get_file())
	_update_start_button()


func _on_add_ai_pressed() -> void:
	var sel := _db_list.get_selected_items()
	if sel.is_empty():
		return
	var path := _db_paths[sel[0]]
	var data := load(path) as ShipData
	_ai_fleet.append(path)
	_ai_list.add_item(data.ship_name if data else path.get_file())
	_update_start_button()


func _on_remove_human_pressed() -> void:
	var sel := _human_list.get_selected_items()
	if sel.is_empty():
		return
	var idx := sel[0]
	_human_fleet.remove_at(idx)
	_human_list.remove_item(idx)
	_update_start_button()
	_update_remove_buttons()


func _on_remove_ai_pressed() -> void:
	var sel := _ai_list.get_selected_items()
	if sel.is_empty():
		return
	var idx := sel[0]
	_ai_fleet.remove_at(idx)
	_ai_list.remove_item(idx)
	_update_start_button()
	_update_remove_buttons()


func _update_remove_buttons() -> void:
	_remove_human_btn.disabled = _human_list.get_selected_items().is_empty()
	_remove_ai_btn.disabled    = _ai_list.get_selected_items().is_empty()


func _update_start_button() -> void:
	var ok := not _human_fleet.is_empty() and not _ai_fleet.is_empty()
	_start_btn.disabled = not ok
	if ok:
		_status_lbl.text = "Human: %d ship(s)   AI: %d ship(s)   — Ready to battle!" % [
			_human_fleet.size(), _ai_fleet.size()
		]
	else:
		_status_lbl.text = "Add at least one ship to each fleet."


func _on_start_pressed() -> void:
	GameManager.fleet_config.clear()
	for path in _human_fleet:
		GameManager.fleet_config.append({"res_path": path, "faction": "human"})
	for path in _ai_fleet:
		GameManager.fleet_config.append({"res_path": path, "faction": "ai"})
	SceneLoader.load_scene("res://scenes/battle/BattleScene.tscn")


func _on_back_pressed() -> void:
	SceneLoader.load_scene("res://scenes/menus/MainMenu.tscn")
