extends Node
## Global game state: signal bars ("kreski"), antennas, inventory, respawn point.

signal bars_changed(bars: int)
signal stats_changed
signal antenna_disabled(antenna: Node)
signal say(speaker: String, text: String, radio: bool)

const MAX_BARS := 5
const START_AMMO := 14
## Distance to the nearest active antenna (px) -> base signal bars.
const BAR_DISTANCES := [120.0, 240.0, 400.0, 640.0, 960.0]

var bars := 0
var error_boost := 0.0
var noise_boost := 0.0
var hacking := false
var player: Node2D = null
var player_hidden := false
var antennas: Array[Node] = []
var disabled_count := 0
var respawn_point := Vector2.ZERO
var has_cable := false
var parts := 0
var ammo := START_AMMO
var flags := {}

## Dev/test options parsed from the command line (after `--`).
var dev := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_parse_args()


func new_game() -> void:
	bars = 0
	error_boost = 0.0
	noise_boost = 0.0
	hacking = false
	player = null
	player_hidden = false
	antennas.clear()
	disabled_count = 0
	respawn_point = Vector2.ZERO
	has_cable = false
	parts = 0
	ammo = START_AMMO
	flags.clear()


func register_antenna(a: Node) -> void:
	if not antennas.has(a):
		antennas.append(a)


func active_antennas() -> Array:
	return antennas.filter(func(a): return is_instance_valid(a) and not a.disabled)


## 0.0 = clear radio, 1.0 = everything drowned in static.
func radio_noise() -> float:
	if antennas.is_empty():
		return 0.0
	var n := float(active_antennas().size()) / float(antennas.size())
	return clampf(0.15 + 0.75 * n, 0.0, 1.0)


func notify_antenna_disabled(a: Node) -> void:
	disabled_count += 1
	respawn_point = a.global_position + Vector2(-24, -8)
	antenna_disabled.emit(a)
	stats_changed.emit()


func add_error() -> void:
	error_boost = minf(error_boost + 1.0, 3.0)
	Sfx.play("error")


## Loud actions (shots, melee) briefly add a bar and alert nearby mutants.
func make_noise(at: Vector2, radius: float) -> void:
	noise_boost = minf(noise_boost + 0.5, 1.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(at) <= radius:
			e.alert()


func add_ammo(n: int) -> void:
	ammo += n
	stats_changed.emit()


func add_part() -> void:
	parts += 1
	stats_changed.emit()


func say_line(speaker: String, text: String, radio := false) -> void:
	say.emit(speaker, text, radio)


func _physics_process(delta: float) -> void:
	error_boost = maxf(0.0, error_boost - delta / 6.0)
	noise_boost = maxf(0.0, noise_boost - delta / 2.0)
	var new_bars := 0
	if is_instance_valid(player):
		var nearest := INF
		for a in active_antennas():
			nearest = minf(nearest, a.global_position.distance_to(player.global_position))
		for i in BAR_DISTANCES.size():
			if nearest < BAR_DISTANCES[i]:
				new_bars = MAX_BARS - i
				break
		if hacking:
			new_bars += 1
		new_bars += roundi(error_boost) + roundi(noise_boost)
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
		"jump": [KEY_SPACE, KEY_W, KEY_UP],
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
