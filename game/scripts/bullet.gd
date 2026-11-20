extends Area2D
## Pistol round: flies straight, hurts the first mutant it touches, stops on walls.

const SPEED := 360.0

var direction := Vector2.RIGHT
var _life := 0.9


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$Sprite.texture = PropArt.bullet()
	$Sprite.material = Art.unshaded()
	$Light.texture = Art.light_radial(64)
	$Sprite.flip_h = direction.x < 0.0


func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies"):
		body.take_damage(1, Vector2(direction.x * 90.0, -40.0))
		Sfx.play("hit")
	queue_free()
