extends CharacterBody2D
## Johnny Walker.

signal died
signal hp_changed(hp: int, max_hp: int)

const BULLET := preload("res://scenes/bullet.tscn")

const SPEED := 85.0
const ACCEL := 900.0
const FRICTION := 1100.0
const JUMP_VELOCITY := -330.0
const GRAVITY := 900.0
const MAX_FALL := 400.0
const COYOTE := 0.1
const JUMP_BUFFER := 0.12
const FIRE_COOLDOWN := 0.3
const MELEE_COOLDOWN := 0.45
const MELEE_RANGE := 22.0
const MAX_HP := 100
const INVULN := 0.9
const ONEWAY_BIT := 6
const BUSH_SLOW := 0.55

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var facing_node: Node2D = $Facing
@onready var muzzle: Marker2D = $Facing/Muzzle
@onready var flash: Sprite2D = $Facing/MuzzleFlash
@onready var camera: Camera2D = $Camera

var hp := MAX_HP
var facing := 1
var dead := false
var hacking := false
var in_bush := 0
var _coyote := 0.0
var _jump_buf := 0.0
var _fire_cd := 0.0
var _melee_cd := 0.0
var _invuln := 0.0
var _drop_timer := 0.0
var _reveal := 0.0
var _step_t := 0.0
var _melee_anim := 0.0
var current_interactable: Node = null


func _ready() -> void:
	add_to_group("player")
	Game.player = self
	sprite.sprite_frames = CharacterArt.player_frames()
	sprite.play("idle")
	flash.texture = CharacterArt.muzzle_flash()
	flash.material = Art.unshaded()
	flash.visible = false
	$Facing/Flashlight.texture = Art.light_cone(170, 22.0)
	$Facing/Flashlight.offset = Vector2(85, 0)
	$Aura.texture = Art.light_radial(96)


func _physics_process(delta: float) -> void:
	_fire_cd -= delta
	_melee_cd -= delta
	_invuln -= delta
	_reveal -= delta
	_melee_anim -= delta
	if _drop_timer > 0.0:
		_drop_timer -= delta
		if _drop_timer <= 0.0:
			set_collision_mask_value(ONEWAY_BIT, true)

	Game.player_hidden = in_bush > 0 and _reveal <= 0.0 and not dead
	sprite.modulate.a = 0.55 if Game.player_hidden else 1.0
	if _invuln > 0.0 and not dead:
		sprite.visible = int(_invuln * 20.0) % 2 == 0
	else:
		sprite.visible = true

	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)

	if dead or hacking:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		move_and_slide()
		_animate()
		return

	var dir := Input.get_axis("move_left", "move_right")
	var speed := SPEED * (BUSH_SLOW if in_bush > 0 else 1.0)
	if dir != 0.0:
		velocity.x = move_toward(velocity.x, dir * speed, ACCEL * delta)
		facing = 1 if dir > 0.0 else -1
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	if is_on_floor():
		_coyote = COYOTE
	else:
		_coyote -= delta
	if Input.is_action_just_pressed("jump"):
		_jump_buf = JUMP_BUFFER
	else:
		_jump_buf -= delta

	if _jump_buf > 0.0 and Input.is_action_pressed("move_down") and is_on_floor():
		# Drop through a one-way platform.
		_jump_buf = 0.0
		set_collision_mask_value(ONEWAY_BIT, false)
		_drop_timer = 0.25
		position.y += 1
	elif _jump_buf > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_buf = 0.0
		_coyote = 0.0
		Sfx.play("jump", 0.05, -8.0)
	if Input.is_action_just_released("jump") and velocity.y < -120.0:
		velocity.y *= 0.55  # variable jump height

	if Input.is_action_just_pressed("shoot"):
		shoot()
	if Input.is_action_just_pressed("melee"):
		melee()

	move_and_slide()
	_update_interactable()
	if Input.is_action_just_pressed("interact") and current_interactable:
		current_interactable.interact(self)
	_footsteps(delta)
	_animate()


func shoot() -> void:
	if _fire_cd > 0.0:
		return
	_fire_cd = FIRE_COOLDOWN
	if Game.ammo <= 0:
		Sfx.play("empty")
		Game.say_line("Johnny", "Pusto. Zostają pięści [K].")
		return
	Game.ammo -= 1
	Game.stats_changed.emit()
	var b := BULLET.instantiate()
	b.global_position = muzzle.global_position
	b.direction = Vector2(facing, 0)
	get_parent().add_child(b)
	Sfx.play("shoot")
	_reveal = 1.5
	Game.make_noise(global_position, 150.0)
	flash.visible = true
	get_tree().create_timer(0.06).timeout.connect(func(): flash.visible = false)


func melee() -> void:
	if _melee_cd > 0.0:
		return
	_melee_cd = MELEE_COOLDOWN
	_melee_anim = 0.2
	Sfx.play("melee")
	var hit := false
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: Vector2 = e.global_position - global_position
		if absf(d.y) < 20.0 and d.x * facing >= -4.0 and absf(d.x) <= MELEE_RANGE:
			e.take_damage(1, Vector2(facing * 140.0, -80.0))
			hit = true
	if hit:
		Sfx.play("hit")
	Game.make_noise(global_position, 60.0)


func take_damage(amount: int, from: Vector2) -> void:
	if dead or _invuln > 0.0 or Game.dev.has("god"):
		return
	hp = maxi(hp - amount, 0)
	_invuln = INVULN
	hp_changed.emit(hp, MAX_HP)
	Sfx.play("hurt")
	var push := signf(global_position.x - from.x)
	velocity = Vector2((push if push != 0.0 else 1.0) * 160.0, -140.0)
	if hp <= 0:
		_die()


func heal(amount: int) -> void:
	hp = mini(hp + amount, MAX_HP)
	hp_changed.emit(hp, MAX_HP)


func _die() -> void:
	dead = true
	set_hacking(false)
	died.emit()


func respawn(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	hp = MAX_HP
	dead = false
	_invuln = 2.0
	hp_changed.emit(hp, MAX_HP)
	camera.reset_smoothing()


func set_hacking(on: bool) -> void:
	hacking = on
	Game.hacking = on


func _update_interactable() -> void:
	var best: Node = null
	var best_d := 26.0
	for n in get_tree().get_nodes_in_group("interactable"):
		if not n.can_interact():
			continue
		var d: float = n.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = n
	current_interactable = best


func _footsteps(delta: float) -> void:
	if is_on_floor() and absf(velocity.x) > 20.0:
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = 0.32
			Sfx.play("step", 0.15, -14.0)
	else:
		_step_t = 0.0


func _animate() -> void:
	sprite.flip_h = facing < 0
	facing_node.scale.x = facing
	var anim := "idle"
	if dead:
		anim = "hurt"
	elif _melee_anim > 0.0:
		anim = "attack"
	elif not is_on_floor():
		anim = "jump" if velocity.y < 0.0 else "fall"
	elif absf(velocity.x) > 10.0:
		anim = "run"
	if sprite.animation != anim and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
