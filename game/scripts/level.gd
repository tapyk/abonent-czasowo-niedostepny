extends Node2D
## Builds one top-down map from res://maps/<name>.txt at runtime.

const T := Art.TILE

const ENEMY := preload("res://scenes/enemy.tscn")
const BUSH := preload("res://scenes/bush.tscn")
const ANTENNA := preload("res://scenes/antenna.tscn")
const PICKUP := preload("res://scenes/pickup.tscn")
const PLANE := preload("res://scenes/plane_exit.tscn")
const TRIGGER := preload("res://scripts/story_trigger.gd")
const WARP := preload("res://scripts/warp.gd")
const DECOR := preload("res://scripts/decor.gd")
const THICKET := preload("res://scripts/thicket.gd")
const HORDE := preload("res://scripts/horde.gd")
const NPC := preload("res://scripts/npc.gd")
const ZIPLINE := preload("res://scripts/zipline.gd")
const BOAT := preload("res://scripts/boat.gd")
const GRASS_TUFTS := preload("res://scripts/grass_tufts.gd")
const CLUE_NOTE := preload("res://scripts/clue_note.gd")

const GROUND := {".": "grass", ",": "grass2", ":": "dirt", "=": "road", "_": "sidewalk",
	"f": "field", "r": "runway", "o": "floor", "d": "sand", "j": "pier", "g": "plaza",
	"n": "plantation"}
const SOLID := {"#": "wall", "R": "roof", "T": "tree", "F": "fence", "w": "iwall",
	"k": "kitchen", "e": "bed", "t": "table", "v": "plant", "|": "garage", "y": "palm", "x": "rock",
	"Q": "solid"}
## Low obstacles: stop walkers (physics layer 6, value 32) but not bullets or sight.
const LOW := {"~": "water", "^": "chasm"}
## Keys that get a collision box.
const COLLIDE := ["wall", "roof", "tree", "fence", "iwall", "kitchen", "bed", "table", "plant", "garage",
	"palm", "rock", "solid"]
const COLLIDE_LOW := ["water", "chasm"]
const LOW_LAYER := 32

var map_name := ""
var rows: PackedStringArray
var width := 0
var height := 0
var header := {}
var darkness := Color(0.25, 0.25, 0.35)
var player_start := Vector2i(-1, -1)
var ground: TileMapLayer
var walls: TileMapLayer
var above: TileMapLayer
var entities: Node2D

var _keys: Array[String] = []          # atlas column -> tile key
var _cells := {}                        # layer -> Array of [Vector2i, key]
var _pine: Texture2D = PropArt.pine()   # tree tiles become pines when the drawing exists
var _pines: Array[Vector2i] = []


func build(name: String) -> void:
	map_name = name
	# Maps are plain .txt, not resources: exports only ship them because the
	# presets list "maps/*.txt" in include_filter (export_presets.cfg).
	var path := "res://maps/%s.txt" % name
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open map %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return
	_parse(f.get_as_text())
	if header.has("dark"):
		var c: PackedStringArray = str(header["dark"]).split(",")
		darkness = Color(float(c[0]), float(c[1]), float(c[2]))
	_cells = {"ground": [], "walls": [], "above": []}
	var spawns: Array = []
	for y in height:
		for x in width:
			var ch := cell(x, y)
			if GROUND.has(ch):
				_add("ground", x, y, GROUND[ch])
			elif LOW.has(ch):
				_add("ground", x, y, _low_variant(ch, x, y))
			elif ch == "T" and _pine != null:
				# pine sprite (y-sorted with the characters) over an invisible collision tile
				_add("ground", x, y, _ground_under(x, y))
				_add("walls", x, y, "solid")
				_pines.append(Vector2i(x, y))
			elif SOLID.has(ch):
				_add("ground", x, y, _ground_under(x, y))
				_add("walls", x, y, _solid_variant(ch, x, y))
				if ch == "T" and y > 0:
					_add("above", x, y - 1, "canopy")
			else:
				var warp := _warp_def(ch)
				if not warp.is_empty() and _between_walls(x, y) and cell(x - 1, y) == "Q":
					_add("ground", x, y, _ground_under(x, y))  # the building picture has the door
				elif not warp.is_empty() and _between_walls(x, y):
					_add("ground", x, y, _ground_under(x, y))
					_add("walls", x, y, "door")
				elif not warp.is_empty() and map_name == "home":
					_add("ground", x, y, "floor")
					_add("walls", x, y, "stairs")
				else:
					_add("ground", x, y, _ground_under(x, y))
				spawns.append([ch, x, y])

	var ts := _make_tileset()
	ground = _layer("Ground", ts, true, -10)  # water / chasm collide
	walls = _layer("Walls", ts, true, -9)
	above = _layer("Above", ts, false, 20)
	entities = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	add_child(entities)
	move_child(above, -1)
	for layer_name in _cells:
		var layer: TileMapLayer = {"ground": ground, "walls": walls, "above": above}[layer_name]
		for e in _cells[layer_name]:
			layer.set_cell(e[0], 0, Vector2i(_keys.find(e[1]), 0))
	_place_buildings()
	_place_pines()
	_place_grass()
	for s in spawns:
		_spawn(s[0], s[1], s[2])
	if Game.is_hard():
		_spawn_hard_clues()
	if Game.coop and map_name in ["world", "roof", "szczelina", "trybunal"]:
		_spawn_coop_extra_enemies(spawns)


