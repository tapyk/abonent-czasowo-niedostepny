extends StaticBody2D
## A pack of mutants standing on the road east.

const COUNT := 3


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect
	add_child(shape)
	var frames := CharacterArt.enemy_frames(randf() < 0.3)
	for i in COUNT:
		var s := AnimatedSprite2D.new()
		s.sprite_frames = frames
		s.play(CharacterArt.anim_name(frames, "walk", Vector2.LEFT))
		s.frame = randi() % maxi(1, frames.get_frame_count(s.animation))
		s.speed_scale = randf_range(0.3, 0.6)
		s.position = Vector2(randf_range(-6, 6), randf_range(-10, 4))
		s.flip_h = randf() < 0.5
		add_child(s)


func can_interact() -> bool:
	return true


func prompt() -> String:
	return "Horda mutantów"


func interact(_player: Node) -> void:
	Game.say_line("Johnny", "Za dużo ich. Stoją jak przy nadajniku. Dopóki antena nadaje, nie przejdę.")
