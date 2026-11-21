extends CharacterBody2D
## Johnny Walker, top-down.

signal died
signal hp_changed(hp: int, max_hp: int)

const BULLET := preload("res://scenes/bullet.tscn")

const SPEED := 72.0
const FIRE_COOLDOWN := 0.3
const MELEE_COOLDOWN := 0.35
const MELEE_RANGE := 30.0
const MELEE_ARC := -0.2     # dot with the swing direction: a bit more than a half circle
const MAX_HP := 100
const INVULN := 0.9
const BUSH_SLOW := 0.55
const LIGHT_TURN := 14.0    # how fast the flashlight follows the cursor
const REGEN_DELAY := 4.0    # s without damage before health starts coming back
const REGEN_RATE := 4.0     # HP/s
const REGEN_QUIET := 10.0   # HP/s with no signal or hidden in a bush
const CHASE_NEAR := 160.0   # a mutant chasing within this range stops the regen

@export var player_index := 1

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var facing_node: Node2D = $Facing
@onready var muzzle: Marker2D = $Facing/Muzzle
@onready var flash: Sprite2D = $Facing/MuzzleFlash
@onready var camera: Camera2D = $Camera

var hp := MAX_HP
var facing := Vector2.DOWN
var dead := false
var _downed_t := 0.0
var _p_tag: Label = null
var hacking := false
var frozen := false
## On a zipline: the line moves him, he can still shoot.
var riding := false
var in_bush := 0
var _aim := Vector2.ZERO
var _aim_t := 0.0
var _fire_cd := 0.0
var _melee_cd := 0.0
var _interact_cd := 0.0
var _invuln := 0.0
var _reveal := 0.0
var _step_t := 0.0
var _melee_anim := 0.0
## Muzzle-flash frame of the aiming pose (drawn pistol art) after a shot.
var _fire_flash := 0.0
var _melee_dir := Vector2.RIGHT
const SPRITE_POS := Vector2(0, -8)
var _knock := Vector2.ZERO
var _since_hurt := 99.0
var _regen_acc := 0.0
## Health is coming back right now (the HUD shows it on the HP bar).
var regenerating := false
var current_interactable: Node = null
## Online client: the host simulates this player; it only shows snapshots (net.gd).
var puppet := false
var _net_pos := Vector2.ZERO
var _net_rot := 0.0


func _ready() -> void:
	add_to_group("player")
	if player_index == 1:
		Game.player = self
	else:
		Game.player2 = self
		camera.enabled = false
	sprite.sprite_frames = CharacterArt.player_frames()
	sprite.offset = sprite.sprite_frames.get_meta("offset", Vector2.ZERO)
	if player_index == 2:
		sprite.self_modulate = Color(0.76, 0.95, 1.16)
	flash.texture = CharacterArt.muzzle_flash()
	flash.material = Art.unshaded()
	flash.visible = false
	$Facing/Flashlight.texture = Art.light_cone(150, 24.0)
	$Facing/Flashlight.offset = Vector2(75, 0)
	if player_index == 2:
		$Facing/Flashlight.color = Color(0.82, 0.95, 1.0, 1.0)
	$Aura.texture = Art.light_radial(112)
	add_child(preload("res://scripts/detect_ring.gd").new())
	if Game.coop:
		_p_tag = Label.new()
		_p_tag.text = "P%d" % player_index
		_p_tag.add_theme_font_override("font", Art.font())
		_p_tag.add_theme_font_size_override("font_size", Art.FONT_SIZE)
		_p_tag.add_theme_color_override("font_color", Color("8fc0ff") if player_index == 1 else Color("8fe0a0"))
		_p_tag.material = Art.unshaded()
		_p_tag.position = Vector2(-5, -27)
		add_child(_p_tag)
	collision_mask = 1 | 32  # walls + water / chasm
	_animate(Vector2.ZERO)


func is_hidden() -> bool:
	return in_bush > 0 and _reveal <= 0.0 and not dead


