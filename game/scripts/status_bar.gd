extends Control
## Top-left status strip: HP, ammo, parts for Fasti Farmer, progress items.

const W := 96
const H := 15

var hp := 100
var max_hp := 100
var _regen := false
var _t := 0.0


func _ready() -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Game.stats_changed.connect(queue_redraw)


func _process(delta: float) -> void:
	var r: bool = is_instance_valid(Game.player) and Game.player.regenerating
	_t += delta
	if r or r != _regen:
		_regen = r
		queue_redraw()


func set_hp(v: int, m: int) -> void:
	hp = v
	max_hp = m
	queue_redraw()


func _draw() -> void:
	var f := Art.font()
	var fs := Art.FONT_SIZE
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.06, 0.08, 0.75))
	draw_rect(Rect2(0, 0, W, H), Color("3a404c"), false, 1.0)
	# HP
	draw_rect(Rect2(2, 2, W - 4, 2), Color(1, 1, 1, 0.12))
	var hp_col := Color("d94a4a")
	if _regen:
		# pulsing green while health comes back
		hp_col = hp_col.lerp(Color("7ee08a"), 0.45 + 0.35 * sin(_t * 6.0))
	draw_rect(Rect2(2, 2, (W - 4) * float(hp) / max_hp, 2), hp_col)
	var y := 12
	var pistol := Art.scaled("res://assets/sprites/ui/ui_pistol.png", 0.5)
	var gear := Art.scaled("res://assets/sprites/ui/ui_gear.png", 0.5, Rect2i(), Color(1.0, 0.6, 0.3))
	var x := 3.0
	if Game.has_pistol:
		if pistol: draw_texture(pistol, Vector2(x, y - 7))
		draw_string(f, Vector2(x + 10, y), str(Game.ammo), HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Color("e8d27a") if Game.ammo > 0 else Color("ff6a5a"))
		x += 26
	if gear: draw_texture(gear, Vector2(x, y - 7))
	draw_string(f, Vector2(x + 10, y), str(Game.parts), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffa060"))
	x += 20
	var items: PackedStringArray = []
	if Game.has_sekator: items.append("S")
	if Game.has_cable: items.append("K1")
	if Game.has_kable: items.append("K2")
	draw_string(f, Vector2(x, y), " ".join(items), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("8fe0a0"))
