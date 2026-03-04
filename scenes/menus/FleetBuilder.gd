## FleetBuilder.gd — Compose human and AI fleets from the ship database before battle.
## Ship Database panel shows two side-by-side faction-filtered lists so players
## pick ships appropriate to each side without wading through all factions.
extends CanvasLayer

const DATA_DIR := "res://data/ships/"

# Parallel arrays for each faction's ship list
var _your_paths:  Array[String] = []   # ships matching player faction
var _enemy_paths: Array[String] = []   # ships matching enemy faction

# Fleet lists — each entry is a res_path string
var _human_fleet: Array[String] = []
var _ai_fleet:    Array[String] = []

# UI refs
var _your_list:     ItemList
var _your_db_hdr:   Label
var _enemy_db_list: ItemList
var _enemy_db_hdr:  Label
var _preview_rtl:   RichTextLabel
var _add_human_btn: Button
var _add_ai_btn:    Button
var _human_list:    ItemList
var _ai_list:       ItemList
var _remove_human_btn: Button
var _remove_ai_btn:    Button
var _start_btn:  Button
var _status_lbl: Label
var _cols_spin:  SpinBox
var _rows_spin:  SpinBox
var _player_faction_opt: OptionButton
var _enemy_faction_opt:  OptionButton

const FACTIONS := ["TFN", "Ophiuchi", "KON", "Gorm", "Rigelian", "Arachnid"]
const FACTION_DEFAULTS := {
	"TFN":      "Arachnid",
	"Ophiuchi": "TFN",
	"KON":      "TFN",
	"Gorm":     "KON",
	"Rigelian": "TFN",
	"Arachnid": "TFN",
}


