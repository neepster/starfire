## Ship.gd — A single ship unit on the battle map.
## Handles display, facing, movement, damage, and player interaction.
class_name Ship
extends Node2D

const HEX_SIZE := 48.0  # Must match HexMap.HEX_SIZE

@export var ship_data: ShipData

# Runtime state
var faction: String = "human"       # "human" or "ai"
var ship_name: String = ""          # unique per-instance name (e.g. "HMS Agincourt")
var hex_position: Vector2i = Vector2i.ZERO
var facing: int = 0                 # 0–5 clockwise, 0 = East
var current_hull: int = 0
var destroyed_box_count: int = 0    # system boxes crossed off from left (Starfire model)
var moves_remaining: int = 0        # drive points left this turn
var has_moved: bool = false
var has_fired: bool = false
var _is_selected: bool = false

@onready var pivot: Node2D = $Pivot
@onready var ship_sprite: Sprite2D = $Pivot/ShipSprite
@onready var facing_indicator: Line2D = $Pivot/FacingIndicator
@onready var health_bar: ProgressBar = $HealthBar
@onready var collision_area: Area2D = $CollisionArea


func _ready() -> void:
	collision_area.input_event.connect(_on_area_input_event)


func _draw() -> void:
	if _is_selected:
		draw_arc(Vector2.ZERO, 36.0, 0.0, TAU, 36, Color(1.0, 0.9, 0.1, 0.9), 2.5)


func initialize(data: ShipData, ship_faction: String, start_hex: Vector2i, start_facing: int = 0) -> void:
	ship_data = data
	faction = ship_faction
	hex_position = start_hex
	facing = start_facing
	destroyed_box_count = 0

	# Set hull from system boxes (if defined) or hull_points fallback
	if data.system_boxes.size() > 0:
		current_hull = _count_h_boxes()
		health_bar.max_value = maxi(current_hull, 1)
	else:
		current_hull = data.hull_points
		health_bar.max_value = data.hull_points
	health_bar.value = current_hull

	moves_remaining = _calc_drive()

	# Load sprite texture — swap _blue for _red for AI faction
	var sprite_path := data.sprite_path
	if faction == "ai":
		sprite_path = sprite_path.replace("_blue.png", "_red.png")
		if not ResourceLoader.exists(sprite_path):
			sprite_path = data.sprite_path

	var tex := load(sprite_path) as Texture2D
	if tex:
		ship_sprite.texture = tex

	pivot.scale = Vector2(0.42, 0.42)

	position = HexGrid.offset_to_world(hex_position, HEX_SIZE)
	_apply_facing()


func move_to_hex(target: Vector2i) -> void:
	var dist: int = HexGrid.offset_distance(hex_position, target)
	moves_remaining = max(0, moves_remaining - dist)
	hex_position = target
	position = HexGrid.offset_to_world(hex_position, HEX_SIZE)
	has_moved = true


## Rotate by steps (positive = CCW, negative = CW in screen space).
## Costs 1 move point per 60° step. Returns true if rotation was applied.
func rotate_facing(steps: int) -> bool:
	if moves_remaining <= 0:
		return false
	var cost: int = absi(steps)
	if cost > moves_remaining:
		return false
	moves_remaining -= cost
	facing = (facing + steps + 6) % 6
	_apply_facing()
	return true


func take_damage(amount: int) -> void:
	if ship_data != null and ship_data.system_boxes.size() > 0:
		# Starfire system box model: cross off boxes left-to-right
		destroyed_box_count = mini(destroyed_box_count + amount, ship_data.system_boxes.size())
		current_hull = _count_h_boxes()
		health_bar.value = current_hull
		_flash_damage()
		if current_hull <= 0 or destroyed_box_count >= ship_data.system_boxes.size():
			_on_destroyed()
	else:
		# Fallback: simple HP model
		current_hull = max(0, current_hull - amount)
		health_bar.value = current_hull
		_flash_damage()
		if current_hull <= 0:
			_on_destroyed()


func _flash_damage() -> void:
	ship_sprite.modulate = Color(2.5, 0.2, 0.2, 1.0)
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(ship_sprite):
		ship_sprite.modulate = Color(1, 1, 1, 1)


func fire_at(target: Node) -> void:
	if ship_data == null or has_fired:
		return
	for i in ship_data.weapons.size():
		var weapon := ship_data.weapons[i] as WeaponData
		if weapon == null:
			continue
		if _is_weapon_destroyed(i):
			continue
		CombatResolver.resolve_attack(self, target, weapon)
	has_fired = true


func set_selected(selected: bool) -> void:
	_is_selected = selected
	queue_redraw()


func reset_for_new_turn() -> void:
	has_moved = false
	has_fired = false
	moves_remaining = _calc_drive()


## Returns the current effective drive rating based on surviving D boxes.
func _calc_drive() -> int:
	if ship_data == null:
		return 0
	if ship_data.system_boxes.is_empty():
		return ship_data.drive_rating
	var total_d := 0
	var alive_d := 0
	for i in ship_data.system_boxes.size():
		if ship_data.system_boxes[i] == "D":
			total_d += 1
			if i >= destroyed_box_count:
				alive_d += 1
	if total_d == 0:
		return ship_data.drive_rating
	return int(ship_data.drive_rating * alive_d / total_d)


## Count intact H boxes (hull remaining).
func _count_h_boxes() -> int:
	if ship_data == null:
		return 0
	var count := 0
	for i in ship_data.system_boxes.size():
		if ship_data.system_boxes[i] == "H" and i >= destroyed_box_count:
			count += 1
	return count


## Returns true if weapon[idx] has its system box destroyed.
func _is_weapon_destroyed(idx: int) -> bool:
	if ship_data == null or ship_data.system_boxes.is_empty():
		return false
	var key: String = "W%d" % idx
	for i in ship_data.system_boxes.size():
		if ship_data.system_boxes[i] == key:
			return i < destroyed_box_count
	return false


func _apply_facing() -> void:
	# Sprite front is at top of PNG (local -Y). Facing 0 = East (+X screen).
	# Formula: rotate -60° per facing step, then +90° to offset sprite's natural up orientation.
	pivot.rotation_degrees = -facing * 60.0 + 90.0


func _on_area_input_event(_viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		EventBus.ship_selected.emit(self)


func _on_destroyed() -> void:
	GameManager.record_ship_destroyed(self)  # capture stats before node is freed
	GameManager.unregister_ship(self)
	EventBus.ship_destroyed.emit(self)
	queue_free()
