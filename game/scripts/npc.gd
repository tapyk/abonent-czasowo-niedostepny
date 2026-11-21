extends StaticBody2D
## Story character standing in the world: Fasti Farmer, Donald Braun, Mama.

const SHEETS := {
	"farmer": "hd:farmer",
	"braun": "hd:braun",
	"mama": "hd:mama",
}
const NAMES := {"farmer": "Fasti Farmer", "braun": "Donald Braun", "mama": "Mama"}
const TINTS := {"farmer": Color(1.0, 0.95, 0.8), "braun": Color(0.85, 0.9, 1.0), "mama": Color.WHITE}

var npc_id := "farmer"
var _sprite: AnimatedSprite2D
var _mark: Label
var _t := 0.0


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("npcs")
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 6)
	shape.shape = rect
	shape.position = Vector2(0, -3)
	add_child(shape)
	_sprite = AnimatedSprite2D.new()
	var sf: SpriteFrames = CharacterArt.npc_frames(SHEETS.get(npc_id, ""), TINTS.get(npc_id, Color.WHITE))
	_sprite.sprite_frames = sf
	_sprite.position = Vector2(0, -8)
	_sprite.offset = sf.get_meta("offset", Vector2.ZERO)
	_sprite.play(CharacterArt.anim_name(sf, "idle", Vector2.DOWN))
	add_child(_sprite)
	# Warm light: safe place / friendly face.
	var l := PointLight2D.new()
	l.texture = Art.light_radial(96)
	l.color = Color(1.0, 0.85, 0.6)
	l.energy = 0.7
	l.position = Vector2(0, -8)
	add_child(l)
	_mark = Label.new()
	_mark.text = "!"
	_mark.add_theme_font_override("font", Art.font())
	_mark.add_theme_font_size_override("font_size", Art.FONT_SIZE)
	_mark.add_theme_color_override("font_color", Color("ffe08a"))
	_mark.material = Art.unshaded()
	_mark.position = Vector2(-2, -30)
	add_child(_mark)


func _process(delta: float) -> void:
	_t += delta
	_mark.visible = has_news()
	_mark.position.y = -30 + sin(_t * 4.0) * 1.5
	# Look at Johnny when he is close.
	var p := Game.player
	if is_instance_valid(p) and p.global_position.distance_to(global_position) < 48.0:
		var d: Vector2 = p.global_position - global_position
		var anim := CharacterArt.anim_name(_sprite.sprite_frames, "idle", d)
		_sprite.flip_h = CharacterArt.flip_for(_sprite.sprite_frames, d)
		if _sprite.animation != anim:
			_sprite.play(anim)


## Yellow "!" while this character has something new to say.
func has_news() -> bool:
	var story := get_tree().get_first_node_in_group("story")
	return story != null and story.has_method("npc_has_news") and story.npc_has_news(npc_id)


func can_interact() -> bool:
	return true


func prompt() -> String:
	return "[E] Rozmawiaj: " + NAMES.get(npc_id, npc_id)


func interact(_player: Node) -> void:
	talk()


func talk() -> void:
	Sfx.play("confirm", 0.05, -8.0)
	get_tree().call_group("story", "on_npc", npc_id)
