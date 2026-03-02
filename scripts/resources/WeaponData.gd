## WeaponData.gd — Resource definition for a weapon system.
## weapon_type drives combat table lookups; damage/range_hexes are display hints
## (set correctly by ShipClassParser; may be stale in old .tres files).
class_name WeaponData
extends Resource

enum ArcType { FORWARD, FORWARD_WIDE, BROADSIDE_LEFT, BROADSIDE_RIGHT, AFT, ALL_ROUND }

enum WeaponType {
	FORCE_BEAM,          ## F, Fa, Fb  — medium beam, range 15
	CAPITAL_FORCE_BEAM,  ## Fc         — heavy beam, range 20
	LASER,               ## L, La, Lb  — short range, ignores shields, range 12
	CAPITAL_LASER,       ## Lc         — capital laser, range 15
	SPRINT_MISSILE,      ## R, Ra, Rb  — sprint-mode missile, range 10
	CAPITAL_SPRINT,      ## Rc         — capital sprint missile, range 10
	STD_MISSILE,         ## M          — long-range missile, range 20
	CAPITAL_MISSILE,     ## M2         — capital long-range missile, range 20
	GRASER,              ## G, Ga, Gb  — gamma-ray laser, ignores armor, range 5
	CAPITAL_GRASER,      ## Gc         — capital graser, range 8
}

@export var weapon_name: String = "F"
@export var weapon_type: WeaponType = WeaponType.FORCE_BEAM
@export var damage: int = 5          ## max damage at range 0 — for display
@export var range_hexes: int = 15    ## max effective range — for display
@export var arc: ArcType = ArcType.ALL_ROUND
@export var shots_per_turn: int = 1


## Derive WeaponType from a notation token (e.g. "Fc", "R").
## Works for old .tres files that predate the weapon_type field.
static func type_for_name(n: String) -> WeaponType:
	match n:
		"F", "Fa", "Fb":  return WeaponType.FORCE_BEAM
		"Fc":              return WeaponType.CAPITAL_FORCE_BEAM
		"L", "La", "Lb":  return WeaponType.LASER
		"Lc":              return WeaponType.CAPITAL_LASER
		"R", "Ra", "Rb":  return WeaponType.SPRINT_MISSILE
		"Rc":              return WeaponType.CAPITAL_SPRINT
		"M":               return WeaponType.STD_MISSILE
		"M2":              return WeaponType.CAPITAL_MISSILE
		"G", "Ga", "Gb":  return WeaponType.GRASER
		"Gc":              return WeaponType.CAPITAL_GRASER
		_:                 return WeaponType.FORCE_BEAM


## Max effective range for a weapon name token.
static func max_range_for_name(n: String) -> int:
	match type_for_name(n):
		WeaponType.FORCE_BEAM:          return 15
		WeaponType.CAPITAL_FORCE_BEAM:  return 20
		WeaponType.LASER:               return 12
		WeaponType.CAPITAL_LASER:       return 15
		WeaponType.SPRINT_MISSILE:      return 10
		WeaponType.CAPITAL_SPRINT:      return 10
		WeaponType.STD_MISSILE:         return 20
		WeaponType.CAPITAL_MISSILE:     return 20
		WeaponType.GRASER:              return 5
		WeaponType.CAPITAL_GRASER:      return 8
		_:                              return 15


## Max damage per hit at range 0 (for display in info panels).
static func max_damage_for_name(n: String) -> int:
	match type_for_name(n):
		WeaponType.FORCE_BEAM:          return 5
		WeaponType.CAPITAL_FORCE_BEAM:  return 8
		WeaponType.LASER:               return 3
		WeaponType.CAPITAL_LASER:       return 5
		WeaponType.SPRINT_MISSILE:      return 1
		WeaponType.CAPITAL_SPRINT:      return 2
		WeaponType.STD_MISSILE:         return 1
		WeaponType.CAPITAL_MISSILE:     return 2
		WeaponType.GRASER:              return 7
		WeaponType.CAPITAL_GRASER:      return 10
		_:                              return 3
