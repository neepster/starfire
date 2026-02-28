## ShipClassParser.gd — Parses 3rd-edition Starfire notation into a ShipData resource.
## Best-effort: unknown codes are skipped gracefully.
##
## Supported input format example:
##   CROMWELL-class SD AM(2) 26 XO 130 HS TL 9[3] Sx13Ax14ZH(BbS)x2Q(IIII)RcFc(IIII)DM2 [5/2]
##
## Extraction rules:
##   - "NAME-class TYPE" → ship_name = Name, ship_class = TYPE
##   - "[speed/accel]" at end → drive_rating = speed
##   - System box string after "TL N[N]" header token
##   - xN = repeat preceding token N times; (...) = expand group inline
class_name ShipClassParser
extends RefCounted

## Parse a Starfire ship class string and return a populated ShipData.
static func parse(input: String) -> ShipData:
	var data := ShipData.new()
	_extract_header(input, data)
	_extract_drive(input, data)
	_extract_boxes(input, data)
	data.sprite_path = _guess_sprite(data.ship_class)
	return data


## Infer sprite path from class code (e.g. "DD" → "dd_blue.png").
## Falls back to placeholder if no matching image exists.
static func _guess_sprite(ship_class: String) -> String:
	var code := ship_class.to_lower()
	var path := "res://assets/ship_images/%s_blue.png" % code
	if ResourceLoader.exists(path):
		return path
	return "res://assets/ships/placeholder.png"


static func _extract_header(s: String, data: ShipData) -> void:
	var rx := RegEx.new()
	rx.compile("(\\w+)-class\\s+(\\w+)")
	var m := rx.search(s)
	if m:
		data.ship_name = m.get_string(1).capitalize()
		data.ship_class = m.get_string(2)
		return
	# Fallback: first two whitespace-separated tokens
	var parts := s.split(" ", false)
	if parts.size() >= 2:
		data.ship_name = parts[0].capitalize()
		data.ship_class = parts[1]
	elif parts.size() == 1:
		data.ship_class = parts[0]
		data.ship_name = parts[0].capitalize()


static func _extract_drive(s: String, data: ShipData) -> void:
	# Match "[N/N]" — first number is speed (drive rating)
	var rx := RegEx.new()
	rx.compile("\\[(\\d+)/(\\d+)\\]")
	var m := rx.search(s)
	if m:
		data.drive_rating = m.get_string(1).to_int()
	else:
		data.drive_rating = 4


static func _extract_boxes(s: String, data: ShipData) -> void:
	# Locate system box string: after "TL N[N]" header if present
	var box_string := s
	var tl_rx := RegEx.new()
	tl_rx.compile("TL\\s+\\d+\\[\\d+\\]\\s*")
	var tm := tl_rx.search(s)
	if tm:
		box_string = s.substr(tm.get_end())

	# Strip trailing "[N/N]" speed token
	var tail_rx := RegEx.new()
	tail_rx.compile("\\s*\\[\\d+/\\d+\\]\\s*$")
	box_string = tail_rx.sub(box_string, "")

	# Tokenize the box string
	var tokens: Array[String] = _tokenize(box_string)

	# Map tokens → internal box codes; build system_boxes + weapons arrays
	var boxes: Array[String] = []
	var weapon_index := 0
	var weapons: Array[Resource] = []
	for tok in tokens:
		var box: String = _map_token(tok, weapon_index, weapons)
		if box != "":
			boxes.append(box)
			if box.begins_with("W"):
				weapon_index += 1

	data.system_boxes = PackedStringArray(boxes)
	data.weapons = weapons

	# Derive hull_points from H-box count
	var h_count := 0
	for b in boxes:
		if b == "H":
			h_count += 1
	data.hull_points = maxi(h_count, 1)


## Tokenize a system-box string, expanding (group)xN and AxN multipliers.
static func _tokenize(s: String) -> Array[String]:
	var result: Array[String] = []
	var pos := 0
	while pos < s.length():
		var c: String = s[pos]

		if c == "(":
			# Find matching close paren
			var end_pos: int = s.find(")", pos)
			if end_pos == -1:
				end_pos = s.length() - 1
			var group: String = s.substr(pos + 1, end_pos - pos - 1)
			var group_toks: Array[String] = _tokenize(group)
			pos = end_pos + 1
			# Check for xN multiplier right after ")"
			var mul: int = _consume_multiplier(s, pos)
			if mul > 1:
				pos += 1 + str(mul).length()  # skip 'x' + digits
			for _i in mul:
				result.append_array(group_toks)

		elif _is_upper(c):
			# Start of a token: Capital letter + optional lowercase + optional digit suffix
			var tok := c
			pos += 1
			while pos < s.length() and _is_lower(s[pos]):
				# Stop if we see 'x' followed by a digit — that is a multiplier, not part of the token name
				if s[pos] == "x" and pos + 1 < s.length() and s[pos + 1].is_valid_int():
					break
				tok += s[pos]
				pos += 1
			while pos < s.length() and s[pos].is_valid_int():
				tok += s[pos]
				pos += 1
			# Check for xN multiplier
			var mul: int = _consume_multiplier(s, pos)
			if mul > 1:
				pos += 1 + str(mul).length()
			for _i in mul:
				result.append(tok)

		else:
			pos += 1

	return result


static func _consume_multiplier(s: String, pos: int) -> int:
	if pos >= s.length() or s[pos] != "x":
		return 1
	var num_start: int = pos + 1
	var num_end: int = num_start
	while num_end < s.length() and s[num_end].is_valid_int():
		num_end += 1
	if num_end == num_start:
		return 1
	return s.substr(num_start, num_end - num_start).to_int()


static func _is_upper(c: String) -> bool:
	return c >= "A" and c <= "Z"


static func _is_lower(c: String) -> bool:
	return c >= "a" and c <= "z"


## Map a single Starfire token to an internal box code.
## Returns "" to skip unknown/non-structural tokens.
static func _map_token(tok: String, w_idx: int, weapons: Array[Resource]) -> String:
	# Hull and internal structure
	if tok == "H" or tok == "I":
		return "H"
	# Armor
	if tok == "A":
		return "A"
	# Shields — distinct from armor so they display correctly
	if tok == "S":
		return "S"
	# Drive systems
	if tok == "D" or tok == "Di" or tok == "Q":
		return "D"
	# Weapon systems (any R/F/L/M/G variant)
	var weapon_codes := ["R","Ra","Rb","Rc","F","Fa","Fb","Fc","L","La","Lb","Lc","Lh","M","M2","Mg","G","Ga","Gb","Gc"]
	if tok in weapon_codes:
		var wd := WeaponData.new()
		wd.weapon_name = tok
		wd.damage = 3
		wd.range_hexes = 6
		wd.arc = 0
		wd.shots_per_turn = 1
		weapons.append(wd)
		return "W%d" % w_idx
	# Skip: Z, CIC, AM, XO, HS, Xr, Bb, and other electronics/command tokens
	return ""
