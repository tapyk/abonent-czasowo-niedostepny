extends Node2D
## Tyrolkowy mutant: a burnt one hanging on the zipline.

const MAX_HP := 7
const SPEED := 30.0
const DAMAGE := 18
const BITE_CD := 1.0

var line: Node2D
var u := 1.0
var hp := MAX_HP
var alive := true
var burnt := true
var _cd := 0.6
var _sprite: AnimatedSprite2D
var _t := 0.0


func _ready() -> void:
	add_to_group("enemies")
	var sf := CharacterArt.enemy_frames(true)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = sf
	_sprite.play(CharacterArt.anim_name(sf, "walk", Vector2.LEFT))
	_sprite.flip_h = CharacterArt.flip_for(sf, Vector2.LEFT)
	_sprite.scale = Vector2(1.25, 1.25) if not sf.has_meta("offset") else Vector2.ONE
	_sprite.offset = sf.get_meta("offset", Vector2.ZERO)
	_sprite.position = Vector2(0, -10)
	add_child(_sprite)
	var glow := PointLight2D.new()
	glow.texture = Art.light_radial(64)
	glow.color = Color(1, 0.45, 0.2)
	glow.energy = 0.8
	glow.position = Vector2(0, -10)
	add_child(glow)
	var hurt := Area2D.new()
	hurt.collision_layer = 4
	hurt.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 20)
	shape.shape = rect
	shape.position = Vector2(0, -10)
	hurt.add_child(shape)
	add_child(hurt)
	Sfx.play("growl", 0.1, -2.0)


func _physics_process(delta: float) -> void:
	if not alive or line == null:
		return
	_t += delta
	_cd -= delta
	var span: float = maxf(line.length(), 1.0)
	var front: Dictionary = line.front_rider()  # the rider closest to it
	var gap: float = (u - front.t) * span if not front.is_empty() else INF
	if not front.is_empty() and gap > 12.0:
		u = maxf(u - SPEED * delta / span, front.t)
	# Same height as the rider's feet, so melee and bites line up.
	position = line.cable_point(u) + Vector2(0, line.HANG - 4)
	_sprite.rotation = sin(_t * 5.0) * 0.12
	if not front.is_empty() and gap < 15.0 and _cd <= 0.0 and is_instance_valid(front.node):
		_cd = BITE_CD
		front.node.take_damage(DAMAGE, global_position)
		line.push_back(26.0, front)
	queue_redraw()


func _draw() -> void:
	if not alive:
		return
	draw_rect(Rect2(-9, -32, 18, 3), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-8, -31, 16.0 * hp / MAX_HP, 1), Color("ff6a3a"))


func alert() -> void:
	pass


func take_damage(amount: int, _knock: Vector2) -> void:
	if not alive:
		return
	hp -= amount
	_sprite.modulate = Color(3, 3, 3)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.15)
	if line != null:
		u = minf(u + 4.0 / maxf(line.length(), 1.0), 1.0)
	if hp <= 0:
		_die()
	else:
		Sfx.play("enemy_hurt")


func _die() -> void:
	alive = false
	remove_from_group("enemies")
	Sfx.play("enemy_die")
	queue_redraw()
	line.boss_died()
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "position:y", position.y + 90.0, 1.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "rotation", 2.5, 1.2)
	tw.tween_property(self, "scale", Vector2(0.4, 0.4), 1.2)
	tw.tween_property(self, "modulate:a", 0.0, 1.2)
	tw.chain().tween_callback(queue_free)
