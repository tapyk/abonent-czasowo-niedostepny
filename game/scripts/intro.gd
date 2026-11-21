extends Control
## Intro cutscene (drawn in code), ~28 s.

const W := 320.0
const H := 180.0
const CURN := Vector2(236, 118)       # CURN complex on the horizon
const T_FLASH := 3.5
const T_PHONE := 12.5
const T_RING := 12.7          # ringback (cut short when the recording starts)
const T_MESSAGE := 15.5       # operator recording (Polish part only)
const T_RADIO := 19.7         # black screen, Mama breaks through the static (just after
                              # "proszę spróbować później": the recording is 3.85 s)
const RADIO_CPS := 14.0       # typing speed of Mama's radio lines
const MAMA_LINES := [[0.6, "Johnny… nie dzwoń…"], [2.4, "…oni idą za sygnałem…"],
	[4.4, "…wyłącz anteny… jestem za jeziorem…"]]
const T_END := T_RADIO + 8.0

var _t := 0.0
var _boomed := false
var _rang := false
var _messaged := false
var _radioed := false
var _rng := RandomNumberGenerator.new()
var _buildings: Array = []            # [x, w, h] (tower pictures scaled to w x h)
var _tower: Texture2D
var _curn: Texture2D        # curn_before.png
var _curn_after: Texture2D  # curn_after.png (ruin, on fire)
const TOWER_SRC := Rect2(29, 0, 74, 128)   # used part of wiezowiec.png
## curn_before / curn_after are 256x256 with the same ground line: centre x 145, bottom 252.
const CURN_SCALE := 0.3
var _antennas: Array = []             # [pos, lit_time]
var _people: Array = []               # [x, speed, mutate_time]
var _stars: Array = []
var _shake := 0.0
var _typed := [0, 0, 0]               # letters already voiced per Mama line


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 2026
	_tower = Art.tex("res://assets/sprites/buildings/wiezowiec.png")
	_curn = Art.tex("res://assets/sprites/buildings/curn_before.png")
	_curn_after = Art.tex("res://assets/sprites/buildings/curn_after.png")
	var x := 0.0
	while x < W:
		var s := _rng.randf_range(0.18, 0.42)
		var w := TOWER_SRC.size.x * s
		var h := TOWER_SRC.size.y * s
		if absf(x + w / 2.0 - CURN.x) < 40.0:
			x += 6.0  # leave the horizon around CURN open
			continue
		_buildings.append([x, w, h])
		if _rng.randf() < 0.55 and h > 20.0:
			_antennas.append([Vector2(x + w / 2.0, 140 - h - 8), -1.0])
		x += w + _rng.randf_range(1, 4)
	for i in 6:
		_people.append([_rng.randf_range(10, 300), _rng.randf_range(6, 12) * (1 if _rng.randf() < 0.5 else -1), -1.0])
	for i in 40:
		_stars.append(Vector2(_rng.randf_range(0, W), _rng.randf_range(0, 90)))
	Sfx.set_static(0.06)  # quiet night hiss; the blast turns it up


func _process(delta: float) -> void:
	_t += delta
	_shake = maxf(_shake - delta, 0.0)
	if _t >= T_FLASH and not _boomed:
		_boomed = true
		_shake = 1.2
		Sfx.set_static(0.3)  # the hiss goes on: the signal is everywhere now
		Sfx.play("explosion", 0.0, 2.0)
	# the signal wave lights antennas and mutates people when it reaches them
	var wave := _wave_radius()
	for a in _antennas:
		if a[1] < 0.0 and wave > a[0].distance_to(CURN):
			a[1] = _t
			Sfx.play("beep", 0.2, -18.0)
	for p in _people:
		if p[2] < 0.0 and _t > T_FLASH + 6.0 and wave > absf(p[0] - CURN.x) * 0.6 + 120.0:
			p[2] = _t
			Sfx.play("growl", 0.2, -14.0)
		p[0] = wrapf(p[0] + p[1] * delta * (0.4 if p[2] > 0.0 else 1.0), -10.0, W + 10.0)
	if _t >= T_RING and not _rang:
		_rang = true
		Sfx.set_static(0.08)
		Sfx.play("ringback", 0.0, -6.0)
	if _t >= T_MESSAGE and not _messaged:
		_messaged = true
		Sfx.stop_all()  # cut the ringback
		Sfx.play("unavailable", 0.0, 0.0)
	if _t >= T_RADIO and not _radioed:
		_radioed = true
		Sfx.stop_all()  # the static breaks into the operator's recording
		Sfx.set_static(0.55)
		Sfx.play("beep", 0.0, -10.0)
	if _radioed:
		_voice_radio()
	if _t > 0.5 and Input.is_action_just_pressed("accept"):
		_finish()
	elif _t >= T_END:
		_finish()
	queue_redraw()