func _ready() -> void:
	_build_ui()
	_reload_db_lists()
	_update_start_button()


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

	# ── Map / faction settings bar ───────────────────────────────────────────
	var settings_bar := HBoxContainer.new()
	settings_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	settings_bar.offset_top = 56
	settings_bar.custom_minimum_size = Vector2(0, 40)
	settings_bar.add_theme_constant_override("separation", 8)
	root.add_child(settings_bar)

	var map_lbl := Label.new()
	map_lbl.text = "  Map Size:"
	settings_bar.add_child(map_lbl)

	_cols_spin = SpinBox.new()
	_cols_spin.min_value = 10
	_cols_spin.max_value = 100
	_cols_spin.value = GameManager.map_cols
	_cols_spin.suffix = "cols"
	_cols_spin.custom_minimum_size = Vector2(110, 0)
	settings_bar.add_child(_cols_spin)

	var x_lbl := Label.new()
	x_lbl.text = "×"
	settings_bar.add_child(x_lbl)

	_rows_spin = SpinBox.new()
	_rows_spin.min_value = 8
	_rows_spin.max_value = 100
	_rows_spin.value = GameManager.map_rows
	_rows_spin.suffix = "rows"
	_rows_spin.custom_minimum_size = Vector2(110, 0)
	settings_bar.add_child(_rows_spin)

	settings_bar.add_child(VSeparator.new())

	var player_faction_lbl := Label.new()
	player_faction_lbl.text = "  Your Faction:"
	settings_bar.add_child(player_faction_lbl)

	_player_faction_opt = OptionButton.new()
	_player_faction_opt.custom_minimum_size = Vector2(110, 0)
	for f in FACTIONS:
		_player_faction_opt.add_item(f)
	_player_faction_opt.selected = FACTIONS.find(GameManager.human_faction_id)
	_player_faction_opt.item_selected.connect(_on_player_faction_changed)
	settings_bar.add_child(_player_faction_opt)

	var enemy_faction_lbl := Label.new()
	enemy_faction_lbl.text = "  vs:"
	settings_bar.add_child(enemy_faction_lbl)

	_enemy_faction_opt = OptionButton.new()
	_enemy_faction_opt.custom_minimum_size = Vector2(110, 0)
	for f in FACTIONS:
		_enemy_faction_opt.add_item(f)
	var default_enemy := FACTION_DEFAULTS.get(GameManager.human_faction_id, "Arachnid") as String
	_enemy_faction_opt.selected = FACTIONS.find(default_enemy)
	_enemy_faction_opt.item_selected.connect(func(_i: int) -> void: _reload_db_lists())
	settings_bar.add_child(_enemy_faction_opt)

	# ── Body: outer split — db area (left) | fleet lists (right) ─────────────
	var body := HSplitContainer.new()
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.offset_top = 100
	root.add_child(body)

	# ── Left: two faction-filtered ship lists ─────────────────────────────────
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(200, 0)
	left.add_theme_constant_override("separation", 6)
	body.add_child(left)

	# Inner split — your faction list (left) | enemy faction list (right)
	var db_split := HSplitContainer.new()
	db_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(db_split)

	# ── Your Faction column ───────────────────────────────────────────────────
	var your_col := VBoxContainer.new()
	your_col.custom_minimum_size = Vector2(120, 0)
	your_col.add_theme_constant_override("separation", 4)
	db_split.add_child(your_col)

	_your_db_hdr = Label.new()
	_your_db_hdr.add_theme_font_size_override("font_size", 13)
	_your_db_hdr.modulate = Color(0.5, 0.85, 1.0)
	your_col.add_child(_your_db_hdr)

	_your_list = ItemList.new()
	_your_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_your_list.allow_reselect = true
	_your_list.item_selected.connect(_on_your_selected)
	your_col.add_child(_your_list)

	_add_human_btn = Button.new()
	_add_human_btn.text = "→ Your Fleet"
	_add_human_btn.disabled = true
	_add_human_btn.pressed.connect(_on_add_human_pressed)
	your_col.add_child(_add_human_btn)

	# ── Enemy Faction column ──────────────────────────────────────────────────
	var enemy_col := VBoxContainer.new()
	enemy_col.custom_minimum_size = Vector2(120, 0)
	enemy_col.add_theme_constant_override("separation", 4)
	db_split.add_child(enemy_col)

	_enemy_db_hdr = Label.new()
	_enemy_db_hdr.add_theme_font_size_override("font_size", 13)
	_enemy_db_hdr.modulate = Color(1.0, 0.55, 0.35)
	enemy_col.add_child(_enemy_db_hdr)

	_enemy_db_list = ItemList.new()
	_enemy_db_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_enemy_db_list.allow_reselect = true
	_enemy_db_list.item_selected.connect(_on_enemy_db_selected)
	enemy_col.add_child(_enemy_db_list)

	_add_ai_btn = Button.new()
	_add_ai_btn.text = "→ AI Fleet"
	_add_ai_btn.disabled = true
	_add_ai_btn.pressed.connect(_on_add_ai_pressed)
	enemy_col.add_child(_add_ai_btn)

	# ── Shared preview ────────────────────────────────────────────────────────
	_preview_rtl = RichTextLabel.new()
	_preview_rtl.bbcode_enabled = true
	_preview_rtl.fit_content = true
	_preview_rtl.scroll_active = false
	_preview_rtl.custom_minimum_size = Vector2(0, 110)
	left.add_child(_preview_rtl)

	# ── Right side: fleet lists split — your fleet | AI fleet ─────────────────
	var fleets_split := HSplitContainer.new()
	fleets_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(fleets_split)

	# ── Center: human fleet ──────────────────────────────────────────────────
	var center := VBoxContainer.new()
	center.custom_minimum_size = Vector2(120, 0)
	center.add_theme_constant_override("separation", 6)
	fleets_split.add_child(center)

	var human_hdr := Label.new()
	human_hdr.text = "Your Fleet"
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

	# ── Right: AI fleet ──────────────────────────────────────────────────────
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(120, 0)
	right.add_theme_constant_override("separation", 6)
	fleets_split.add_child(right)

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

## Reload both faction-filtered ship lists from the database directory.
## Called on startup and whenever either faction dropdown changes.
func _reload_db_lists() -> void:
	_your_paths.clear()
	_your_list.clear()
	_enemy_paths.clear()
	_enemy_db_list.clear()
	_add_human_btn.disabled = true
	_add_ai_btn.disabled = true
	_preview_rtl.text = ""

	var your_faction:  String = FACTIONS[_player_faction_opt.selected]
	var enemy_faction: String = FACTIONS[_enemy_faction_opt.selected]

	_your_db_hdr.text  = "%s Ships" % your_faction
	_enemy_db_hdr.text = "%s Ships" % enemy_faction

	var dir := DirAccess.open(DATA_DIR)
	if not dir:
		return

	var entries: Array = []
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".tres"):
			var path := DATA_DIR + f
			var data := load(path) as ShipData
			if data != null:
				entries.append({"path": path, "data": data})
		f = dir.get_next()
	dir.list_dir_end()

	const CLASS_ORDER := ["Fighter", "Strike", "ES", "CT", "FG", "DD", "CL", "CA", "BC", "BB", "DN", "SD", "CVL", "CV"]
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ci := CLASS_ORDER.find((a.data as ShipData).ship_class)
		var di := CLASS_ORDER.find((b.data as ShipData).ship_class)
		if ci < 0: ci = CLASS_ORDER.size()
		if di < 0: di = CLASS_ORDER.size()
		if ci != di:
			return ci < di
		return (a.data as ShipData).ship_name < (b.data as ShipData).ship_name
	)

	for entry in entries:
		var path: String = entry.path
		var data := entry.data as ShipData
		var label := "%s  [%s]" % [data.ship_name, data.ship_class]
		if data.faction_id == your_faction:
			_your_paths.append(path)
			_your_list.add_item(label)
		elif data.faction_id == enemy_faction:
			_enemy_paths.append(path)
			_enemy_db_list.add_item(label)

	if _your_list.item_count > 0:
		_your_list.select(0)
		_on_your_selected(0)
	if _enemy_db_list.item_count > 0:
		_enemy_db_list.select(0)
		_on_enemy_db_selected(0)


