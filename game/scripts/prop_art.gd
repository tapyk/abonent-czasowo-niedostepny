class_name PropArt
## Textures for props and items. Placeholders if an asset is missing.

const P := "res://assets/sprites/"


static func _or(t: Texture2D, fallback: Texture2D) -> Texture2D:
	return t if t else fallback


static func bullet() -> Texture2D:
	return _or(Art.scaled(P + "fx/fx_bullet_strip.png", 0.5, Rect2i(0, 0, 20, 5)), Art.box(Vector2i(4, 2), Color("fff3b0")))


static func bush() -> Texture2D:
	return _or(Art.scaled(P + "tiles/city_tiles.png", 1.0, Rect2i(33 * 16, 13 * 16, 16, 16)), Art.box(Vector2i(16, 14), Color("2f5a26")))


static func thicket() -> Texture2D:
	return _or(Art.scaled(P + "tiles/urban_tiles.png", 1.0, Rect2i(19 * 16, 9 * 16, 16, 16)), Art.box(Vector2i(16, 16), Color("1d3a18")))


static func antenna_mast() -> Texture2D:
	var m := Art.scaled(P + "props/maszt5.png", 1.0, Rect2i(22, 2, 22, 62))  # team's lattice mast
	return _or(m if m else Art.scaled(P + "props/prop_antenna.png", 0.75), Art.box(Vector2i(6, 56), Color("6d737c"), Color("3d4148")))


static func antenna_panel() -> Texture2D:
	return _or(Art.scaled(P + "props/prop_control_box_2.png", 0.75), Art.box(Vector2i(10, 14), Color("39424d"), Color("8fd18f")))


## Team's jet, side view, nose to the right: parked (gear down), flying, wrecked.
static func plane() -> Texture2D:
	return _or(Art.scaled(P + "props/samolot_postoj.png", 1.0, Rect2i(19, 44, 148, 57)), Art.box(Vector2i(48, 48), Color("c9ccd1")))


static func plane_flying() -> Texture2D:
	return _or(Art.scaled(P + "props/samolot_lot.png", 1.0, Rect2i(19, 44, 148, 57)), plane())


static func plane_wrecked() -> Texture2D:
	return _or(Art.scaled(P + "props/samolot_uszkodzony.png", 1.0, Rect2i(19, 44, 148, 63)), plane())


static func decor(_kind: String) -> Texture2D:
	var f: String = ["car_gray_side_right.png", "car_green_side_left.png", "car_gray_side_left.png"].pick_random()
	return _or(Art.scaled(P + "props/" + f, 1.0, Rect2i(), Color(0.6, 0.55, 0.55)), Art.box(Vector2i(28, 16), Color("5a3b2e")))


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
		"pistol":
			return _or(Art.scaled(P + "ui/ui_pistol.png", 0.75), Art.box(Vector2i(8, 5), Color("555a60")))
		"sekator":
			return _or(Art.scaled(P + "items/item_shears.png", 0.5), Art.box(Vector2i(8, 8), Color("c04040")))
		"cable":
			return CharacterArt.corpse()
	return Art.box(Vector2i(6, 6), Color.MAGENTA)
