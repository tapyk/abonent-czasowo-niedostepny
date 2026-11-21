extends Control
## Hard-mode multi-stage antenna hacking panel drawn in authentic 320x180 pixel art.

const PANEL := Vector2(150, 142)
const PAIRS := [[3, 7], [8, 4], [6, 4], [9, 5], [2, 8], [7, 3], [5, 2], [4, 9]]

var antenna: Node = null
var player: Node = null
var notes_hud: Control = null
var active := false
var ant_id := "a1"
var stage := 0
var cursor := 0
var status_msg := ""
var status_ok := true

var _open_t := 0.0
var _flash := 0.0
var _blink := 0.0

# Antenna 1 (PIN 4074 + 865 MHz -> Suppression with Heat & 50% Drift)
var a1_pin: Array[int] = [4, 0, 7, 0]
var a1_freq := 850
var a1_prog := 0.0
var a1_heat := 0.0
var a1_drifted := false

# Antenna 2 (4 Jumpers + Red Diode -> Dual Mode Checksum -> Discharge)
var a2_jumpers: Array[bool] = [true, false, false, true] # base: GÓRA, DÓŁ, DÓŁ, GÓRA -> target: GÓRA, GÓRA, DÓŁ, DÓŁ
var a2_hits := 0
var a2_green := true
var a2_pair_a := 3
var a2_pair_b := 7
var a2_pair_t := 1.6
var a2_roll_idx := 0
var a2_prog := 0.0
var a2_heat := 0.0

# Antenna 3 (Transformers T2->T3->T1 + Phase -3 -> Shutdown with Tripping Fuses)
var a3_seq: Array[int] = []
var a3_phase := 0
var a3_prog := 0.0
var a3_fuse_a := false
var a3_fuse_b := false
var a3_fuse_t := 2.4


func _ready() -> void:
	add_to_group("hack_ui")
	visible = false
	custom_minimum_size = PANEL
	size = PANEL


func open(a: Node, p: Node) -> void:
	if not Game.is_hard():
		return
	antenna = a
	player = p
	ant_id = str(a.antenna_id)
	stage = int(Game.hard_stage.get(ant_id, 0))
	cursor = 0
	_open_t = 0.25
	_flash = 0.0
	status_msg = _default_status()
	status_ok = true
	if ant_id == "a2" and stage == 1 and a2_hits == 0:
		_roll_a2_pair(true)
	if is_instance_valid(notes_hud):
		notes_hud.active_group = ant_id
	visible = true
	active = true
	p.set_hacking(true)
	Sfx.play("beep")


func close() -> void:
	visible = false
	active = false
	if is_instance_valid(notes_hud):
		notes_hud.active_group = ""
	if is_instance_valid(player):
		player.set_hacking(false)


func _default_status() -> String:
	match ant_id:
		"a1":
			return "Wpisz PIN i pasmo MHz" if stage == 0 else "Trzymaj tłumienie (uwaga TEMP!)"
		"a2":
			if stage == 0: return "Ustaw 4 zworki (dioda CZERWONA!)"
			if stage == 1: return "Łap pary zgodne z kolorem lampki"
			return "Przytrzymaj rozładowanie"
		"a3":
			return "Odłącz T1-T3 (od max kW) i fazę" if stage == 0 else "Klikaj wybijające bezpieczniki!"
	return ""


func _advance_stage(next_st: int, msg: String) -> void:
	stage = next_st
	Game.set_hard_stage(ant_id, stage)
	cursor = 0
	status_msg = msg
	status_ok = true
	Sfx.play("confirm", 0.05, -5.0)
	if ant_id == "a2" and stage == 1:
		a2_hits = 0
		_roll_a2_pair(true)
	elif ant_id == "a3" and stage == 1:
		a3_prog = 0.0
		a3_fuse_a = false
		a3_fuse_b = false
		a3_fuse_t = 2.2


func _fail_msg(msg: String) -> void:
	status_msg = msg
	status_ok = false
	_flash = 0.35
	Game.add_error()


func _finish() -> void:
	var a := antenna
	close()
	Game.set_hard_stage(ant_id, 0)
	if is_instance_valid(a):
		a.on_hacked()


## Player 2 on the shared screen: no mouse, ENTER / L labels.
func _is_p2() -> bool:
	return is_instance_valid(player) and Game.is_shared_p2(player)


