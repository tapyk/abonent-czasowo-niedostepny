extends Area2D
## Bush: slows whoever walks through and hides Johnny from ordinary mutants.

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	add_to_group("bushes")
	sprite.texture = PropArt.bush()
	sprite.flip_h = randf() < 0.5
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(body: Node) -> void:
	if body.is_in_group("player"):
		body.in_bush += 1
	_rustle()


func _on_exit(body: Node) -> void:
	if body.is_in_group("player"):
		body.in_bush = maxi(body.in_bush - 1, 0)


func _rustle() -> void:
	var tw := create_tween()
	tw.tween_property(sprite, "skew", 0.25, 0.08)
	tw.tween_property(sprite, "skew", -0.15, 0.12)
	tw.tween_property(sprite, "skew", 0.0, 0.15)
