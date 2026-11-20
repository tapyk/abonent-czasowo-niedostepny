class_name TileArt
## Which asset tile is used for each terrain key (16x16).

## key: [sheet path, cell (col,row)]  — filled in once the top-down tileset is wired.
const MAP := {}


static func get_tile(key: String) -> Texture2D:
	var e: Array = MAP.get(key, MAP.get(key.split("_")[0], []))
	if e.is_empty():
		return null
	var img := Art.image(e[0], Rect2i(e[1] * 16, Vector2i(16, 16)))
	return ImageTexture.create_from_image(img) if img else null


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
