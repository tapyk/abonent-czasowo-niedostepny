extends Control
## Johnny's cracked tablet in the bottom-right corner.

const W := 52
const H := 40
const SCREEN := Rect2(3, 3, 46, 30)
const PEEK := 12.0          # visible strip when tucked away
const SLIDE_SPEED := 6.0

## Fully slid-out position (set by the HUD).
var base_position := Vector2.ZERO
var _open := 0.0

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
	var m := get_local_mouse_position()
	var hover := Rect2(-4, -6, W + 8, H + 12).has_point(m)
	_open = move_toward(_open, 1.0 if hover else 0.0, delta * SLIDE_SPEED)
	var e := ease(_open, -2.0)
	position = base_position + Vector2(0, (H - PEEK) * (1.0 - e))
	queue_redraw()


func is_open() -> bool:
	return _open >= 1.0


func _draw() -> void:
	var f := Art.font()
	var fs := Art.FONT_SIZE
	var bars := Game.bars
	var hot := bars >= 4
	var o := Vector2(0, -2.0 * _bump / 0.25)
	# body / bezel
	draw_rect(Rect2(o, Vector2(W, H)), Color("15171c"))
	var edge := Color("ff4a3a") if hot and fmod(_pulse, 0.6) < 0.3 else Color("4a5160")
	draw_rect(Rect2(o, Vector2(W, H)), edge, false, 1.0)
	draw_rect(Rect2(o + Vector2(W / 2.0 - 2, H - 4), Vector2(4, 2)), Color("3a3e46"))  # home button
	draw_rect(Rect2(o + Vector2(W / 2.0 - 1, 1), Vector2(2, 1)), Color("3a3e46"))      # camera
	# screen
	var scr := Rect2(SCREEN.position + o, SCREEN.size)
	var bg := Color("06100a") if bars == 0 else (Color("1a0806") if hot else Color("0a0d14"))
	draw_rect(scr, bg)
	var tl := scr.position
	# status line: carrier + mini bars (all that shows while tucked away)
	draw_string(f, tl + Vector2(2, 7), "LTE" if bars > 0 else "---", HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
		Color("ff6a5a") if hot else Color("6a7480"))
	for i in Game.MAX_BARS:
		var bh := 1 + i
		var on := i < bars
		var mc := (Color("ff4a3a") if hot else Color("e0e6ee")) if on else Color(1, 1, 1, 0.15)
		draw_rect(Rect2(tl + Vector2(29 + i * 3, 7 - bh), Vector2(2, bh)), mc)
	if bars == 0:
		var g := Color("8fe0a0")
		g.a = 0.75 + 0.25 * sin(_pulse * 2.0)
		draw_string(f, tl + Vector2(0, 17), "BRAK", HORIZONTAL_ALIGNMENT_CENTER, scr.size.x, fs, g)
		draw_string(f, tl + Vector2(0, 26), "ZASIĘGU", HORIZONTAL_ALIGNMENT_CENTER, scr.size.x, fs, g)
	else:
		var flick := hot and fmod(_pulse, 0.6) < 0.3
		for i in Game.MAX_BARS:
			var bh := 3 + i * 3
			var r := Rect2(tl + Vector2(9 + i * 6, 21 - bh), Vector2(4, bh))
			var c := Color("ff4a3a") if hot else Color("e0e6ee")
			if flick: c = Color("ffb0a0")
			draw_rect(r, c if i < bars else Color(1, 1, 1, 0.1))
		var label := "UWAGA!" if hot else "%d/5" % bars
		draw_string(f, tl + Vector2(0, 29), label, HORIZONTAL_ALIGNMENT_CENTER, scr.size.x, fs,
			Color("ff6a5a") if hot else Color("9aa3ad"))
	# crack across the glass
	draw_line(tl + Vector2(scr.size.x - 10, 0), tl + Vector2(scr.size.x - 6, 7), Color(1, 1, 1, 0.22))
	draw_line(tl + Vector2(scr.size.x - 6, 7), tl + Vector2(scr.size.x - 9, 13), Color(1, 1, 1, 0.16))
	draw_line(tl + Vector2(scr.size.x - 6, 7), tl + Vector2(scr.size.x, 9), Color(1, 1, 1, 0.12))
