extends Node
## Global game state.

signal bars_changed(bars: int)
signal stats_changed
signal antenna_disabled(antenna: Node)
signal say(speaker: String, text: String, radio: bool, urgent: bool)
## Short control tip shown on the HUD right away, apart from the dialog queue.
signal hint(text: String)

const MAX_BARS := 5
const START_AMMO := 14
## Antennas that exist in the whole game.
const ALL_ANTENNAS := ["a1", "a2", "a3"]
## Distance to the nearest active antenna (px) -> base signal bars.
const BAR_DISTANCES := [120.0, 240.0, 400.0, 640.0, 960.0]

var bars := 0
var error_boost := 0.0
var hacking := false
## A conversation / story line is on screen: Johnny and the mutants wait (dialog_box.gd).
var dialog_lock := false
var player: Node2D = null
var player_hidden := false
## Antenna nodes in the currently loaded map (signal sources).
var antennas: Array[Node] = []
var disabled_ids: Array[String] = []
var disabled_count := 0
## Where Johnny comes back after death: map name + cell.
var respawn_map := "home"
var respawn_cell := Vector2i(3, 5)
var current_map := ""
## Inventory / progress gates.
var has_pistol := false
var has_sekator := false
var has_cable := false
## Fasti Farmer's cables for antennas 2 and 3.
var has_kable := false
var parts := 0
var ammo := 0
## Persistent world changes, keyed "map:x,y" -> true.
var gone := {}
var flags := {}
## Progress as it was at the last checkpoint (or the start); death rolls back to it.
var _saved := {}

## Dev/test options parsed from the command line (after `--`).
var dev := {}
## Save file loaded on the title screen / pause menu, applied by main.gd on start.
var pending_load := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_parse_args()
	if dev.has("shot"):
		_dev_shot.call_deferred()


## --shot=<file.png> [--scene=<name>] [--delay=s]: screenshot of any scene, then quit.
func _dev_shot() -> void:
	if dev.has("scene"):
		get_tree().change_scene_to_file("res://scenes/%s.tscn" % dev["scene"])
	await get_tree().create_timer(float(dev.get("delay", 1.5)), true, false, true).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(str(dev["shot"]))
	print("SHOT saved ", dev["shot"], " ", img.get_size())
	get_tree().quit()


func new_game() -> void:
	dialog_lock = false
	bars = 0
	error_boost = 0.0
	hacking = false
	player = null
	player_hidden = false
	antennas.clear()
	disabled_ids.clear()
	disabled_count = 0
	respawn_map = "home"
	respawn_cell = Vector2i(3, 5)
	current_map = ""
	has_pistol = false
	has_sekator = false
	has_cable = false
	has_kable = false
	parts = 0
	ammo = 0
	gone.clear()
	flags.clear()
	save_state()


func register_antenna(a: Node) -> void:
	if not antennas.has(a):
		antennas.append(a)


func active_antennas() -> Array:
	return antennas.filter(func(a): return is_instance_valid(a) and not a.disabled)


func is_antenna_off(id: String) -> bool:
	return disabled_ids.has(id)


## 0.0 = clear radio, 1.0 = everything drowned in static.
func radio_noise() -> float:
	var on := ALL_ANTENNAS.size() - disabled_ids.size()
	return clampf(0.15 + 0.75 * float(on) / ALL_ANTENNAS.size(), 0.0, 1.0)


func notify_antenna_disabled(a: Node, respawn_at: Vector2i) -> void:
	if disabled_ids.has(a.antenna_id):
		return
	disabled_ids.append(a.antenna_id)
	disabled_count += 1
	respawn_map = current_map
	respawn_cell = respawn_at
	antenna_disabled.emit(a)
	stats_changed.emit()
	save_state()


## Persistent removal of map objects (pickups, thickets, killed mutants).
func mark_gone(key: String) -> void:
	gone[key] = true


func is_gone(key: String) -> bool:
	return gone.has(key)


## Progress gate check by name (used by warps: need=pistol etc.).
func has(item: String) -> bool:
	match item:
		"pistol": return has_pistol
		"sekator": return has_sekator
		"cable": return has_cable
		"kable": return has_kable
		"a1", "a2", "a3": return is_antenna_off(item)
	return flags.has(item)


func set_checkpoint(map_name: String, cell: Vector2i) -> void:
	respawn_map = map_name
	respawn_cell = cell
	save_state()


## Remember ammo, parts, items and the world.
func save_state() -> void:
	_saved = {
		"ammo": ammo, "parts": parts,
		"has_pistol": has_pistol, "has_sekator": has_sekator,
		"has_cable": has_cable, "has_kable": has_kable,
		"gone": gone.duplicate(), "flags": flags.duplicate(true),
	}


## After death: everything since the last checkpoint is undone.
func restore_state() -> void:
	if _saved.is_empty():
		return
	ammo = _saved.ammo
	parts = _saved.parts
	has_pistol = _saved.has_pistol
	has_sekator = _saved.has_sekator
	has_cable = _saved.has_cable
	has_kable = _saved.has_kable
	gone = _saved.gone.duplicate()
	flags = _saved.flags.duplicate(true)
	error_boost = 0.0
	stats_changed.emit()


