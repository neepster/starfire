## ShipClassImportDialog.gd — Paste a Starfire 3rd-ed ship class string and import it as a new ship.
extends Window

@onready var paste_field: TextEdit = $VBox/PasteField
@onready var preview_text: RichTextLabel = $VBox/PreviewText
@onready var btn_parse: Button = $VBox/BtnRow1/BtnParse
@onready var btn_human: Button = $VBox/BtnRow2/BtnHuman
@onready var btn_ai: Button = $VBox/BtnRow2/BtnAI
@onready var btn_cancel: Button = $VBox/BtnRow2/BtnCancel

var _parsed_data: ShipData = null


func _ready() -> void:
	btn_parse.pressed.connect(_on_parse_pressed)
	btn_human.pressed.connect(func() -> void: _on_add_fleet("human"))
	btn_ai.pressed.connect(func() -> void: _on_add_fleet("ai"))
	btn_cancel.pressed.connect(func() -> void: hide())
	close_requested.connect(func() -> void: hide())
	btn_human.disabled = true
	btn_ai.disabled = true


func _on_parse_pressed() -> void:
	var input: String = paste_field.text.strip_edges()
	if input.is_empty():
		preview_text.text = "[color=red]Please paste a ship class string above.[/color]"
		return

	_parsed_data = ShipClassParser.parse(input)
	_show_preview(_parsed_data)
	btn_human.disabled = false
	btn_ai.disabled = false


func _show_preview(data: ShipData) -> void:
	var t := "[b]Parsed Ship:[/b]\n"
	t += "  Name: %s\n" % data.ship_name
	t += "  Class: %s\n" % data.ship_class
	t += "  Drive: %d\n" % data.drive_rating
	t += "  Hull boxes (H): %d\n" % data.hull_points

	t += "  System boxes: "
	for i in data.system_boxes.size():
		var box: String = data.system_boxes[i]
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

	if data.weapons.size() > 0:
		t += "  Weapons (%d):\n" % data.weapons.size()
		for w in data.weapons:
			var wd := w as WeaponData
			if wd:
				t += "    [color=orange]%s[/color] dmg %d rng %d\n" % [wd.weapon_name, wd.damage, wd.range_hexes]
	else:
		t += "  [color=gray]No weapons detected[/color]\n"

	preview_text.text = t


func _on_add_fleet(faction: String) -> void:
	if _parsed_data == null:
		return
	EventBus.ship_import_confirmed.emit(_parsed_data, faction)
	hide()