func is_walkable_cell(x: int, y: int) -> bool:
	if x < 1 or y < 1 or x >= width - 1 or y >= height - 1:
		return false
	var ch := cell(x, y)
	if not (GROUND.has(ch) or ch in ["P", "z", "Z", "a", "m", "b"]):
		return false
	for n in entities.get_children():
		if n.get_meta("cell", Vector2i(-99, -99)) == Vector2i(x, y):
			if "target_map" in n or "npc_id" in n or "antenna_id" in n:
				return false
	return true


func nearest_walkable(start: Vector2i) -> Vector2i:
	for rad in range(0, 7):
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				var c := start + Vector2i(dx, dy)
				if is_walkable_cell(c.x, c.y):
					return c
	return Vector2i(-1, -1)


func _spawn_hard_clues() -> void:
	match map_name:
		"home":
			_add_clue_node(Vector2i(6, 4), "a1_floor", "a1", "Rachunek za mieszkanie",
				"Mieszkanie Johnny'ego: 4. piętro",
				"Rachunek za czynsz: lokal na 4. piętrze. Ktoś tu zgłaszał awarię zasięgu.", false)
		"roof":
			_add_clue_node(Vector2i(8, 2), "a1_freq", "a1", "Tabliczka przekaźnika",
				"Maszt A1: baza 850 MHz, odchyłka po wybuchu +15 MHz",
				"Tabliczka masztu: pasmo bazowe osiedla 850 MHz. Dopisek markerem: po wybuchu odchyłka +15 MHz. Ostatnie zgłoszenie: lokator z 4. piętra.", true)
		"stodola":
			_add_clue_node(Vector2i(2, 2), "a2_farmer", "a2", "Notatka Fasti Farmera",
				"Farmer: odwróć Z2, a przy czerwonej diodzie też Z4",
				"Zapiski Farmera: w masztach plantacji odwróć zworkę Z2. Jeśli przy panelu świeci czerwona dioda, odwróć też Z4.", false)
		"world":
			var a2 := _find_antenna_cell("a2")
			if a2.x >= 0:
				_add_clue_node(nearest_walkable(a2 + Vector2i(-4, -2)), "a2_base", "a2", "Schemat zworek plantacji",
					"Schemat zworek: Z1 GÓRA, Z2 DÓŁ, Z3 DÓŁ, Z4 GÓRA",
					"Schemat fabryczny: Z1 = GÓRA, Z2 = DÓŁ, Z3 = DÓŁ, Z4 = GÓRA. Obok panelu mruga czerwona dioda.", true)
				_add_clue_node(nearest_walkable(a2 + Vector2i(3, 1)), "a2_math", "a2", "Instrukcja sumy kontrolnej",
					"Lampka zielona: para o sumie 10, pomarańczowa: o różnicy 4",
					"Instrukcja: gdy świeci zielona lampka, złap parę o sumie 10. Gdy pomarańczowa, parę o różnicy 4.", false)
		"trybunal":
			var a3 := _find_antenna_cell("a3")
			if a3.x >= 0:
				_add_clue_node(nearest_walkable(a3 + Vector2i(-3, -3)), "a3_main", "a3", "Główny licznik i faza",
					"Licznik główny: razem 180 kW, faza zewnętrzna +3",
					"Główny licznik ogrodu: transformatory razem 180 kW. Faza zewnętrzna: +3.", true)
				_add_clue_node(nearest_walkable(a3 + Vector2i(-2, 3)), "a3_tr", "a3", "Tabliczki transformatorów",
					"Transformatory: T1 35 kW, T2 85 kW, T3 nieczytelna",
					"Tabliczki: T1 = 35 kW, T2 = 85 kW. Tabliczka T3 stopiona, nie da się odczytać.", true)


