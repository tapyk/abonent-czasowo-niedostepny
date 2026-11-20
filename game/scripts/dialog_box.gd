extends Control
## Bottom dialog strip.

const W := 234
const H := 42
const CPS := 38.0

var _queue: Array = []
var _speaker := ""
var _full := ""
var _shown := 0.0
var _hold := 0.0
var _radio := false
var _active := false
var _led := 0.0


func _ready() -> void:
	size = Vector2(W, H)
	visible = false
	Game.say.connect(enqueue)


func enqueue(speaker: String, text: String, radio: bool) -> void:
	# Don't stack the same line (e.g. repeated "no ammo").
	if _active and _full == text or _queue.any(func(q): return q[1] == text):
		return
	_queue.append([speaker, text, radio])
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
	_hold = 1.4 + _full.length() * 0.035
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
	for w in words:
		var r := rng.randf()
		if r < noise * 0.45:
			out.append("…" if rng.randf() < 0.6 else "[szum]")
		else:
			out.append(w)
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
		_hold -= delta
		if _hold <= 0.0 or (Input.is_action_just_pressed("accept") and not Game.hacking and _hold < 1.0):
			_next()
	queue_redraw()


func _draw() -> void:
	var f := Art.font()
	var fs := Art.FONT_SIZE
	draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.04, 0.05, 0.88))
	var edge := Color("a8743a") if _radio else Color("4a5160")
	draw_rect(Rect2(0, 0, W, H), edge, false, 1.0)
	var name_col := Color("ffb060") if _radio else (Color("8fc0ff") if _speaker == "Johnny" else Color("c0c8d0"))
	var label := _speaker.to_upper()
	if _radio:
		label += "  (radio)"
		# walkie-talkie LED
		draw_rect(Rect2(W - 8, 4, 3, 3), Color("ff3a2a") if fmod(_led, 0.5) < 0.25 else Color("5a1a14"))
	draw_string(f, Vector2(5, 10), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, name_col)
	var txt := _full.substr(0, int(_shown))
	draw_multiline_string(f, Vector2(5, 21), txt, HORIZONTAL_ALIGNMENT_LEFT, W - 10, fs, 3, Color("e6e6e6"))
