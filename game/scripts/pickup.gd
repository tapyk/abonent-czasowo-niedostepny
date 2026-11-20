extends Area2D
## Pickups: pistol, garden shears.

@export var kind := "ammo"

@onready var sprite: Sprite2D = $Sprite

var _t := randf() * TAU
var _taken := false


func _ready() -> void:
	sprite.texture = PropArt.pickup(kind)
	if kind == "cable":
		add_to_group("interactable")
		sprite.position = Vector2(0, -4)
	else:
		body_entered.connect(_on_body_entered)
		if kind in ["pistol", "sekator"]:
			var l := PointLight2D.new()
			l.texture = Art.light_radial(48)
			l.energy = 0.6
			l.color = Color(1, 0.9, 0.6)
			add_child(l)


func _process(delta: float) -> void:
	if kind != "cable":
		_t += delta * 3.0
		sprite.position.y = -2.0 + sin(_t) * 1.0


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
		"pistol":
			Game.has_pistol = true
			Game.add_ammo(Game.START_AMMO)
			Game.say_line("Johnny", "Pistolet taty. Zawsze mówił, że kiedyś się przyda. Wolałbym, żeby nie miał racji.")
			Game.say_line("Tablet", "Strzał: LPM (tam, gdzie kursor) albo J. Cios: PPM / K.")
		"sekator":
			Game.has_sekator = true
			Game.stats_changed.emit()
			Game.say_line("Johnny", "Sekator. Teraz te chaszcze przed blokiem nie mają szans.")
	_taken = true
	if has_meta("key"):
		Game.mark_gone(get_meta("key"))
	Sfx.play("pickup")
	queue_free()