func _just(action: String) -> bool:
	return Input.is_action_just_pressed(Game.action_for(player, action))


func _just_up() -> bool:
	return _just("move_up")


func _just_down() -> bool:
	return _just("move_down")


func _just_left() -> bool:
	return _just("move_left")


func _just_right() -> bool:
	return _just("move_right")


func _just_confirm() -> bool:
	return _just("accept")


func _hold_charge() -> bool:
	var btn_rect := Rect2(10, 94, 130, 26)
	var mouse_hold := (not _is_p2()) and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and btn_rect.has_point(get_local_mouse_position())
	return mouse_hold or Input.is_action_pressed(Game.action_for(player, "accept"))


func _just_leave() -> bool:
	return Input.is_action_just_pressed("back") or _just("interact")


func _process(delta: float) -> void:
	if not active:
		return
	_blink += delta
	_flash = maxf(_flash - delta, 0.0)
	_open_t -= delta
	if not is_instance_valid(player) or player.dead:
		close()
		return
	if _open_t <= 0.0 and _just_leave():
		close()
		return

	match ant_id:
		"a1":
			_step_a1(delta)
		"a2":
			_step_a2(delta)
		"a3":
			_step_a3(delta)
	queue_redraw()


func _step_a1(delta: float) -> void:
	if stage == 0:
		if _just_left(): cursor = wrapi(cursor - 1, 0, 6); Sfx.play("beep", 0.05, -12.0)
		elif _just_right(): cursor = wrapi(cursor + 1, 0, 6); Sfx.play("beep", 0.05, -12.0)
		elif _just_up():
			if cursor < 4: a1_pin[cursor] = wrapi(a1_pin[cursor] + 1, 0, 10)
			elif cursor == 4: a1_freq = clampi(a1_freq + 5, 820, 900)
			Sfx.play("beep", 0.05, -12.0)
		elif _just_down():
			if cursor < 4: a1_pin[cursor] = wrapi(a1_pin[cursor] - 1, 0, 10)
			elif cursor == 4: a1_freq = clampi(a1_freq - 5, 820, 900)
			Sfx.play("beep", 0.05, -12.0)
		elif _open_t <= 0.0 and _just_confirm():
			_submit_a1_stage0()
	else:
		if _just_left(): a1_freq = clampi(a1_freq - 5, 820, 900); Sfx.play("beep", 0.05, -12.0)
		elif _just_right(): a1_freq = clampi(a1_freq + 5, 820, 900); Sfx.play("beep", 0.05, -12.0)
		var tuned := (a1_freq == 865)
		if tuned and a1_drifted and not status_ok and a1_heat < 90.0:
			status_msg = "Pasmo 865 MHz OK! Trzymaj dalej"
			status_ok = true
		if _open_t <= 0.0 and _hold_charge():
			a1_heat = minf(100.0, a1_heat + 34.0 * delta)
			if a1_heat >= 100.0:
				a1_heat = 30.0
				a1_prog = maxf(0.0, a1_prog - 15.0)
				_fail_msg("PRZEGRZANIE! Chłodzenie...")
			elif tuned:
				a1_prog = minf(100.0, a1_prog + 14.0 * delta)
				if not a1_drifted and a1_prog >= 50.0:
					a1_drifted = true
					a1_freq = 845
					status_msg = "DRYF! Wróć na 865 MHz!"
					status_ok = false
					Sfx.play("beep", 0.1, -4.0)
			else:
				a1_prog = maxf(0.0, a1_prog - 4.0 * delta)
		else:
			a1_heat = maxf(0.0, a1_heat - 46.0 * delta)
			if not tuned:
				a1_prog = maxf(0.0, a1_prog - 2.5 * delta)
		if a1_prog >= 100.0:
			_finish()


func _submit_a1_stage0() -> void:
	var pin_ok := (a1_pin == [4, 0, 7, 4])
	var freq_ok := (a1_freq == 865)
	if pin_ok and freq_ok:
		a1_prog = 0.0
		a1_heat = 0.0
		a1_drifted = false
		_advance_stage(1, "OK! Trzymaj SPACJA/LPM")
	elif not pin_ok and not freq_ok:
		_fail_msg("Zły PIN i złe pasmo MHz!")
	elif not pin_ok:
		_fail_msg("Zły PIN! (407? -> piętro)")
	else:
		_fail_msg("Złe pasmo! (baza + odchyłka)")
