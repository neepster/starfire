## BattleScene.gd — Main gameplay scene controller.
## Spawns ships, wires up input, drives the turn/phase loop.
extends Node2D

const SHIP_SCENE := preload("res://scenes/ships/Ship.tscn")
const IMPORT_DIALOG_SCENE := preload("res://scenes/ui/ShipClassImportDialog.tscn")
const RESULT_SCREEN_SCENE := preload("res://scenes/ui/BattleResultScreen.tscn")

const DEFAULT_HUMAN_SHIP_PATH := "res://data/ships/escort_dd.tres"
const DEFAULT_AI_SHIP_PATH    := "res://data/ships/cruiser_ca.tres"

@onready var hex_map: HexMap = $WorldRoot/HexMap
@onready var ship_container: Node2D = $WorldRoot/ShipContainer
@onready var camera: Camera2D = $Camera2D
@onready var hud: Node = $UI/HUD

var _selected_ship: Node = null
var _highlighter: HexHighlighter = HexHighlighter.new()
var _pathfinder: HexPathfinder = HexPathfinder.new()
var _ai_controller: AIController
var _import_dialog: Window = null


func _ready() -> void:
	GameManager.start_battle(null)   # resets fleets and battle records
	ShipNameGenerator.reset()
	_setup_ai()
	_setup_highlighter()
	_spawn_default_fleet()
	_connect_signals()
	TurnManager.reset()
	EventBus.turn_phase_changed.emit(TurnManager.current_phase)


func _setup_ai() -> void:
	_ai_controller = AIController.new()
	add_child(_ai_controller)


func _setup_highlighter() -> void:
	_highlighter.setup(hex_map)
	_pathfinder.setup(hex_map.get_passable_dict(), HexMap.HEX_SIZE)


func _spawn_default_fleet() -> void:
	var human_data := load(DEFAULT_HUMAN_SHIP_PATH) as ShipData
	if human_data:
		for i in 2:
			_spawn_ship(human_data, "human", Vector2i(2, 5 + i * 3), 0)

	var ai_data := load(DEFAULT_AI_SHIP_PATH) as ShipData
	if ai_data:
		for i in 2:
			_spawn_ship(ai_data, "ai", Vector2i(17, 5 + i * 3), 3)


func _spawn_ship(data: ShipData, faction: String, hex: Vector2i, initial_facing: int) -> Node:
	var ship := SHIP_SCENE.instantiate() as Ship
	ship_container.add_child(ship)
	ship.ship_name = ShipNameGenerator.generate(faction)
	ship.initialize(data, faction, hex, initial_facing)
	GameManager.register_ship(ship, faction)
	return ship


func _connect_signals() -> void:
	EventBus.ship_selected.connect(_on_ship_selected)
	EventBus.ship_destroyed.connect(_on_ship_destroyed)
	EventBus.hex_clicked.connect(_on_hex_clicked)
	EventBus.turn_phase_changed.connect(_on_phase_changed)
	EventBus.import_ship_requested.connect(_on_import_ship_requested)
	EventBus.ship_import_confirmed.connect(_on_ship_import_confirmed)


# --- Input ---

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("end_turn"):
		TurnManager.advance_phase()
	if event.is_action_pressed("cancel"):
		_deselect_ship()

	# Rotate selected ship: Q = CCW, E = CW. Each step costs 1 move point.
	if _selected_ship != null and TurnManager.current_phase == TurnManager.Phase.MOVEMENT_PLOT:
		if event is InputEventKey and event.pressed and not event.echo:
			var sel := _selected_ship as Ship
			if sel != null:
				var rotated := false
				if event.keycode == KEY_Q:
					rotated = sel.rotate_facing(1)   # CCW
				elif event.keycode == KEY_E:
					rotated = sel.rotate_facing(-1)  # CW
				if rotated:
					_refresh_movement_highlight(sel)

	# Camera pan
	const PAN_SPEED := 400.0
	var pan := Vector2.ZERO
	if Input.is_action_pressed("camera_pan_left"):  pan.x -= 1
	if Input.is_action_pressed("camera_pan_right"): pan.x += 1
	if Input.is_action_pressed("camera_pan_up"):    pan.y -= 1
	if Input.is_action_pressed("camera_pan_down"):  pan.y += 1
	if pan != Vector2.ZERO:
		camera.position += pan * PAN_SPEED * get_process_delta_time()

	# Zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom = (camera.zoom * 1.1).clamp(Vector2(0.3, 0.3), Vector2(2.0, 2.0))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom = (camera.zoom / 1.1).clamp(Vector2(0.3, 0.3), Vector2(2.0, 2.0))


# --- Signal Handlers ---

