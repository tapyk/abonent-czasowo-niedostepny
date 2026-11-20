extends Node2D
## Braun's jet at the small airfield. Grounded while the signal jams the avionics.

func _ready() -> void:
	add_to_group("interactable")
	var t := PropArt.plane()
	$Sprite.texture = t
	$Sprite.position = Vector2(0, -t.get_height() / 2.0)


func can_interact() -> bool:
	return true


func prompt() -> String:
	return "[E] Samolot"


func interact(_player: Node) -> void:
	if Game.disabled_count == 0:
		Game.say_line("Johnny", "Awionika martwa. Dopóki antena nadaje, nic stąd nie wystartuje.")
		return
	get_tree().call_group("story", "go_to_ending")
