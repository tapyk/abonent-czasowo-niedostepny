extends CharacterBody2D
## Johnny Walker, top-down.

signal died
signal hp_changed(hp: int, max_hp: int)

const BULLET := preload("res://scenes/bullet.tscn")

const SPEED := 72.0
const FIRE_COOLDOWN := 0.3
const MELEE_COOLDOWN := 0.45
const MELEE_RANGE := 20.0
const MAX_HP := 100
const INVULN := 0.9
const BUSH_SLOW := 0.55
const LIGHT_TURN := 14.0    # how fast the flashlight follows the cursor
const REGEN_DELAY := 4.0    # s without damage before health starts coming back
const REGEN_RATE := 4.0     # HP/s
const REGEN_QUIET := 10.0   # HP/s with no signal or hidden in a bush
const CHASE_NEAR := 160.0   # a mutant chasing within this range stops the regen

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var facing_node: Node2D = $Facing
@onready var muzzle: Marker2D = $Facing/Muzzle
@onready var flash: Sprite2D = $Facing/MuzzleFlash
@onready var camera: Camera2D = $Camera

var hp := MAX_HP
var facing := Vector2.DOWN
var dead := false
var hacking := false
var frozen := false
## On a zipline: the line moves him, he can still shoot.
var riding := false
var in_bush := 0
var _aim := Vector2.ZERO
var _aim_t := 0.0
var _fire_cd := 0.0
var _melee_cd := 0.0
var _invuln := 0.0
var _reveal := 0.0
var _step_t := 0.0
var _melee_anim := 0.0
var _knock := Vector2.ZERO
var _since_hurt := 99.0
var _regen_acc := 0.0
## Health is coming back right now (the HUD shows it on the HP bar).
var regenerating := false
var current_interactable: Node = null


func _ready() -> void:
	add_to_group("player")
	Game.player = self
	sprite.sprite_frames = CharacterArt.player_frames()
	flash.texture = CharacterArt.muzzle_flash()
	flash.material = Art.unshaded()
	flash.visible = false
	$Facing/Flashlight.texture = Art.light_cone(150, 24.0)
	$Facing/Flashlight.offset = Vector2(75, 0)
	$Aura.texture = Art.light_radial(112)
	add_child(preload("res://scripts/detect_ring.gd").new())
	collision_mask = 1 | 32  # walls + water / chasm
	_animate(Vector2.ZERO)


func _physics_process(delta: float) -> void:
	_fire_cd -= delta
	_melee_cd -= delta
	_invuln -= delta
	_reveal -= delta
	_melee_anim -= delta
	_aim_t -= delta

	Game.player_hidden = in_bush > 0 and _reveal <= 0.0 and not dead
	sprite.modulate.a = 0.6 if Game.player_hidden else 1.0
	sprite.visible = not (_invuln > 0.0 and not dead and int(_invuln * 20.0) % 2 == 1)

	var dir := Vector2.ZERO
	if not (dead or hacking or frozen or riding):
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if dir != Vector2.ZERO:
			# Snap to 8 directions so diagonals are exact and the speed stays the same.
			dir = Vector2.RIGHT.rotated(snappedf(dir.angle(), PI / 4.0))
			facing = dir
	var speed := SPEED * (BUSH_SLOW if in_bush > 0 else 1.0)
	_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
	if not riding:
		velocity = dir * speed + _knock
		move_and_slide()

	if not (dead or hacking or frozen):
		if Input.is_action_just_pressed("shoot"):
			if can_shoot():
				shoot(_aim_dir(MOUSE_BUTTON_LEFT))
			else:
				melee(_aim_dir(MOUSE_BUTTON_LEFT))
		if Input.is_action_just_pressed("melee"):
			melee(_aim_dir(MOUSE_BUTTON_RIGHT))
	if not (dead or hacking or frozen or riding):
		_update_interactable()
		if Input.is_action_just_pressed("interact") and current_interactable:
			current_interactable.interact(self)
	else:
		current_interactable = null
	_footsteps(delta, dir)
	_regen(delta)
	_aim_light(delta)
	_animate(dir)


## Mouse button held -> aim at the cursor (and turn that way); otherwise facing.
func _aim_dir(button: MouseButton) -> Vector2:
	if not Input.is_mouse_button_pressed(button):
		return facing
	var d := get_global_mouse_position() - (global_position + Vector2(0, -6))
	if d.length() < 2.0:
		return facing
	d = d.normalized()
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
	Sfx.play("shoot")
	_reveal = 1.5
	Game.make_noise(global_position, 150.0)
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
	var hit := false
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: Vector2 = e.global_position - global_position
		if d.length() <= MELEE_RANGE and (d.length() < 6.0 or d.normalized().dot(dir) > 0.3):
			e.take_damage(1, dir * 150.0)
			hit = true
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
	riding = false
	set_hacking(false)
	died.emit()


func respawn() -> void:
	velocity = Vector2.ZERO
	_knock = Vector2.ZERO
	hp = MAX_HP
	dead = false
	_invuln = 2.0
	facing = Vector2.DOWN
	hp_changed.emit(hp, MAX_HP)


func set_hacking(on: bool) -> void:
	hacking = on
	Game.hacking = on


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
		var d := get_global_mouse_position() - (global_position + Vector2(0, -6))
		if d.length() > 2.0:
			want = d.angle()
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
	var anim := CharacterArt.anim_name(sprite.sprite_frames, kind, look)
	sprite.flip_h = CharacterArt.flip_for(sprite.sprite_frames, look)
	if sprite.animation != anim:
		sprite.play(anim)
