## Main.gd — Root scene. Registers the scene container and loads the main menu.
extends Node

@onready var scene_container: Node = $SceneContainer


func _ready() -> void:
	SceneLoader.register_container(scene_container)
	SceneLoader.load_scene("res://scenes/menus/MainMenu.tscn")
