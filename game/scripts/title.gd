extends Control
## Title screen: a short vertical menu over the skyline with the blinking antenna.

const SETTINGS_PANEL := preload("res://scripts/settings_panel.gd")
const ROW_Y := {"new": 72, "load": 83, "players": 98, "difficulty": 109, "online": 120, "settings": 131,
	"host": 84, "join": 100, "back": 116}
const ROW_W := 180.0
const NET_CFG := "user://net.cfg"

var _t := 0.0
var _loading := false
var _rows: Array[String] = []
var _main_rows: Array[String] = []
var _sel := 0
var _save_info := ""
var _net_screen := false
var _ip: LineEdit
var _settings: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Sfx.set_static(0.15)
	Net.leave()  # back on the title = no online session (Net.status keeps why it ended)
	_main_rows = ["new"]
	if Game.has_save():
		_main_rows.append("load")
		var d := Game.read_save()
		_save_info = "%s, %s" % ["2 graczy" if d.get("coop", false) else "1 gracz",
			"trudny" if d.get("difficulty", "normal") == "hard" else "normalny"]
	_main_rows.append_array(["players", "difficulty", "online", "settings"])
	_rows = _main_rows
	_make_ip_field()
	_settings = SETTINGS_PANEL.new()
	add_child(_settings)
	Net.peer_joined.connect(_on_peer_joined)
	if Game.dev.has("nethost"):  # --nethost / --netjoin=<ip>: dev runs of online co-op
		_open_net(true)
		_confirm.call_deferred("host")
	elif Game.dev.has("netjoin"):
		_open_net(true)
		if str(Game.dev["netjoin"]) != "true":
			_ip.text = str(Game.dev["netjoin"])
		_join.call_deferred()
	elif not Game.dev.has("scene") and (Game.dev.has("autostart") or Game.dev.has("autotest") or Game.dev.has("shot")):
		_start.call_deferred()
	elif Net.status != "":
		_open_net(true)  # e.g. "Host zakończył grę." after being sent back here


func _make_ip_field() -> void:
	_ip = LineEdit.new()
	_ip.text = "127.0.0.1"
	var cfg := ConfigFile.new()
	if cfg.load(NET_CFG) == OK:
		_ip.text = str(cfg.get_value("net", "ip", "127.0.0.1"))
	_ip.add_theme_font_override("font", Art.font())
	_ip.add_theme_font_size_override("font_size", Art.FONT_SIZE)
	_ip.add_theme_color_override("font_color", Color("ffe08a"))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.1, 0.95)
	sb.border_color = Color("4a5160")
	sb.set_border_width_all(1)
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	_ip.add_theme_stylebox_override("normal", sb)
	_ip.add_theme_stylebox_override("focus", sb)
	_ip.add_theme_constant_override("minimum_character_width", 0)
	_ip.position = Vector2(166, ROW_Y["join"] - 12)
	_ip.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_URL
	_ip.placeholder_text = "127.0.0.1"
	_ip.visible = false
	_ip.text_submitted.connect(func(_t): _confirm("join"))
	add_child(_ip)
	_ip.set_deferred("size", Vector2(76, 0))  # shrink to the font's height once themed


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _loading or _settings.visible:
		return  # the settings box takes the input while open
	if _ip.has_focus():
		if Input.is_action_just_pressed("back"):
			_ip.release_focus()
		return  # typing the address (Enter joins: text_submitted)
	if Input.is_action_just_pressed("back") and _net_screen:
		_confirm("back")
	elif Input.is_action_just_pressed("move_up"):
		_move(-1)
	elif Input.is_action_just_pressed("move_down"):
		_move(1)
	elif Input.is_action_just_pressed("move_left"):
		_change(_rows[_sel], -1)
	elif Input.is_action_just_pressed("move_right"):
		_change(_rows[_sel], 1)
	elif Input.is_action_just_pressed("accept") or Input.is_action_just_pressed("interact"):
		_confirm(_rows[_sel])


func _input(event: InputEvent) -> void:
	if _loading or _settings.visible or not (event is InputEventMouse):
		return
	var at: Vector2 = make_input_local(event).position
	var row := _row_at(at)
	if row < 0:
		return
	if _ip.visible and _ip.get_rect().has_point(at):
		_sel = row  # a click in the IP field only edits it (the field takes focus), no joining
		return
	if event is InputEventMouseMotion and row != _sel:
		_sel = row
		Sfx.play("beep", 0.05, -12.0)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_sel = row
		_confirm(_rows[row])