# --- save file ------------------------------------------------------------------

func save_path() -> String:
	if dev.has("savefile"):
		return "user://" + str(dev["savefile"])  # --savefile=<name>: dev / screenshot runs
	return "user://save_test.json" if dev.has("autotest") else "user://save.json"


func has_save() -> bool:
	return FileAccess.file_exists(save_path())


## Writes the progress plus where Johnny stands (map, cell) and his HP.
func save_game(map_name: String, cell: Vector2i, hp: int) -> bool:
	var d := {
		"version": 1, "map": map_name, "cell": [cell.x, cell.y], "hp": hp,
		"respawn_map": respawn_map, "respawn_cell": [respawn_cell.x, respawn_cell.y],
		"ammo": ammo, "parts": parts,
		"has_pistol": has_pistol, "has_sekator": has_sekator, "has_cable": has_cable, "has_kable": has_kable,
		"disabled_ids": disabled_ids, "gone": gone.keys(), "flags": flags,
	}
	var f := FileAccess.open(save_path(), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d, "\t"))
	return true


func read_save() -> Dictionary:
	if not has_save():
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(save_path()))
	return d if d is Dictionary else {}


## Puts a read save into the game state (after new_game()); returns map / cell / hp.
func apply_save(d: Dictionary) -> Dictionary:
	ammo = int(d.get("ammo", 0))
	parts = int(d.get("parts", 0))
	has_pistol = bool(d.get("has_pistol", false))
	has_sekator = bool(d.get("has_sekator", false))
	has_cable = bool(d.get("has_cable", false))
	has_kable = bool(d.get("has_kable", false))
	disabled_ids.clear()
	for id in d.get("disabled_ids", []):
		disabled_ids.append(str(id))
	disabled_count = disabled_ids.size()
	gone.clear()
	for k in d.get("gone", []):
		gone[str(k)] = true
	flags = d.get("flags", {})
	respawn_map = str(d.get("respawn_map", "home"))
	var rc: Array = d.get("respawn_cell", [3, 5])
	respawn_cell = Vector2i(int(rc[0]), int(rc[1]))
	save_state()
	stats_changed.emit()
	var c: Array = d.get("cell", [-1, -1])
	return {"map": str(d.get("map", "home")), "cell": Vector2i(int(c[0]), int(c[1])), "hp": int(d.get("hp", -1))}


func add_error() -> void:
	error_boost = minf(error_boost + 1.0, 3.0)
	Sfx.play("error")


## Loud actions (shots, melee) alert nearby mutants.
func make_noise(at: Vector2, radius: float) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(at) <= radius:
			e.alert()


func add_ammo(n: int) -> void:
	ammo += n
	stats_changed.emit()


func add_part() -> void:
	parts += 1
	stats_changed.emit()


func take_parts(n: int) -> void:
	parts = maxi(parts - n, 0)
	stats_changed.emit()


## `urgent` lines (reactions to what the player just did) jump the dialog queue.
func say_line(speaker: String, text: String, radio := false, urgent := false) -> void:
	say.emit(speaker, text, radio, urgent)


func show_hint(text: String) -> void:
	hint.emit(text)


func _physics_process(delta: float) -> void:
	error_boost = maxf(0.0, error_boost - delta / 6.0)
	var new_bars := 0
	if is_instance_valid(player):
		var nearest := INF
		for a in active_antennas():
			nearest = minf(nearest, a.global_position.distance_to(player.global_position))
		for i in BAR_DISTANCES.size():
			if nearest < BAR_DISTANCES[i]:
				new_bars = MAX_BARS - i
				break
		# Hacking and hacking errors make the antenna "louder", but only where there is
		# a network at all: no signal stays no signal. Shots don't change the bars
		# (they alert mutants via make_noise instead).
		if new_bars > 0:
			if hacking:
				new_bars += 1
			new_bars += roundi(error_boost)
	new_bars = clampi(new_bars, 0, MAX_BARS)
	if new_bars != bars:
		bars = new_bars
		bars_changed.emit(bars)


## How far (px) a mutant can sense the player right now.
func detection_radius(base: float, per_bar: float) -> float:
	return base + per_bar * bars


func _setup_input() -> void:
	var map := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"shoot": [KEY_J, KEY_CTRL, MOUSE_BUTTON_LEFT],
		"melee": [KEY_K, KEY_F, MOUSE_BUTTON_RIGHT],
		"interact": [KEY_E],
		"back": [KEY_ESCAPE],
		"accept": [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE],
	}
	for action in map:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action)
		for code in map[action]:
			var ev: InputEvent
			# Key codes are large numbers, so 1/2 can only mean mouse buttons here.
			if code == MOUSE_BUTTON_LEFT or code == MOUSE_BUTTON_RIGHT:
				ev = InputEventMouseButton.new()
				ev.button_index = code
			else:
				ev = InputEventKey.new()
				ev.physical_keycode = code
			InputMap.action_add_event(action, ev)


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var a: String = arg.trim_prefix("--")
		if "=" in a:
			var kv := a.split("=", true, 1)
			dev[kv[0]] = kv[1]
		else:
			dev[a] = true
