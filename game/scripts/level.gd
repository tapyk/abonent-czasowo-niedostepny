extends Node2D
## Builds the level from an ASCII map (one char = one tile) at runtime.

const T := Art.TILE

@export_file("*.txt") var map_path := "res://maps/level1.txt"

const ENEMY := preload("res://scenes/enemy.tscn")
const BUSH := preload("res://scenes/bush.tscn")
const ANTENNA := preload("res://scenes/antenna.tscn")
const PICKUP := preload("res://scenes/pickup.tscn")
const PLANE := preload("res://scenes/plane_exit.tscn")
const TRIGGER := preload("res://scripts/story_trigger.gd")
const DECOR := preload("res://scripts/decor.gd")

var rows: PackedStringArray
var width := 0
var height := 0
var player_start := Vector2.ZERO
var back: TileMapLayer
var terrain: TileMapLayer
var entities: Node2D

## Tile keys -> atlas column in the generated atlas.
const TILE_KEYS := ["solid_top", "solid", "ground_top", "ground", "oneway", "wall_bg", "window_bg", "pole_bg", "wall_side"]


func build() -> void:
	var f := FileAccess.open(map_path, FileAccess.READ)
	rows = f.get_as_text().replace("\r", "").strip_edges(false, true).split("\n")
	height = rows.size()
	for r in rows:
		width = maxi(width, r.length())

	var tileset := _make_tileset()
	back = TileMapLayer.new()
	back.name = "Back"
	back.tile_set = tileset
	back.collision_enabled = false
	back.modulate = Color(0.55, 0.55, 0.62)
	add_child(back)
	terrain = TileMapLayer.new()
	terrain.name = "Terrain"
	terrain.tile_set = tileset
	add_child(terrain)
	entities = Node2D.new()
	entities.name = "Entities"
	add_child(entities)

	for y in height:
		for x in width:
			_place(x, y, _cell(x, y))


func bounds() -> Rect2:
	return Rect2(0, 0, width * T, height * T)


func _cell(x: int, y: int) -> String:
	if y < 0 or y >= height or x < 0:
		return "#"
	var r := rows[y]
	return r[x] if x < r.length() else "."


func _is_solid(x: int, y: int) -> bool:
	return _cell(x, y) == "#"


func _place(x: int, y: int, c: String) -> void:
	var cell := Vector2i(x, y)
	match c:
		"#":
			terrain.set_cell(cell, 0, Vector2i(_solid_key(x, y), 0))
		"-":
			terrain.set_cell(cell, 0, Vector2i(TILE_KEYS.find("oneway"), 0))
			_place_bg(x, y)
		":":
			back.set_cell(cell, 0, Vector2i(TILE_KEYS.find("wall_bg"), 0))
		"w":
			back.set_cell(cell, 0, Vector2i(TILE_KEYS.find("window_bg"), 0))
		"|":
			back.set_cell(cell, 0, Vector2i(TILE_KEYS.find("pole_bg"), 0))
		".":
			pass
		_:
			_place_bg(x, y)
			_spawn(c, x, y)


## Entity cells inherit the background of their left neighbour.
func _place_bg(x: int, y: int) -> void:
	for dx in [-1, 1, -2, 2]:
		var n := _cell(x + dx, y)
		if n in [":", "w"]:
			back.set_cell(Vector2i(x, y), 0, Vector2i(TILE_KEYS.find("wall_bg"), 0))
			return


func _solid_key(x: int, y: int) -> int:
	var top_open := not _is_solid(x, y - 1)
	if y >= _ground_row():
		return TILE_KEYS.find("ground_top" if top_open else "ground")
	if top_open:
		return TILE_KEYS.find("solid_top")
	var side_open := not _is_solid(x - 1, y) or not _is_solid(x + 1, y)
	return TILE_KEYS.find("wall_side" if side_open else "solid")


var _ground_cache := -1
func _ground_row() -> int:
	if _ground_cache < 0:
		_ground_cache = height
		for y in range(height - 1, -1, -1):
			var full := true
			for x in width:
				if _cell(x, y) != "#":
					full = false
					break
			if not full:
				_ground_cache = y + 1
				break
	return _ground_cache