func _physics_process(delta: float) -> void:
	if puppet:
		_puppet_step(delta)
		return
	_fire_cd -= delta
	_melee_cd -= delta
	_interact_cd -= delta
	_invuln -= delta
	_reveal -= delta
	_melee_anim -= delta
	_fire_flash -= delta
	_aim_t -= delta

	var my_hidden := is_hidden()
	if player_index == 1:
		Game.player_hidden = my_hidden
	sprite.modulate.a = 0.6 if my_hidden else 1.0
	sprite.visible = not (_invuln > 0.0 and not dead and int(_invuln * 20.0) % 2 == 1)

	if dead and Game.coop:
		_tick_coop_downed(delta)

	var dir := Vector2.ZERO
	var talking := Game.dialog_lock or Game.menu_open
	if not (dead or hacking or frozen or riding or talking):
		dir = _move_input()
		if dir != Vector2.ZERO:
			# Snap to 8 directions so diagonals are exact and the speed stays the same.
			dir = Vector2.RIGHT.rotated(snappedf(dir.angle(), PI / 4.0))
			facing = dir
	var speed := SPEED * (BUSH_SLOW if in_bush > 0 else 1.0)
	_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
	if not riding:
		velocity = dir * speed + _knock
		move_and_slide()

	if not (dead or hacking or frozen or talking):
		_handle_combat_inputs()
	if not (dead or hacking or frozen or riding or talking):
		_update_interactable()
		if _interact_cd <= 0.0 and _just("interact") and current_interactable:
			current_interactable.interact(self)
	else:
		current_interactable = null
	_footsteps(delta, dir)
	_regen(delta)
	_aim_light(delta)
	_animate(dir)


## Online Player 2 on the host: moved by the client's input (net.gd).
func _remote() -> bool:
	return player_index == 2 and Net.is_host()


## This player's input action (see Game.action_for).
func _act(action: String) -> String:
	return Game.action_for(self, action)


func _move_input() -> Vector2:
	if _remote():
		return Net.p2_move
	return Input.get_vector(_act("move_left"), _act("move_right"), _act("move_up"), _act("move_down"))


func _just(action: String) -> bool:
	if _remote():
		return Net.consume(action)
	return Input.is_action_just_pressed(_act(action))


func _handle_combat_inputs() -> void:
	if _just("shoot"):
		var d := _aim_dir(MOUSE_BUTTON_LEFT)
		if can_shoot():
			shoot(d)
		else:
			melee(d)
	if _just("melee"):
		melee(_aim_dir(MOUSE_BUTTON_RIGHT))


## Shared-screen P2's right stick (pad 0); ZERO when it rests.
func _p2_stick() -> Vector2:
	var rv := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	return rv.normalized() if rv.length() > 0.28 else Vector2.ZERO


func _tick_coop_downed(delta: float) -> void:
	var other: Node2D = Game.player2 if player_index == 1 else Game.player
	if not is_instance_valid(other) or other.dead:
		return
	var near_partner := other.global_position.distance_to(global_position) < 22.0
	_downed_t -= delta * (3.5 if near_partner else 1.0)
	if _downed_t <= 0.0:
		dead = false
		hp = 45 if near_partner else 30
		_invuln = 1.6
		hp_changed.emit(hp, MAX_HP)
		Sfx.play("pickup", 0.08, -4.0)
		Game.show_hint("Gracz P%d wraca do walki!" % player_index)


## Where this player aims while aiming.
func _held_aim(button: MouseButton) -> Vector2:
	if _remote():
		return Net.p2_aim if Net.p2_aiming else Vector2.ZERO
	if Game.is_shared_p2(self):
		return _p2_stick()
	var at := Vector2.INF
	if Touch.active:
		if button == MOUSE_BUTTON_LEFT and Touch.aiming:
			at = Touch.aim_world(self)
	elif Input.is_mouse_button_pressed(button):
		at = get_global_mouse_position()
	if at == Vector2.INF:
		return Vector2.ZERO
	var d := at - (global_position + Vector2(0, -6))
	return d.normalized() if d.length() >= 2.0 else Vector2.ZERO


## Where the flashlight looks when nothing is held: the cursor (or the online client's).
func _look_dir() -> Vector2:
	if _remote():
		return Net.p2_aim
	if Game.is_shared_p2(self) or Touch.active:
		return _held_aim(MOUSE_BUTTON_LEFT)
	var d := get_global_mouse_position() - (global_position + Vector2(0, -6))
	return d.normalized() if d.length() > 2.0 else Vector2.ZERO


## Aiming -> that way (and turn that way); otherwise facing.
func _aim_dir(button: MouseButton) -> Vector2:
	var d := _held_aim(button)
	if d == Vector2.ZERO:
		return facing
	if not riding:
		facing = Vector2(signf(d.x), 0) if absf(d.x) > absf(d.y) else Vector2(0, signf(d.y))
	_aim = d
	_aim_t = 0.6
	return d


