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


## Decompressed RGBA8 copy of (a region of) an image file; null if missing.
static func image(path: String, rect := Rect2i()) -> Image:
	var t := tex(path)
	if t == null:
		return null
	var img := t.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	if rect.size != Vector2i.ZERO:
		img = img.get_region(rect)
	return img


## Pixel-art texture scaled once at load time (Lanczos keeps detail when shrinking).
static func scaled(path: String, scale: float, rect := Rect2i(), tint := Color.WHITE) -> Texture2D:
	var key := "sc_%s_%f_%s_%s" % [path, scale, rect, tint.to_html()]
	if _cache.has(key):
		return _cache[key]
	var img := image(path, rect)
	if img == null:
		return null
	if scale != 1.0:
		img.resize(maxi(1, roundi(img.get_width() * scale)), maxi(1, roundi(img.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
	if tint != Color.WHITE:
		for y in img.get_height():
			for x in img.get_width():
				img.set_pixel(x, y, img.get_pixel(x, y) * tint)
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
	if ResourceLoader.exists(FONT_PATH):
		var ff: FontFile = load(FONT_PATH)
		ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		ff.hinting = TextServer.HINTING_NONE
		ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		ff.generate_mipmaps = false
		# Bitmap font: draw 1:1 at FONT_SIZE, crisp 2x/3x for big titles.
		ff.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
		f = ff
	else:
		f = ThemeDB.fallback_font
	_cache["font"] = f
	return f


## Abonent5: the game's own bitmap font.
const FONT_PATH := "res://assets/fonts/abonent5.fnt"
const FONT_SIZE := 8
