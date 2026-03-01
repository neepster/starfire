## ShipDatabase.gd — Browse, parse, delete, and permanently save ship class .tres files.
## Accessible from the Main Menu. Ships saved here appear in-game and in the import dialog.
extends CanvasLayer

const DATA_DIR   := "res://data/ships/"
const SPRITE_DIR := "res://assets/ship_images/"

var _ship_paths: Array[String] = []      # sorted .tres paths
var _selected_list_index: int = -1       # which saved ship is highlighted
var _parsed_data: ShipData = null
var _sprite_codes: Array[String] = []    # e.g. ["bb", "bc", "ca", ...]

# UI refs built in _build_ui
var _list: ItemList
var _detail_rtl: RichTextLabel
var _delete_btn: Button
var _paste_field: TextEdit
var _preview_rtl: RichTextLabel
var _name_field: LineEdit
var _desc_field: LineEdit
var _sprite_option: OptionButton
var _save_btn: Button
var _status_lbl: Label


func _ready() -> void:
	_build_ui()
	_populate_sprite_options()
	_refresh_ship_list()


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
	title_bar.add_theme_constant_override("separation", 12)
	root.add_child(title_bar)

	var back_btn := Button.new()
	back_btn.text = "← Back"
	back_btn.custom_minimum_size = Vector2(110, 44)
	back_btn.pressed.connect(_on_back_pressed)
	title_bar.add_child(back_btn)

	var title_lbl := Label.new()
	title_lbl.text = "SHIP DATABASE"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_bar.add_child(title_lbl)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(110, 0)
	title_bar.add_child(spacer)

	# ── Main split ───────────────────────────────────────────────────────────
	var split := HSplitContainer.new()
	split.set_anchors_preset(Control.PRESET_FULL_RECT)
	split.offset_top = 56
	split.add_theme_constant_override("separation", 8)
	root.add_child(split)

	# ── Left panel: saved ships list ─────────────────────────────────────────
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	left.add_theme_constant_override("separation", 6)
	split.add_child(left)

	var list_hdr := Label.new()
	list_hdr.text = "Saved Ships"
	list_hdr.add_theme_font_size_override("font_size", 16)
	left.add_child(list_hdr)

	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_list_ship_selected)
	left.add_child(_list)

	_detail_rtl = RichTextLabel.new()
	_detail_rtl.bbcode_enabled = true
	_detail_rtl.fit_content = true
	_detail_rtl.scroll_active = false
	_detail_rtl.custom_minimum_size = Vector2(0, 150)
	left.add_child(_detail_rtl)

	_delete_btn = Button.new()
	_delete_btn.text = "Delete Selected Ship"
	_delete_btn.disabled = true
	_delete_btn.pressed.connect(_on_delete_pressed)
	left.add_child(_delete_btn)

	# ── Right panel: import / save ───────────────────────────────────────────
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	split.add_child(right)

	var paste_lbl := Label.new()
	paste_lbl.text = "Paste Starfire 3rd-edition ship class string:"
	right.add_child(paste_lbl)

	_paste_field = TextEdit.new()
	_paste_field.custom_minimum_size = Vector2(0, 72)
	_paste_field.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	right.add_child(_paste_field)

	var parse_btn := Button.new()
	parse_btn.text = "Parse"
	parse_btn.pressed.connect(_on_parse_pressed)
	right.add_child(parse_btn)

	right.add_child(HSeparator.new())

	_preview_rtl = RichTextLabel.new()
	_preview_rtl.bbcode_enabled = true
	_preview_rtl.fit_content = true
	_preview_rtl.scroll_active = false
	_preview_rtl.custom_minimum_size = Vector2(0, 130)
	right.add_child(_preview_rtl)

	right.add_child(HSeparator.new())

	# Display name (editable — e.g. "Cromwell SD")
	var name_row := HBoxContainer.new()
	right.add_child(name_row)
	var name_lbl := Label.new()
	name_lbl.text = "Display name:"
	name_lbl.custom_minimum_size = Vector2(120, 0)
	name_row.add_child(name_lbl)
	_name_field = LineEdit.new()
	_name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_field.placeholder_text = "e.g. Cromwell SD"
	name_row.add_child(_name_field)

	# Description
	var desc_row := HBoxContainer.new()
	right.add_child(desc_row)
	var desc_lbl := Label.new()
	desc_lbl.text = "Description:"
	desc_lbl.custom_minimum_size = Vector2(120, 0)
	desc_row.add_child(desc_lbl)
	_desc_field = LineEdit.new()
	_desc_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_desc_field.placeholder_text = "Optional flavour text"
	desc_row.add_child(_desc_field)

	# Sprite picker
	var sprite_row := HBoxContainer.new()
	right.add_child(sprite_row)
	var sprite_lbl := Label.new()
	sprite_lbl.text = "Sprite:"
	sprite_lbl.custom_minimum_size = Vector2(120, 0)
	sprite_row.add_child(sprite_lbl)
	_sprite_option = OptionButton.new()
	_sprite_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sprite_row.add_child(_sprite_option)

	right.add_child(HSeparator.new())

	_save_btn = Button.new()
	_save_btn.text = "Save to Database"
	_save_btn.disabled = true
	_save_btn.pressed.connect(_on_save_pressed)
	right.add_child(_save_btn)

	_status_lbl = Label.new()
	right.add_child(_status_lbl)


# ── Data population ──────────────────────────────────────────────────────────