func _step_a2(delta: float) -> void:
	if stage == 0:
		if _just_left(): cursor = wrapi(cursor - 1, 0, 5); Sfx.play("beep", 0.05, -12.0)
		elif _just_right(): cursor = wrapi(cursor + 1, 0, 5); Sfx.play("beep", 0.05, -12.0)
		elif (_just_up() or _just_down()) and cursor < 4:
			a2_jumpers[cursor] = not a2_jumpers[cursor]
			Sfx.play("beep", 0.05, -10.0)
		elif _open_t <= 0.0 and _just_confirm():
			if cursor < 4:
				a2_jumpers[cursor] = not a2_jumpers[cursor]
				Sfx.play("beep", 0.05, -10.0)
			else:
				_submit_a2_stage0()
	elif stage == 1:
		a2_pair_t -= delta
		if a2_pair_t <= 0.0:
			_roll_a2_pair(false)
		if _open_t <= 0.0 and _just_confirm():
			_submit_a2_pair()
	else:
		if _open_t <= 0.0 and _hold_charge():
			a2_heat = minf(100.0, a2_heat + 28.0 * delta)
			if a2_heat >= 100.0:
				a2_heat = 25.0
				a2_prog = maxf(0.0, a2_prog - 12.0)
				_fail_msg("PRZEGRZANIE kondensatorów!")
			else:
				a2_prog = minf(100.0, a2_prog + 18.0 * delta)
		else:
			a2_heat = maxf(0.0, a2_heat - 45.0 * delta)
		if a2_prog >= 100.0:
			_finish()


func _submit_a2_stage0() -> void:
	if a2_jumpers == [true, true, false, false]:
		_advance_stage(1, "Zworki OK! Łap pary (3x)")
	else:
		_fail_msg("Złe zworki! (notatka Farmera)")


func _roll_a2_pair(force_valid: bool) -> void:
	a2_pair_t = 1.65
	a2_roll_idx += 1
	if force_valid or (a2_roll_idx % 2 == 0):
		a2_green = (a2_roll_idx % 4 == 0)
		var valid_p: Array = ([3, 7] if randf() < 0.5 else [6, 4]) if a2_green else ([8, 4] if randf() < 0.5 else [9, 5])
		a2_pair_a = valid_p[0]
		a2_pair_b = valid_p[1]
	else:
		a2_green = (randf() < 0.5)
		var p: Array = PAIRS[randi() % PAIRS.size()]
		a2_pair_a = p[0]
		a2_pair_b = p[1]


func _submit_a2_pair() -> void:
	var ok := (a2_pair_a + a2_pair_b == 10) if a2_green else (absi(a2_pair_a - a2_pair_b) == 4)
	if ok:
		a2_hits += 1
		Sfx.play("confirm", 0.05, -6.0)
		status_msg = "Trafiono %d / 3!" % a2_hits
		status_ok = true
		if a2_hits >= 3:
			a2_prog = 0.0
			a2_heat = 0.0
			_advance_stage(2, "OK! Przytrzymaj rozładowanie")
		else:
			_roll_a2_pair(false)
	else:
		a2_hits = maxi(0, a2_hits - 1)
		_fail_msg("Zła para dla tej lampki!")


func _step_a3(delta: float) -> void:
	if stage == 0:
		if _just_left(): cursor = wrapi(cursor - 1, 0, 6); Sfx.play("beep", 0.05, -12.0)
		elif _just_right(): cursor = wrapi(cursor + 1, 0, 6); Sfx.play("beep", 0.05, -12.0)
		elif _just_up() and cursor == 4: a3_phase = clampi(a3_phase + 1, -5, 5); Sfx.play("beep", 0.05, -12.0)
		elif _just_down() and cursor == 4: a3_phase = clampi(a3_phase - 1, -5, 5); Sfx.play("beep", 0.05, -12.0)
		elif _open_t <= 0.0 and _just_confirm():
			if cursor < 3:
				var tn := cursor + 1
				if not a3_seq.has(tn):
					a3_seq.append(tn)
					Sfx.play("beep", 0.05, -10.0)
			elif cursor == 3:
				a3_seq.clear()
				Sfx.play("beep", 0.05, -10.0)
			elif cursor == 5:
				_submit_a3_stage0()
	else:
		if _open_t <= 0.0 and _just_confirm():
			if a3_fuse_a:
				a3_fuse_a = false; Sfx.play("confirm", 0.05, -8.0)
			elif a3_fuse_b:
				a3_fuse_b = false; Sfx.play("confirm", 0.05, -8.0)
			if not a3_fuse_a and not a3_fuse_b:
				status_msg = "Bezpieczniki OK - wygaszanie..."
				status_ok = true
		if not a3_fuse_a and not a3_fuse_b:
			a3_prog = minf(100.0, a3_prog + 12.0 * delta)
			a3_fuse_t -= delta
			if a3_fuse_t <= 0.0 and a3_prog < 92.0:
				a3_fuse_t = 2.6
				if randf() < 0.5: a3_fuse_a = true
				else: a3_fuse_b = true
				status_msg = "WYBIŁ BEZPIECZNIK! Wciśnij!"
				status_ok = false
				Sfx.play("beep", 0.1, -4.0)
		if a3_prog >= 100.0:
			_finish()