func can_shoot() -> bool:
	return Game.has_pistol and Game.ammo > 0


func shoot(dir := Vector2.ZERO) -> void:
	if dir == Vector2.ZERO:
		dir = facing
	if _fire_cd > 0.0:
		return
	_fire_cd = FIRE_COOLDOWN
	if not Game.has_pistol:
		return
	if Game.ammo <= 0:
		Sfx.play("empty")
		return
	Game.ammo -= 1
	Game.stats_changed.emit()
	if Game.ammo == 0:
		Game.say_line("Johnny", "Pusto. Dalej pięściami.", false, true)
		Game.show_hint("Bez amunicji LPM to cios")
	var b := BULLET.instantiate()
	b.global_position = global_position + Vector2(0, -6) + dir * 8.0
	b.direction = dir
	_aim = dir
	_aim_t = maxf(_aim_t, 0.3)
	facing_node.rotation = dir.angle()
	get_parent().add_child(b)
	Net.send_shot(b.global_position, dir)
	Sfx.play("shoot")
	_reveal = 1.5
	Game.make_noise(global_position, 150.0)
	if sprite.sprite_frames.has_animation("gun_flat_fire_idle"):
		_fire_flash = 0.1  # the *_2 drawing has its own flash
	else:
		flash.visible = true
		get_tree().create_timer(0.06).timeout.connect(func(): flash.visible = false)


func melee(dir := Vector2.ZERO) -> void:
	if dir == Vector2.ZERO:
		dir = facing
	if _melee_cd > 0.0:
		return
	_melee_cd = MELEE_COOLDOWN
	_melee_anim = 0.2
	Sfx.play("melee")
	# Wide swing in front; nothing there but a mutant in reach -> turn to it and hit it.
	var in_reach: Array[Node] = []
	var nearest: Node = null
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: Vector2 = e.global_position - global_position
		if d.length() > MELEE_RANGE:
			continue
		if d.length() < 8.0 or d.normalized().dot(dir) > MELEE_ARC:
			in_reach.append(e)
		if nearest == null or d.length() < (nearest.global_position - global_position).length():
			nearest = e
	if in_reach.is_empty() and nearest != null:
		dir = (nearest.global_position - global_position).normalized()
		in_reach.append(nearest)
		if not riding:
			facing = Vector2(signf(dir.x), 0) if absf(dir.x) > absf(dir.y) else Vector2(0, signf(dir.y))
	_melee_dir = dir
	var hit := not in_reach.is_empty()
	for e in in_reach:
		e.take_damage(1, dir * 170.0)
	if hit:
		Sfx.play("hit")
	Game.make_noise(global_position, 60.0)


func take_damage(amount: int, from: Vector2) -> void:
	if dead or _invuln > 0.0 or Game.dev.has("god"):
		return
	hp = maxi(hp - amount, 0)
	_invuln = INVULN
	_since_hurt = 0.0
	_regen_acc = 0.0
	regenerating = false
	hp_changed.emit(hp, MAX_HP)
	Sfx.play("hurt")
	shake(3.0)
	var push := global_position - from
	_knock = (push.normalized() if push.length() > 0.1 else -facing) * 160.0
	if hp <= 0:
		_die()


func shake(strength: float) -> void:
	var tw := create_tween()
	for i in 6:
		tw.tween_property(camera, "offset", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength, 0.03)
	tw.tween_property(camera, "offset", Vector2.ZERO, 0.03)


func heal(amount: int) -> void:
	hp = mini(hp + amount, MAX_HP)
	hp_changed.emit(hp, MAX_HP)


## Used by gated doors: step back out of the doorway.
func bounce_back() -> void:
	global_position -= facing * 6.0


func _die() -> void:
	dead = true
	_downed_t = 6.0
	riding = false
	set_hacking(false)
	if Game.coop:
		var other: Node2D = Game.player2 if player_index == 1 else Game.player
		if is_instance_valid(other) and not other.dead:
			Game.show_hint("Gracz P%d powalony! Podejdź bliżej, by go ocucić!" % player_index)
			return
	died.emit()


