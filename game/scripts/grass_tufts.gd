extends Node2D
## Interactive grass.

const GRASS := "res://assets/sprites/tiles/trawa.png"
## Blade clusters in trawa.png (x, y, w, h); the bottom edge is the root.
const RECTS := [Rect2i(0, 3, 10, 8), Rect2i(11, 9, 8, 7), Rect2i(18, 11, 9, 8),
	Rect2i(0, 23, 10, 8), Rect2i(10, 24, 10, 8), Rect2i(24, 23, 8, 8)]
const DENSITY := 0.45       # chance of a tuft per grass cell
const REACH := Vector2(10, 7)  # how close a walker bends a tuft
const T := 16

var _tex: Array[Texture2D] = []
var _pos := PackedVector2Array()
var _kind := PackedInt32Array()
var _phase := PackedFloat32Array()
var _bend := PackedFloat32Array()
var _grid := {}             # Vector2i cell -> Array of tuft indices
var _t := 0.0


## `cells`: grass cells (Vector2i) that may get a tuft.
func setup(cells: Array, seed_value: int) -> void:
	var src := Art.image(GRASS)
	if src == null:
		return
	for r in RECTS:
		var img := src.get_region(r)
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.r + c.g + c.b < 1.02:  # dark background of the texture -> transparent
					img.set_pixel(x, y, Color(0, 0, 0, 0))
		_tex.append(ImageTexture.create_from_image(img))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for c in cells:
		if rng.randf() >= DENSITY:
			continue
		var i := _pos.size()
		_pos.append(Vector2(c.x * T + rng.randf_range(3, 13), c.y * T + rng.randf_range(10, 15)))
		_kind.append(rng.randi() % _tex.size())
		_phase.append(rng.randf() * TAU)
		_bend.append(0.0)
		if not _grid.has(c):
			_grid[c] = []
		_grid[c].append(i)


func _process(delta: float) -> void:
	if _pos.is_empty():
		return
	_t += delta
	var push := {}
	var walkers: Array = get_tree().get_nodes_in_group("enemies")
	if is_instance_valid(Game.player):
		walkers.append(Game.player)
	for w in walkers:
		var wp: Vector2 = w.global_position - global_position
		var wc := Vector2i(floori(wp.x / T), floori(wp.y / T))
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				for i in _grid.get(wc + Vector2i(dx, dy), []):
					var d: Vector2 = _pos[i] - wp
					if absf(d.x) < REACH.x and absf(d.y) < REACH.y:
						# lean away from the walker, harder the closer it is
						var side := signf(d.x) if absf(d.x) > 0.5 else 1.0
						push[i] = side * (1.2 - absf(d.x) / REACH.x)
	var k := minf(1.0, delta * 10.0)
	for i in _bend.size():
		_bend[i] = lerpf(_bend[i], push.get(i, 0.0), k if push.has(i) else k * 0.35)
	queue_redraw()


func _draw() -> void:
	if _pos.is_empty():
		return
	var view := get_viewport_rect()
	var inv := get_global_transform_with_canvas().affine_inverse()
	var a: Vector2 = inv * view.position
	var b: Vector2 = inv * view.end
	var c0 := Vector2i(floori(minf(a.x, b.x) / T) - 1, floori(minf(a.y, b.y) / T) - 1)
	var c1 := Vector2i(floori(maxf(a.x, b.x) / T) + 1, floori(maxf(a.y, b.y) / T) + 1)
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			for i in _grid.get(Vector2i(cx, cy), []):
				var tex := _tex[_kind[i]]
				var lean := sin(_t * 1.6 + _phase[i]) * 0.12 + _bend[i]
				# shear: the root stays put, the tips move sideways
				draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(-lean, 1), _pos[i]))
				draw_texture(tex, Vector2(-tex.get_width() / 2.0, -tex.get_height()))
	draw_set_transform_matrix(Transform2D.IDENTITY)
