## FleetStatusPanel.gd — Collapsible sidebar showing one fleet's status during battle.
## Call configure() before populate() to choose left (human) or right (enemy) side.
## Each ship row is clickable — emits ship_selected so BattleScene can handle it.
class_name FleetStatusPanel
extends PanelContainer

const PANEL_WIDTH := 250

var _ship_btns: Dictionary = {}    # Ship -> Button
var _content_vbox: VBoxContainer
var _title_btn: Button             # click to collapse/expand
var _scroll: ScrollContainer
var _collapsed: bool = false
var _fleet_label: String = "YOUR FLEET"
var _title_color: Color = Color(0.5, 0.85, 1.0)


func _ready() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, 40)
	# Default position — overridden by configure()
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_top  = 64
	offset_left = 6

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 3)
	add_child(outer)

	# ── Title / toggle row ────────────────────────────────────────────────────
	_title_btn = Button.new()
	_title_btn.flat = true
	_title_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_btn.add_theme_font_size_override("font_size", 13)
	_title_btn.pressed.connect(_on_toggle_pressed)
	outer.add_child(_title_btn)

	outer.add_child(HSeparator.new())

	# ── Scrollable ship list ──────────────────────────────────────────────────
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0, 0)
	outer.add_child(_scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", 3)
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content_vbox)

	EventBus.ship_destroyed.connect(_on_ship_destroyed)
	EventBus.turn_phase_changed.connect(func(_p: int) -> void: _refresh_all())


## Call this immediately after adding to the scene tree, before populate().
## is_enemy=false → left side, blue (human fleet).
## is_enemy=true  → right side, orange (enemy fleet).
func configure(is_enemy: bool) -> void:
	if is_enemy:
		_fleet_label = "ENEMY FLEET"
		_title_color  = Color(1.0, 0.55, 0.35)
		set_anchors_preset(Control.PRESET_TOP_RIGHT)
		offset_top   = 64
		offset_right = -6
		offset_left  = offset_right - PANEL_WIDTH
	else:
		_fleet_label = "YOUR FLEET"
		_title_color  = Color(0.5, 0.85, 1.0)
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		offset_top  = 64
		offset_left = 6
	_title_btn.modulate = _title_color
	_update_title()


## Call this after placement is complete, passing GameManager.human_fleet.
func populate(fleet: Array[Node]) -> void:
	for child in _content_vbox.get_children():
		child.queue_free()
	_ship_btns.clear()

	for node in fleet:
		var ship := node as Ship
		if ship == null or not is_instance_valid(ship):
			continue
		_add_ship_row(ship)

	_update_title()
	_resize_to_content()


# ── Private helpers ───────────────────────────────────────────────────────────

func _add_ship_row(ship: Ship) -> void:
	var class_str := ship.ship_data.ship_class if ship.ship_data != null else "?"
	var btn := Button.new()
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(240, 30)
	btn.pressed.connect(func() -> void: EventBus.ship_selected.emit(ship))
	_content_vbox.add_child(btn)
	_ship_btns[ship] = btn

	# Update HP whenever the ship's health bar changes (e.g. after each hit)
	ship.health_bar.value_changed.connect(func(_v: float) -> void: _update_ship_row(ship))

	_update_ship_row(ship)


func _update_ship_row(ship: Ship) -> void:
	var btn := _ship_btns.get(ship) as Button
	if btn == null or not is_instance_valid(btn):
		return
	if not is_instance_valid(ship) or ship.ship_data == null:
		return

	var class_str := ship.ship_data.ship_class
	var hp     := ship.current_hull
	var max_hp := int(ship.health_bar.max_value)
	var pct    := float(hp) / float(max_hp) if max_hp > 0 else 0.0

	btn.text = " %s  (%s)   ♥ %d / %d" % [ship.ship_name, class_str, hp, max_hp]

	if pct > 0.66:
		btn.modulate = Color(1.0, 1.0, 1.0)        # white  — healthy
	elif pct > 0.33:
		btn.modulate = Color(1.0, 0.85, 0.3)       # yellow — damaged
	else:
		btn.modulate = Color(1.0, 0.35, 0.35)      # red    — critical


func _refresh_all() -> void:
	for ship in _ship_btns.keys():
		var s := ship as Ship
		if s != null and is_instance_valid(s):
			_update_ship_row(s)


func _on_ship_destroyed(ship: Node) -> void:
	if _ship_btns.has(ship):
		var btn := _ship_btns[ship] as Button
		if btn != null and is_instance_valid(btn):
			btn.queue_free()
		_ship_btns.erase(ship)
	_update_title()
	_resize_to_content()


func _on_toggle_pressed() -> void:
	_collapsed = not _collapsed
	_scroll.visible = not _collapsed
	_resize_to_content()
	_update_title()


func _update_title() -> void:
	var arrow := "▶" if _collapsed else "▼"
	_title_btn.text = "%s  %s  (%d)" % [arrow, _fleet_label, _ship_btns.size()]


func _resize_to_content() -> void:
	if _collapsed:
		custom_minimum_size.y = 40
	else:
		# Clamp height so the panel doesn't swallow the whole screen
		var row_count := _ship_btns.size()
		var row_h     := 33
		var header_h  := 46
		var clamped   := mini(row_count * row_h + header_h, 480)
		custom_minimum_size.y = maxi(clamped, 40)
