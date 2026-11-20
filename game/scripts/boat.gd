extends Node2D
## Rowing boat at the pier.

var target_map := ""
var target_cell := Vector2i.ZERO
var _t := 0.0


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("boats")
	z_index = -1


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var bob := sin(_t * 2.0) * 0.8
	var o := Vector2(0, bob)
	# hull (top-down, pointy bow to the right)
	var hull := PackedVector2Array([o + Vector2(-14, -9), o + Vector2(8, -9), o + Vector2(16, -4),
		o + Vector2(8, 1), o + Vector2(-14, 1)])
	draw_colored_polygon(hull, Color("6a4424"))
	draw_polyline(hull + PackedVector2Array([hull[0]]), Color("3a2412"), 1.0)
	draw_rect(Rect2(o + Vector2(-12, -7), Vector2(18, 6)), Color("8a5a30"))
	draw_rect(Rect2(o + Vector2(-4, -7), Vector2(2, 6)), Color("5a3a1a"))  # bench
	draw_line(o + Vector2(-6, -11), o + Vector2(2, 3), Color("c0a070"), 1.0)  # oar
	# ripples
	var a := 0.25 + 0.15 * sin(_t * 3.0)
	draw_line(o + Vector2(-17, 3), o + Vector2(-8, 3), Color(0.7, 0.85, 1.0, a))
	draw_line(o + Vector2(10, 3), o + Vector2(18, 2), Color(0.7, 0.85, 1.0, a))


func get_interact_position() -> Vector2:
	return global_position + Vector2(0, -4)


func can_interact() -> bool:
	return true


func prompt() -> String:
	return "[E] Łódka"


func interact(player: Node) -> void:
	get_tree().call_group("story", "board_boat", self, player)