func _row_at(m: Vector2) -> int:
	for i in _rows.size():
		var y: float = ROW_Y[_rows[i]]
		if Rect2((size.x - ROW_W) / 2.0, y - 9.0, ROW_W, 12.0).has_point(m):
			return i
	return -1


func _move(step: int) -> void:
	_sel = wrapi(_sel + step, 0, _rows.size())
	Sfx.play("beep", 0.05, -10.0)


## Flips an option row (players / difficulty); action rows ignore it.
func _change(row: String, _step: int) -> void:
	match row:
		"players":
			Game.coop = not Game.coop
		"difficulty":
			Game.difficulty = "normal" if Game.is_hard() else "hard"
		_:
			return
	Sfx.play("confirm", 0.05, -10.0)


func _confirm(row: String) -> void:
	match row:
		"new":
			_start()
		"load":
			_load_save()
		"online":
			_open_net(true)
		"settings":
			_settings.open()
		"host":
			if not Net.is_host():
				Net.host_game()
		"join":
			_join()  # the field itself only edits the address (see _input)
		"back":
			Net.leave()
			Net.status = ""
			_open_net(false)
		_:
			_change(row, 1)


func _join() -> void:
	if Net.is_client():
		return
	_ip.release_focus()
	var cfg := ConfigFile.new()
	cfg.set_value("net", "ip", _ip.text.strip_edges())
	cfg.save(NET_CFG)
	Net.join_game(_ip.text)


func _open_net(on: bool) -> void:
	_net_screen = on
	_rows = (["host", "join", "back"] as Array[String]) if on else _main_rows
	_sel = 0 if not on else (2 if Net.status != "" and not Net.active() else 0)
	_ip.visible = on
	Sfx.play("confirm", 0.05, -10.0)


func _on_peer_joined() -> void:
	if _loading or not Net.is_host():
		return
	Game.coop = true
	_loading = true
	Sfx.set_static(0.0)
	if Game.dev.has("nettest") or Game.dev.has("autostart"):
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	Net.send_intro()  # both watch it; the host's end starts the game for both
	get_tree().change_scene_to_file("res://scenes/intro.tscn")


func _load_save() -> void:
	_loading = true
	Game.pending_load = Game.read_save()
	Sfx.set_static(0.0)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _start() -> void:
	_loading = true
	Sfx.set_static(0.0)
	# Dev runs (autotest / screenshots / autostart) skip the intro cutscene.
	var dev := Game.dev.has("autostart") or Game.dev.has("autotest") or Game.dev.has("shot")
	if Game.dev.has("load"):
		Game.pending_load = Game.read_save()  # --load: start from the save file
	get_tree().change_scene_to_file("res://scenes/main.tscn" if dev else "res://scenes/intro.tscn")