func _try_add_to_fleet(path: String, side: String) -> void:
	var data := load(path) as ShipData
	if data == null:
		return
	if side == "human":
		_human_fleet.append(path)
		_human_list.add_item(data.ship_name)
	else:
		_ai_fleet.append(path)
		_ai_list.add_item(data.ship_name)


func _show_ship_preview(path: String) -> void:
	var data := load(path) as ShipData
	if data == null:
		return
	var t := "[b]%s[/b]  (class: %s)  [color=gray]%s[/color]\n" % [
		data.ship_name, data.ship_class, data.faction_id]
	t += "Drive: %d   Hull: %d   Weapons: %d\n" % [
		data.drive_rating, data.hull_points, data.weapons.size()]
	if data.weapons.size() > 0:
		var wnames: Array[String] = []
		for w in data.weapons:
			var wd := w as WeaponData
			if wd:
				wnames.append(wd.weapon_name)
		t += "[color=orange]%s[/color]\n" % ", ".join(wnames)
	t += "Boxes: "
	for box in data.system_boxes:
		var col: String = {"H": "lime", "S": "lightblue", "A": "yellow", "D": "cyan"}.get(box, "orange")
		t += "[color=%s][%s][/color]" % [col, box]
	t += "\n"
	if data.description != "":
		t += "[i]%s[/i]\n" % data.description
	_preview_rtl.text = t


# ── Signal handlers ──────────────────────────────────────────────────────────

func _on_your_selected(index: int) -> void:
	_add_human_btn.disabled = false
	_show_ship_preview(_your_paths[index])


func _on_enemy_db_selected(index: int) -> void:
	_add_ai_btn.disabled = false
	_show_ship_preview(_enemy_paths[index])


func _on_add_human_pressed() -> void:
	var sel := _your_list.get_selected_items()
	if sel.is_empty():
		return
	var path := _your_paths[sel[0]]
	var data := load(path) as ShipData
	_human_fleet.append(path)
	_human_list.add_item(data.ship_name if data else path.get_file())
	_update_start_button()


func _on_add_ai_pressed() -> void:
	var sel := _enemy_db_list.get_selected_items()
	if sel.is_empty():
		return
	var path := _enemy_paths[sel[0]]
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
		_status_lbl.text = "Your Fleet: %d ship(s)   AI Fleet: %d ship(s)   — Ready to battle!" % [
			_human_fleet.size(), _ai_fleet.size()
		]
	else:
		_status_lbl.text = "Add at least one ship to each fleet."


func _on_start_pressed() -> void:
	GameManager.map_cols = int(_cols_spin.value)
	GameManager.map_rows = int(_rows_spin.value)
	GameManager.human_faction_id = FACTIONS[_player_faction_opt.selected]
	GameManager.ai_faction_id    = FACTIONS[_enemy_faction_opt.selected]
	GameManager.fleet_config.clear()
	for path in _human_fleet:
		GameManager.fleet_config.append({"res_path": path, "faction": "human"})
	for path in _ai_fleet:
		GameManager.fleet_config.append({"res_path": path, "faction": "ai"})
	SceneLoader.load_scene("res://scenes/battle/BattleScene.tscn")


func _on_player_faction_changed(index: int) -> void:
	var player_faction: String = FACTIONS[index]
	var enemy_faction: String = FACTION_DEFAULTS.get(player_faction, "Arachnid") as String
	_enemy_faction_opt.selected = FACTIONS.find(enemy_faction)
	_reload_db_lists()


func _on_back_pressed() -> void:
	SceneLoader.load_scene("res://scenes/menus/MainMenu.tscn")
