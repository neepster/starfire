## HUD.gd — Turn/phase display, End Turn button, and combat log.
extends Node

const MAX_LOG_LINES := 20

@onready var lbl_turn: Label = $TopBar/HBoxContainer/LblTurn
@onready var lbl_phase: Label = $TopBar/HBoxContainer/LblPhase
@onready var btn_import: Button = $TopBar/HBoxContainer/BtnImportShip
@onready var btn_combat_speed: Button = $TopBar/HBoxContainer/BtnCombatSpeed
@onready var btn_end_turn: Button = $TopBar/HBoxContainer/BtnEndTurn
@onready var log_text: RichTextLabel = $CombatLog/VBox/LogText

var _log_lines: Array[String] = []


func _ready() -> void:
	EventBus.turn_phase_changed.connect(_on_phase_changed)
	EventBus.weapon_fired.connect(_on_weapon_fired)
	EventBus.ship_destroyed.connect(_on_ship_destroyed)
	btn_end_turn.pressed.connect(_on_end_turn_pressed)
	btn_import.pressed.connect(func() -> void: EventBus.import_ship_requested.emit())
	btn_combat_speed.pressed.connect(_on_combat_speed_pressed)
	btn_combat_speed.text = "Combat: Slow" if GameManager.combat_slow else "Combat: Fast"
	_refresh_labels()


func _refresh_labels() -> void:
	lbl_turn.text = "Turn: %d" % TurnManager.current_turn
	lbl_phase.text = "Phase: %s" % TurnManager.get_phase_name()


func _on_phase_changed(_phase: int) -> void:
	_refresh_labels()


func _on_end_turn_pressed() -> void:
	TurnManager.advance_phase()


func _on_combat_speed_pressed() -> void:
	GameManager.combat_slow = not GameManager.combat_slow
	btn_combat_speed.text = "Combat: Slow" if GameManager.combat_slow else "Combat: Fast"


func _add_log(line: String) -> void:
	var entry := "[color=gray][T%d][/color] %s" % [TurnManager.current_turn, line]
	_log_lines.append(entry)
	if _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
	log_text.text = "\n".join(_log_lines)


func _on_ship_destroyed(ship: Node) -> void:
	var s := ship as Ship
	if s == null:
		return
	var color := "cyan" if s.faction == "human" else "orange"
	var class_str := ""
	if s.ship_data != null:
		class_str = " (%s)" % s.ship_data.ship_class
	_add_log("[color=%s][b]DESTROYED[/b][/color]  %s%s was destroyed!" % [color, s.ship_name, class_str])


func _on_weapon_fired(attacker: String, target: String, weapon: String, hit: bool, damage: int, roll: int, roll_needed: int) -> void:
	var roll_str := "[roll %d/%d]" % [roll, roll_needed]
	var line: String
	if hit:
		line = "[color=orange][b]HIT[/b][/color]  %s fires %s at %s — [color=red]%d dmg[/color]  [color=gray]%s[/color]" % [
			attacker, weapon, target, damage, roll_str
		]
	else:
		line = "[color=gray]MISS[/color]  %s fires %s at %s  [color=gray]%s[/color]" % [
			attacker, weapon, target, roll_str
		]
	_add_log(line)