func _find_antenna_cell(aid: String) -> Vector2i:
	for n in entities.get_children():
		if "antenna_id" in n and n.antenna_id == aid:
			return n.get_meta("cell", to_cell(n.position))
	return Vector2i(-1, -1)


func _add_clue_node(c: Vector2i, cid: String, grp: String, prm: String, line: String, dlg: String, meter: bool) -> void:
	if c.x < 0:
		return
	var cn := CLUE_NOTE.new()
	cn.clue_id = cid
	cn.ant_group = grp
	cn.title_prompt = prm
	cn.note_line = line
	cn.dialog_text = dlg
	cn.is_meter = meter
	cn.position = center(c.x, c.y)
	entities.add_child(cn)


func _spawn_coop_extra_enemies(spawns: Array) -> void:
	var hard := Game.is_hard()
	var idx := 0
	for s in spawns:
		var ch: String = s[0]
		if ch != "z" and ch != "Z":
			continue
		idx += 1
		# Co-op Normal: +50% extra map mutants; Co-op Hard: +100% extra map mutants (more burnt!)
		if not hard and (idx % 2 == 1):
			continue
		var base_c := Vector2i(int(s[1]), int(s[2]))
		if player_start.x >= 0 and base_c.distance_to(player_start) < 5.0:
			continue
		var extra_key := "%s:coop_%d,%d" % [map_name, base_c.x, base_c.y]
		if Game.is_gone(extra_key):
			continue
		var sc := nearest_walkable(base_c + Vector2i(2 if idx % 2 == 0 else -2, 1 if idx % 3 == 0 else -1))
		if sc.x < 0 or (player_start.x >= 0 and sc.distance_to(player_start) < 4.5):
			continue
		var en := ENEMY.instantiate()
		en.burnt = (ch == "Z") or (hard and idx % 3 == 0)
		en.set_meta("cell", sc)
		en.set_meta("key", extra_key)
		en.position = feet(sc.x, sc.y)
		entities.add_child(en)


## Interactive grass tufts on plain grass cells (. and ,), drawn above the ground.
func _place_grass() -> void:
	if not TileArt.has_grass():
		return
	var cells: Array = []
	for y in height:
		for x in width:
			if cell(x, y) in [".", ","]:
				cells.append(Vector2i(x, y))
	if cells.is_empty():
		return
	var g := GRASS_TUFTS.new()
	g.name = "GrassTufts"
	g.z_index = -9  # above the ground, after the walls; building pictures (-8) cover it
	add_child(g)
	move_child(g, walls.get_index() + 1)
	g.setup(cells, hash(map_name))


## Building pictures from the `buildings` header (see the top of this file).
func _place_pines() -> void:
	for c in _pines:
		var h := hash(c)
		var s := Sprite2D.new()
		s.texture = _pine
		s.centered = false
		var k := 0.8 + float(h % 5) * 0.05
		s.scale = Vector2(k, k)
		s.flip_h = (h >> 3) % 2 == 0
		s.offset = Vector2(-_pine.get_width() / 2.0, -_pine.get_height() + 2.0)
		s.position = feet(c.x, c.y) + Vector2(float((h >> 5) % 5) - 2.0, 0.0)
		entities.add_child(s)


func _place_buildings() -> void:
	if not header.has("buildings"):
		return
	for b in str(header["buildings"]).split(";"):
		var p: PackedStringArray = b.strip_edges().split(":")
		var tex := Art.tex("res://assets/sprites/buildings/%s.png" % p[0])
		if tex == null:
			continue
		var s := Sprite2D.new()
		s.name = "Building_" + p[0]
		s.texture = tex
		s.centered = false
		s.position = Vector2(int(p[1]) * T, int(p[2]) * T)
		s.z_index = -8
		add_child(s)


func bounds() -> Rect2:
	return Rect2(0, 0, width * T, height * T)


func cell(x: int, y: int) -> String:
	if y < 0 or y >= height or x < 0:
		return ""
	var r := rows[y]
	return r[x] if x < r.length() else ""


