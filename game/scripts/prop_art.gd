class_name PropArt
## Textures for props and items (scaled to the game's scale). Placeholders if missing.

const P := "res://assets/sprites/"


static func _or(t: Texture2D, fallback: Texture2D) -> Texture2D:
	return t if t else fallback


static func bullet() -> Texture2D:
	return _or(Art.scaled(P + "fx/fx_bullet_strip.png", 0.5, Rect2i(0, 0, 20, 5)), Art.box(Vector2i(4, 2), Color("fff3b0")))


static func bush() -> Texture2D:
	var file := "props/prop_bush_large.png" if randf() < 0.6 else "props/prop_bush_small.png"
	return _or(Art.scaled(P + file, 0.75), Art.box(Vector2i(28, 20), Color("2f4a26"), Color("1f3319")))


static func antenna_mast() -> Texture2D:
	return _or(Art.tex(P + "props/prop_antenna.png"), Art.box(Vector2i(8, 72), Color("6d737c"), Color("3d4148")))


static func antenna_panel() -> Texture2D:
	return _or(Art.scaled(P + "props/prop_control_box_2.png", 0.75), Art.box(Vector2i(10, 14), Color("39424d"), Color("8fd18f")))


static func decor(kind: String) -> Texture2D:
	if kind == "lamp":
		return _or(Art.scaled(P + "props/prop_lamp_post.png", 1.0, Rect2i(16, 0, 16, 64)), Art.box(Vector2i(3, 40), Color("4b4f55")))
	var file := "props/prop_car_red.png" if randf() < 0.5 else "props/prop_car_police.png"
	return _or(Art.scaled(P + file, 0.5, Rect2i(), Color(0.55, 0.5, 0.5)), Art.box(Vector2i(34, 14), Color("5a3b2e"), Color("2e1f18")))


static func pickup(kind: String) -> Texture2D:
	match kind:
		"ammo":
			return _or(Art.scaled(P + "items/item_ammo_box_9mm.png", 0.5), Art.box(Vector2i(8, 6), Color("c9a640")))
		"ammo_small":
			return _or(Art.scaled(P + "items/item_ammo_clip.png", 0.75), Art.box(Vector2i(6, 6), Color("c9a640")))
		"medkit":
			return _or(Art.scaled(P + "items/item_medkit.png", 0.5), Art.box(Vector2i(9, 8), Color("e8e8e8"), Color("d02a2a")))
		"part":
			return _or(Art.scaled(P + "items/item_gear.png", 0.75, Rect2i(), Color(1.0, 0.6, 0.3)), Art.box(Vector2i(7, 7), Color("9aa0a8")))
		"cable":
			return CharacterArt.corpse()
	return Art.box(Vector2i(6, 6), Color.MAGENTA)


## Side-view jet drawn in code (no CC0 side-view plane was found).
static func plane() -> Texture2D:
	if Art._cache.has("plane"):
		return Art._cache["plane"]
	var img := Image.create_empty(64, 22, false, Image.FORMAT_RGBA8)
	var body := Color("c9ccd1")
	var dark := Color("7d828a")
	img.fill_rect(Rect2i(6, 10, 50, 6), body)           # fuselage
	img.fill_rect(Rect2i(56, 11, 4, 4), body)            # nose
	img.fill_rect(Rect2i(60, 12, 2, 2), dark)
	img.fill_rect(Rect2i(6, 16, 50, 1), dark)            # belly line
	for i in 8:
		img.fill_rect(Rect2i(4 + i, 2 + i, 3, 1), body)  # tail fin
	img.fill_rect(Rect2i(2, 9, 10, 2), dark)             # tail plane
	img.fill_rect(Rect2i(24, 15, 18, 2), dark)           # wing
	img.fill_rect(Rect2i(14, 8, 8, 3), dark)             # engine
	for x in range(26, 54, 4):
		img.fill_rect(Rect2i(x, 11, 2, 2), Color("ffd27a"))  # lit windows
	img.fill_rect(Rect2i(54, 11, 3, 2), Color("6fb0ff"))  # cockpit
	img.fill_rect(Rect2i(20, 17, 1, 4), dark)            # landing gear
	img.fill_rect(Rect2i(48, 17, 1, 4), dark)
	img.fill_rect(Rect2i(19, 20, 3, 2), Color("222222"))
	img.fill_rect(Rect2i(47, 20, 3, 2), Color("222222"))
	var t := ImageTexture.create_from_image(img)
	Art._cache["plane"] = t
	return t
