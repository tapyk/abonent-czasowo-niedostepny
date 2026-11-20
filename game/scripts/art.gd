class_name Art
## Central place that maps game visuals to asset files.

const TILE := 16

static var _cache := {}


static func tex(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[path] = t
	return t


## Sub-region of a sheet (grid coordinates) as an AtlasTexture.
static func region(path: String, cell: Vector2i, cell_size: Vector2i, span := Vector2i.ONE, spacing := 0) -> Texture2D:
	var base := tex(path)
	if base == null:
		return null
	var at := AtlasTexture.new()
	at.atlas = base
	var pos := Vector2(cell.x * (cell_size.x + spacing), cell.y * (cell_size.y + spacing))
	at.region = Rect2(pos, Vector2(cell_size * span + (span - Vector2i.ONE) * spacing))
	return at


static func box(size: Vector2i, fill: Color, outline := Color.TRANSPARENT) -> ImageTexture:
	var key := "box_%s_%s_%s" % [size, fill.to_html(), outline.to_html()]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	if outline.a > 0.0:
		for x in size.x:
			img.set_pixel(x, 0, outline)
			img.set_pixel(x, size.y - 1, outline)
		for y in size.y:
			img.set_pixel(0, y, outline)
			img.set_pixel(size.x - 1, y, outline)
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


## Simple 16x24 humanoid used until real character sprites exist.
static func humanoid(body: Color, head: Color, frame := 0) -> ImageTexture:
	var key := "hum_%s_%s_%d" % [body.to_html(), head.to_html(), frame]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create_empty(16, 24, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(5, 1, 6, 6), head)
	img.fill_rect(Rect2i(4, 7, 8, 9), body)
	var leg := 1 if frame % 2 == 0 else -1
	img.fill_rect(Rect2i(5 + leg, 16, 2, 8), body.darkened(0.3))
	img.fill_rect(Rect2i(9 - leg, 16, 2, 8), body.darkened(0.3))
	img.fill_rect(Rect2i(11, 9, 4, 2), body.darkened(0.15))
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


## Soft radial light texture.
static func light_radial(size := 128) -> Texture2D:
	var key := "light_%d" % size
	if _cache.has(key):
		return _cache[key]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = size
	gt.height = size
	_cache[key] = gt
	return gt


## Flashlight cone pointing right; origin at the left-middle of the texture.
static func light_cone(length := 160, half_angle_deg := 24.0) -> Texture2D:
	var key := "cone_%d_%f" % [length, half_angle_deg]
	if _cache.has(key):
		return _cache[key]
	var h := int(ceil(tan(deg_to_rad(half_angle_deg)) * length)) * 2 + 2
	var img := Image.create_empty(length, h, false, Image.FORMAT_RGBA8)
	var cy := h / 2.0
	for x in length:
		for y in h:
			var dy := absf(y + 0.5 - cy)
			var ang := rad_to_deg(atan2(dy, x + 0.5))
			if ang > half_angle_deg:
				continue
			var edge := clampf((half_angle_deg - ang) / 6.0, 0.0, 1.0)
			var fall := pow(1.0 - float(x) / length, 1.3)
			img.set_pixel(x, y, Color(1, 1, 1, edge * fall))
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


static func unshaded() -> CanvasItemMaterial:
	if not _cache.has("unshaded"):
		var m := CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		_cache["unshaded"] = m
	return _cache["unshaded"]


static func font() -> Font:
	if _cache.has("font"):
		return _cache["font"]
	var f: Font = null
	for p in ["res://assets/fonts/pixel_font.ttf", "res://assets/fonts/pixel_font.otf"]:
		if ResourceLoader.exists(p):
			f = load(p)
			break
	if f == null:
		f = ThemeDB.fallback_font
	_cache["font"] = f
	return f


const FONT_SIZE := 16
