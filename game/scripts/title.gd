extends Control
## Title screen.

const MODES := ["solo", "local_coop", "steam_coop"]
const MODE_NAMES := {
	"solo": "1 GRACZ",
	"local_coop": "LOCAL CO-OP (2P)",
	"steam_coop": "STEAM CO-OP (480)",
}

var _t := 0.0
var _loading := false
var _row := 2          # 0 = mode, 1 = difficulty, 2 = start (default ready to start!)
var _mode_idx := 0
var _diff_idx := 0     # 0 = normal, 1 = hard
var _lobby_open := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Sfx.set_static(0.15)
	_diff_idx = 1 if Game.difficulty == "hard" else 0
	_mode_idx = (2 if Game.coop_steam else 1) if Game.coop else 0
	SteamNet.peer_joined_coop.connect(_on_steam_peer_joined)
	SteamNet.lobby_status_changed.connect(func(_s): queue_redraw())
	if not Game.dev.has("scene") and (Game.dev.has("autostart") or Game.dev.has("autotest") or Game.dev.has("shot")):
		_start.call_deferred()


func _apply_selection() -> void:
	var m: String = MODES[_mode_idx]
	Game.coop = (m != "solo")
	Game.coop_steam = (m == "steam_coop")
	Game.difficulty = "hard" if _diff_idx == 1 else "normal"


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _lobby_open:
		return
	if Input.is_action_just_pressed("move_up"):
		_row = wrapi(_row - 1, 0, 3)
		Sfx.play("beep", 0.05, -10.0)
	elif Input.is_action_just_pressed("move_down"):
		_row = wrapi(_row + 1, 0, 3)
		Sfx.play("beep", 0.05, -10.0)
	elif Input.is_action_just_pressed("move_left"):
		if _row == 2: _row = 1
		_change_option(-1)
	elif Input.is_action_just_pressed("move_right"):
		if _row == 2: _row = 1
		_change_option(1)
	elif Input.is_physical_key_pressed(KEY_W) and Game.has_save() and not _loading and _row == 2:
		_load_save()


func _input(event: InputEvent) -> void:
	if _lobby_open:
		if event is InputEventKey and event.pressed and not event.echo:
			match event.physical_keycode:
				KEY_ESCAPE:
					_lobby_open = false
					SteamNet.leave_lobby()
					Sfx.play("beep", 0.05, -10.0)
				KEY_H:
					SteamNet.leave_lobby()
					SteamNet.host_steam_lobby()
				KEY_J:
					SteamNet.find_and_join_lobby()
				KEY_G, KEY_ENTER, KEY_KP_ENTER:
					Game.coop_steam = false
					_lobby_open = false
					_start()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ENTER, KEY_KP_ENTER:
				_confirm_start()
			KEY_SPACE:
				if _row < 2:
					_change_option(1)
				else:
					_confirm_start()
			KEY_1:
				_diff_idx = 0; _apply_selection(); Sfx.play("beep", 0.05, -10.0)
			KEY_2:
				_diff_idx = 1; _apply_selection(); Sfx.play("beep", 0.05, -10.0)
			KEY_C:
				_mode_idx = (_mode_idx + 1) % MODES.size(); _apply_selection(); Sfx.play("beep", 0.05, -10.0)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mp := get_local_mouse_position()
		if Rect2(24, 46, 272, 14).has_point(mp):
			_row = 0; _change_option(-1 if mp.x < 160.0 else 1)
		elif Rect2(24, 60, 272, 14).has_point(mp):
			_row = 1; _change_option(-1 if mp.x < 160.0 else 1)
		elif Rect2(40, 99, 240, 15).has_point(mp):
			_row = 2; _confirm_start()
		elif Game.has_save() and Rect2(60, 115, 200, 13).has_point(mp):
			_load_save()


func _change_option(step: int) -> void:
	if _row == 0:
		_mode_idx = wrapi(_mode_idx + step, 0, MODES.size())
	elif _row == 1:
		_diff_idx = wrapi(_diff_idx + step, 0, 2)
	_apply_selection()
	Sfx.play("confirm", 0.05, -10.0)


func _confirm_start() -> void:
	_apply_selection()
	if Game.coop:
		SteamNet.set_local_coop_presence()
	if Game.coop_steam:
		_lobby_open = true
		SteamNet.init_steam()
		Sfx.play("confirm", 0.05, -6.0)
		return
	_start()


func _on_steam_peer_joined() -> void:
	if _lobby_open:
		_lobby_open = false
		_start()


func _load_save() -> void:
	if _loading:
		return
	_loading = true
	Game.pending_load = Game.read_save()
	Sfx.set_static(0.0)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _start() -> void:
	Sfx.set_static(0.0)
	var dev := Game.dev.has("autostart") or Game.dev.has("autotest") or Game.dev.has("shot")
	if not dev:
		_apply_selection()
	if Game.dev.has("load"):
		Game.pending_load = Game.read_save()
	var skip_intro := dev or Game.coop_steam
	get_tree().change_scene_to_file("res://scenes/main.tscn" if skip_intro else "res://scenes/intro.tscn")


