## EventBus.gd — Global signal bus for decoupled communication.
## All cross-system events are emitted and received through here.
extends Node

# Ship interaction signals
signal ship_selected(ship: Node)
signal ship_deselected()
signal ship_moved(ship: Node, from_hex: Vector2i, to_hex: Vector2i)
signal ship_destroyed(ship: Node)

# Hex map signals
signal hex_clicked(hex_coord: Vector2i)
signal hex_hovered(hex_coord: Vector2i)

# Combat signals
signal weapon_fired(attacker_name: String, target_name: String, weapon_name: String, hit: bool, damage: int, roll: int, roll_needed: int)

# Game flow signals
signal turn_phase_changed(phase: int)   # TurnManager.Phase enum value
signal battle_ended(winner: String)     # "human", "ai", or "draw"
signal scenario_selected(scenario: Resource)

# Ship import signals
signal import_ship_requested()
signal ship_import_confirmed(data: ShipData, faction: String)

# Fighter launch/recover signals
signal launch_fighters_requested(carrier: Node)
signal recover_fighters_requested(group: Node)
signal fighter_group_launched(carrier: Node, group: Node)
signal fighter_group_recovered(carrier: Node, group: Node)
