class_name TileArt
## Which asset tile is used for each terrain key (16x16).

const C := "res://assets/sprites/tiles/city_tiles.png"     # Kenney Roguelike Modern City
const U := "res://assets/sprites/tiles/urban_tiles.png"    # Kenney RPG Urban Pack
const I := "res://assets/sprites/tiles/indoor_tiles.png"   # Kenney Roguelike Indoors
const G := "res://assets/sprites/tiles/rpg_tiles.png"      # Kenney Roguelike RPG Pack
const F := "res://assets/sprites/tiles/farm_crops.png"     # josehzz Farming crops (CC0)

## key: [sheet, cell] or [sheet, cell, overlay sheet, overlay cell, (base sheet, base cell)]
const MAP := {
	"grass": [C, Vector2i(0, 24)], "grass2": [C, Vector2i(1, 24)],
	"dirt": [C, Vector2i(4, 24)], "road": [C, Vector2i(11, 19)],
	"sidewalk": [C, Vector2i(1, 20)], "runway": [C, Vector2i(9, 19)],
	"field": [C, Vector2i(4, 24), F, Vector2i(3, 5)],
	"floor": [G, Vector2i(8, 2)],
	# flat dark-grey roof, 9-slice
	"roof_tl": [C, Vector2i(8, 0)], "roof_t": [C, Vector2i(10, 0)], "roof_tr": [C, Vector2i(9, 0)],
	"roof_l": [C, Vector2i(11, 0)], "roof_c": [C, Vector2i(14, 0)], "roof_r": [C, Vector2i(11, 1)],
	"roof_bl": [C, Vector2i(8, 1)], "roof_b": [C, Vector2i(10, 1)], "roof_br": [C, Vector2i(9, 1)],
	# grey brick facade (the "blok" look) with windows
	"wall_l": [C, Vector2i(5, 5), C, Vector2i(26, 18)], "wall": [C, Vector2i(6, 5), C, Vector2i(26, 18)],
	"wall_r": [C, Vector2i(7, 5), C, Vector2i(26, 18)],
	"door": [C, Vector2i(6, 5), C, Vector2i(20, 27)],
	"garage": [U, Vector2i(12, 11)],
	"tree": [C, Vector2i(33, 11)], "canopy": [C, Vector2i(33, 10)],
	"fence": [U, Vector2i(5, 14)], "fence_v": [U, Vector2i(7, 14)],
	"iwall": [G, Vector2i(25, 15)], "iwall_face": [G, Vector2i(25, 16)],
	"kitchen": [I, Vector2i(2, 13)], "bed": [I, Vector2i(9, 6)], "table": [I, Vector2i(1, 0)],
	"plant": [C, Vector2i(33, 13)], "stairs": [G, Vector2i(22, 18)],
}


static func get_tile(key: String) -> Texture2D:
	var e: Array = MAP.get(key, MAP.get(key.split("_")[0], []))
	if e.is_empty():
		return null
	var img := Art.image(e[0], Rect2i(e[1] * 16, Vector2i(16, 16)))
	if img == null:
		return null
	if e.size() >= 4:
		var over := Art.image(e[2], Rect2i(e[3] * 16, Vector2i(16, 16)))
		if over:
			img.blend_rect(over, Rect2i(0, 0, 16, 16), Vector2i.ZERO)
	return ImageTexture.create_from_image(img)


static func placeholder(key: String) -> Image:
	var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	var base := key.split("_")[0]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	match base:
		"grass", "grass2":
			img.fill(Color("3d5a2e") if base == "grass" else Color("466634"))
			for i in 6:
				img.set_pixel(rng.randi_range(0, 15), rng.randi_range(0, 15), Color("587a40"))
		"dirt":
			img.fill(Color("6b5a3e"))
		"road":
			img.fill(Color("3a3c40"))
		"sidewalk":
			img.fill(Color("7a7c80")); img.fill_rect(Rect2i(0, 15, 16, 1), Color("5f6165")); img.fill_rect(Rect2i(15, 0, 1, 16), Color("5f6165"))
		"field":
			img.fill(Color("5a4a2a"))
			for x in range(1, 16, 4): img.fill_rect(Rect2i(x, 0, 2, 16), Color("7a8a3a"))
		"runway":
			img.fill(Color("2e3034")); img.fill_rect(Rect2i(0, 7, 8, 2), Color("d0d0c0"))
		"floor":
			img.fill(Color("8a6a48")); img.fill_rect(Rect2i(0, 7, 16, 1), Color("74583a"))
		"wall":
			img.fill(Color("9a9890"))
			img.fill_rect(Rect2i(3, 3, 4, 5), Color("2a3448")); img.fill_rect(Rect2i(9, 3, 4, 5), Color("2a3448"))
			if key == "wall_l": img.fill_rect(Rect2i(0, 0, 1, 16), Color("5a5850"))
			if key == "wall_r": img.fill_rect(Rect2i(15, 0, 1, 16), Color("5a5850"))
		"roof":
			img.fill(Color("5a4a48"))
			if "t" in key.trim_prefix("roof_"): img.fill_rect(Rect2i(0, 0, 16, 2), Color("7a6a68"))
			if "b" in key.trim_prefix("roof_"): img.fill_rect(Rect2i(0, 13, 16, 3), Color("3a2e2c"))
			if key.ends_with("l"): img.fill_rect(Rect2i(0, 0, 2, 16), Color("3a2e2c"))
			if key.ends_with("r"): img.fill_rect(Rect2i(14, 0, 2, 16), Color("3a2e2c"))
		"tree":
			img.fill(Color("1f3a1c")); img.fill_rect(Rect2i(6, 6, 4, 10), Color("4a3420"))
		"canopy":
			img.fill_rect(Rect2i(1, 2, 14, 14), Color("2a5226")); img.fill_rect(Rect2i(3, 4, 4, 3), Color("3a6a32"))
		"fence":
			if key == "fence_v": img.fill_rect(Rect2i(7, 0, 2, 16), Color("8a8a8a"))
			else: img.fill_rect(Rect2i(0, 6, 16, 2), Color("8a8a8a")); img.fill_rect(Rect2i(0, 11, 16, 1), Color("8a8a8a"))
			for x in range(1, 16, 5): img.fill_rect(Rect2i(x, 4, 1, 10), Color("6a6a6a"))
		"iwall":
			img.fill(Color("4a4038") if key == "iwall" else Color("c8b89a"))
			if key == "iwall_face": img.fill_rect(Rect2i(0, 13, 16, 3), Color("6a5a48"))
		"kitchen":
			img.fill(Color("b8bcc0")); img.fill_rect(Rect2i(2, 2, 5, 5), Color("3a3c40"))
		"bed":
			img.fill(Color("6a3a3a")); img.fill_rect(Rect2i(1, 1, 14, 5), Color("e0e0d8"))
		"table":
			img.fill_rect(Rect2i(1, 3, 14, 10), Color("7a5432"))
		"plant":
			img.fill_rect(Rect2i(5, 10, 6, 6), Color("8a4a2a")); img.fill_rect(Rect2i(3, 2, 10, 9), Color("3a7a32"))
		"garage":
			img.fill(Color("6a7078"))
			for y in range(1, 16, 3): img.fill_rect(Rect2i(0, y, 16, 1), Color("50565e"))
		"door":
			img.fill(Color("9a9890")); img.fill_rect(Rect2i(3, 2, 10, 14), Color("3a2a1a"))
		"stairs":
			img.fill(Color("5a5a5a"))
			for y in range(0, 16, 4): img.fill_rect(Rect2i(0, y, 16, 2), Color("8a8a8a"))
	return img
