extends Node
## Online co-op over ENet (LAN or the same PC via 127.0.0.1).

signal peer_joined           # host: Player 2 connected
signal status_changed(text: String)

const PORT := 24565
const SNAP_RATE := 20.0
const STATE_CHECK := 0.2
const PRESS_TTL_MS := 300
## Client -> host button presses (moving is sent continuously).
const PRESS_ACTIONS := ["shoot", "melee", "interact", "accept"]

var role := ""               # "" | "host" | "client"
var status := ""
## Host: bumped on every map (re)load; the client rebuilds its map when it changes.
var map_rev := 0
## Client: the host's first state, kept until main.tscn is up.
var pending_state := {}
## Client: the host's dialog line that came before main.tscn was up.
var _pending_dialog := []

# --- host: Player 2's remote input ------------------------------------------------
var p2_move := Vector2.ZERO
var p2_aim := Vector2.ZERO
var p2_aiming := false
var remote_hack_antenna := ""
var _p2_presses := {}

var _snap_t := 0.0
var _state_t := 0.0
var _state_hash := 0
var _force_state := false
var _next_id := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(func(): _set_status("Połączono. Czekam na hosta…"))
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	Game.hint.connect(func(text: String): if is_host() and _has_peer(): _rpc_hint.rpc(text))
	if Game.dev.has("nettest"):
		add_child(load("res://tools/net_test.gd").new())


func is_host() -> bool:
	return role == "host"


func is_client() -> bool:
	return role == "client"


func active() -> bool:
	return role != ""


func _has_peer() -> bool:
	return multiplayer.multiplayer_peer != null and not multiplayer.get_peers().is_empty()


func _set_status(text: String) -> void:
	status = text
	status_changed.emit(text)


## LAN addresses to tell the other player (no loopback / link-local).
func local_ips() -> PackedStringArray:
	var out := PackedStringArray()
	for ip in IP.get_local_addresses():
		if ip.count(".") == 3 and not ip.begins_with("127.") and not ip.begins_with("169.254."):
			out.append(ip)
	return out


func host_game() -> bool:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, 1)
	if err != OK:
		_set_status("Nie mogę otworzyć portu %d (błąd %d)." % [PORT, err])
		return false
	multiplayer.multiplayer_peer = peer
	role = "host"
	var ips := local_ips()
	if ips.size() > 2:
		ips.resize(2)  # fits the screen; the first ones are the usual Wi-Fi / LAN ones
	_set_status("Czekam na gracza 2. Twoje IP: %s" % (", ".join(ips) if not ips.is_empty() else "127.0.0.1"))
	return true


func join_game(address: String) -> bool:
	leave()
	address = address.strip_edges()
	if address == "":
		address = "127.0.0.1"
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, PORT)
	if err != OK:
		_set_status("Zły adres: %s" % address)
		return false
	multiplayer.multiplayer_peer = peer
	role = "client"
	_set_status("Łączę z %s…" % address)
	return true


func leave() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	role = ""
	pending_state = {}
	_pending_dialog = []
	p2_move = Vector2.ZERO
	p2_aiming = false
	remote_hack_antenna = ""
	_p2_presses.clear()


func _on_peer_connected(_id: int) -> void:
	if is_host():
		_set_status("Gracz 2 dołączył!")
		_force_state = true
		peer_joined.emit()
		if _story() != null:
			Game.show_hint("Gracz 2 dołączył.")


func _on_peer_disconnected(_id: int) -> void:
	if is_host():
		p2_move = Vector2.ZERO
		p2_aiming = false
		if remote_hack_antenna != "" and is_instance_valid(Game.player2):
			Game.player2.set_hacking(false)
		remote_hack_antenna = ""
		_set_status("Gracz 2 się rozłączył.")
		if _story() != null:
			Game.show_hint("Gracz 2 się rozłączył. Może dołączyć ponownie.")


func _on_connection_failed() -> void:
	leave()
	_set_status("Nie udało się połączyć.")


func _on_server_disconnected() -> void:
	leave()
	_set_status("Host zakończył grę.")
	_back_to_title()


func _back_to_title() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if get_tree().current_scene == null or get_tree().current_scene.scene_file_path != "res://scenes/title.tscn":
		get_tree().change_scene_to_file.call_deferred("res://scenes/title.tscn")


func _story() -> Node:
	return get_tree().get_first_node_in_group("story")


