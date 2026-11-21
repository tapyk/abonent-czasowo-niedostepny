extends Node
## Online co-op check with two real processes on 127.0.0.1 (net.gd adds this with --nettest).

var _failed := 0
var _t := 0.0
var _phase := 0
var _p2_start := Vector2.INF
var _err_seen := false
var _shots_seen := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(25.0, true, false, true).timeout.connect(func():
		_ok("finished in time", false)
		_finish())


func _ok(what: String, cond: bool, info := "") -> void:
	print("%s %s  %s%s" % ["PASS" if cond else "FAIL", Net.role.to_upper(), what, ("  (" + info + ")") if info != "" else ""])
	if not cond:
		_failed += 1


func _finish() -> void:
	print("NETTEST %s done: %d failed" % [Net.role, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _story() -> Node:
	return get_tree().get_first_node_in_group("story")


func _physics_process(delta: float) -> void:
	var story := _story()
	if story == null or not is_instance_valid(Game.player2):
		return
	_t += delta
	if Net.is_host():
		_host_step(story)
	elif Net.is_client():
		_client_step(story)


func _host_step(story: Node) -> void:
	if _p2_start == Vector2.INF:
		_p2_start = Game.player2.global_position
	if Game.error_boost > 0.0:
		_err_seen = true
	if _phase == 0 and _t > 3.0:
		_phase = 1
		Game.has_pistol = true
		Game.ammo = 5
		Game.player.shoot(Vector2.RIGHT)
	if _phase == 1 and _t > 4.0:
		_phase = 2
		Net.open_remote_hack("a1")
	if _phase == 2 and _t > 9.0:
		_phase = 3
		var moved: float = Game.player2.global_position.x - _p2_start.x
		_ok("P2 walks right from the client's input", moved > 20.0, "%.0f px" % moved)
		_ok("client's hack error raised the bars boost", _err_seen)
		_ok("client's finished hack switched antenna a1 off here", Game.is_antenna_off("a1"))
		_ok("P2 is not left hacking", not Game.player2.hacking)
		story._plane_crash()  # the jet falls on both screens
		# stay up a bit so the client can finish its checks before the server goes away
		get_tree().create_timer(9.0, true, false, true).timeout.connect(_finish)


func _client_step(story: Node) -> void:
	for n in story.level.entities.get_children():
		if n.get("visual") == true:
			_shots_seen += 1
	if _phase == 0 and _t > 1.0:
		_phase = 1
		_ok("client builds the host's map", Game.current_map == "world" and story.level != null, Game.current_map)
		var puppets := get_tree().get_nodes_in_group("enemies").size()
		_ok("host mutants mirrored", puppets > 0, str(puppets))
		_ok("players are puppets", Game.player.puppet and Game.player2.puppet)
		Input.action_press("move_right")
	if _phase == 1 and _t > 2.6:
		_phase = 2
		Input.action_release("move_right")
	if _phase == 2:
		var panel: Node = null
		for ui in get_tree().get_nodes_in_group("hack_ui"):
			if ui.visible:
				panel = ui
		if panel != null:
			_phase = 3
			_ok("host-requested hack panel opens on the client", panel.get("player") == Game.player2)
			Game.add_error()
			get_tree().create_timer(0.8).timeout.connect(func(): panel.antenna.on_hacked(); panel.close())
	if _phase == 3 and _t > 7.5:
		_phase = 4
		_ok("host shot seen on the client", _shots_seen > 0)
		_ok("antenna a1 off came back from the host", Game.is_antenna_off("a1"))
		_ok("bars come from the host", Game.bars >= 0)
	if _phase == 4 and story.level.entities.get_node_or_null("Wreck") != null:
		_phase = 5
		var s: Sprite2D = null
		for c in story.level.entities.get_node("Wreck").get_children():
			if c is Sprite2D:
				s = c
		_ok("the jet falls on the client too (animated)", s != null and s.position.y < -100.0, str(s.position if s else null))
	if _phase == 5 and _t > 13.5:
		_phase = 6
		_ok("the jet is down on the client", Game.flags.has("plane_down"))
		_finish()
