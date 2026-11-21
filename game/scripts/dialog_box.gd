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
var _urgent := false
## A face-to-face conversation (Farmer, Donald, Mama) is running: see begin_conversation().
var _conv := false
var _active := false
var _led := 0.0
var _typed := 0
## Speaker of the line before this one in the same run of lines ("" at the start).
var _prev_speaker := ""
## Online client: the host says whether this line is muttered (see is_mutter()).
var _mirror_mutter := false
## Who can mutter to himself (the players).
const SELF_TALKERS := ["Johnny", "Białawski"]


func _ready() -> void:
	size = Vector2(W, _h)
	visible = false
	Game.say.connect(enqueue)


func enqueue(speaker: String, text: String, radio: bool, urgent := false) -> void:
	if Net.is_client():
		return  # the host's dialog comes in line by line (mirror_line)
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
		_conv = false
		Sfx.set_static(0.0)
		_set_lock()
		Net.send_dialog_end()
		return
	var q: Array = _queue.pop_front()
	_prev_speaker = _speaker if _active else ""
	_urgent = q[3]
	_show_line(q[0], _corrupt(q[1]) if q[2] else q[1], q[2])
	# at the end of the frame, once the rest of this run of lines is queued
	_send_line.call_deferred()


func _send_line() -> void:
	if _active:
		Net.send_dialog_line(_speaker, _full, _radio, is_mutter())


## Johnny (or Białawski) talking to himself.
func is_mutter() -> bool:
	if Net.is_client():
		return _mirror_mutter
	if _radio or _conv or not _speaker in SELF_TALKERS:
		return false
	if _prev_speaker != "" and _prev_speaker != _speaker:
		return false
	return _queue.is_empty() or _queue[0][0] == _speaker


## Online client: the host started this line (already corrupted on the host).
func mirror_line(speaker: String, text: String, radio: bool, mutter := false) -> void:
	_mirror_mutter = mutter
	_show_line(speaker, text, radio)


func mirror_end() -> void:
	_active = false
	visible = false
	Sfx.set_static(0.0)


func _show_line(speaker: String, text: String, radio: bool) -> void:
	_speaker = speaker
	_radio = radio
	_full = text
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
	_set_lock()
	Sfx.set_static(Game.radio_noise() if _radio else 0.0)
	if _radio:
		Sfx.play("beep", 0.0, -10.0)


func begin_conversation() -> void:
	if not is_busy():
		return
	_conv = true
	_set_lock()


func _set_lock() -> void:
	if Net.is_client():
		return  # the host's lock comes with its snapshots
	Game.dialog_lock = _active and _conv


func _exit_tree() -> void:
	Game.dialog_lock = false


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
		if _skip_pressed():
			_shown = _full.length()
		else:
			_blip()
		_typed = int(_shown)
	elif not Net.is_client():  # the client waits for the host's next line
		# More lines waiting -> don't linger on this one.
		_hold -= delta * (1.6 if not _queue.is_empty() else 1.0)
		if _hold <= 0.0 or _skip_pressed():
			_next()
	queue_redraw()


## Enter (or online Player 2's Enter, sent to the host) skips typing / the line.
func _skip_pressed() -> bool:
	if Game.hacking:
		return false
	return Input.is_action_just_pressed("accept") or (Net.is_host() and Net.consume("accept"))


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
	var name_col := Color("c0c8d0")
	if _radio:
		name_col = Color("ffb060")
	elif _speaker == "Johnny":
		name_col = Color("8fc0ff")  # P1's colour
	elif _speaker == "Białawski":
		name_col = Color("8fe0a0")  # P2's colour
	var label := _speaker.to_upper()
	if _radio:
		label += "  (radio)"
		# walkie-talkie LED
		draw_rect(Rect2(W - 6, 3, 2, 2), Color("ff3a2a") if fmod(_led, 0.5) < 0.25 else Color("5a1a14"))
	var text_col := Color("e6e6e6")
	if is_mutter():
		# under his breath: fainter name and text
		name_col.a = 0.55
		text_col.a = 0.5
	draw_string(f, Vector2(PAD, PAD + 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, name_col)
	if Game.dialog_lock and fmod(_led, 1.0) < 0.7:
		draw_string(f, Vector2(0, PAD + 5), "[Enter]", HORIZONTAL_ALIGNMENT_RIGHT, W - PAD, fs, Color("8a929c"))
	var txt := _full.substr(0, int(_shown))
	draw_multiline_string(f, Vector2(PAD, PAD + 5 + LINE), txt, HORIZONTAL_ALIGNMENT_LEFT, W - PAD * 2, fs, -1, text_col)
