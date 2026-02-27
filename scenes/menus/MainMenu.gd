## MainMenu.gd — Main menu screen.
extends CanvasLayer

@onready var btn_new_game: Button = $CenterContainer/VBoxContainer/BtnNewGame
@onready var btn_quit: Button = $CenterContainer/VBoxContainer/BtnQuit


func _ready() -> void:
	btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)


func _on_new_game_pressed() -> void:
	SceneLoader.load_scene("res://scenes/battle/BattleScene.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