## Unique, stable id for a host node the client mirrors (mutants, drops).
func net_id(n: Node) -> String:
	if not n.has_meta("net_id"):
		if n.has_meta("key"):
			n.set_meta("net_id", "k:" + str(n.get_meta("key")))
		else:
			_next_id += 1
			n.set_meta("net_id", "n%d" % _next_id)
	return n.get_meta("net_id")


# --- host -> client ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if is_host() and _has_peer() and _story() != null:
		_state_t -= delta
		if _state_t <= 0.0 or _force_state:
			_state_t = STATE_CHECK
			var st := Game.net_state()
			var h := hash(st)
			if h != _state_hash or _force_state:
				_state_hash = h
				_force_state = false
				_rpc_state.rpc(st)
		_snap_t -= delta
		if _snap_t <= 0.0:
			_snap_t = 1.0 / SNAP_RATE
			_rpc_snap.rpc(_story().net_snapshot())
	elif is_client() and _has_peer():
		_send_client_input()


## Host: a map was (re)built; the client rebuilds too.
func map_loaded() -> void:
	map_rev += 1
	_force_state = true


func send_dialog_line(speaker: String, text: String, radio: bool, mutter := false) -> void:
	if is_host() and _has_peer():
		_rpc_dialog.rpc(speaker, text, radio, true, mutter)


func send_dialog_end() -> void:
	if is_host() and _has_peer():
		_rpc_dialog.rpc("", "", false, false, false)


func send_hud(method: String, args: Array) -> void:
	if is_host() and _has_peer():
		_rpc_hud.rpc(method, args)


func send_shot(pos: Vector2, dir: Vector2) -> void:
	if is_host() and _has_peer():
		_rpc_shot.rpc(pos, dir)


## Host: both players watch the intro; the host's ends it for both (its first state).
func send_intro() -> void:
	if is_host() and _has_peer():
		_rpc_intro.rpc()


func send_wreck_fall() -> void:
	if is_host() and _has_peer():
		_rpc_wreck_fall.rpc()


func send_ending() -> void:
	if is_host() and _has_peer():
		_rpc_ending.rpc()


## Host: Player 2 used an antenna; their own screen opens the hack panel.
func open_remote_hack(antenna_id: String) -> void:
	if is_host() and _has_peer():
		_rpc_open_hack.rpc(antenna_id)


@rpc("authority", "call_remote", "reliable")
func _rpc_state(st: Dictionary) -> void:
	var story := _story()
	if story == null:
		var first := pending_state.is_empty()
		pending_state = st  # a newer state before main.tscn is up replaces the older one
		if first:
			Game.coop = true
			Game.difficulty = str(st.get("diff", "normal"))
			_set_status("Start!")
			get_tree().change_scene_to_file("res://scenes/main.tscn")
	elif story.has_method("client_apply_state"):
		story.client_apply_state(st)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_snap(s: Dictionary) -> void:
	var story := _story()
	if story != null and story.has_method("client_apply_snap"):
		story.client_apply_snap(s)


@rpc("authority", "call_remote", "reliable")
func _rpc_dialog(speaker: String, text: String, radio: bool, show: bool, mutter: bool) -> void:
	var story := _story()
	if story == null:
		_pending_dialog = [speaker, text, radio, mutter] if show else []
		return
	if show:
		story.hud.dialog.mirror_line(speaker, text, radio, mutter)
	else:
		story.hud.dialog.mirror_end()


## Client: show the line that was on the host's screen when we arrived.
func flush_pending_dialog(dialog: Control) -> void:
	if not _pending_dialog.is_empty():
		dialog.mirror_line(_pending_dialog[0], _pending_dialog[1], _pending_dialog[2], _pending_dialog[3])
	_pending_dialog = []


@rpc("authority", "call_remote", "reliable")
func _rpc_hud(method: String, args: Array) -> void:
	var story := _story()
	if story != null and method in ["show_big", "fade"]:
		story.hud.callv(method, args)


@rpc("authority", "call_remote", "reliable")
func _rpc_hint(text: String) -> void:
	if _story() != null:
		Game.show_hint(text)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_shot(pos: Vector2, dir: Vector2) -> void:
	var story := _story()
	if story != null:
		story.client_spawn_shot(pos, dir)


