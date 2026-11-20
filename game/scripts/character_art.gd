class_name CharacterArt
## SpriteFrames for characters. Placeholder humanoids until real sheets are wired.

const ANIMS := ["idle", "run", "jump", "fall", "attack", "hurt"]


static func player_frames() -> SpriteFrames:
	return _placeholder(Color("3f6fb5"), Color("e0b48a"))


static func enemy_frames(burnt: bool) -> SpriteFrames:
	if burnt:
		return _placeholder(Color("5a2a1a"), Color("ff7a2a"))
	return _placeholder(Color("4f6b3a"), Color("9fb08a"))


static func muzzle_flash() -> Texture2D:
	return Art.box(Vector2i(5, 3), Color("ffe27a"))


static func _placeholder(body: Color, head: Color) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for a in ANIMS:
		sf.add_animation(a)
		sf.set_animation_speed(a, 8.0)
		sf.set_animation_loop(a, a in ["idle", "run"])
		var frames := 2 if a == "run" else 1
		for i in frames:
			sf.add_frame(a, Art.humanoid(body, head, i))
	return sf
