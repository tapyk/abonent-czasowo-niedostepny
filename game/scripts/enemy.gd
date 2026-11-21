extends CharacterBody2D
## Mutant (top-down).

enum State { WANDER, CHASE, HURT, DEAD }

@export var burnt := false

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var glow: PointLight2D = $Glow

var hp := 2
var walk_speed := 18.0
var chase_speed := 44.0
var detect_base := 28.0
var detect_per_bar := 22.0
var damage := 15
var state := State.WANDER
var dir := Vector2.ZERO
var facing := Vector2.DOWN
var home := Vector2.ZERO
var _lose_t := 0.0
var _attack_cd := 0.0
var _hurt_t := 0.0
var _think_t := 0.0
var _wander_t := 0.0
var _side_t := 0.0
var _side := Vector2.ZERO
var _attack_anim := 0.0
var _knock := Vector2.ZERO
var _mark: Label


func _ready() -> void:
	add_to_group("enemies")
	collision_mask = 1 | 32  # walls + water / chasm
	home = global_position
	var diff := 1.0 + 0.15 * Game.disabled_count
	if burnt:
		hp = 4
		walk_speed = 24.0
		chase_speed = 60.0
		detect_base = 70.0
		detect_per_bar = 38.0
		damage = 25
	walk_speed *= diff
	chase_speed *= diff
	sprite.sprite_frames = CharacterArt.enemy_frames(burnt)
	sprite.offset = sprite.sprite_frames.get_meta("offset", Vector2.ZERO)
	glow.visible = burnt
	glow.texture = Art.light_radial(64)
	_mark = Label.new()
	_mark.text = "!"
	_mark.add_theme_font_override("font", Art.font())
	_mark.add_theme_font_size_override("font_size", Art.FONT_SIZE)
	_mark.add_theme_color_override("font_color", Color("ff4a3a"))
	_mark.material = Art.unshaded()
	_mark.position = Vector2(-2, -28)
	_mark.visible = false
	add_child(_mark)
	_wander_t = randf_range(0.5, 2.0)
	Game.antenna_disabled.connect(_on_antenna_disabled)


func _physics_process(delta: float) -> void:
	if Game.dialog_lock and state != State.DEAD:
		# conversation on screen: everyone waits
		velocity = Vector2.ZERO
		_animate(Vector2.ZERO)
		return
	_attack_cd -= delta
	_attack_anim -= delta
	_knock = _knock.move_toward(Vector2.ZERO, 600.0 * delta)
	var move := Vector2.ZERO
	match state:
		State.WANDER:
			move = _wander(delta)
		State.CHASE:
			move = _chase(delta)
		State.HURT:
			_hurt_t -= delta
			if _hurt_t <= 0.0:
				state = State.CHASE
	velocity = move + _knock
	move_and_slide()
	_animate(move)
	if burnt:
		glow.energy = 0.55 + 0.15 * sin(Time.get_ticks_msec() * 0.006)


func _wander(delta: float) -> Vector2:
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(1.0, 2.5)
		var to_home := home - global_position
		if to_home.length() > 40.0:
			dir = _axis(to_home)
		else:
			dir = [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN].pick_random()
	if get_slide_collision_count() > 0:
		dir = -dir
	_think_t -= delta
	if _think_t <= 0.0:
		_think_t = 0.2
		if _can_sense_player():
			alert()
	return dir * walk_speed


func _chase(delta: float) -> Vector2:
	var p := Game.player
	if not is_instance_valid(p) or p.dead:
		state = State.WANDER
		return Vector2.ZERO
	var d: Vector2 = p.global_position - global_position
	var move := d.normalized() * chase_speed if d.length() > 6.0 else Vector2.ZERO
	# Stuck on a corner: slide sideways for a moment.
	if _side_t > 0.0:
		_side_t -= delta
		move = _side * chase_speed
	elif get_slide_collision_count() > 0 and get_real_velocity().length() < chase_speed * 0.3:
		_side = Vector2(-d.y, d.x).normalized() * (1.0 if randf() < 0.5 else -1.0)
		_side_t = 0.45
	if d.length() < 13.0 and _attack_cd <= 0.0:
		_attack_cd = 0.9
		_attack_anim = 0.25
		p.take_damage(damage, global_position)
	var radius := Game.detection_radius(detect_base, detect_per_bar)
	var lost := d.length() > maxf(radius * 1.8, 120.0)
	if not burnt and Game.player_hidden and d.length() > 18.0:
		lost = true
	_lose_t = _lose_t + delta if lost else 0.0
	if _lose_t > 2.5:
		_lose_t = 0.0
		state = State.WANDER
		home = global_position
	return move


func _axis(v: Vector2) -> Vector2:
	if absf(v.x) > absf(v.y):
		return Vector2(signf(v.x), 0)
	return Vector2(0, signf(v.y))


func _can_sense_player() -> bool:
	var p := Game.player
	if not is_instance_valid(p) or p.dead:
		return false
	if Game.player_hidden and not burnt:
		return false
	var radius := Game.detection_radius(detect_base, detect_per_bar)
	var from := global_position + Vector2(0, -8)
	var to: Vector2 = p.global_position + Vector2(0, -8)
	if from.distance_to(to) > radius:
		return false
	var q := PhysicsRayQueryParameters2D.create(from, to, 1)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func alert() -> void:
	if state == State.WANDER:
		state = State.CHASE
		_lose_t = 0.0
		_mark.visible = true
		Sfx.play("growl", 0.15, -10.0)
		get_tree().create_timer(0.8).timeout.connect(func(): if is_instance_valid(_mark): _mark.visible = false)


func take_damage(amount: int, knock: Vector2) -> void:
	if state == State.DEAD:
		return
	hp -= amount
	_knock = knock
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
	$Hurtbox.collision_layer = 0
	if has_meta("key"):
		Game.mark_gone(get_meta("key"))
	_drop_loot()
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(1, 1, 1, 0), 0.6).set_delay(1.2)
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
	pickup.position = position + Vector2(0, -4)
	get_parent().call_deferred("add_child", pickup)


func _on_antenna_disabled(_antenna: Node) -> void:
	# The signal stops — mutants lose interest.
	if state == State.CHASE:
		state = State.WANDER
		home = global_position


func _animate(move: Vector2) -> void:
	if move.length() > 1.0:
		facing = _axis(move)
	var kind := "walk" if move.length() > 1.0 else "idle"
	if state == State.DEAD:
		kind = "die"
	elif state == State.HURT:
		kind = "hurt"
	elif _attack_anim > 0.0:
		kind = "attack"
	var anim := CharacterArt.anim_name(sprite.sprite_frames, kind, facing)
	sprite.flip_h = CharacterArt.flip_for(sprite.sprite_frames, facing)
	if sprite.animation != anim:
		sprite.play(anim)
	sprite.speed_scale = 1.6 if state == State.CHASE else 1.0