## Killcam: the aluminium cap flies off Johnny's head and lands next to him.
func drop_cap() -> void:
	var cap := CharacterArt.johnny_cap()
	if cap.is_empty():
		return
	var s := Sprite2D.new()
	s.name = "FallenCap"
	s.texture = cap[0]
	var off: Vector2 = cap[1]
	if sprite.flip_h:
		off.x = -off.x
		s.flip_h = true
	var start := sprite.global_position + sprite.offset + off
	var side := -1.0 if sprite.flip_h else 1.0
	get_parent().add_child(s)
	s.global_position = start
	s.z_index = 1
	var land := global_position + Vector2(side * 18.0, 2.0)
	s.set_meta("arc", [start, (start + land) / 2.0 + Vector2(0, -22), land])
	var tw := s.create_tween().set_parallel(true)
	tw.tween_method(_cap_arc.bind(s), 0.0, 1.0, 0.7)
	tw.tween_property(s, "rotation", side * TAU * 1.25, 0.7).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func() -> void: Sfx.play("step", 0.1, -6.0))


## Quadratic arc start -> top -> land for the falling cap.
func _cap_arc(k: float, s: Sprite2D) -> void:
	if not is_instance_valid(s):
		return
	var a: Array = s.get_meta("arc")
	var p0: Vector2 = a[0]
	var p1: Vector2 = a[1]
	var p2: Vector2 = a[2]
	s.global_position = p0.lerp(p1, k).lerp(p1.lerp(p2, k), k)


func respawn() -> void:
	for c in get_parent().get_children():
		if c.name.begins_with("FallenCap"):
			c.queue_free()
	velocity = Vector2.ZERO
	_knock = Vector2.ZERO
	hp = MAX_HP
	dead = false
	_invuln = 2.0
	facing = Vector2.DOWN
	hp_changed.emit(hp, MAX_HP)


func set_hacking(on: bool) -> void:
	if hacking and not on:
		_interact_cd = 0.22
	hacking = on
	Game.hacking = on
	if puppet:
		# Online client hacking on its own screen: the host freezes its Player 2.
		var aid := ""
		for ui in get_tree().get_nodes_in_group("hack_ui"):
			if ui.get("player") == self and ui.get("antenna") != null:
				aid = ui.antenna.antenna_id
		Net.send_hack_state(on, aid)


## Nearest interactable within reach, preferring what Johnny is facing.
func _update_interactable() -> void:
	var best: Node = null
	var best_score := INF
	for n in get_tree().get_nodes_in_group("interactable"):
		if not n.can_interact():
			continue
		var at: Vector2 = n.get_interact_position() if n.has_method("get_interact_position") else n.global_position
		var d: Vector2 = at - (global_position + Vector2(0, -6))
		if d.length() > 24.0:
			continue
		var score := d.length() - (8.0 if d.length() > 0.1 and d.normalized().dot(facing) > 0.5 else 0.0)
		if score < best_score:
			best_score = score
			best = n
	current_interactable = best


func _footsteps(delta: float, dir: Vector2) -> void:
	if dir != Vector2.ZERO:
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = 0.34
			Sfx.play("step", 0.15, -16.0)
	else:
		_step_t = 0.0


func _regen(delta: float) -> void:
	_since_hurt += delta
	regenerating = not dead and hp < MAX_HP and _since_hurt >= REGEN_DELAY and not _chased()
	if not regenerating:
		_regen_acc = 0.0
		return
	if not Game.flags.has("regen_hint"):
		Game.flags["regen_hint"] = true
		Game.show_hint("Zdrowie wraca, gdy nikt cię nie goni. Bez zasięgu szybciej.")
	_regen_acc += (REGEN_QUIET if Game.bars == 0 or Game.player_hidden else REGEN_RATE) * delta
	if _regen_acc >= 1.0:
		var n := int(_regen_acc)
		_regen_acc -= n
		heal(n)


func _chased() -> bool:
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = e.global_position.distance_to(global_position)
		if d < 28.0:
			return true  # anything biting distance (e.g. the zipline mutant)
		if d < CHASE_NEAR and "state" in e and "burnt" in e and e.state == e.State.CHASE:
			return true
	return false


## Flashlight (and muzzle) turn toward the mouse cursor.
func _aim_light(delta: float) -> void:
	var want := facing.angle()
	if _aim_t > 0.0:
		want = _aim.angle()
	elif not (dead or frozen or hacking):
		var look := _look_dir()
		if look != Vector2.ZERO:
			want = look.angle()
	facing_node.rotation = lerp_angle(facing_node.rotation, want, minf(1.0, delta * LIGHT_TURN))


