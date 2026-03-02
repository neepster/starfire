## CombatResolver.gd — Resolves weapon attacks using Starfire 3rd-edition tables.
##
## 28.01  Hit-Probability Table: roll d10 equal-or-under = hit.
## 28.02  Weapon Range & Damage Table: damage points per hit at each range.
##
## All energy beams (F, Fc, L, G…) share the Beam(any) hit-probability curve.
## Missiles use their own sprint or long-range hit curves.
## Damage varies by weapon type and range from 28.02.
class_name CombatResolver
extends RefCounted


# ── 28.01  Hit-Probability Tables (index = range in hexes) ───────────────────

## All energy beams: F/Fc/L/Lc/G/Gc — same hit curve, different damage tables.
const HIT_BEAM: Array[int] = [
	10, 10,  9,  9,  9,  8,  8,  8,  8,  7,  7,  7,  7,  7,  6,  6,
	 6,  5,  5,  5,  4,  4,  4,  3,  3,  2,  2,  1,  1,  1,  1,
]  # indices 0–30; beyond 30 → 1

## Sprint-mode missiles (R, Ra, Rb, Rc): fire-and-forget, close range.
const HIT_SPRINT: Array[int] = [9, 9, 9, 8, 8, 8, 7, 6, 5, 3, 1]
# indices 0–10; beyond → 0 (out of range)

## Long-range missiles (M, M2): seeking, minimum range 1 (can't fire at range 0).
const HIT_LONG: Array[int] = [0, 2, 3, 4, 7, 8, 8, 8, 8, 8, 8, 8, 8, 8, 7, 7, 7, 6, 6, 5, 5]
# indices 0–20; beyond → 0 (out of range)


# ── 28.02  Damage-per-Hit Tables (index = range in hexes) ────────────────────

const DMG_F: Array[int]  = [5, 4, 3, 3, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
# F / Fa / Fb  — max range 15 (index 15 = last valid, index 16+ = 0)

const DMG_FC: Array[int] = [8, 7, 6, 5, 4, 4, 4, 3, 3, 3, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1]
# Fc           — max range 20

const DMG_L: Array[int]  = [3, 3, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1]
# L / La / Lb  — max range 12; lasers ignore shields (not modelled in hit table)

const DMG_LC: Array[int] = [5, 5, 4, 4, 3, 3, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1]
# Lc           — max range 15 (approx. capital laser)

const DMG_G: Array[int]  = [7, 7, 7, 6, 6, 6]
# G / Ga / Gb  — Graser (Pg row), max range 5; ignores armor

const DMG_GC: Array[int] = [10, 10, 9, 9, 9, 8, 7, 6, 5]
# Gc           — Capital Graser (Pg2 row), max range 8; ignores armor


# ── Public API ────────────────────────────────────────────────────────────────

## Attempt an attack.  Returns the damage dealt (0 = miss or out of range).
static func resolve_attack(attacker: Node, target: Node, weapon: WeaponData) -> int:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return 0

	var attacker_ship := attacker as Ship
	var target_ship   := target  as Ship

	var attacker_name: String = attacker_ship.ship_data.ship_name \
			if attacker_ship and attacker_ship.ship_data else "?"
	var target_name: String   = target_ship.ship_data.ship_name \
			if target_ship   and target_ship.ship_data   else "?"

	var dist: int = HexGrid.offset_distance(
			attacker_ship.hex_position, target_ship.hex_position) \
			if attacker_ship and target_ship else 999

	# Derive type from weapon_name — works for old .tres files without weapon_type set.
	var wt := WeaponData.type_for_name(weapon.weapon_name)

	var hit_prob := _hit_probability(wt, dist)
	var dmg      := _damage_at_range(wt, dist)

	if hit_prob <= 0 or dmg <= 0:
		return 0  # out of range for this weapon

	var roll := randi_range(1, 10)
	if roll <= hit_prob:
		target_ship.take_damage(dmg)
		EventBus.weapon_fired.emit(
				attacker_name, target_name, weapon.weapon_name, true, dmg, roll, hit_prob)
		return dmg

	EventBus.weapon_fired.emit(
			attacker_name, target_name, weapon.weapon_name, false, 0, roll, hit_prob)
	return 0


# ── Private helpers ───────────────────────────────────────────────────────────

static func _hit_probability(wt: WeaponData.WeaponType, dist: int) -> int:
	match wt:
		WeaponData.WeaponType.SPRINT_MISSILE, WeaponData.WeaponType.CAPITAL_SPRINT:
			return HIT_SPRINT[dist] if dist < HIT_SPRINT.size() else 0
		WeaponData.WeaponType.STD_MISSILE, WeaponData.WeaponType.CAPITAL_MISSILE:
			return HIT_LONG[dist] if dist < HIT_LONG.size() else 0
		_:  # all energy beams use the Beam(any) curve
			return HIT_BEAM[dist] if dist < HIT_BEAM.size() else 1


static func _damage_at_range(wt: WeaponData.WeaponType, dist: int) -> int:
	match wt:
		WeaponData.WeaponType.FORCE_BEAM:
			return DMG_F[dist] if dist < DMG_F.size() else 0
		WeaponData.WeaponType.CAPITAL_FORCE_BEAM:
			return DMG_FC[dist] if dist < DMG_FC.size() else 0
		WeaponData.WeaponType.LASER:
			return DMG_L[dist] if dist < DMG_L.size() else 0
		WeaponData.WeaponType.CAPITAL_LASER:
			return DMG_LC[dist] if dist < DMG_LC.size() else 0
		WeaponData.WeaponType.SPRINT_MISSILE:
			return 1 if dist < HIT_SPRINT.size() and HIT_SPRINT[dist] > 0 else 0
		WeaponData.WeaponType.CAPITAL_SPRINT:
			return 2 if dist < HIT_SPRINT.size() and HIT_SPRINT[dist] > 0 else 0
		WeaponData.WeaponType.STD_MISSILE:
			return 1 if dist < HIT_LONG.size() and HIT_LONG[dist] > 0 else 0
		WeaponData.WeaponType.CAPITAL_MISSILE:
			return 2 if dist < HIT_LONG.size() and HIT_LONG[dist] > 0 else 0
		WeaponData.WeaponType.GRASER:
			return DMG_G[dist] if dist < DMG_G.size() else 0
		WeaponData.WeaponType.CAPITAL_GRASER:
			return DMG_GC[dist] if dist < DMG_GC.size() else 0
		_:
			return DMG_F[dist] if dist < DMG_F.size() else 0
