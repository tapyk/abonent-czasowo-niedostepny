extends Node2D
## Braun's jet on the strip by Mama's house.

func _ready() -> void:
	add_to_group("interactable")
	var t := PropArt.plane()
	$Sprite.texture = t
	$Sprite.position = Vector2(0, -t.get_height() / 2.0)
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(t.get_width() * 0.6, t.get_height() * 0.4)
	shape.shape = rect
	shape.position = Vector2(0, -t.get_height() * 0.35)
	body.add_child(shape)
	add_child(body)


func can_interact() -> bool:
	return true


func prompt() -> String:
	return "[E] Samolot"


func interact(_player: Node) -> void:
	get_tree().call_group("story", "try_board_plane")