func _draw() -> void:
	var f := Art.font()
	var fs := Art.FONT_SIZE
	draw_rect(Rect2(Vector2.ZERO, size), Color("07080c"))
	for i in 12:
		var h := 20 + (i * 37) % 45
		draw_rect(Rect2(i * 28, 180 - h, 24, h), Color("10131a"))
	draw_line(Vector2(250, 180 - 50), Vector2(250, 60), Color("2a2e36"), 2.0)
	if fmod(_t, 1.2) < 0.7:
		draw_rect(Rect2(248, 57, 4, 4), Color("ff2a2a"))
		draw_circle(Vector2(250, 59), 10.0, Color(1, 0.1, 0.1, 0.12))

	_center(f, "ABONENT NIEDOSTĘPNY", 22, fs * 2, Color("e8e8e8"))
	_center(f, "Wszyscy przywracają zasięg. My go wyłączamy.", 35, fs, Color("ff6a5a"))

	if _lobby_open:
		_draw_lobby(f, fs)
		return

	draw_rect(Rect2(24, 42, 272, 88), Color(0.04, 0.05, 0.08, 0.88))
	draw_rect(Rect2(24, 42, 272, 88), Color("3a4250"), false, 1.0)

	var m_key: String = MODES[_mode_idx]
	var c0 := Color("ffe08a") if _row == 0 else Color("c8d0d8")
	var c1 := Color("ffe08a") if _row == 1 else Color("c8d0d8")
	var c2 := Color("ffe08a") if _row == 2 else Color("d0d6de")
	_center(f, ("%s TRYB: < %s >" % [">" if _row == 0 else " ", MODE_NAMES[m_key]]), 55, fs, c0)
	var d_name := "HARD" if _diff_idx == 1 else "NORMAL"
	var d_col := Color("ff7a5a") if _diff_idx == 1 and _row == 1 else c1
	_center(f, ("%s POZIOM: < %s >" % [">" if _row == 1 else " ", d_name]), 68, fs, d_col)

	if _diff_idx == 0:
		_center(f, "Normal: bazowa wersja z GitHuba (bez zmian)", 81, fs, Color("8fe0a0"))
	else:
		_center(f, "Hard: wieloetapowe hakowanie + wskazówki [TAB]", 81, fs, Color("ffb060"))
	if m_key != "solo":
		_center(f, "Co-op (Steam ID 480): więcej mobów i fale przy antenach!", 92, fs, Color("9fd8ff"))

	if _row != 2 or fmod(_t, 1.0) < 0.72:
		_center(f, ("%s [ENTER] ROZPOCZNIJ GRĘ" % [">" if _row == 2 else " "]), 109, fs, c2)
	if Game.has_save():
		_center(f, "[klik / W] wczytaj zapis", 122, fs, Color("8fe0a0"))

	if m_key == "solo":
		_center(f, "W/S wybór   A/D zmień   1/2 Normal/Hard   C Co-op", 143, fs, Color("8a929c"))
		_center(f, "WSAD ruch   LPM strzał   PPM cios   E akcja", 154, fs, Color("8a929c"))
		_center(f, "ESC pauza / wyjście   TAB wskazówki (Hard)", 165, fs, Color("8a929c"))
	else:
		_center(f, "P1: WSAD + Mysz (LPM/PPM) + E akcja", 143, fs, Color("8fc0ff"))
		_center(f, "P2: Strzałki + P strzał + O cios + L akcja (lub Pad)", 154, fs, Color("8fe0a0"))
		_center(f, "1 osoba odpiera fale mobów, 2. hakuje antenę!", 165, fs, Color("ffe08a"))


func _draw_lobby(f: Font, fs: int) -> void:
	draw_rect(Rect2(20, 46, 280, 110), Color(0.04, 0.06, 0.1, 0.94))
	draw_rect(Rect2(20, 46, 280, 110), Color("5a8abf"), false, 1.0)
	_center(f, "STEAM CO-OP - APPID 480 (SPACEWAR)", 60, fs, Color("9fd8ff"))
	_center(f, "Poziom: " + ("HARD" if _diff_idx == 1 else "NORMAL"), 72, fs, Color("ffe08a"))
	var st := SteamNet.status_text if SteamNet.status_text != "" else "Gotowy (Steam ID 480)"
	_center(f, st, 88, fs, Color("8fe0a0"))
	_center(f, "[H] Hostuj lobby Steam (2 graczy)", 104, fs, Color("e8e8e8"))
	_center(f, "[J] Szukaj i dołącz do lobby znajomego", 116, fs, Color("e8e8e8"))
	_center(f, "[G] Graj od razu na 1 ekranie (Remote Play)", 128, fs, Color("ffe08a"))
	_center(f, "[ESC] Wróć", 144, fs, Color("8a929c"))


func _center(f: Font, text: String, y: float, fs: int, c: Color) -> void:
	draw_string(f, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, c)