func _animate(dir: Vector2) -> void:
	var kind := "walk" if dir != Vector2.ZERO else "idle"
	if dead:
		kind = "hurt"
	elif _melee_anim > 0.0:
		kind = "attack"
	# Sprites have 4 directions: diagonals use the side view.
	var look := facing
	if absf(look.x) > 0.1 and absf(look.y) > 0.1:
		look = Vector2(signf(look.x), 0)
	var sf := sprite.sprite_frames
	var anim := CharacterArt.anim_name(sf, kind, look)
	sprite.flip_h = CharacterArt.flip_for(sf, look)
	sprite.position = SPRITE_POS
	if dead and sf.has_animation("dead_down"):
		anim = "dead_down"
	elif kind == "attack" and sf.has_animation("punch_down"):
		# Fists (no pistol in hand) with a short lunge toward the hit.
		anim = "punch_down"
		sprite.position += _melee_dir * 3.0 * clampf(_melee_anim / 0.2, 0.0, 1.0)
		if absf(_melee_dir.x) > 0.05:
			sprite.flip_h = _melee_dir.x < 0.0
	elif not dead and Game.has_pistol and sf.has_animation("gun_flat_idle"):
		# Pistol in hand: shoot_up / flat / down drawing by where Johnny aims (the
		# flashlight / cursor), walking with it too; the *_2 drawings (muzzle flash)
		# right after a shot. Mirrored when aiming left.
		var aim := Vector2.from_angle(facing_node.rotation)
		var up := atan2(-aim.y, absf(aim.x))
		var pose := "up" if up > 0.45 else ("down" if up < -0.45 else "flat")
		anim = "gun_%s_%s%s" % [pose, "fire_" if _fire_flash > 0.0 else "", kind]
		if absf(aim.x) > 0.05:
			sprite.flip_h = aim.x < 0.0
	if sprite.animation != anim:
		# Same kind of motion (pose change, shot): keep the step so the legs don't jump.
		var keep := anim.ends_with("walk") and String(sprite.animation).ends_with("walk")
		var f := sprite.frame
		var fp := sprite.frame_progress
		sprite.play(anim)
		if keep:
			sprite.set_frame_and_progress(f, fp)


# --- online co-op (net.gd) ------------------------------------------------------------

## Client side: the host moves this player; no collisions, no input, no story.
func make_puppet() -> void:
	puppet = true
	collision_layer = 0
	collision_mask = 0
	_net_pos = global_position
	_net_rot = facing_node.rotation


func net_snapshot() -> Array:
	return [global_position, sprite.animation, sprite.frame, sprite.flip_h, sprite.position,
		facing_node.rotation, sprite.modulate.a, sprite.visible, hp, dead, hacking, facing, flash.visible]


func net_apply(a: Array) -> void:
	var pos: Vector2 = a[0]
	if pos.distance_to(global_position) > 64.0:
		global_position = pos  # warps, boat, respawn: jump instead of sliding there
	_net_pos = pos
	var anim: StringName = a[1]
	if sprite.animation != anim:
		sprite.play(anim)
	if absi(sprite.frame - int(a[2])) > 1:
		sprite.frame = int(a[2])
	sprite.flip_h = a[3]
	sprite.position = a[4]
	_net_rot = a[5]
	sprite.modulate.a = a[6]
	sprite.visible = a[7]
	var new_hp: int = a[8]
	if new_hp != hp:
		if new_hp < hp:
			Sfx.play("hurt")
			shake(2.0)
		hp = new_hp
		hp_changed.emit(hp, MAX_HP)
	dead = a[9]
	if player_index == 1:
		hacking = a[10]  # Player 2's panel is open here, its state is ours
	facing = a[11]
	flash.visible = a[12]


func _puppet_step(delta: float) -> void:
	global_position = global_position.lerp(_net_pos, minf(1.0, delta * 18.0))
	facing_node.rotation = lerp_angle(facing_node.rotation, _net_rot, minf(1.0, delta * 20.0))
	# Our own prompt on the HUD ("[E] ..."); pressing E is sent to the host.
	if player_index == 2 and not (dead or hacking or Game.dialog_lock):
		_update_interactable()
	else:
		current_interactable = null
