## ScenarioSelect.gd — Scenario selection screen (stub for future use).
extends CanvasLayer

@onready var scenario_list: ItemList = $VBoxContainer/ScenarioList
@onready var btn_start: Button = $VBoxContainer/BtnStart
@onready var btn_back: Button = $VBoxContainer/BtnBack

var _scenarios: Array[Resource] = []


func _ready() -> void:
	btn_start.pressed.connect(_on_start_pressed)
	btn_back.pressed.connect(_on_back_pressed)
	_load_scenarios()


func _load_scenarios() -> void:
	# Load all .tres files from data/ships — placeholder until scenario resources exist
	_scenarios.clear()
	scenario_list.clear()
	scenario_list.add_item("Tutorial — First Contact (2 DDs per side)")
	scenario_list.add_item("Skirmish — Cruiser Clash (1 CA + 2 DD per side)")
	scenario_list.select(0)


func _on_start_pressed() -> void:
	SceneLoader.load_scene("res://scenes/battle/BattleScene.tscn")


func _on_back_pressed() -> void:
	SceneLoader.load_scene("res://scenes/menus/MainMenu.tscn")
