class_name CharacterArt
## SpriteFrames for characters, cut from horizontal strips and scaled to the game's scale.

const SCALE := 0.5
const CHAR := "res://assets/sprites/characters/"
const ENEMY := "res://assets/sprites/enemies/"
const PLAYER_FRAME := Vector2i(71, 67)
const ZOMBIE_FRAME := Vector2i(45, 45)
const BURNT_TINT := Color(1.0, 0.55, 0.3)

const ANIMS := ["idle", "run", "jump", "fall", "attack", "hurt"]

static var _cache := {}


## [animation, file, frame indices (empty = all), fps, loop]
const PLAYER_ANIMS := [
	["idle", "player_idle_strip.png", [], 7.0, true],
	["run", "player_run_strip.png", [], 13.0, true],
	["jump", "player_jump_strip.png", [0, 1, 2], 10.0, false],
	["fall", "player_jump_strip.png", [3], 1.0, false],
	["shoot", "player_shoot.png", [], 1.0, false],
	["run_shoot", "player_run_shoot_strip.png", [], 13.0, true],
	["attack", "player_crouch_shoot.png", [], 1.0, false],
	["hurt", "player_hurt.png", [], 1.0, false],
]


static func player_frames() -> SpriteFrames:
	if _cache.has("player"):
		return _cache["player"]
	if Art.tex(CHAR + "player_idle_strip.png") == null:
		return _placeholder(Color("3f6fb5"), Color("e0b48a"))
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for a in PLAYER_ANIMS:
		_add_strip(sf, a[0], CHAR + a[1], PLAYER_FRAME, a[2], a[3], a[4])
	_cache["player"] = sf
	return sf


static func enemy_frames(burnt: bool) -> SpriteFrames:
	var key := "enemy_burnt" if burnt else "enemy"
	if _cache.has(key):
		return _cache[key]
	var walk := ENEMY + ("zombie_cop_walk_strip.png" if burnt else "zombie_walk_strip.png")
	var die := ENEMY + ("zombie_cop_death_strip.png" if burnt else "zombie_death_strip.png")
	if Art.tex(walk) == null:
		if burnt:
			return _placeholder(Color("5a2a1a"), Color("ff7a2a"))
		return _placeholder(Color("4f6b3a"), Color("9fb08a"))
	var tint := BURNT_TINT if burnt else Color.WHITE
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	_add_strip(sf, "run", walk, ZOMBIE_FRAME, [], 8.0, true, tint)
	_add_strip(sf, "idle", walk, ZOMBIE_FRAME, [0, 1], 2.0, true, tint)
	_add_strip(sf, "jump", walk, ZOMBIE_FRAME, [2], 1.0, false, tint)
	_add_strip(sf, "attack", walk, ZOMBIE_FRAME, [3, 4], 10.0, false, tint)
	_add_strip(sf, "hurt", die, ZOMBIE_FRAME, [0], 1.0, false, tint)
	_add_strip(sf, "die", die, ZOMBIE_FRAME, [], 10.0, false, tint)
	_cache[key] = sf
	return sf


## Lying corpse used as the dead technician.
static func corpse() -> Texture2D:
	var t := Art.scaled(ENEMY + "zombie_death_strip.png", SCALE, Rect2i(Vector2i(5 * 45, 0), ZOMBIE_FRAME), Color(0.55, 0.65, 0.85))
	return t if t else Art.box(Vector2i(16, 6), Color("4d5a46"))


static func muzzle_flash() -> Texture2D:
	var t := Art.scaled("res://assets/sprites/fx/fx_muzzle_flash_strip.png", 0.5, Rect2i(0, 0, 16, 16))
	return t if t else Art.box(Vector2i(5, 3), Color("ffe27a"))


static func _add_strip(sf: SpriteFrames, anim: String, path: String, frame: Vector2i, indices: Array, fps: float, loop: bool, tint := Color.WHITE) -> void:
	var base := Art.tex(path)
	if base == null:
		return
	var count := int(base.get_width() / frame.x)
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loop)
	var idx: Array = indices if not indices.is_empty() else range(count)
	for i in idx:
		sf.add_frame(anim, Art.scaled(path, SCALE, Rect2i(Vector2i(i * frame.x, 0), frame), tint))


static func _placeholder(body: Color, head: Color) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for a in ANIMS + ["die"]:
		sf.add_animation(a)
		sf.set_animation_speed(a, 8.0)
		sf.set_animation_loop(a, a in ["idle", "run"])
		var frames := 2 if a == "run" else 1
		for i in frames:
			sf.add_frame(a, Art.humanoid(body, head, i))
	return sf
