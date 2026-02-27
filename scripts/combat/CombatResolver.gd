## CombatResolver.gd — Resolves weapon hits and applies damage.
## Starfire uses a d10 roll: roll equal to or under weapon damage to score a hit.
class_name CombatResolver
extends RefCounted


## Attempt an attack. Returns the damage dealt (0 if missed).
static func resolve_attack(attacker: Node, target: Node, weapon: WeaponData) -> int:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return 0

	var attacker_ship := attacker as Ship
	var target_ship   := target as Ship

	var attacker_name := attacker_ship.ship_data.ship_name if attacker_ship and attacker_ship.ship_data else "?"
	var target_name   := target_ship.ship_data.ship_name   if target_ship   and target_ship.ship_data   else "?"

	var dist := HexGrid.offset_distance(attacker_ship.hex_position, target_ship.hex_position) \
			if attacker_ship and target_ship else 999
	if dist > weapon.range_hexes:
		return 0  # Out of range

	# Range modifier: damage halved beyond half range
	var effective_damage := weapon.damage
	if dist > weapon.range_hexes / 2:
		effective_damage = max(1, effective_damage / 2)

	# Roll to hit: d10, equal or under effective_damage = hit
	var roll := randi_range(1, 10)
	if roll <= effective_damage:
		if target_ship:
			target_ship.take_damage(1)
		EventBus.weapon_fired.emit(attacker_name, target_name, weapon.weapon_name, true, 1)
		return 1

	EventBus.weapon_fired.emit(attacker_name, target_name, weapon.weapon_name, false, 0)
	return 0