@rpc("authority", "call_remote", "reliable")
func _rpc_intro() -> void:
	if _story() == null and pending_state.is_empty():
		_set_status("Start!")
		get_tree().change_scene_to_file("res://scenes/intro.tscn")


@rpc("authority", "call_remote", "reliable")
func _rpc_wreck_fall() -> void:
	var story := _story()
	if story != null:
		story.client_wreck_fall()


@rpc("authority", "call_remote", "reliable")
func _rpc_ending() -> void:
	var story := _story()
	if story != null:
		story.go_to_ending()


@rpc("authority", "call_remote", "reliable")
func _rpc_open_hack(antenna_id: String) -> void:
	var p2 := Game.player2
	if not is_instance_valid(p2):
		return
	for a in Game.antennas:
		if is_instance_valid(a) and a.antenna_id == antenna_id:
			get_tree().call_group("hack_ui", "open", a, p2)
			return


# --- client -> host ---------------------------------------------------------------------

func _send_client_input() -> void:
	var story := _story()
	var p2 := Game.player2
	if story == null or not is_instance_valid(p2) or not p2.puppet:
		return
	var busy: bool = p2.hacking or Game.menu_open
	var move := Vector2.ZERO if busy else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var origin: Vector2 = p2.global_position + Vector2(0, -6)
	var aim_at: Vector2 = Touch.aim_world(story) if Touch.active else story.get_global_mouse_position()
	var aim := (aim_at - origin).normalized() if aim_at.distance_to(origin) > 2.0 else Vector2.ZERO
	if Touch.active and not Touch.aiming:
		aim = Vector2.ZERO  # no finger on the aim side: the host keeps P2's facing
	var aiming := Touch.aiming if Touch.active else Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	_rpc_input.rpc_id(1, move, aim, aiming)
	if busy:
		return
	for a in PRESS_ACTIONS:
		if Input.is_action_just_pressed(a):
			_rpc_press.rpc_id(1, a, aim, aiming or a == "shoot")


func send_hack_state(on: bool, antenna_id: String) -> void:
	if is_client() and _has_peer():
		_rpc_hack_state.rpc_id(1, on, antenna_id)


func send_hacked(antenna_id: String) -> void:
	if is_client() and _has_peer():
		_rpc_hacked.rpc_id(1, antenna_id)


func send_error() -> void:
	if is_client() and _has_peer():
		_rpc_error.rpc_id(1)


func send_hard_stage(antenna_id: String, stage: int) -> void:
	if is_client() and _has_peer():
		_rpc_hard_stage.rpc_id(1, antenna_id, stage)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_input(move: Vector2, aim: Vector2, aiming: bool) -> void:
	if not is_host():
		return
	p2_move = move.limit_length(1.0)
	if aim != Vector2.ZERO:
		p2_aim = aim.normalized()
	p2_aiming = aiming and aim != Vector2.ZERO


@rpc("any_peer", "call_remote", "reliable")
func _rpc_press(action: String, aim: Vector2, aiming: bool) -> void:
	if not is_host() or not action in PRESS_ACTIONS:
		return
	if aim != Vector2.ZERO:
		p2_aim = aim.normalized()
		p2_aiming = aiming
	_p2_presses[action] = Time.get_ticks_msec()


## Host: did Player 2 press `action` just now? Each press counts once.
func consume(action: String) -> bool:
	var t: int = _p2_presses.get(action, -1)
	if t < 0:
		return false
	_p2_presses.erase(action)
	return Time.get_ticks_msec() - t <= PRESS_TTL_MS


@rpc("any_peer", "call_remote", "reliable")
func _rpc_hack_state(on: bool, antenna_id: String) -> void:
	if not is_host() or not is_instance_valid(Game.player2):
		return
	remote_hack_antenna = antenna_id if on else ""
	Game.player2.set_hacking(on)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_hacked(antenna_id: String) -> void:
	if not is_host():
		return
	remote_hack_antenna = ""
	if is_instance_valid(Game.player2):
		Game.player2.set_hacking(false)
	for a in Game.antennas:
		if is_instance_valid(a) and a.antenna_id == antenna_id and not a.disabled:
			a.on_hacked()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_error() -> void:
	if is_host():
		Game.add_error()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_hard_stage(antenna_id: String, stage: int) -> void:
	if is_host() and Game.hard_stage.has(antenna_id):
		Game.hard_stage[antenna_id] = stage