## Feet position of something standing in cell (x, y).
func feet(x: int, y: int) -> Vector2:
	return Vector2(x * T + T / 2.0, y * T + T - 3)


func center(x: int, y: int) -> Vector2:
	return Vector2(x * T + T / 2.0, y * T + T / 2.0)


func to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / T), floori(p.y / T))


func key_for(x: int, y: int) -> String:
	return "%s:%d,%d" % [map_name, x, y]


# --- parsing ---------------------------------------------------------------

func _parse(text: String) -> void:
	var lines := text.replace("\r", "").split("\n")
	var i := 0
	while i < lines.size() and lines[i] != "---":
		var l := lines[i].strip_edges()
		if "=" in l:
			var kv := l.split("=", true, 1)
			header[kv[0]] = kv[1]
		i += 1
	rows = PackedStringArray()
	for j in range(i + 1, lines.size()):
		if lines[j] != "":
			rows.append(lines[j])
	height = rows.size()
	for r in rows:
		width = maxi(width, r.length())


func _warp_def(ch: String) -> Dictionary:
	if not ch.is_valid_int() or not header.has(ch):
		return {}
	var p: PackedStringArray = str(header[ch]).split(":")
	if p[0] != "warp":
		return {}
	var d := {"map": p[1], "cell": Vector2i(int(p[2]), int(p[3])), "need": ""}
	if p[1] == "":
		return {}
	if p.size() > 4 and p[4].begins_with("need="):
		d["need"] = p[4].trim_prefix("need=")
	return d


func _between_walls(x: int, y: int) -> bool:
	return SOLID.has(cell(x - 1, y)) and SOLID.has(cell(x + 1, y))


func _default_ground() -> String:
	return GROUND.get(header.get("ground", "."), "grass")


## Entities and solid tiles sit on the ground of a neighbouring cell.
func _ground_under(x: int, y: int) -> String:
	for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := cell(x + d.x, y + d.y)
		if GROUND.has(n):
			return GROUND[n]
	return _default_ground()


## Water/chasm edges: a lighter rim where they touch land above.
func _low_variant(ch: String, x: int, y: int) -> String:
	if not LOW.has(cell(x, y - 1)) and cell(x, y - 1) != "":
		return LOW[ch] + "_top"
	if ch == "^" and not LOW.has(cell(x - 1, y)) and cell(x - 1, y) != "":
		return "chasm_l"
	if ch == "^" and not LOW.has(cell(x + 1, y)) and cell(x + 1, y) != "":
		return "chasm_r"
	return LOW[ch]


## Neighbour-aware variants (edges/corners) so real tilesets can be wired later.
func _solid_variant(ch: String, x: int, y: int) -> String:
	var same := func(dx: int, dy: int) -> bool: return cell(x + dx, y + dy) == ch
	match ch:
		"R":
			var v := "t" if not same.call(0, -1) else ("b" if not same.call(0, 1) else "")
			var h := "l" if not same.call(-1, 0) else ("r" if not same.call(1, 0) else "")
			return "roof_" + (v + h if v + h != "" else "c")
		"#":
			var left: bool = not (same.call(-1, 0) or cell(x - 1, y).is_valid_int())
			var right: bool = not (same.call(1, 0) or cell(x + 1, y).is_valid_int())
			return "wall_l" if left else ("wall_r" if right else "wall")
		"F":
			return "fence_v" if (same.call(0, -1) or same.call(0, 1)) and not (same.call(-1, 0) or same.call(1, 0)) else "fence"
		"w":
			return "iwall" if SOLID.has(cell(x, y + 1)) or y + 1 >= height else "iwall_face"
	return SOLID[ch]


func _add(layer: String, x: int, y: int, key: String) -> void:
	# Grass from the team's 32x32 tile (trawa.png): each cell takes its quarter.
	if layer == "ground" and key in ["grass", "grass2"] and TileArt.has_grass():
		key = "grass_q%d" % (posmod(x, 2) + posmod(y, 2) * 2)
	if not _keys.has(key):
		_keys.append(key)
	_cells[layer].append([Vector2i(x, y), key])


func _layer(n: String, ts: TileSet, collide: bool, z: int) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.name = n
	l.tile_set = ts
	l.collision_enabled = collide
	l.z_index = z
	add_child(l)
	return l


# --- entities ----------------------------------------------------------------