func _draw() -> void:
	var f := Art.font()
	var fs := Art.FONT_SIZE
	draw_rect(Rect2(Vector2.ZERO, size), Color("07080c"))
	# horizon blocks + antenna
	for i in 12:
		var h := 20 + (i * 37) % 45
		draw_rect(Rect2(i * 28, 180 - h, 24, h), Color("10131a"))
	draw_line(Vector2(250, 180 - 50), Vector2(250, 60), Color("2a2e36"), 2.0)
	var beacon_on := fmod(_t, 1.2) < 0.7
	if beacon_on:
		draw_rect(Rect2(248, 57, 4, 4), Color("ff2a2a"))
		draw_circle(Vector2(250, 59), 10.0, Color(1, 0.1, 0.1, 0.12))
	_center(f, "ABONENT NIEDOSTĘPNY", 40, fs * 2, Color("e8e8e8"))
	if _net_screen:
		_center(f, "GRA PRZEZ SIEĆ", 56, fs, Color("ff6a5a"))

	var x0 := (size.x - ROW_W) / 2.0
	if not _net_screen:
		draw_line(Vector2(x0 + 30, 89), Vector2(x0 + ROW_W - 30, 89), Color("232832"), 1.0)
	for i in _rows.size():
		var row := _rows[i]
		var y: float = ROW_Y[row]
		var sel := i == _sel
		if sel:
			draw_rect(Rect2(x0, y - 9, ROW_W, 12), Color(1, 0.16, 0.1, 0.10))
			# the selection marker blinks with the mast's beacon
			if beacon_on:
				draw_rect(Rect2(x0 + 4, y - 5, 4, 4), Color("ff2a2a"))
		var col := Color("ffe08a") if sel else Color("aab2bc")
		match row:
			"new":
				_center(f, "NOWA GRA", y, fs, col)
			"load":
				_center(f, "KONTYNUUJ", y, fs, col if sel else Color("8fe0a0"))
			"players":
				_option(f, fs, y, "GRACZE", "2  (jeden ekran)" if Game.coop else "1", sel, col)
			"difficulty":
				_option(f, fs, y, "POZIOM", "TRUDNY" if Game.is_hard() else "NORMALNY", sel,
					Color("ff8a5a") if Game.is_hard() and sel else col)
			"online":
				_center(f, "GRA PRZEZ SIEĆ", y, fs, col)
			"settings":
				_center(f, "USTAWIENIA", y, fs, col)
			"host":
				_center(f, "HOSTUJ GRĘ (poziom: %s)" % ("trudny" if Game.is_hard() else "normalny"), y, fs, col)
			"join":
				draw_string(f, Vector2(0, y), "DOŁĄCZ DO", HORIZONTAL_ALIGNMENT_RIGHT, size.x / 2.0, fs, col)
			"back":
				_center(f, "WRÓĆ", y, fs, col)

	if _net_screen:
		var st := Net.status if Net.status != "" else "Ten sam Wi-Fi / sieć LAN, albo 127.0.0.1 na jednym PC."
		_center(f, st, 138, fs, Color("8fe0a0") if Net.active() else Color("9fd8ff"))
		_center(f, "Host gra jako P1 i zapisuje, drugi gracz jako P2.", 158, fs, Color("8a929c"))
		_center(f, "Port %d (UDP)." % Net.PORT, 168, fs, Color("8a929c"))
		return
	_center(f, _describe(_rows[_sel]), 144, fs, Color("9fd8ff"))
	if Touch.active:
		_center(f, "Lewa strona: ruch.  Prawa: celuj i strzelaj.", 158, fs, Color("8a929c"))
		_center(f, "CIOS   E akcja   II pauza", 168, fs, Color("8a929c"))
	elif Game.coop:
		_center(f, "P1: WSAD + mysz, E akcja", 158, fs, Color("8fc0ff"))
		_center(f, "P2: strzałki, P strzał, O cios, L akcja (lub pad)", 168, fs, Color("8fe0a0"))
	else:
		_center(f, "WSAD ruch   LPM strzał   PPM cios   E akcja", 158, fs, Color("8a929c"))
		_center(f, "ENTER dialog   ESC pauza" + ("   TAB notatki" if Game.is_hard() else ""), 168, fs, Color("8a929c"))


## "LABEL   < value >" with the label right-aligned to the middle of the screen.
func _option(f: Font, fs: int, y: float, label: String, value: String, sel: bool, col: Color) -> void:
	var mid := size.x / 2.0
	draw_string(f, Vector2(0, y), label, HORIZONTAL_ALIGNMENT_RIGHT, mid - 6.0, fs, col)
	draw_string(f, Vector2(mid + 6.0, y), ("< %s >" % value) if sel else value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _describe(row: String) -> String:
	match row:
		"new":
			return "%s, poziom %s." % ["Dwóch graczy" if Game.coop else "Jeden gracz",
				"trudny" if Game.is_hard() else "normalny"]
		"load":
			return "Ostatni zapis (%s)." % _save_info
		"players":
			return "Co-op na jednym ekranie: więcej mutantów." if Game.coop else "Sam przeciw całej sieci."
		"difficulty":
			return "Zagadki z notatek zamiast minigier." if Game.is_hard() else "Minigry przy antenach."
		"online":
			return "Co-op przez Wi-Fi albo na jednym PC."
		"settings":
			return "Głośność, ekran, wstrząsy, dotyk."
	return ""


func _center(f: Font, text: String, y: float, fs: int, c: Color) -> void:
	draw_string(f, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, c)
