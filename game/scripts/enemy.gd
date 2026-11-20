extends CharacterBody2D
## Mutant.

const GRAVITY := 900.0
const ONEWAY_BIT := 6

enum State { PATROL, CHASE, HURT, DEAD }

@export var burnt := false

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var glow: PointLight2D = $Glow

var hp := 2
var walk_speed := 22.0
var chase_speed := 46.0
var detect_base := 28.0
var detect_per_bar := 22.0
var damage := 15
var state := State.PATROL
var dir := 1
var home_x := 0.0
var _lose_t := 0.0
var _attack_cd := 0.0
var _hurt_t := 0.0
var _think_t := 0.0
var _drop_t := 0.0
var _attack_anim := 0.0


func _ready() -> void:
	add_to_group("enemies")
	home_x = global_position.x
	dir = 1 if randf() < 0.5 else -1
	var diff := 1.0 + 0.15 * Game.disabled_count
	if burnt:
		hp = 4
		walk_speed = 30.0
		chase_speed = 66.0
		detect_base = 70.0
		detect_per_bar = 38.0
		damage = 25
	walk_speed *= diff
	chase_speed *= diff
	sprite.sprite_frames = CharacterArt.enemy_frames(burnt)
	sprite.play("run")
	glow.visible = burnt
	glow.texture = Art.light_radial(64)
	Game.antenna_disabled.connect(_on_antenna_disabled)


func _physics_process(delta: float) -> void:
	_attack_cd -= delta
	_attack_anim -= delta
	if _drop_t > 0.0:
		_drop_t -= delta
		if _drop_t <= 0.0:
			set_collision_mask_value(ONEWAY_BIT, true)
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 400.0)

	match state:
		State.PATROL:
			_patrol(delta)
		State.CHASE:
			_chase(delta)
		State.HURT:
			_hurt_t -= delta
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			if _hurt_t <= 0.0:
				state = State.CHASE
		State.DEAD:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	move_and_slide()
	_animate()
	if burnt:
		glow.energy = 0.55 + 0.15 * sin(Time.get_ticks_msec() * 0.006)


func _patrol(delta: float) -> void:
	velocity.x = dir * walk_speed
	if is_on_floor() and (is_on_wall() or _ledge_ahead() or absf(global_position.x - home_x) > 56.0 and signf(global_position.x - home_x) == dir):
		dir = -dir
	_think_t -= delta
	if _think_t <= 0.0:
		_think_t = 0.2
		if _can_sense_player():
			alert()


func _chase(delta: float) -> void:
	var p := Game.player
	if not is_instance_valid(p) or p.dead:
		state = State.PATROL
		return
	var d: Vector2 = p.global_position - global_position
	dir = 1 if d.x > 0.0 else -1
	velocity.x = dir * chase_speed if absf(d.x) > 6.0 else 0.0
	if is_on_floor():
		if is_on_wall() and d.y < 8.0:
			velocity.y = -250.0
		elif d.y > 24.0 and _drop_t <= 0.0:
			set_collision_mask_value(ONEWAY_BIT, false)
			_drop_t = 0.3
		elif d.y < -30.0 and absf(d.x) < 40.0 and randf() < 0.02:
			velocity.y = -300.0
	# Attack on contact.
	if absf(d.x) < 12.0 and absf(d.y) < 20.0 and _attack_cd <= 0.0:
		_attack_cd = 0.9
		_attack_anim = 0.25
		p.take_damage(damage, global_position)
	# Lose track.
	var radius := Game.detection_radius(detect_base, detect_per_bar)
	var lost := d.length() > maxf(radius * 1.8, 120.0)
	if not burnt and Game.player_hidden and d.length() > 18.0:
		lost = true
	_lose_t = _lose_t + delta if lost else 0.0
	if _lose_t > 2.5:
		_lose_t = 0.0
		state = State.PATROL
		home_x = global_position.x


func _can_sense_player() -> bool:
	var p := Game.player
	if not is_instance_valid(p) or p.dead:
		return false
	if Game.player_hidden and not burnt:
		return false
	var radius := Game.detection_radius(detect_base, detect_per_bar)
	var from := global_position + Vector2(0, -16)
	var to: Vector2 = p.global_position + Vector2(0, -12)
	if from.distance_to(to) > radius:
		return false
	var q := PhysicsRayQueryParameters2D.create(from, to, 1)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _ledge_ahead() -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = global_position + Vector2(dir * 8, 4)
	q.collision_mask = 1 | (1 << 5)
	return get_world_2d().direct_space_state.intersect_point(q, 1).is_empty()


func alert() -> void:
	if state == State.PATROL:
		state = State.CHASE
		_lose_t = 0.0


func take_damage(amount: int, knock: Vector2) -> void:
	if state == State.DEAD:
		return
	hp -= amount
	velocity = knock
	sprite.modulate = Color(3, 3, 3)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)
	if hp <= 0:
		_die()
	else:
		Sfx.play("enemy_hurt")
		state = State.HURT
		_hurt_t = 0.25


func _die() -> void:
	state = State.DEAD
	remove_from_group("enemies")
	Sfx.play("enemy_die")
	collision_layer = 0
	_drop_loot()
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(1, 1, 1, 0), 0.6).set_delay(0.3)
	tw.tween_callback(queue_free)


func _drop_loot() -> void:
	var pickup: Node2D = preload("res://scenes/pickup.tscn").instantiate()
	if burnt:
		pickup.kind = "part"
	elif randf() < 0.65:
		pickup.kind = "ammo_small"
	else:
		pickup.free()
		return
	pickup.position = position
	get_parent().call_deferred("add_child", pickup)


func _on_antenna_disabled(antenna: Node) -> void:
	# The signal stops — nearby mutants wander off.
	if state == State.CHASE and antenna.global_position.distance_to(global_position) < 420.0:
		state = State.PATROL
		home_x = global_position.x


func _animate() -> void:
	sprite.flip_h = dir < 0
	var anim := "run"
	if state == State.DEAD or state == State.HURT:
		anim = "hurt"
	elif _attack_anim > 0.0:
		anim = "attack"
	elif not is_on_floor():
		anim = "jump"
	elif absf(velocity.x) < 2.0:
		anim = "idle"
	if sprite.animation != anim and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
	sprite.speed_scale = 1.6 if state == State.CHASE else 1.0
