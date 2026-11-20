extends Area2D
## Invisible one-shot zone; tells the "story" group which trigger the player entered.

var trigger_id := ""


func _ready() -> void:
	collision_layer = 16
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 40)
	shape.shape = rect
	shape.position = Vector2.ZERO
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		get_tree().call_group("story", "on_trigger", trigger_id)
		queue_free()
