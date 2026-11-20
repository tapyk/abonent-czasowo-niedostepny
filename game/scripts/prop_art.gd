class_name PropArt
## Textures for props and items. Placeholders if an asset is missing.

const P := "res://assets/sprites/"


static func _or(t: Texture2D, fallback: Texture2D) -> Texture2D:
	return t if t else fallback


static func bullet() -> Texture2D:
	return _or(Art.scaled(P + "fx/fx_bullet_strip.png", 0.5, Rect2i(0, 0, 20, 5)), Art.box(Vector2i(4, 2), Color("fff3b0")))


static func bush() -> Texture2D:
	return Art.box(Vector2i(16, 14), Color("2f5a26"), Color("1f3a19"))


static func thicket() -> Texture2D:
	return Art.box(Vector2i(16, 16), Color("1d3a18"), Color("4a7a30"))


static func antenna_mast() -> Texture2D:
	return _or(Art.scaled(P + "props/prop_antenna.png", 0.75), Art.box(Vector2i(6, 56), Color("6d737c"), Color("3d4148")))


static func antenna_panel() -> Texture2D:
	return _or(Art.scaled(P + "props/prop_control_box_2.png", 0.75), Art.box(Vector2i(10, 14), Color("39424d"), Color("8fd18f")))


static func plane() -> Texture2D:
	return _or(Art.scaled(P + "props/airplane_topdown.png", 2.0), Art.box(Vector2i(48, 48), Color("c9ccd1")))


static func decor(_kind: String) -> Texture2D:
	return Art.box(Vector2i(28, 16), Color("5a3b2e"), Color("2e1f18"))


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
			return Art.box(Vector2i(8, 8), Color("c04040"), Color("c0c8d0"))
		"cable":
			return CharacterArt.corpse()
	return Art.box(Vector2i(6, 6), Color.MAGENTA)
