extends Control
## Top-left status strip: HP, ammo, parts for Fast Farmer, progress items.

const W := 96
const H := 15

var hp := 100
var max_hp := 100
var hp2 := 100
var max_hp2 := 100
var _regen := false
var _regen2 := false
var _t := 0.0


func _ready() -> void:
	size = Vector2(W, 19 if Game.coop else H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Game.stats_changed.connect(queue_redraw)


func _process(delta: float) -> void:
	var r: bool = is_instance_valid(Game.player) and Game.player.regenerating
	var r2: bool = Game.coop and is_instance_valid(Game.player2) and Game.player2.regenerating
	_t += delta
	if r or r2 or r != _regen or r2 != _regen2 or Game.coop:
		_regen = r
		_regen2 = r2
		queue_redraw()


func set_hp(v: int, m: int) -> void:
	hp = v
	max_hp = m
	queue_redraw()


func set_hp2(v: int, m: int) -> void:
	hp2 = v
	max_hp2 = m
	queue_redraw()


func _draw() -> void:
	var f := Art.font()
	var fs := Art.FONT_SIZE
	var box_h := 19 if Game.coop else H
	draw_rect(Rect2(0, 0, W, box_h), Color(0.05, 0.06, 0.08, 0.75))
	draw_rect(Rect2(0, 0, W, box_h), Color("3a404c"), false, 1.0)
	# P1 HP
	draw_rect(Rect2(2, 2, W - 4, 2), Color(1, 1, 1, 0.12))
	var hp_col := Color("d94a4a")
	if _regen:
		hp_col = hp_col.lerp(Color("7ee08a"), 0.45 + 0.35 * sin(_t * 6.0))
	draw_rect(Rect2(2, 2, (W - 4) * float(hp) / max_hp, 2), hp_col)
	var y := 12
	if Game.coop:
		draw_rect(Rect2(2, 5, W - 4, 2), Color(1, 1, 1, 0.12))
		var hp2_col := Color("4aa8e8")
		if _regen2:
			hp2_col = hp2_col.lerp(Color("7ee08a"), 0.45 + 0.35 * sin(_t * 6.0))
		draw_rect(Rect2(2, 5, (W - 4) * float(hp2) / max_hp2, 2), hp2_col)
		y = 16
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