func _submit_a3_stage0() -> void:
	var seq_ok := (a3_seq == [2, 3, 1])
	var ph_ok := (a3_phase == -3)
	if seq_ok and ph_ok:
		_advance_stage(1, "OK! Pilnuj bezpieczników B1/B2")
	elif not seq_ok:
		a3_seq.clear()
		_fail_msg("Zła kolejność! (od największej mocy)")
	else:
		_fail_msg("Zła faza! (przeciwna do zewnętrznej)")
func _input(event: InputEvent) -> void:
	if not active or _open_t > 0.0:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kc: int = event.physical_keycode
		if ant_id == "a1" and stage == 0:
			var digit := -1
			if kc >= KEY_0 and kc <= KEY_9:
				digit = kc - KEY_0
			elif kc >= KEY_KP_0 and kc <= KEY_KP_9:
				digit = kc - KEY_KP_0
			if digit >= 0 and cursor < 4:
				a1_pin[cursor] = digit
				cursor = mini(cursor + 1, 4)
				Sfx.play("beep", 0.05, -10.0)
				return
		elif ant_id == "a3" and stage == 1:
			if kc in [KEY_1, KEY_KP_1] and a3_fuse_a:
				a3_fuse_a = false; status_msg = "Bezpiecznik B1 OK!"; status_ok = true; Sfx.play("confirm", 0.05, -8.0); return
			if kc in [KEY_2, KEY_KP_2] and a3_fuse_b:
				a3_fuse_b = false; status_msg = "Bezpiecznik B2 OK!"; status_ok = true; Sfx.play("confirm", 0.05, -8.0); return
	if not _is_p2():
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var m: Vector2 = make_input_local(event).position
			if Rect2(Vector2.ZERO, PANEL).has_point(m):
				_on_click(m)
		elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and ant_id == "a1":
			var m: Vector2 = make_input_local(event).position
			var slider_y := 70.0 if stage == 0 else 28.0
			if Rect2(8, slider_y, 134, 22).has_point(m):
				var ratio := clampf((m.x - 14.0) / 122.0, 0.0, 1.0)
				a1_freq = int(snappedf(820.0 + ratio * 80.0, 5.0))


