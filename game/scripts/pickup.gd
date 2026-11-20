extends Area2D
## Pickups: ammo, medkit, parts (from burnt mutants) and the dead technician's cable.

@export var kind := "ammo"

@onready var sprite: Sprite2D = $Sprite

var _t := randf() * TAU
var _taken := false


func _ready() -> void:
	sprite.texture = PropArt.pickup(kind)
	if kind == "cable":
		add_to_group("interactable")
		sprite.position = Vector2(0, -sprite.texture.get_height() / 2.0)
	else:
		body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if kind != "cable":
		_t += delta * 3.0
		sprite.position.y = -7.0 + sin(_t) * 1.5


func can_interact() -> bool:
	return kind == "cable" and not Game.has_cable


func prompt() -> String:
	return "[E] Przeszukaj technika"


func interact(_player: Node) -> void:
	Game.has_cable = true
	Game.stats_changed.emit()
	Sfx.play("pickup")
	Game.say_line("Johnny", "Kabel serwisowy. Wybacz, kolego. Tobie się już nie przyda.")
	Game.say_line("Mama", "Podłącz się do panelu. Jak zaczniesz hakować, zrobi się głośno.", true)
	Game.say_line("Johnny", "Jak głośno?")
	Game.say_line("Mama", "Bardzo.", true)


func _on_body_entered(body: Node) -> void:
	if _taken or not body.is_in_group("player"):
		return
	match kind:
		"ammo":
			Game.add_ammo(5)
		"ammo_small":
			Game.add_ammo(3)
		"medkit":
			if body.hp >= body.MAX_HP:
				return
			body.heal(35)
		"part":
			Game.add_part()
	_taken = true
	Sfx.play("pickup")
	queue_free()