func _on_ship_selected(ship: Node) -> void:
	var clicked_ship := ship as Ship
	if clicked_ship == null:
		return

	# Enemy ships: show info; fire if in WEAPONS_FIRE with an attacker ready
	if clicked_ship.faction == "ai":
		if TurnManager.current_phase == TurnManager.Phase.WEAPONS_FIRE and _selected_ship != null:
			var attacker := _selected_ship as Ship
			if attacker != null and not attacker.has_fired:
				attacker.fire_at(clicked_ship)
				_highlighter.clear_all()
		return

	if TurnManager.current_phase != TurnManager.Phase.MOVEMENT_PLOT \
			and TurnManager.current_phase != TurnManager.Phase.WEAPONS_FIRE:
		return

	_deselect_ship()
	_selected_ship = clicked_ship
	clicked_ship.set_selected(true)

	if TurnManager.current_phase == TurnManager.Phase.MOVEMENT_PLOT:
		_refresh_movement_highlight(clicked_ship)
	elif TurnManager.current_phase == TurnManager.Phase.WEAPONS_FIRE and not clicked_ship.has_fired:
		_show_weapon_arcs(clicked_ship)


func _on_hex_clicked(hex: Vector2i) -> void:
	if _selected_ship == null:
		return
	if TurnManager.current_phase != TurnManager.Phase.MOVEMENT_PLOT:
		return
	var sel := _selected_ship as Ship
	if sel == null or sel.moves_remaining <= 0:
		return
	_pathfinder.setup(hex_map.get_passable_dict(), HexMap.HEX_SIZE)
	var reachable := _pathfinder.reachable_hexes(sel.hex_position, sel.moves_remaining)
	if hex in reachable:
		sel.move_to_hex(hex)
		_refresh_movement_highlight(sel)


func _on_ship_destroyed(_ship: Node) -> void:
	if _selected_ship == _ship:
		_selected_ship = null
	var winner := GameManager.check_victory()
	if winner != "":
		GameManager.end_battle(winner)
		_show_result_screen(winner)


func _show_result_screen(winner: String) -> void:
	var screen := RESULT_SCREEN_SCENE.instantiate() as BattleResultScreen
	screen.setup(winner, GameManager.get_battle_results())
	$UI.add_child(screen)


func _on_phase_changed(phase: int) -> void:
	_highlighter.clear_all()
	_deselect_ship()

	# Auto-advance phases that have no player interaction yet
	if phase == TurnManager.Phase.MOVEMENT_EXECUTE or phase == TurnManager.Phase.DAMAGE_RESOLVE:
		TurnManager.advance_phase()
		return

	if phase == TurnManager.Phase.AI_TURN:
		_ai_controller.take_turn()

	if phase == TurnManager.Phase.MOVEMENT_PLOT:
		for ship in ship_container.get_children():
			ship.reset_for_new_turn()


func _on_import_ship_requested() -> void:
	if _import_dialog == null:
		_import_dialog = IMPORT_DIALOG_SCENE.instantiate() as Window
		$UI.add_child(_import_dialog)
	_import_dialog.popup_centered()


func _on_ship_import_confirmed(data: ShipData, faction: String) -> void:
	# Spawn the imported ship near its faction's starting zone
	var spawn_hex: Vector2i
	if faction == "human":
		spawn_hex = Vector2i(3, 8)
	else:
		spawn_hex = Vector2i(16, 8)
	var facing: int = 0 if faction == "human" else 3
	var ship := _spawn_ship(data, faction, spawn_hex, facing) as Ship
	if ship != null:
		# Imported ships get a class-counter name: "SD #1", "SD #2", etc.
		ship.ship_name = ShipNameGenerator.get_import_name(data.ship_class)


func _deselect_ship() -> void:
	if _selected_ship and is_instance_valid(_selected_ship):
		_selected_ship.set_selected(false)
	_selected_ship = null
	_highlighter.clear_all()


func _refresh_movement_highlight(ship: Ship) -> void:
	if ship.moves_remaining > 0:
		_pathfinder.setup(hex_map.get_passable_dict(), HexMap.HEX_SIZE)
		var reachable := _pathfinder.reachable_hexes(ship.hex_position, ship.moves_remaining)
		_highlighter.show_movement_range(reachable)
	else:
		_highlighter.clear_all()


func _show_weapon_arcs(ship: Ship) -> void:
	var all_arc_hexes: Array[Vector2i] = []
	for weapon in ship.ship_data.weapons:
		var w := weapon as WeaponData
		if w == null:
			continue
		var hexes := WeaponArc.get_arc_hexes(
				ship.hex_position, ship.facing, w, hex_map.get_map_bounds())
		for h in hexes:
			if h not in all_arc_hexes:
				all_arc_hexes.append(h)
	_highlighter.show_attack_range(all_arc_hexes)
