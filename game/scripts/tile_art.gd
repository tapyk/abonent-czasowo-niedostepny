class_name TileArt
## Which asset tile is used for each terrain key (16x16 cells). null -> placeholder.

const SHEET_1 := "res://assets/sprites/tiles/tiles_warped_city.png"
const SHEET_2 := "res://assets/sprites/tiles/tiles_warped_city_2.png"

## key: [sheet, cell, darken (0 = none)]
const MAP := {
	"solid_top": [SHEET_2, Vector2i(1, 1), 0.0],
	"solid": [SHEET_1, Vector2i(10, 2), 0.0],
	"wall_side": [SHEET_1, Vector2i(9, 2), 0.0],
	"ground_top": [SHEET_2, Vector2i(1, 1), 0.15],
	"ground": [SHEET_1, Vector2i(10, 3), 0.45],
	"oneway": [SHEET_1, Vector2i(8, 11), 0.0],
	"wall_bg": [SHEET_1, Vector2i(10, 2), 0.0],
	"window_bg": [SHEET_1, Vector2i(4, 2), 0.0],
	"pole_bg": [SHEET_1, Vector2i(8, 7), 0.0],
}


static func get_tile(key: String) -> Texture2D:
	if not MAP.has(key):
		return null
	var e: Array = MAP[key]
	var img := Art.image(e[0], Rect2i(e[1] * 16, Vector2i(16, 16)))
	if img == null:
		return null
	if e[2] > 0.0:
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(c.r * (1.0 - e[2]), c.g * (1.0 - e[2]), c.b * (1.0 - e[2]), c.a))
	return ImageTexture.create_from_image(img)
