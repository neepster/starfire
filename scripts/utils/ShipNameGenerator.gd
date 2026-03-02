## ShipNameGenerator.gd — Provides unique random names for ship instances.
## Supports per-faction lore name pools (faction_id from ShipData).
class_name ShipNameGenerator
extends RefCounted

static var _used: Array[String] = []
static var _class_counters: Dictionary = {}   # for get_import_name()
static var _arachnid_counters: Dictionary = {}  # ship_class → int

static var _faction_pools: Dictionary = {
	"TFN": {
		"prefix": "TFNS",
		"names": [
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
	},
	"Ophiuchi": {
		"prefix": "OADC",
		"names": [
			"Ophiuchus", "Serpens", "Aquila", "Cygnus", "Lyra",
			"Hercules", "Corona", "Bootes", "Arcturus", "Vega"
		]
	},
	"KON": {
		"prefix": "KON",
		"names": [
			"Kel", "Vrak", "Drax", "Zorn", "Keth",
			"Marg", "Thorn", "Rax", "Brek", "Gorath"
		]
	},
	"Gorm": {
		"prefix": "IGS",
		"names": [
			"Grath", "Dorm", "Kroth", "Bund", "Grel",
			"Drak", "Morg", "Tunk", "Grob", "Wurn"
		]
	},
	"Rigelian": {
		"prefix": "RPSA",
		"names": [
			"Rigel", "Bellatrix", "Mintaka", "Alnilam", "Alnitak",
			"Saiph", "Meissa", "Hatsya", "Tabit", "Orion"
		]
	},
	"Arachnid": {
		"prefix": "",
		"names": [
			"Avalanche", "Swarm", "Surge", "Flood", "Storm",
			"Tide", "Plague", "Rush", "Wave", "Crush", "Horde", "Deluge"
		]
	}
}


## Returns a unique ship name for the given lore faction_id.
## Arachnid ships get: "[SwarmWord] [ShipClass] #N" (e.g. "Avalanche SD #1").
## All others get: "[PREFIX] [Name]" (e.g. "TFNS Agincourt").
## Unknown faction_id falls back to TFN.
static func generate_for_faction(faction_id: String, ship_class: String = "") -> String:
	if faction_id == "Arachnid":
		var pool_entry: Dictionary = _faction_pools["Arachnid"]
		var names: Array = pool_entry.get("names", [])
		var available: Array[String] = []
		for n in names:
			if n not in _used:
				available.append(n)
		if available.is_empty():
			for n in names:
				if _used.has(n):
					_used.erase(n)
			for n in names:
				available.append(n)
		var word: String = available[randi() % available.size()]
		_used.append(word)
		var count: int = (_arachnid_counters.get(ship_class, 0) as int) + 1
		_arachnid_counters[ship_class] = count
		return "%s %s #%d" % [word, ship_class, count]

	var entry: Dictionary
	if _faction_pools.has(faction_id):
		entry = _faction_pools[faction_id]
	else:
		entry = _faction_pools["TFN"]
	var names: Array = entry.get("names", [])
	var prefix: String = entry.get("prefix", "")
	var available: Array[String] = []
	for n in names:
		if n not in _used:
			available.append(n)
	if available.is_empty():
		for n in names:
			if _used.has(n):
				_used.erase(n)
		for n in names:
			available.append(n)
	var chosen: String = available[randi() % available.size()]
	_used.append(chosen)
	if prefix.is_empty():
		return chosen
	return prefix + " " + chosen


## Returns a per-class counter name for imported ships (e.g. "SD #1", "SD #2").
## No faction prefix — the class code itself is the identifier.
static func get_import_name(ship_class: String) -> String:
	var count: int = (_class_counters.get(ship_class, 0) as int) + 1
	_class_counters[ship_class] = count
	return "%s #%d" % [ship_class, count]


## Reset all used-name pools and counters (call at battle start).
static func reset() -> void:
	_used.clear()
	_class_counters.clear()
	_arachnid_counters.clear()
