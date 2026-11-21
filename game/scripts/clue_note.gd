extends Node2D
## Hard-mode readable world clue (plaque / schematic / meter).

var clue_id := ""
var ant_group := "a1"
var title_prompt := "Notatka"
var note_line := ""
var dialog_speaker := "Johnny"
var dialog_text := ""
var is_meter := false

var _t := randf() * TAU
var _mark: Label
var _sprite: Sprite2D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("hard_clues")
	_sprite = Sprite2D.new()
	if is_meter:
		_sprite.texture = PropArt.antenna_panel()
		_sprite.scale = Vector2(0.8, 0.8)
	else:
		_sprite.texture = Art.box(Vector2i(9, 11), Color("ebe0c0"), Color("4a3c2c"))
	_sprite.position = Vector2(0, -6)
	add_child(_sprite)

	var light := PointLight2D.new()
	light.texture = Art.light_radial(56)
	light.color = Color("7ad8ff") if is_meter else Color("ffe29a")
	light.energy = 0.72
	light.position = Vector2(0, -6)
	add_child(light)

	_mark = Label.new()
	_mark.text = "?"
	_mark.add_theme_font_override("font", Art.font())
	_mark.add_theme_font_size_override("font_size", Art.FONT_SIZE)
	_mark.add_theme_color_override("font_color", Color("9fd8ff"))
	_mark.material = Art.unshaded()
	_mark.position = Vector2(-2, -22)
	add_child(_mark)


func _process(delta: float) -> void:
	_t += delta
	var unread := not Game.note_ids.has(clue_id)
	_mark.visible = unread
	_mark.position.y = -22.0 + sin(_t * 4.0) * 1.5


func get_interact_position() -> Vector2:
	return global_position + Vector2(0, -4)


func can_interact() -> bool:
	return true


func prompt() -> String:
	return "[E] " + title_prompt  # the HUD shows [L] when it is P2's prompt


func interact(_player: Node) -> void:
	var added := Game.add_clue(clue_id, ant_group, note_line)
	if not added:
		Sfx.play("beep", 0.05, -8.0)
		Game.show_hint("Wskazówka [TAB]: " + note_line)
	Game.say_line(dialog_speaker, dialog_text, false, true)
