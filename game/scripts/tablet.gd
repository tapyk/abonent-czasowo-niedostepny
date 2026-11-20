extends Control
## Johnny's cracked tablet in the bottom-right corner.

const W := 76
const H := 56
const SCREEN := Rect2(5, 5, 66, 42)

var _pulse := 0.0
var _last_bars := -1
var _bump := 0.0


func _ready() -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Game.bars_changed.connect(_on_bars)


func _on_bars(b: int) -> void:
	if b > _last_bars and _last_bars >= 0:
		_bump = 0.25
	_last_bars = b
	queue_redraw()


func _process(delta: float) -> void:
	_pulse += delta
	_bump = maxf(_bump - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var f := Art.font()
	var fs := Art.FONT_SIZE
	var bars := Game.bars
	var hot := bars >= 4
	var o := Vector2(0, -2.0 * _bump / 0.25)
	# body / bezel
	draw_rect(Rect2(o, Vector2(W, H)), Color("15171c"))
	draw_rect(Rect2(o + Vector2(1, 1), Vector2(W - 2, H - 2)), Color("2a2e36"), false, 1.0)
	var edge := Color("ff4a3a") if hot and fmod(_pulse, 0.6) < 0.3 else Color("4a5160")
	draw_rect(Rect2(o, Vector2(W, H)), edge, false, 1.0)
	draw_circle(o + Vector2(W / 2.0, H - 4.5), 2.0, Color("3a3e46"))         # home button
	draw_rect(Rect2(o + Vector2(W / 2.0 - 1, 2), Vector2(2, 1)), Color("3a3e46"))  # camera
	# screen
	var scr := Rect2(SCREEN.position + o, SCREEN.size)
	var bg := Color("06100a") if bars == 0 else (Color("1a0806") if hot else Color("0a0d14"))
	draw_rect(scr, bg)
	var tl := scr.position
	# status line: carrier + clock
	draw_string(f, tl + Vector2(2, 8), "LTE" if bars > 0 else "---", HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
		Color("ff6a5a") if hot else Color("6a7480"))
	draw_string(f, tl + Vector2(34, 8), "4:04", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("6a7480"))
	if bars == 0:
		var g := Color("8fe0a0")
		g.a = 0.75 + 0.25 * sin(_pulse * 2.0)
		draw_string(f, tl + Vector2(0, 23), "BRAK", HORIZONTAL_ALIGNMENT_CENTER, scr.size.x, fs, g)
		draw_string(f, tl + Vector2(0, 33), "ZASIĘGU", HORIZONTAL_ALIGNMENT_CENTER, scr.size.x, fs, g)
		for i in Game.MAX_BARS:
			var bh := 2 + i
			draw_rect(Rect2(tl + Vector2(22 + i * 5, 41 - bh), Vector2(3, bh)), Color(1, 1, 1, 0.12))
		draw_line(tl + Vector2(20, 41), tl + Vector2(46, 34), Color("8fe0a0"), 1.0)
	else:
		var flick := hot and fmod(_pulse, 0.6) < 0.3
		for i in Game.MAX_BARS:
			var bh := 5 + i * 4
			var r := Rect2(tl + Vector2(14 + i * 8, 33 - bh), Vector2(6, bh))
			var c := Color("ff4a3a") if hot else Color("e0e6ee")
			if flick: c = Color("ffb0a0")
			draw_rect(r, c if i < bars else Color(1, 1, 1, 0.1))
		var label := "UWAGA!" if hot else "%d/5" % bars
		draw_string(f, tl + Vector2(0, 41), label, HORIZONTAL_ALIGNMENT_CENTER, scr.size.x, fs,
			Color("ff6a5a") if hot else Color("9aa3ad"))
	# crack across the glass
	draw_line(tl + Vector2(scr.size.x - 14, 0), tl + Vector2(scr.size.x - 8, 10), Color(1, 1, 1, 0.22))
	draw_line(tl + Vector2(scr.size.x - 8, 10), tl + Vector2(scr.size.x - 12, 19), Color(1, 1, 1, 0.16))
	draw_line(tl + Vector2(scr.size.x - 8, 10), tl + Vector2(scr.size.x, 13), Color(1, 1, 1, 0.12))
