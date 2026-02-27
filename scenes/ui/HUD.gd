## HUD.gd — Turn/phase display, End Turn button, and combat log.
extends Node

const MAX_LOG_LINES := 20

@onready var lbl_turn: Label = $TopBar/HBoxContainer/LblTurn
@onready var lbl_phase: Label = $TopBar/HBoxContainer/LblPhase
@onready var btn_import: Button = $TopBar/HBoxContainer/BtnImportShip
@onready var btn_end_turn: Button = $TopBar/HBoxContainer/BtnEndTurn
@onready var log_text: RichTextLabel = $CombatLog/VBox/LogText

var _log_lines: Array[String] = []


func _ready() -> void:
	EventBus.turn_phase_changed.connect(_on_phase_changed)
	EventBus.weapon_fired.connect(_on_weapon_fired)
	btn_end_turn.pressed.connect(_on_end_turn_pressed)
	btn_import.pressed.connect(func() -> void: EventBus.import_ship_requested.emit())
	_refresh_labels()


func _refresh_labels() -> void:
	lbl_turn.text = "Turn: %d" % TurnManager.current_turn
	lbl_phase.text = "Phase: %s" % TurnManager.get_phase_name()


func _on_phase_changed(_phase: int) -> void:
	_refresh_labels()


func _on_end_turn_pressed() -> void:
	TurnManager.advance_phase()


func _on_weapon_fired(attacker: String, target: String, weapon: String, hit: bool, damage: int) -> void:
	var line: String
	if hit:
		line = "[color=orange][b]HIT[/b][/color]  %s fires %s at %s — [color=red]%d dmg[/color]" % [
			attacker, weapon, target, damage
		]
	else:
		line = "[color=gray]MISS[/color]  %s fires %s at %s" % [attacker, weapon, target]

	_log_lines.append(line)
	if _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()

	log_text.text = "\n".join(_log_lines)
