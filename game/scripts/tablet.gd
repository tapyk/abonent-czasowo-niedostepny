extends Control
## Johnny's cracked tablet.

const W := 112
const H := 30

var hp := 100
var max_hp := 100
var _pulse := 0.0


func _ready() -> void:
	size = Vector2(W, H)
	Game.bars_changed.connect(func(_b): queue_redraw())
	Game.stats_changed.connect(queue_redraw)


func set_hp(v: int, m: int) -> void:
	hp = v
	max_hp = m
	queue_redraw()


func _process(delta: float) -> void:
	_pulse += delta
	if Game.bars >= 4:
		queue_redraw()


func _draw() -> void:
	var f := Art.font()
	var fs := Art.FONT_SIZE
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.06, 0.08, 0.85))
	draw_rect(Rect2(0, 0, W, H), Color("4a5160"), false, 1.0)
	# crack
	draw_line(Vector2(W - 30, 0), Vector2(W - 22, 9), Color(1, 1, 1, 0.25))
	draw_line(Vector2(W - 22, 9), Vector2(W - 26, 17), Color(1, 1, 1, 0.18))
	# signal bars
	var bars := Game.bars
	var hot := bars >= 4 and fmod(_pulse, 0.6) < 0.3
	for i in Game.MAX_BARS:
		var bh := 3 + i * 2
		var r := Rect2(4 + i * 4, 13 - bh, 3, bh)
		var on := i < bars
		var c := Color("ff4a3a") if bars >= 4 else Color("e0e6ee")
		if hot: c = Color("ffb0a0")
		draw_rect(r, c if on else Color(1, 1, 1, 0.12))
	draw_string(f, Vector2(26, 12), "LTE" if bars > 0 else "BRAK ZASIĘGU", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ff6a5a") if bars >= 4 else Color("9aa3ad"))
	# HP
	draw_rect(Rect2(4, 17, 50, 4), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(4, 17, 50.0 * hp / max_hp, 4), Color("d94a4a"))
	# ammo / parts / cable
	draw_string(f, Vector2(4, H - 1), "AMMO %d" % Game.ammo, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("e8d27a") if Game.ammo > 0 else Color("ff6a5a"))
	draw_string(f, Vector2(58, 22), "CZĘŚCI %d" % Game.parts, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffa060"))
	if Game.has_cable:
		draw_string(f, Vector2(58, H - 1), "KABEL", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("8fe0a0"))
