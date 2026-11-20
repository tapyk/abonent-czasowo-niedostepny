class_name PropArt
## Textures for props and items. Placeholders until the asset pack is wired.


static func bullet() -> Texture2D:
	return Art.box(Vector2i(4, 2), Color("fff3b0"))


static func bush() -> Texture2D:
	return Art.box(Vector2i(28, 20), Color("2f4a26"), Color("1f3319"))


static func antenna_mast() -> Texture2D:
	return Art.box(Vector2i(8, 72), Color("6d737c"), Color("3d4148"))


static func antenna_panel() -> Texture2D:
	return Art.box(Vector2i(10, 14), Color("39424d"), Color("8fd18f"))


static func plane() -> Texture2D:
	return Art.box(Vector2i(56, 18), Color("c9ccd1"), Color("7d828a"))


static func decor(kind: String) -> Texture2D:
	if kind == "lamp":
		return Art.box(Vector2i(3, 40), Color("4b4f55"))
	return Art.box(Vector2i(34, 14), Color("5a3b2e"), Color("2e1f18"))


static func pickup(kind: String) -> Texture2D:
	match kind:
		"ammo", "ammo_small":
			return Art.box(Vector2i(8, 6), Color("c9a640"), Color("6b5a1f"))
		"medkit":
			return Art.box(Vector2i(9, 8), Color("e8e8e8"), Color("d02a2a"))
		"part":
			return Art.box(Vector2i(7, 7), Color("9aa0a8"), Color("ff7a2a"))
		"cable":
			return Art.box(Vector2i(16, 6), Color("4d5a46"), Color("2a3326"))
	return Art.box(Vector2i(6, 6), Color.MAGENTA)