## Mama's voice blip for each newly typed letter of her radio lines.
func _voice_radio() -> void:
	for i in MAMA_LINES.size():
		var text: String = MAMA_LINES[i][1]
		var n := clampi(int((_t - T_RADIO - MAMA_LINES[i][0]) * RADIO_CPS), 0, text.length())
		if n > _typed[i]:
			_typed[i] = n
			if text[n - 1] not in " .,!?…[]":
				Sfx.voice("Mama", true)


func _finish() -> void:
	set_process(false)
	Sfx.set_static(0.0)
	Sfx.stop_all()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


## Signal wave from CURN, starting after the blast.
func _wave_radius() -> float:
	return maxf(_t - (T_FLASH + 2.0), 0.0) * 38.0


func _draw() -> void:
	var f := Art.font()
	var fs := Art.FONT_SIZE
	if _t >= T_RADIO:
		_draw_radio(f, fs)
		return
	var off := Vector2(randf_range(-2, 2), randf_range(-2, 2)) * _shake * 2.0
	draw_set_transform(off)
	_draw_city()
	draw_set_transform(Vector2.ZERO)
	if _t >= T_PHONE:
		_draw_phone(f, fs)
	# white flash
	if _t >= T_FLASH:
		var fa := clampf(1.0 - (_t - T_FLASH) / 1.4, 0.0, 1.0)
		if fa > 0.0:
			draw_rect(Rect2(0, 0, W, H), Color(1, 0.97, 0.9, fa))
	_captions(f, fs)


## Black screen, walkie-talkie LED and Mama's lines typed through the static.
func _draw_radio(f: Font, fs: int) -> void:
	draw_rect(Rect2(0, 0, W, H), Color.BLACK)
	var k := _t - T_RADIO
	# static snow fading as her voice comes through
	var snow := clampf(1.0 - k / 1.5, 0.15, 1.0)
	for i in int(120 * snow):
		draw_rect(Rect2(randf() * W, randf() * H, 1, 1), Color(1, 1, 1, randf() * 0.35 * snow))
	if fmod(_t, 0.5) < 0.25:
		draw_rect(Rect2(W / 2.0 - 2, 52, 4, 4), Color("ff3a2a"))
	_center(f, "MAMA  (radio)", 64, fs, Color(1.0, 0.69, 0.38, clampf(k / 0.4, 0.0, 1.0)))
	var y := 82.0
	for l in MAMA_LINES:
		if k > l[0]:
			var n := int((k - l[0]) * RADIO_CPS)
			var s: String = l[1].substr(0, n)
			_center(f, s, y, fs, Color(1.0, 0.85, 0.7, 0.95))
		y += 12.0


