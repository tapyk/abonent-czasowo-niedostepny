extends Control
## Bottom dialog strip.

const W := 210
const BOTTOM := 177.0
const PAD := 4.0
const LINE := 9.0

var _h := 22.0
const CPS := 20.0

var _queue: Array = []
var _speaker := ""
var _full := ""
var _shown := 0.0
var _hold := 0.0
var _radio := false
var _active := false
var _led := 0.0
var _typed := 0


func _ready() -> void:
	size = Vector2(W, _h)
	visible = false
	Game.say.connect(enqueue)


func enqueue(speaker: String, text: String, radio: bool, urgent := false) -> void:
	# Don't stack the same line (e.g. repeated "no ammo").
	if _active and _full == text or _queue.any(func(q): return q[1] == text):
		return
	if urgent:
		# Right after the current line, ahead of older story lines.
		var at := 0
		while at < _queue.size() and _queue[at][3]:
			at += 1
		_queue.insert(at, [speaker, text, radio, true])
	else:
		_queue.append([speaker, text, radio, false])
	if not _active:
		_next()


func is_busy() -> bool:
	return _active or not _queue.is_empty()


func _next() -> void:
	if _queue.is_empty():
		_active = false
		visible = false
		Sfx.set_static(0.0)
		return
	var q: Array = _queue.pop_front()
	_speaker = q[0]
	_radio = q[2]
	_full = _corrupt(q[1]) if _radio else q[1]
	_shown = 0.0
	_hold = 1.8 + _full.length() * 0.045
	_typed = 0
	var lines := maxi(1, roundi(Art.font().get_multiline_string_size(_full, HORIZONTAL_ALIGNMENT_LEFT,
		W - PAD * 2, Art.FONT_SIZE).y / LINE))
	_h = PAD + LINE + lines * LINE + 2.0
	size = Vector2(W, _h)
	position.y = BOTTOM - _h
	_active = true
	visible = true
	Sfx.set_static(Game.radio_noise() if _radio else 0.0)
	if _radio:
		Sfx.play("beep", 0.0, -10.0)


func _corrupt(text: String) -> String:
	var noise := Game.radio_noise()
	var words := text.split(" ")
	var out: PackedStringArray = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(text) + Game.disabled_count
	# Light touch: a few words drop out, never two in a row, so lines stay readable.
	var dropped := false
	for w in words:
		if not dropped and w.length() > 3 and rng.randf() < noise * 0.14:
			out.append("…")
			dropped = true
		else:
			out.append(w)
			dropped = false
	return " ".join(out)


func _process(delta: float) -> void:
	if not _active:
		return
	_led += delta
	if _shown < _full.length():
		_shown += CPS * delta
		if Input.is_action_just_pressed("accept") and not Game.hacking:
			_shown = _full.length()
		else:
			_blip()
		_typed = int(_shown)
	else:
		# More lines waiting -> don't linger on this one.
		_hold -= delta * (1.6 if not _queue.is_empty() else 1.0)
		if _hold <= 0.0 or (Input.is_action_just_pressed("accept") and not Game.hacking):
			_next()
	queue_redraw()


## Undertale-style voice: one blip per newly typed letter (spaces and punctuation stay silent).
func _blip() -> void:
	var now := int(_shown)
	if now <= _typed or now > _full.length():
		return
	var c := _full[now - 1]
	if c == " " or c in ".,!?…:;-–—()\"'„”":
		return
	Sfx.voice(_speaker, _radio)


func _draw() -> void:
	var f := Art.font()
	var fs := Art.FONT_SIZE
	draw_rect(Rect2(0, 0, W, _h), Color(0.03, 0.04, 0.05, 0.85))
	var edge := Color("a8743a") if _radio else Color("4a5160")
	draw_rect(Rect2(0, 0, W, _h), edge, false, 1.0)
	var name_col := Color("ffb060") if _radio else (Color("8fc0ff") if _speaker == "Johnny" else Color("c0c8d0"))
	var label := _speaker.to_upper()
	if _radio:
		label += "  (radio)"
		# walkie-talkie LED
		draw_rect(Rect2(W - 6, 3, 2, 2), Color("ff3a2a") if fmod(_led, 0.5) < 0.25 else Color("5a1a14"))
	draw_string(f, Vector2(PAD, PAD + 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, name_col)
	var txt := _full.substr(0, int(_shown))
	draw_multiline_string(f, Vector2(PAD, PAD + 5 + LINE), txt, HORIZONTAL_ALIGNMENT_LEFT, W - PAD * 2, fs, -1, Color("e6e6e6"))
