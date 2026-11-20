class_name CharacterArt
## SpriteFrames for top-down characters.

static var _cache := {}


const CH := "res://assets/sprites/characters/"
const EN := "res://assets/sprites/enemies/"


static func player_frames() -> SpriteFrames:
	if not _cache.has("player"):
		var sf := _from_sheet(CH + "player_johnny.png", 8.0)
		_cache["player"] = sf if sf else _placeholder(Color("c9a640"), Color("e0b48a"), Color("3a3a48"))
	return _cache["player"]


static func enemy_frames(burnt: bool) -> SpriteFrames:
	var key := "enemy_burnt" if burnt else "enemy"
	if not _cache.has(key):
		var sf := _from_sheet(EN + ("mutant_b.png" if burnt else "mutant_a.png"), 5.0, Color(1.0, 0.6, 0.35) if burnt else Color.WHITE)
		if sf == null:
			sf = _placeholder(Color("5a2a1a"), Color("ff7a2a"), Color("2a1a14")) if burnt \
				else _placeholder(Color("4f6b3a"), Color("9fb08a"), Color("2f3a28"))
		_cache[key] = sf
	return _cache[key]


static func npc_frames(path: String, tint := Color.WHITE) -> SpriteFrames:
	var key := "npc_" + path
	if not _cache.has(key):
		var sf := _from_sheet(path, 4.0, tint) if path != "" else null
		_cache[key] = sf if sf else _placeholder(Color("7a6a9a"), Color("e0b48a"), Color("3a3a48"))
	return _cache[key]


## Kenney RPG Urban character sheet: 3x4 frames of 16x16; rows down/left/right/up.
static func _from_sheet(path: String, fps: float, tint := Color.WHITE) -> SpriteFrames:
	if Art.tex(path) == null:
		return null
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var rows := {"down": 0, "left": 1, "right": 2, "up": 3}
	for d in rows:
		var fr := func(col: int) -> Texture2D: return Art.scaled(path, 1.0, Rect2i(col * 16, rows[d] * 16, 16, 16), tint)
		for kind in ["idle", "walk", "attack", "hurt", "die"]:
			var a: String = kind + "_" + d
			sf.add_animation(a)
			sf.set_animation_speed(a, fps)
			sf.set_animation_loop(a, kind in ["idle", "walk"])
			if kind == "walk":
				for c in [1, 0, 2, 0]:
					sf.add_frame(a, fr.call(c))
			elif kind == "die":
				var img: Image = fr.call(0).get_image()
				img.rotate_90(CLOCKWISE)
				sf.add_frame(a, ImageTexture.create_from_image(img))
			else:
				sf.add_frame(a, fr.call(0))
	return sf


## Best animation for kind + facing direction.
static func anim_name(sf: SpriteFrames, kind: String, dir: Vector2) -> String:
	var d := "down"
	if absf(dir.x) > absf(dir.y):
		d = "right" if dir.x > 0 else "left"
	elif dir.y < 0:
		d = "up"
	var tries := [kind + "_" + d]
	if d in ["left", "right"]:
		tries.append(kind + "_side")
	tries.append_array([kind + "_down", kind, "walk_" + d, "walk_side", "walk_down"])
	for t in tries:
		if sf.has_animation(t):
			return t
	return sf.get_animation_names()[0]


## Mirror side animations when facing the other way.
static func flip_for(sf: SpriteFrames, dir: Vector2) -> bool:
	if absf(dir.x) <= absf(dir.y):
		return false
	if sf.has_animation("walk_left") and sf.has_animation("walk_right"):
		return false
	var faces_left: bool = sf.get_meta("side_faces_left", false)
	return (dir.x < 0) != faces_left


static func muzzle_flash() -> Texture2D:
	var t := Art.scaled("res://assets/sprites/fx/fx_muzzle_flash_strip.png", 0.5, Rect2i(0, 0, 16, 16))
	return t if t else Art.box(Vector2i(5, 3), Color("ffe27a"))


static func corpse() -> Texture2D:
	var t := Art.tex(CH + "npc_technician_dead.png")
	if t:
		return t
	var img := Image.create_empty(20, 10, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(0, 3, 6, 5), Color("e0b48a"))
	img.fill_rect(Rect2i(6, 2, 10, 7), Color("d05a20"))
	img.fill_rect(Rect2i(16, 3, 4, 2), Color("3a3a48"))
	img.fill_rect(Rect2i(16, 6, 4, 2), Color("3a3a48"))
	return ImageTexture.create_from_image(img)


## 16x24 humanoid seen from the 3/4 view, per direction, 2 walk frames.
static func _humanoid(body: Color, head: Color, legs: Color, d: String, frame: int) -> ImageTexture:
	var img := Image.create_empty(16, 24, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(4, 22, 8, 2), Color(0, 0, 0, 0.35))      # shadow
	img.fill_rect(Rect2i(5, 2, 6, 6), head)
	img.fill_rect(Rect2i(4, 8, 8, 8), body)
	var step := 1 if frame == 1 else 0
	img.fill_rect(Rect2i(5, 16, 2, 6 - step), legs)
	img.fill_rect(Rect2i(9, 16, 2, 6 - (1 - step) * (1 if frame >= 0 else 0)), legs)
	match d:
		"down":
			img.set_pixel(6, 5, Color.BLACK); img.set_pixel(9, 5, Color.BLACK)
		"up":
			img.fill_rect(Rect2i(5, 2, 6, 3), head.darkened(0.4))
		"side":
			img.set_pixel(9, 5, Color.BLACK)
			img.fill_rect(Rect2i(11, 10, 3, 2), body.darkened(0.2))  # arm forward
	return ImageTexture.create_from_image(img)


static func _placeholder(body: Color, head: Color, legs: Color) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for d in ["down", "up", "side"]:
		for kind in ["idle", "walk", "attack", "hurt", "die"]:
			var a: String = kind + "_" + d
			sf.add_animation(a)
			sf.set_animation_speed(a, 6.0)
			sf.set_animation_loop(a, kind in ["idle", "walk"])
			var n := 2 if kind == "walk" else 1
			for i in n:
				var t := _humanoid(body, head, legs, d, i if kind == "walk" else -1)
				if kind == "die":
					var img := t.get_image()
					img.rotate_90(CLOCKWISE)
					t = ImageTexture.create_from_image(img)
				sf.add_frame(a, t)
	return sf
