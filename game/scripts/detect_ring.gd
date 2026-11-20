extends Node2D
## Faint ring around Johnny showing how far ordinary mutants can sense him right now.

const NORMAL_BASE := 28.0
const NORMAL_PER_BAR := 22.0

var _r := 0.0
var _t := 0.0


func _ready() -> void:
	material = Art.unshaded()
	z_index = -1


func _process(delta: float) -> void:
	_t += delta
	var target := 0.0 if Game.bars == 0 or Game.player_hidden else Game.detection_radius(NORMAL_BASE, NORMAL_PER_BAR)
	_r = lerpf(_r, target, minf(delta * 6.0, 1.0))
	queue_redraw()


func _draw() -> void:
	if _r < 4.0:
		return
	var a := 0.10 + 0.05 * sin(_t * 4.0)
	var col := Color(1.0, 0.3, 0.25, a) if Game.bars >= 4 else Color(0.8, 0.85, 1.0, a * 0.7)
	draw_arc(Vector2(0, -12), _r, 0.0, TAU, 48, col, 1.0)