func _on_click(m: Vector2) -> void:
	if ant_id == "a1":
		if stage == 0:
			for i in 4:
				var bx := 14.0 + i * 31.0
				if Rect2(bx, 34, 24, 24).has_point(m):
					cursor = i
					a1_pin[i] = wrapi(a1_pin[i] + 1, 0, 10)
					Sfx.play("beep", 0.05, -10.0)
					return
			if Rect2(10, 74, 130, 16).has_point(m):
				cursor = 4
				var ratio := clampf((m.x - 14.0) / 122.0, 0.0, 1.0)
				a1_freq = int(snappedf(820.0 + ratio * 80.0, 5.0))
				Sfx.play("beep", 0.05, -10.0)
			elif Rect2(18, 98, 114, 16).has_point(m):
				_submit_a1_stage0()
		else:
			if Rect2(10, 32, 130, 16).has_point(m):
				var ratio := clampf((m.x - 14.0) / 122.0, 0.0, 1.0)
				a1_freq = int(snappedf(820.0 + ratio * 80.0, 5.0))
				Sfx.play("beep", 0.05, -10.0)
	elif ant_id == "a2":
		if stage == 0:
			for i in 4:
				if Rect2(8 + i * 35, 42, 31, 38).has_point(m):
					cursor = i
					a2_jumpers[i] = not a2_jumpers[i]
					Sfx.play("beep", 0.05, -10.0)
					return
			if Rect2(18, 94, 114, 16).has_point(m):
				_submit_a2_stage0()
		elif stage == 1:
			if Rect2(18, 94, 114, 16).has_point(m):
				_submit_a2_pair()
	elif ant_id == "a3":
		if stage == 0:
			for i in 3:
				if Rect2(10 + i * 33, 34, 29, 18).has_point(m):
					var tn := i + 1
					if not a3_seq.has(tn):
						a3_seq.append(tn)
						Sfx.play("beep", 0.05, -10.0)
					return
			if Rect2(110, 34, 32, 18).has_point(m):
				a3_seq.clear()
				Sfx.play("beep", 0.05, -10.0)
			elif Rect2(12, 74, 56, 16).has_point(m):
				a3_phase = clampi(a3_phase - 1, -5, 5); Sfx.play("beep", 0.05, -10.0)
			elif Rect2(82, 74, 56, 16).has_point(m):
				a3_phase = clampi(a3_phase + 1, -5, 5); Sfx.play("beep", 0.05, -10.0)
			elif Rect2(18, 98, 114, 16).has_point(m):
				_submit_a3_stage0()
		else:
			if Rect2(12, 74, 60, 22).has_point(m) and a3_fuse_a:
				a3_fuse_a = false; status_msg = "Bezpiecznik B1 OK!"; status_ok = true; Sfx.play("confirm", 0.05, -8.0)
			elif Rect2(78, 74, 60, 22).has_point(m) and a3_fuse_b:
				a3_fuse_b = false; status_msg = "Bezpiecznik B2 OK!"; status_ok = true; Sfx.play("confirm", 0.05, -8.0)