func _draw_city() -> void:
	var dust := clampf((_t - (T_FLASH + 1.5)) / 4.0, 0.0, 1.0)
	var top := Color("05070f").lerp(Color("1a1018"), dust)
	var bottom := Color("101830").lerp(Color("4a2a20"), dust)
	for y in range(0, 140, 4):
		draw_rect(Rect2(0, y, W, 4), top.lerp(bottom, y / 140.0))
	for s in _stars:
		draw_rect(Rect2(s, Vector2(1, 1)), Color(1, 1, 1, 0.6 * (1.0 - dust)))
	# CURN on the horizon: curn_before at night, the burning ruin (curn_after) after the blast
	var ct := _curn if _t < T_FLASH else _curn_after
	if ct:
		var s := CURN_SCALE
		var tint := Color(0.55, 0.6, 0.8) if _t < T_FLASH else Color(0.8, 0.7, 0.65)
		draw_texture_rect(ct, Rect2(CURN.x - 145.0 * s, 140.0 - 252.0 * s, 256.0 * s, 256.0 * s), false, tint)
	else:
		draw_circle(CURN + Vector2(0, 6), 12.0, Color("1a2030"))
	if _t < T_FLASH:
		if fmod(_t, 1.0) < 0.6:
			draw_rect(Rect2(CURN.x - 2, CURN.y - 2, 4, 3), Color("8ab0ff"))
		_text_small("CURN", CURN + Vector2(-10, 30))
	else:
		_draw_blast(dust)
	# dust clouds rolling over
	if dust > 0.0:
		for i in 7:
			var cx := fmod(i * 61.0 + _t * (6.0 + i), W + 80.0) - 40.0
			draw_circle(Vector2(cx, 30 + (i % 3) * 18), 30.0 + i * 3, Color(0.18, 0.1, 0.1, 0.35 * dust))
	# signal wave
	var wave := _wave_radius()
	if wave > 0.0 and wave < 500.0:
		for k in 3:
			var r := wave - k * 14.0
			if r > 0.0:
				draw_arc(CURN, r, PI, TAU, 48, Color(0.7, 0.3, 1.0, 0.35 - k * 0.1), 1.5)
	# skyline
	var night := Color(0.32, 0.36, 0.5).lerp(Color(0.2, 0.14, 0.16), dust)
	for b in _buildings:
		var r := Rect2(b[0], 140 - b[2], b[1], b[2])
		if _tower:
			draw_texture_rect_region(_tower, r, TOWER_SRC, night)
		else:
			draw_rect(Rect2(r.position, r.size + Vector2(0, 40)), Color("0b0c12"))
		# a few lit windows until the power goes
		if _t < T_FLASH + 0.5:
			var wy: float = r.position.y + 5
			while wy < 134.0:
				var wx: float = b[0] + 3
				while wx < b[0] + b[1] - 3:
					if hash(Vector2(wx, wy)) % 7 == 0:
						draw_rect(Rect2(wx, wy, 2, 2), Color("e8c060"))
					wx += 5.0
				wy += 6.0
	for a in _antennas:
		var p: Vector2 = a[0]
		draw_line(p, p + Vector2(0, 8), Color("2a2e36"), 1.0)
		if a[1] >= 0.0:
			if fmod(_t - a[1], 1.2) < 0.7:
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), Color("ff2a2a"))
				draw_circle(p, 6.0, Color(1, 0.1, 0.1, 0.15))
			var rr := fmod(_t - a[1], 1.6) * 18.0
			draw_arc(p, rr, 0, TAU, 16, Color(0.7, 0.3, 1.0, 0.4 * (1.0 - rr / 29.0)), 1.0)
	# street + people
	draw_rect(Rect2(0, 160, W, 20), Color("08080a"))
	for p in _people:
		var x: float = p[0]
		var mutated: bool = p[2] >= 0.0
		var c := Color("1a1c24")
		if mutated:
			c = Color("3a2014").lerp(Color("ff7a2a"), 0.3 + 0.2 * sin(_t * 6.0 + x))
		var lean := sin(_t * 8.0 + x) * 1.5 if mutated else 0.0
		draw_rect(Rect2(x - 2 + lean, 148, 4, 8), c)
		draw_rect(Rect2(x - 1.5 + lean * 1.5, 144, 3, 4), c)
		draw_rect(Rect2(x - 2, 156, 1.5, 5), c)
		draw_rect(Rect2(x + 0.5, 156, 1.5, 5), c)
		if mutated:
			draw_circle(Vector2(x + lean, 150), 6.0, Color(1, 0.4, 0.1, 0.12))
	# window frame (Johnny's flat, 4th floor)
	var frame := Color("1e1a16")
	draw_rect(Rect2(0, 0, W, 8), frame)
	draw_rect(Rect2(0, 0, 8, H), frame)
	draw_rect(Rect2(W - 8, 0, 8, H), frame)
	draw_rect(Rect2(W / 2.0 - 2, 0, 4, 140), frame)
	draw_rect(Rect2(0, 136, W, 6), frame)


