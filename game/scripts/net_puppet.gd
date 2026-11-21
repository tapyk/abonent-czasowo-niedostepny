extends Node2D
## Online client.

var burnt := false
var sprite: AnimatedSprite2D
var _target := Vector2.ZERO
var _dying := false


func _ready() -> void:
	add_to_group("enemies")
	_target = position
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = CharacterArt.enemy_frames(burnt)
	sprite.offset = sprite.sprite_frames.get_meta("offset", Vector2.ZERO)
	add_child(sprite)
	if burnt:
		var glow := PointLight2D.new()
		glow.texture = Art.light_radial(64)
		glow.color = Color(1, 0.45, 0.2)
		glow.energy = 0.6
		glow.position = Vector2(0, -8)
		add_child(glow)


## [id, position, sprite position, animation, flip, rotation, scale, modulate, burnt]
func net_apply(e: Array) -> void:
	if _dying:
		return
	var pos: Vector2 = e[1]
	if pos.distance_to(position) > 64.0:
		position = pos
	_target = pos
	sprite.position = e[2]
	var anim: StringName = e[3]
	if sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)
	sprite.flip_h = e[4]
	sprite.rotation = e[5]
	sprite.scale = e[6]
	sprite.modulate = e[7]


func _process(delta: float) -> void:
	if not _dying:
		position = position.lerp(_target, minf(1.0, delta * 15.0))


## Gone from the host's snapshot: it died there.
func net_die() -> void:
	if _dying:
		return
	_dying = true
	remove_from_group("enemies")
	Sfx.play("enemy_die")
	var die := CharacterArt.anim_name(sprite.sprite_frames, "die", Vector2.DOWN)
	if sprite.sprite_frames.has_animation(die):
		sprite.play(die)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate:a", 0.0, 0.6).set_delay(1.0)
	tw.tween_callback(queue_free)
