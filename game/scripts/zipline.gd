extends Node2D
## Zipline (tyrolka) across the crevice.

const ZIP_MUTANT := preload("res://scripts/zip_mutant.gd")
const SPEED := 46.0
const HANG := 22.0  # cable height above the ground
const SAG := 7.0
const GAP := 14.0   # px between two riders going the same way

## Far end, in the same (parent-local) coordinates as `position`.
var end_pos := Vector2.ZERO
## Everyone hanging on the cable: {"node": player, "t": 0..1 along it, "dir": 1 / -1}.
var riders: Array[Dictionary] = []
## First rider (or null), for callers that only care whether the line is in use.
var rider: Node2D:
	get:
		return riders[0].node if not riders.is_empty() else null
var boss: Node2D = null
var _start_cell := Vector2i.ZERO
var _end_cell := Vector2i.ZERO


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("ziplines")
	z_index = 5
	# The cable catches a bit of light so it reads against the dark chasm.
	material = Art.unshaded()
	_start_cell = get_meta("cell", Vector2i.ZERO)
	_end_cell = Vector2i(floori(end_pos.x / Art.TILE), floori(end_pos.y / Art.TILE))
	queue_redraw()


func length() -> float:
	return (end_pos - position).length()


## Point on the cable at u (0 = start post, 1 = far post), local to this node.
func cable_point(u: float) -> Vector2:
	var p := (end_pos - position) * u
	return p + Vector2(0, -HANG + sin(u * PI) * SAG)


func _draw() -> void:
	var far := end_pos - position
	for post in [Vector2.ZERO, far]:
		draw_rect(Rect2(post + Vector2(-1, -HANG - 4), Vector2(3, HANG + 4)), Color("5a4a3a"))
		draw_rect(Rect2(post + Vector2(-3, -HANG - 5), Vector2(7, 2)), Color("8a7a6a"))
	var pts := PackedVector2Array()
	for i in 25:
		pts.append(cable_point(i / 24.0))
	draw_polyline(pts, Color("c8c8d0"), 1.0)


func _near_far_end(p: Vector2) -> bool:
	return p.distance_to(to_global(end_pos - position)) < p.distance_to(global_position)


func get_interact_position() -> Vector2:
	for p in Game.living_players():
		if _near_far_end(p.global_position):
			return to_global(end_pos - position) + Vector2(0, -6)
	return global_position + Vector2(0, -6)


func can_interact() -> bool:
	return riders.size() < 2


func prompt() -> String:
	return "[E] Tyrolka"


func interact(player: Node) -> void:
	if riders.any(func(r): return r.node == player):
		return
	var dir := -1 if _near_far_end(player.global_position) else 1
	riders.append({"node": player, "t": 0.0 if dir == 1 else 1.0, "dir": dir})
	player.riding = true
	player.facing = Vector2.RIGHT if (end_pos.x - position.x) * dir > 0 else Vector2.LEFT
	Sfx.play("jump", 0.05, -6.0)
	if dir == 1 and not Game.flags.has("zip_boss_dead") and boss == null:
		boss = ZIP_MUTANT.new()
		boss.line = self
		boss.u = 1.0
		add_child(boss)
		get_tree().call_group("story", "on_trigger", "zip_boss")


func _physics_process(delta: float) -> void:
	if riders.is_empty():
		return
	var span := maxf(length(), 1.0)
	for r in riders.duplicate():
		var p: Node2D = r.node
		if not is_instance_valid(p) or p.dead:
			riders.erase(r)
			continue
		var blocked: bool = r.dir == 1 and is_instance_valid(boss) and boss.alive and (boss.u - r.t) * span < GAP
		# the one who got on later waits for a gap behind the one in front
		for o in riders:
			if o == r:
				break
			if o.dir == r.dir and (o.t - r.t) * r.dir * span < GAP:
				blocked = true
		if not blocked:
			r.t = clampf(r.t + r.dir * SPEED * delta / span, 0.0, 1.0)
		p.global_position = to_global(cable_point(r.t)) + Vector2(0, HANG - 4)
		if (r.dir == 1 and r.t >= 1.0) or (r.dir == -1 and r.t <= 0.0):
			_dismount(r)


## The rider closest to the zipline mutant (heading to the far post), or {}.
func front_rider() -> Dictionary:
	var best := {}
	for r in riders:
		if r.dir == 1 and (best.is_empty() or r.t > best.t):
			best = r
	return best


## Bitten by the mutant: slide back a little.
func push_back(px: float, r: Dictionary) -> void:
	r.t = clampf(r.t - r.dir * px / maxf(length(), 1.0), 0.0, 1.0)


func _dismount(r: Dictionary) -> void:
	riders.erase(r)
	var p: Node2D = r.node
	p.riding = false
	var c := _end_cell if r.dir == 1 else _start_cell
	var lvl := get_parent().get_parent()
	# someone already standing on the post's cell: step next to them
	for op in Game.living_players():
		if op != p and not op.riding and op.global_position.distance_to(lvl.to_global(lvl.feet(c.x, c.y))) < 8.0:
			c = lvl.nearest_walkable(c + Vector2i(1, 0)) if lvl.has_method("nearest_walkable") else c
	p.global_position = lvl.to_global(lvl.feet(c.x, c.y))
	Sfx.play("step", 0.1, -6.0)
	if r.dir == 1:
		Game.set_checkpoint(Game.current_map, _end_cell)
		get_tree().call_group("story", "on_trigger", "zip_across")


func boss_died() -> void:
	Game.flags["zip_boss_dead"] = true
	get_tree().call_group("story", "on_trigger", "zip_boss_dead")