func _draw_blast(dust: float) -> void:
	var k := _t - T_FLASH
	# fireball rising into a mushroom
	var rise := minf(k * 14.0, 60.0)
	var r := minf(6.0 + k * 9.0, 30.0)
	var heat := Color("ffd060").lerp(Color("a03a1a"), clampf(k / 5.0, 0.0, 1.0))
	draw_rect(Rect2(CURN.x - r * 0.25, CURN.y - rise, r * 0.5, rise + 6), heat.darkened(0.3))
	draw_circle(CURN + Vector2(0, -rise), r, heat)
	draw_circle(CURN + Vector2(-r * 0.6, -rise + 4), r * 0.6, heat.darkened(0.2))
	draw_circle(CURN + Vector2(r * 0.6, -rise + 4), r * 0.6, heat.darkened(0.2))
	draw_circle(CURN + Vector2(0, -rise), r * 2.2, Color(1, 0.5, 0.2, 0.12 * (1.0 - dust * 0.5)))
	# shockwave ring
	var sw := k * 120.0
	if sw < 400.0:
		draw_arc(CURN, sw, PI, TAU, 64, Color(1, 0.9, 0.7, 0.6 * (1.0 - sw / 400.0)), 2.0)


func _draw_phone(f: Font, fs: int) -> void:
	var a := clampf((_t - T_PHONE) / 0.5, 0.0, 1.0)
	var r := Rect2(106, 30, 108, 120)
	draw_rect(r.grow(2), Color(0.1, 0.1, 0.12, a))
	draw_rect(r, Color(0.04, 0.05, 0.07, a))
	draw_rect(Rect2(r.position + Vector2(4, 8), r.size - Vector2(8, 20)), Color(0.08, 0.1, 0.14, a))
	_center_in(f, "MAMA", r, 30, fs, Color(1, 1, 1, a))
	if _t < T_MESSAGE:
		var dots := ".".repeat(int(_t * 3.0) % 4)
		_center_in(f, "łączenie" + dots, r, 46, fs, Color(0.7, 0.75, 0.8, a))
	else:
		_center_in(f, "Abonent", r, 52, fs, Color("ff6a5a"))
		_center_in(f, "czasowo", r, 62, fs, Color("ff6a5a"))
		_center_in(f, "niedostępny", r, 72, fs, Color("ff6a5a"))
	draw_circle(r.position + Vector2(r.size.x / 2.0, 92), 7.0, Color(0.85, 0.2, 0.2, a))


func _captions(f: Font, fs: int) -> void:
	var caps := [[0.3, T_FLASH - 0.2, "Noc. Widok z okna, 4. piętro."],
		[T_FLASH + 2.0, T_FLASH + 6.4, "Sygnał z CURNu wszedł do sieci LTE."],
		[T_FLASH + 3.6, T_FLASH + 6.4, "Każda antena nadaje go dalej."],
		[T_FLASH + 6.6, T_PHONE + 2.0, "Ludzie w zasięgu mutują."],
		[T_FLASH + 7.4, T_PHONE + 2.0, "Mutanci idą za sygnałem."]]  # ~3.6 s, stays under the phone
	var shown := caps.filter(func(c): return _t >= c[0] and _t < c[1])
	var y := 170.0 - 11.0 * (shown.size() - 1)
	for c in shown:
		var a := clampf((_t - c[0]) / 0.4, 0.0, 1.0) * clampf((c[1] - _t) / 0.4, 0.0, 1.0)
		draw_rect(Rect2(0, y - 9, W, 11), Color(0, 0, 0, 0.6 * a))
		_center(f, c[2], y, fs, Color(0.92, 0.92, 0.92, a))
		y += 11.0
	if _t > 1.0 and fmod(_t, 1.2) < 0.8:
		draw_string(f, Vector2(0, 20), "[ENTER] pomiń", HORIZONTAL_ALIGNMENT_RIGHT, W - 12, fs, Color(0.6, 0.6, 0.65, 0.6))


func _text_small(s: String, at: Vector2) -> void:
	draw_string(Art.font(), at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, Art.FONT_SIZE, Color(0.5, 0.6, 0.8, 0.8))


func _center(f: Font, text: String, y: float, fs: int, c: Color) -> void:
	draw_string(f, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, W, fs, c)


func _center_in(f: Font, text: String, r: Rect2, y: float, fs: int, c: Color) -> void:
	draw_string(f, Vector2(r.position.x, r.position.y + y), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, c)
