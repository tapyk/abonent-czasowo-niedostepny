extends Control
## Top-left status strip: HP, ammo, parts for Fast Farmer, progress items.

const W := 128
const H := 22

var hp := 100
var max_hp := 100


func _ready() -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Game.stats_changed.connect(queue_redraw)


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
	draw_rect(Rect2(3, 3, W - 6, 3), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(3, 3, (W - 6) * float(hp) / max_hp, 3), Color("d94a4a"))
	var y := 17
	var pistol := Art.scaled("res://assets/sprites/ui/ui_pistol.png", 0.5)
	var gear := Art.scaled("res://assets/sprites/ui/ui_gear.png", 0.5, Rect2i(), Color(1.0, 0.6, 0.3))
	var x := 3.0
	if Game.has_pistol:
		if pistol: draw_texture(pistol, Vector2(x, y - 8))
		draw_string(f, Vector2(x + 10, y), str(Game.ammo), HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Color("e8d27a") if Game.ammo > 0 else Color("ff6a5a"))
		x += 34
	if gear: draw_texture(gear, Vector2(x, y - 8))
	draw_string(f, Vector2(x + 10, y), str(Game.parts), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffa060"))
	x += 26
	var items: PackedStringArray = []
	if Game.has_sekator: items.append("S")
	if Game.has_cable: items.append("K1")
	if Game.has_kable: items.append("K2")
	draw_string(f, Vector2(x, y), " ".join(items), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("8fe0a0"))