## Feet position for an entity standing in cell (x, y).
func feet(x: int, y: int) -> Vector2:
	return Vector2(x * T + T / 2.0, (y + 1) * T)


func _spawn(c: String, x: int, y: int) -> void:
	var pos := feet(x, y)
	var node: Node2D = null
	match c:
		"P":
			player_start = pos
		"z", "Z":
			node = ENEMY.instantiate()
			node.burnt = c == "Z"
		"b":
			node = BUSH.instantiate()
		"A":
			node = ANTENNA.instantiate()
		"a", "m":
			node = PICKUP.instantiate()
			node.kind = "ammo" if c == "a" else "medkit"
		"T":
			node = PICKUP.instantiate()
			node.kind = "cable"
		"X":
			node = PLANE.instantiate()
		"c", "l":
			node = DECOR.new()
			node.kind = "car" if c == "c" else "lamp"
		_:
			if c.is_valid_int():
				node = TRIGGER.new()
				node.trigger_id = c
	if node:
		node.position = pos
		entities.add_child(node)


# --- TileSet --------------------------------------------------------------

func _make_tileset() -> TileSet:
	var atlas := Image.create_empty(T * TILE_KEYS.size(), T, false, Image.FORMAT_RGBA8)
	for i in TILE_KEYS.size():
		var img := _tile_image(TILE_KEYS[i])
		atlas.blit_rect(img, Rect2i(0, 0, T, T), Vector2i(i * T, 0))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	# Physics layer 0: solid ("world", bit 1). Layer 1: one-way platforms (bit 6),
	# separate so characters can drop through them by toggling one mask bit.
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(1, 1 << 5)
	ts.set_physics_layer_collision_mask(1, 0)
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(atlas)
	src.texture_region_size = Vector2i(T, T)
	ts.add_source(src, 0)
	var h := T / 2.0
	for i in TILE_KEYS.size():
		var coord := Vector2i(i, 0)
		src.create_tile(coord)
		var key: String = TILE_KEYS[i]
		var td := src.get_tile_data(coord, 0)
		if key in ["solid_top", "solid", "ground_top", "ground", "wall_side"]:
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]))
		elif key == "oneway":
			td.add_collision_polygon(1)
			td.set_collision_polygon_points(1, 0, PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, -h + 4), Vector2(-h, -h + 4)]))
			td.set_collision_polygon_one_way(1, 0, true)
	return ts


## Real tile art if available (see TileArt), otherwise a flat-colour placeholder.
func _tile_image(key: String) -> Image:
	var t: Texture2D = TileArt.get_tile(key)
	if t:
		var src_img := t.get_image()
		if src_img.is_compressed():
			src_img.decompress()
		src_img.convert(Image.FORMAT_RGBA8)
		if src_img.get_size() != Vector2i(T, T):
			src_img.resize(T, T, Image.INTERPOLATE_NEAREST)
		return src_img
	var img := Image.create_empty(T, T, false, Image.FORMAT_RGBA8)
	match key:
		"solid_top":
			img.fill(Color("5b5f66")); img.fill_rect(Rect2i(0, 0, T, 3), Color("80858d"))
		"solid", "wall_side":
			img.fill(Color("4a4d54")); img.fill_rect(Rect2i(0, T - 1, T, 1), Color("3b3d43"))
		"ground_top":
			img.fill(Color("3a3328")); img.fill_rect(Rect2i(0, 0, T, 3), Color("4d5a3a"))
		"ground":
			img.fill(Color("2e281f"))
		"oneway":
			img.fill_rect(Rect2i(0, 0, T, 4), Color("8a7a5a"))
		"wall_bg":
			img.fill(Color("2c2e34"))
		"window_bg":
			img.fill(Color("2c2e34")); img.fill_rect(Rect2i(2, 2, T - 4, T - 4), Color("151a24"))
		"pole_bg":
			img.fill_rect(Rect2i(7, 0, 2, T), Color("555a60"))
	return img
