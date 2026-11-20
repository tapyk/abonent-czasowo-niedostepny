extends Area2D
## Pistol round.

const SPEED := 340.0

var direction := Vector2.RIGHT
var _life := 0.8
var _done := false


func _ready() -> void:
	body_entered.connect(_on_hit)
	area_entered.connect(func(a: Area2D): _on_hit(a.get_parent()))
	$Sprite.texture = PropArt.bullet()
	$Sprite.material = Art.unshaded()
	$Light.texture = Art.light_radial(64)
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_hit(body: Node) -> void:
	if _done or body == null or body.is_in_group("player"):
		return
	if body.is_in_group("enemies"):
		body.take_damage(1, direction * 90.0)
		Sfx.play("hit")
	elif body.is_in_group("bushes"):
		return
	_done = true
	queue_free()
