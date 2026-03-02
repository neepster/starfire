## ShipData.gd — Resource definition for a ship class's stats.
## Create .tres instances of this for each ship type (DD, CA, etc.).
class_name ShipData
extends Resource

@export var ship_name: String = "Unknown Ship"
@export var ship_class: String = "DD"          # e.g. "DD", "CA", "BB"
@export var hull_points: int = 10              # total hull boxes
@export var drive_rating: int = 4             # max hexes moved per turn
@export var weapons: Array[Resource] = []      # Array of WeaponData
@export var sprite_path: String = "res://assets/ships/placeholder.png"
@export var description: String = ""          # flavour text for info panel
@export var faction_id: String = "TFN"        # lore faction: TFN/Ophiuchi/KON/Gorm/Rigelian/Arachnid
@export var system_boxes: PackedStringArray = []  # Ordered Starfire system boxes: "H","A","D","W0","W1"…
