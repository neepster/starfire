## SceneLoader.gd — Handles scene transitions by swapping content in a registered container.
extends Node

var _scene_container: Node = null


func register_container(container: Node) -> void:
	_scene_container = container


func load_scene(path: String) -> void:
	if not _scene_container:
		push_error("SceneLoader: No container registered. Call register_container() first.")
		return

	# Free existing children
	for child in _scene_container.get_children():
		child.queue_free()

	var packed = load(path)
	if packed == null:
		push_error("SceneLoader: Failed to load scene: %s" % path)
		return

	var instance = packed.instantiate()
	_scene_container.add_child(instance)
