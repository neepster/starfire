## WeaponData.gd — Resource definition for a weapon system.
class_name WeaponData
extends Resource

enum ArcType { FORWARD, FORWARD_WIDE, BROADSIDE_LEFT, BROADSIDE_RIGHT, AFT, ALL_ROUND }

@export var weapon_name: String = "Laser"
@export var damage: int = 1
@export var range_hexes: int = 6
@export var arc: ArcType = ArcType.FORWARD
@export var shots_per_turn: int = 1