func _draw() -> void:
	var f := Art.font()
	var fs := Art.FONT_SIZE
	var border := Color("3f8f5a") if ant_id == "a1" else (Color("5a6abf") if ant_id == "a2" else Color("bf5a3a"))
	var bg := Color(0.04, 0.08, 0.07, 0.94)
	if ant_id == "a2": bg = Color(0.05, 0.05, 0.11, 0.94)
	elif ant_id == "a3": bg = Color(0.10, 0.04, 0.04, 0.94)
	if _flash > 0.0:
		bg = Color(0.32, 0.07, 0.07, 0.96)
	draw_rect(Rect2(Vector2.ZERO, PANEL), bg)
	draw_rect(Rect2(Vector2.ZERO, PANEL), border, false, 1.0)

	var hdr := "ANTENA 1 [HARD]" if ant_id == "a1" else ("ANTENA 2 [HARD]" if ant_id == "a2" else "ANTENA 3 [HARD]")
	draw_string(f, Vector2(5, 10), hdr, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffe08a"))
	draw_string(f, Vector2(5, 20), status_msg, HORIZONTAL_ALIGNMENT_LEFT, PANEL.x - 10, fs,
		Color("8fe0a0") if status_ok else Color("ff6a5a"))

	var key_lbl := "ENTER" if _is_p2() else "SPACJA"
	var leave_lbl := "L / ESC: odejdź (etap zapisany)" if _is_p2() else "E / ESC: odejdź (etap zapisany)"
	if ant_id == "a1":
		_draw_a1(f, fs, key_lbl)
	elif ant_id == "a2":
		_draw_a2(f, fs, key_lbl)
	else:
		_draw_a3(f, fs, key_lbl)

	draw_string(f, Vector2(5, PANEL.y - 4), leave_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("8a929c"))


func _draw_a1(f: Font, fs: int, key_lbl := "SPACJA") -> void:
	if stage == 0:
		draw_string(f, Vector2(6, 31), "PIN (0-9 / W S / klik):", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("c8d0d8"))
		for i in 4:
			var r := Rect2(14 + i * 31, 35, 24, 22)
			draw_rect(r, Color("121a16"))
			draw_rect(r, Color("ffe08a") if cursor == i else Color("3f8f5a"), false, 1.0)
			draw_string(f, Vector2(r.position.x, r.position.y + 15), str(a1_pin[i]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, Color("e8f8ec"))
		draw_string(f, Vector2(6, 70), "PASMO: %d MHz (góra/dół)" % a1_freq, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Color("ffe08a") if cursor == 4 else Color("c8d0d8"))
		_draw_slider(Rect2(14, 75, 122, 10), float(a1_freq - 820) / 80.0, Color("47c46b"), cursor == 4)
		_draw_btn(f, fs, Rect2(18, 98, 114, 15), "[%s] AUTORYZUJ" % key_lbl, cursor == 5, Color("3f8f5a"))
	else:
		var ok := (a1_freq == 865)
		draw_string(f, Vector2(6, 31), "PASMO: %d MHz %s" % [a1_freq, "(OK)" if ok else "(DRYF->865!)"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("8fe0a0") if ok else Color("ff6a5a"))
		_draw_slider(Rect2(14, 35, 122, 9), float(a1_freq - 820) / 80.0, Color("47c46b") if ok else Color("ff5050"), not ok)
		draw_string(f, Vector2(6, 56), "WYGASZANIE: %d%%" % roundi(a1_prog), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("c8d0d8"))
		_draw_bar(Rect2(14, 60, 122, 9), a1_prog / 100.0, Color("8fe0a0"))
		draw_string(f, Vector2(6, 81), "TEMP (puść przed 100%%):", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffb060"))
		_draw_bar(Rect2(14, 85, 122, 9), a1_heat / 100.0, Color("ff4a3a") if a1_heat > 75.0 else Color("ff9a3a"))
		_draw_btn(f, fs, Rect2(12, 104, 126, 15), "[TRZYMAJ %s/LPM] TŁUM" % key_lbl, _hold_charge(), Color("3f8f5a"))


func _draw_a2(f: Font, fs: int, key_lbl := "SPACJA") -> void:
	if stage == 0:
		var led_on := fmod(_blink, 0.8) < 0.55
		draw_circle(Vector2(138, 10), 4.0, Color("ff2a2a") if led_on else Color("6a1414"))
		draw_string(f, Vector2(6, 33), "DIODA OBOK PANELU: CZERWONA!", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ff6a5a"))
		for i in 4:
			var r := Rect2(8 + i * 35, 42, 31, 38)
			var up_state: bool = a2_jumpers[i]
			draw_rect(r, Color("101326"))
			draw_rect(r, Color("ffe08a") if cursor == i else Color("5a6abf"), false, 1.0)
			draw_string(f, Vector2(r.position.x, r.position.y + 9), "Z%d" % (i + 1), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, Color("a0b0ff"))
			var sw := Rect2(r.position.x + 5, r.position.y + (12 if up_state else 20), 21, 7)
			draw_rect(sw, Color("4fbf6f") if up_state else Color("bf6a4a"))
			draw_string(f, Vector2(r.position.x, r.position.y + 35), "GÓRA" if up_state else "DÓŁ", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, Color("e8e8e8"))
		_draw_btn(f, fs, Rect2(18, 94, 114, 15), "[%s] ZATWIERDŹ" % key_lbl, cursor == 4, Color("5a6abf"))
	elif stage == 1:
		var l_col := Color("4fdf6f") if a2_green else Color("ffa03a")
		draw_circle(Vector2(18, 36), 5.0, l_col)
		draw_string(f, Vector2(28, 39), "ZIELONA (suma=10)" if a2_green else "POMAR. (różnica=4)", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, l_col)
		var box := Rect2(26, 49, 98, 26)
		draw_rect(box, Color("0d1020"))
		draw_rect(box, l_col, false, 1.0)
		draw_string(f, Vector2(box.position.x, box.position.y + 18), "%d  |  %d" % [a2_pair_a, a2_pair_b],
			HORIZONTAL_ALIGNMENT_CENTER, box.size.x, fs * 2, Color("ffffff"))
		draw_string(f, Vector2(6, 86), "Trafienia: %d / 3" % a2_hits, HORIZONTAL_ALIGNMENT_CENTER, PANEL.x - 12, fs, Color("c8d0d8"))
		_draw_btn(f, fs, Rect2(18, 95, 114, 15), "[%s/LPM] ZŁAP PARĘ" % key_lbl, true, Color("5a6abf"))
	else:
		draw_string(f, Vector2(6, 40), "ROZŁADOWANIE: %d%%" % roundi(a2_prog), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("c8d0d8"))
		_draw_bar(Rect2(14, 46, 122, 10), a2_prog / 100.0, Color("8fe0a0"))
		draw_string(f, Vector2(6, 70), "TEMP KONDENSATORÓW:", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffb060"))
		_draw_bar(Rect2(14, 76, 122, 9), a2_heat / 100.0, Color("ff6a3a"))
		_draw_btn(f, fs, Rect2(12, 98, 126, 15), "[TRZYMAJ %s/LPM]" % key_lbl, _hold_charge(), Color("5a6abf"))


func _draw_a3(f: Font, fs: int, key_lbl := "SPACJA") -> void:
	if stage == 0:
		for i in 3:
			var tn := i + 1
			var r := Rect2(10 + i * 33, 34, 29, 17)
			var used := a3_seq.has(tn)
			draw_rect(r, Color("2a3a2a") if used else Color("1c1212"))
			draw_rect(r, Color("ffe08a") if cursor == i else Color("bf5a3a"), false, 1.0)
			draw_string(f, Vector2(r.position.x, r.position.y + 12), "T%d" % tn, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, Color("8fe0a0") if used else Color("e8e8e8"))
		var rr := Rect2(110, 34, 32, 17)
		draw_rect(rr, Color("241414"))
		draw_rect(rr, Color("ffe08a") if cursor == 3 else Color("bf5a3a"), false, 1.0)
		draw_string(f, Vector2(rr.position.x, rr.position.y + 12), "CLR", HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, fs, Color("ff9a8a"))
		var seq_txt := "Kolejność: " + ("-" if a3_seq.is_empty() else "T" + "->T".join(a3_seq.map(func(x): return str(x))))
		draw_string(f, Vector2(8, 62), seq_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffe08a"))
		draw_string(f, Vector2(8, 72), "FAZA: %+d (W/S lub klik -/+)" % a3_phase, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Color("ffe08a") if cursor == 4 else Color("c8d0d8"))
		_draw_btn(f, fs, Rect2(12, 76, 56, 14), "FAZA -", false, Color("bf5a3a"))
		_draw_btn(f, fs, Rect2(82, 76, 56, 14), "FAZA +", false, Color("bf5a3a"))
		_draw_btn(f, fs, Rect2(18, 98, 114, 15), "[%s] ZATWIERDŹ" % key_lbl, cursor == 5, Color("bf5a3a"))
	else:
		draw_string(f, Vector2(8, 42), "WYGASZANIE MOCY: %d%%" % roundi(a3_prog), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("c8d0d8"))
		_draw_bar(Rect2(14, 48, 122, 11), a3_prog / 100.0, Color("8fe0a0"))
		draw_string(f, Vector2(8, 69), "BEZPIECZNIKI (klik/SPACJA):", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffb090"))
		_draw_btn(f, fs, Rect2(12, 74, 60, 22), "B1: WYBIŁ!" if a3_fuse_a else "B1: OK", a3_fuse_a, Color("ff3a3a") if a3_fuse_a else Color("3f8f5a"))
		_draw_btn(f, fs, Rect2(78, 74, 60, 22), "B2: WYBIŁ!" if a3_fuse_b else "B2: OK", a3_fuse_b, Color("ff3a3a") if a3_fuse_b else Color("3f8f5a"))


func _draw_bar(r: Rect2, ratio: float, col: Color) -> void:
	draw_rect(r, Color(0, 0, 0, 0.55))
	draw_rect(Rect2(r.position + Vector2(1, 1), Vector2((r.size.x - 2) * clampf(ratio, 0.0, 1.0), r.size.y - 2)), col)
	draw_rect(r, Color(1, 1, 1, 0.25), false, 1.0)


func _draw_slider(r: Rect2, ratio: float, col: Color, sel: bool) -> void:
	_draw_bar(r, ratio, col)
	var kx := r.position.x + clampf(ratio, 0.0, 1.0) * (r.size.x - 4)
	draw_rect(Rect2(kx, r.position.y - 1, 4, r.size.y + 2), Color("ffe08a") if sel else Color("ffffff"))


func _draw_btn(f: Font, fs: int, r: Rect2, txt: String, sel: bool, edge: Color) -> void:
	draw_rect(r, edge.darkened(0.55) if sel else Color(0.08, 0.1, 0.12, 0.9))
	draw_rect(r, Color("ffe08a") if sel else edge, false, 1.0)
	draw_string(f, Vector2(r.position.x, r.position.y + r.size.y - 4), txt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs,
		Color("ffe08a") if sel else Color("e0e6ee"))
