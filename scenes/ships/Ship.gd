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
var _weapon_ready: Array[bool] = [] # per-weapon "not yet fired this turn" flag
var _is_selected: bool = false
var _is_destroyed: bool = false     # guard against double-destruction

## True only when every non-destroyed weapon has been assigned a target this turn.
## Ships with no weapons are considered done.
var has_fired: bool:
	get:
		if ship_data == null:
			return true
		for i in _weapon_ready.size():
			if _weapon_ready[i] and not _is_weapon_destroyed(i):
				return false   # at least one weapon still ready
		return true

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

	_weapon_ready.clear()
	for _i in data.weapons.size():
		_weapon_ready.append(true)

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
	if _is_destroyed:
		return
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
	var target_ship := target as Ship
	for i in ship_data.weapons.size():
		var weapon := ship_data.weapons[i] as WeaponData
		if weapon == null or _is_weapon_destroyed(i) or not _weapon_ready[i]:
			continue
		if GameManager.combat_slow:
			# Stop if the target was killed by an earlier shot in this salvo
			if not is_instance_valid(target) or (target_ship != null and target_ship._is_destroyed):
				break
			_weapon_ready[i] = false   # mark assigned before the await
			var proj := _make_projectile(weapon, target)
			await proj.arrived
			if is_instance_valid(target):
				CombatResolver.resolve_attack(self, target, weapon)
		else:
			_weapon_ready[i] = false   # mark assigned
			CombatResolver.resolve_attack(self, target, weapon)


func _make_projectile(weapon: WeaponData, target: Node) -> Projectile:
	var proj := Projectile.new()
	get_parent().add_child(proj)
	var target_ship := target as Ship
	var to_pos := target_ship.global_position if target_ship != null else global_position
	var is_missile := weapon.weapon_name.begins_with("M")
	var speed := 250.0 if is_missile else 700.0
	var color: Color
	if is_missile:
		color = Color(1.0, 0.55, 0.0)          # orange missile
	elif weapon.weapon_name.begins_with("L"):
		color = Color(0.2, 1.0, 1.0)            # cyan laser
	elif weapon.weapon_name.begins_with("R"):
		color = Color(1.0, 0.2, 0.2)            # red railgun
	else:
		color = Color(1.0, 1.0, 0.2)            # yellow energy
	var radius := 5.0 if is_missile else 3.0
	proj.launch(global_position, to_pos, speed, color, radius, is_missile)
	return proj


func set_selected(selected: bool) -> void:
	_is_selected = selected
	queue_redraw()


func reset_for_new_turn() -> void:
	has_moved = false
	_weapon_ready.fill(true)
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
	# Sprite front is at top of PNG (local -Y).
	# In flat-top odd-q offset coords the East hex neighbor sits 30° below horizontal
	# (at 330° math-angle), so the sprite needs +120° (not +90°) to align the bow
	# with the actual hex the ship is facing. This matches WeaponArc's -30° correction.
	pivot.rotation_degrees = -facing * 60.0 + 120.0


func _on_area_input_event(_viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		EventBus.ship_selected.emit(self)


func _on_destroyed() -> void:
	if _is_destroyed:
		return
	_is_destroyed = true
	GameManager.record_ship_destroyed(self)  # capture stats before node is freed
	GameManager.unregister_ship(self)
	EventBus.ship_destroyed.emit(self)
	queue_free()