func _spawn(c: String, x: int, y: int) -> void:
	var node: Node2D = null
	var gone := Game.is_gone(key_for(x, y))
	var def: PackedStringArray = str(header.get(c, "")).split(":") if c.is_valid_int() else PackedStringArray()
	match c:
		"P":
			player_start = Vector2i(x, y)
		"z", "Z":
			if not gone:
				node = ENEMY.instantiate()
				node.burnt = c == "Z"
		"b":
			node = BUSH.instantiate()
		"B":
			if not gone:
				node = THICKET.new()
		"H":
			if not Game.is_antenna_off("a1"):
				node = HORDE.new()
		"A":
			node = ANTENNA.instantiate()
			node.antenna_id = "a1"
			node.hackable = map_name == "roof"
			node.need = "cable"
		"a", "m", "p", "s", "C":
			if not gone or c == "C":
				node = PICKUP.instantiate()
				node.kind = {"a": "ammo", "m": "medkit", "p": "pistol", "s": "sekator", "C": "cable"}[c]
		"X":
			node = PLANE.instantiate()
		"c":
			node = DECOR.new()
			node.kind = "car"
		_:
			if not def.is_empty() and def[0] == "npc":
				node = NPC.new()
				node.npc_id = def[1]
			elif not def.is_empty() and def[0] == "antenna":
				node = ANTENNA.instantiate()
				node.antenna_id = def[1]
				node.hackable = true
				node.minigame = def[2]
				node.need = "kable"
				c = "A"
			elif not def.is_empty() and def[0] == "horde":
				if not Game.horde_gone(def[1]):
					node = HORDE.new()
					node.antenna_id = def[1]
			elif not def.is_empty() and def[0] == "zip":
				node = ZIPLINE.new()
				node.end_pos = feet(int(def[1]), int(def[2]))
				c = "A"
			elif not def.is_empty() and def[0] == "boat":
				node = BOAT.new()
				node.target_map = def[1]
				node.target_cell = Vector2i(int(def[2]), int(def[3]))
				c = "A"
			elif c.is_valid_int() and header.has(c):
				var w := _warp_def(c)
				if w.is_empty():
					node = TRIGGER.new()
					node.trigger_id = str(header[c]).split(":")[1]
				else:
					node = WARP.new()
					node.target_map = w["map"]
					node.target_cell = w["cell"]
					node.need = w["need"]
	if node == null:
		return
	node.set_meta("cell", Vector2i(x, y))
	node.set_meta("key", key_for(x, y))
	# Characters and tall props stand on their feet; areas sit in the cell centre.
	node.position = feet(x, y) if (node is CharacterBody2D or node is StaticBody2D and node.has_method("talk") 		or c in ["A", "X", "c", "C"]) else center(x, y)
	entities.add_child(node)


# --- TileSet -----------------------------------------------------------------

func _make_tileset() -> TileSet:
	var atlas := Image.create_empty(T * _keys.size(), T, false, Image.FORMAT_RGBA8)
	for i in _keys.size():
		atlas.blit_rect(_tile_image(_keys[i]), Rect2i(0, 0, T, T), Vector2i(i * T, 0))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(1, LOW_LAYER)
	ts.set_physics_layer_collision_mask(1, 0)
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(atlas)
	src.texture_region_size = Vector2i(T, T)
	ts.add_source(src, 0)
	var h := T / 2.0
	for i in _keys.size():
		var coord := Vector2i(i, 0)
		src.create_tile(coord)
		var base: String = _keys[i].split("_")[0]
		var square := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
		if base in COLLIDE:
			var td := src.get_tile_data(coord, 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, square)
		elif base in COLLIDE_LOW:
			var td := src.get_tile_data(coord, 0)
			td.add_collision_polygon(1)
			td.set_collision_polygon_points(1, 0, square)
	return ts


func _tile_image(key: String) -> Image:
	if key == "solid":
		return Image.create_empty(T, T, false, Image.FORMAT_RGBA8)
	var t: Texture2D = TileArt.get_tile(key)
	if t:
		var src_img := t.get_image()
		if src_img.is_compressed():
			src_img.decompress()
		src_img.convert(Image.FORMAT_RGBA8)
		if src_img.get_size() != Vector2i(T, T):
			src_img.resize(T, T, Image.INTERPOLATE_NEAREST)
		return src_img
	return TileArt.placeholder(key)