func _populate_sprite_options() -> void:
	_sprite_codes.clear()
	var dir := DirAccess.open(SPRITE_DIR)
	if dir:
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if f.ends_with("_blue.png"):
				_sprite_codes.append(f.replace("_blue.png", ""))
			f = dir.get_next()
		dir.list_dir_end()
	_sprite_codes.sort()

	_sprite_option.clear()
	for code in _sprite_codes:
		_sprite_option.add_item(code)


func _refresh_ship_list() -> void:
	_ship_paths.clear()
	_selected_list_index = -1
	_delete_btn.disabled = true
	_detail_rtl.text = ""
	_list.clear()

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
		_ship_paths.append(path)
		var data := load(path) as ShipData
		var display := data.ship_name if data else name.replace(".tres", "")
		_list.add_item(display)


# ── Signal handlers ──────────────────────────────────────────────────────────

func _on_list_ship_selected(index: int) -> void:
	_selected_list_index = index
	_delete_btn.disabled = false

	var data := load(_ship_paths[index]) as ShipData
	if data == null:
		_detail_rtl.text = "[color=red]Failed to load.[/color]"
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
	_detail_rtl.text = t


func _on_delete_pressed() -> void:
	if _selected_list_index < 0 or _selected_list_index >= _ship_paths.size():
		return

	var path := _ship_paths[_selected_list_index]
	var dir := DirAccess.open(DATA_DIR)
	if dir == null:
		_status_lbl.modulate = Color(1.0, 0.3, 0.3)
		_status_lbl.text = "Could not open data directory."
		return

	var err := dir.remove(path.get_file())
	if err == OK:
		_status_lbl.modulate = Color(0.2, 1.0, 0.2)
		_status_lbl.text = "Deleted: %s" % path.get_file()
		_refresh_ship_list()
	else:
		_status_lbl.modulate = Color(1.0, 0.3, 0.3)
		_status_lbl.text = "Delete failed (error %d)" % err


func _on_parse_pressed() -> void:
	var input: String = _paste_field.text.strip_edges()
	if input.is_empty():
		_preview_rtl.text = "[color=red]Paste a ship class string above first.[/color]"
		return

	_parsed_data = ShipClassParser.parse(input)
	_show_preview(_parsed_data)

	# Pre-fill editable fields — ship_name is now "Cromwell SD", ship_class is "SD"
	_name_field.text = _parsed_data.ship_name
	_desc_field.text  = _parsed_data.description

	# Pre-select matching sprite from class code
	var guessed := _parsed_data.ship_class.to_lower()
	for i in _sprite_codes.size():
		if _sprite_codes[i] == guessed:
			_sprite_option.selected = i
			break

	_save_btn.disabled = false
	_status_lbl.text = ""


func _show_preview(data: ShipData) -> void:
	var t := "[b]%s[/b]  (class: %s)\n" % [data.ship_name, data.ship_class]
	t += "Drive: %d   Hull boxes: %d\n" % [data.drive_rating, data.hull_points]
	t += "System boxes: "
	for box in data.system_boxes:
		var col: String = {"H": "lime", "S": "lightblue", "A": "yellow", "D": "cyan"}.get(box, "orange")
		t += "[color=%s][%s][/color]" % [col, box]
	t += "\n"
	if data.weapons.size() > 0:
		t += "Weapons (%d):\n" % data.weapons.size()
		for w in data.weapons:
			var wd := w as WeaponData
			if wd:
				t += "  [color=orange]%s[/color]  dmg %d  rng %d\n" % [
					wd.weapon_name, wd.damage, wd.range_hexes
				]
	else:
		t += "[color=gray]No weapons detected[/color]\n"
	t += "Sprite: [color=aqua]%s[/color]\n" % data.sprite_path.get_file()
	_preview_rtl.text = t


func _on_save_pressed() -> void:
	if _parsed_data == null:
		return

	# Apply display name edit (does NOT change ship_class — keep type code for sprites/naming)
	var name_edit: String = _name_field.text.strip_edges()
	if name_edit != "":
		_parsed_data.ship_name = name_edit

	_parsed_data.description = _desc_field.text.strip_edges()

	# Apply selected sprite
	var sel := _sprite_option.selected
	if sel >= 0 and sel < _sprite_codes.size():
		_parsed_data.sprite_path = "%s%s_blue.png" % [SPRITE_DIR, _sprite_codes[sel]]

	# Filename derived from display name (e.g. "Cromwell SD" → "cromwell_sd.tres")
	# Using ship_name (not ship_class) so two ships of the same class don't overwrite each other.
	var raw_name: String = _parsed_data.ship_name.to_lower()
	for ch in [" ", "/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		raw_name = raw_name.replace(ch, "_")
	var save_path: String = "%s%s.tres" % [DATA_DIR, raw_name]

	var err := ResourceSaver.save(_parsed_data, save_path)
	if err == OK:
		_status_lbl.modulate = Color(0.2, 1.0, 0.2)
		_status_lbl.text = "Saved: %s" % save_path.get_file()
		_parsed_data = null
		_save_btn.disabled = true
		_paste_field.text = ""
		_preview_rtl.text = ""
		_refresh_ship_list()
	else:
		_status_lbl.modulate = Color(1.0, 0.3, 0.3)
		_status_lbl.text = "Save failed (error %d)" % err


func _on_back_pressed() -> void:
	SceneLoader.load_scene("res://scenes/menus/MainMenu.tscn")
