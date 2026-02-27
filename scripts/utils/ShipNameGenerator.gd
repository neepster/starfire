## ShipNameGenerator.gd — Provides unique random names for ship instances.
class_name ShipNameGenerator
extends RefCounted

static var _used: Array[String] = []
static var _class_counters: Dictionary = {}  # ship_class → int, for imported ships

static var _pool: Array[String] = [
	"Agincourt", "Trafalgar", "Jutland", "Midway", "Coral Sea",
	"Enterprise", "Intrepid", "Hornet", "Lexington", "Saratoga",
	"Ranger", "Wasp", "Essex", "Valiant", "Warspite", "Renown",
	"Repulse", "Hood", "Dreadnought", "Invincible", "Inflexible",
	"Sheffield", "Coventry", "Ardent", "Antelope", "Brilliant",
	"Cromwell", "Marlborough", "Wellington", "Drake", "Hawke",
	"Bismarck", "Yamato", "Tirpitz", "Scharnhorst", "Gneisenau",
	"Indomitable", "Illustrious", "Formidable", "Victorious",
	"Devastation", "Thunderer", "Devastator", "Implacable",
	"Courageous", "Glorious", "Furious", "Hermes", "Ark Royal",
	"Vanguard", "Lion", "Tiger", "Conqueror", "Ajax",
	"Achilles", "Exeter", "Cumberland", "Dorsetshire", "Norfolk"
]


## Returns a unique ship name. Prefix "HMS" for human, "ISS" for AI.
static func generate(faction: String) -> String:
	var available: Array[String] = []
	for n in _pool:
		if n not in _used:
			available.append(n)

	if available.is_empty():
		_used.clear()
		available = _pool.duplicate()

	var chosen: String = available[randi() % available.size()]
	_used.append(chosen)

	var prefix := "HMS " if faction == "human" else "ISS "
	return prefix + chosen


## Returns a per-class counter name for imported ships (e.g. "SD #1", "SD #2").
## No HMS/ISS prefix — the class code itself is the identifier.
static func get_import_name(ship_class: String) -> String:
	var count: int = _class_counters.get(ship_class, 0) + 1
	_class_counters[ship_class] = count
	return "%s #%d" % [ship_class, count]


## Reset the used list and class counters (call at battle start).
static func reset() -> void:
	_used.clear()
	_class_counters.clear()
