extends Node2D
## Braun's plane at the small airfield. Grounded while the signal jams the avionics.

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
	if Game.disabled_count == 0:
		Game.say_line("Johnny", "Awionika martwa. Dopóki antena nadaje, nic stąd nie wystartuje.")
		return
	get_tree().call_group("story", "go_to_ending")
