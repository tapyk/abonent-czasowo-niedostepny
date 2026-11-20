extends Area2D
## Door / stairs: stepping in moves Johnny to another map. Optional progress gate.

var target_map := ""
var target_cell := Vector2i.ZERO
var need := ""

const BLOCKED := {
	"pistol": "Bez pistoletu taty nie wychodzę. Leży na stole.",
}


func _ready() -> void:
	collision_layer = 16
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 12)
	shape.shape = rect
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or body.dead:
		return
	if need != "" and not Game.has(need):
		Game.say_line("Johnny", BLOCKED.get(need, "Jeszcze nie."))
		body.bounce_back()
		return
	get_tree().call_group("story", "warp_to", target_map, target_cell)
