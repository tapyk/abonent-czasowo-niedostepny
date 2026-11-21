extends Control
## Crisp pixel-art Clues / Cheat-sheet overlay for Hard Mode (320x180 viewport).

const BOX := Rect2(4, 25, 136, 120)

var manual_open := false
var hide_in_hack := false
var active_group := ""
var _was_hacking := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(320, 180)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if Game.is_hard() and not Game.hacking and manual_open and event.is_action_pressed("back"):
		manual_open = false
		visible = false
		Sfx.play("beep", 0.05, -10.0)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not Game.is_hard():
		visible = false
		return
	if Game.hacking and not _was_hacking:
		hide_in_hack = false
	_was_hacking = Game.hacking
	if Input.is_action_just_pressed("toggle_notes"):
		if Game.hacking:
			hide_in_hack = not hide_in_hack
		else:
			manual_open = not manual_open
		Sfx.play("beep", 0.05, -10.0)
	var show_now := (Game.hacking and not hide_in_hack) or (not Game.hacking and manual_open)
	if visible != show_now:
		visible = show_now
	if visible:
		queue_redraw()


func _current_group() -> String:
	if active_group != "" and Game.hacking:
		return active_group
	match Game.current_map:
		"home", "roof":
			return "a1"
		"stodola", "world":
			return "a2"
		"trybunal":
			return "a3"
	return ""


func _missing_hints(grp: String) -> Array[String]:
	var miss: Array[String] = []
	match grp:
		"a1":
			if not Game.note_ids.has("a1_floor"):
				miss.append("Sprawdź rachunek w mieszkaniu lub tabliczkę dachu")
			if not Game.note_ids.has("a1_tech"):
				miss.append("Przeszukaj technika na dachu [E]")
			if not Game.note_ids.has("a1_freq"):
				miss.append("Sprawdź tabliczkę obok anteny na dachu [E]")
		"a2":
			if not Game.note_ids.has("a2_farmer"):
				miss.append("Pogadaj z Fasti Farmerem w stodole")
			if not Game.note_ids.has("a2_base"):
				miss.append("Przeczytaj schemat zworek przy palmach [E]")
			if not Game.note_ids.has("a2_math"):
				miss.append("Przeczytaj instrukcję lampki obok Anteny 2 [E]")
		"a3":
			if not Game.note_ids.has("a3_rule"):
				miss.append("Braun w Trybunale zna kolejność")
			if not Game.note_ids.has("a3_main"):
				miss.append("Odczytaj główny licznik w ogrodzie (północ) [E]")
			if not Game.note_ids.has("a3_tr"):
				miss.append("Odczytaj tabliczki T1-T3 w ogrodzie (południe) [E]")
	return miss


func _draw() -> void:
	var f := Art.font()
	var fs := Art.FONT_SIZE
	draw_rect(BOX, Color(0.03, 0.06, 0.09, 0.94))
	draw_rect(BOX, Color("5a9abf"), false, 1.0)

	var grp := _current_group()
	var hdr := "WSKAZÓWKI [TAB]"
	if grp != "":
		hdr += " - " + grp.to_upper()
	draw_string(f, BOX.position + Vector2(5, 9), hdr, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("9fd8ff"))
	draw_line(BOX.position + Vector2(3, 12), BOX.position + Vector2(BOX.size.x - 3, 12), Color(0.35, 0.6, 0.75, 0.5), 1.0)

	var y := BOX.position.y + 21.0
	var w := BOX.size.x - 10.0
	var list := Game.clues_for(grp if Game.hacking else "")
	if list.is_empty():
		draw_multiline_string(f, Vector2(BOX.position.x + 5, y), "Brak zebranych notatek.", HORIZONTAL_ALIGNMENT_LEFT, w, fs, -1, Color("9aa3ad"))
		y += 12.0
	else:
		for item in list:
			if y > BOX.end.y - 16.0:
				break
			var lines := maxi(1, roundi(f.get_multiline_string_size("+ " + item, HORIZONTAL_ALIGNMENT_LEFT, w, fs).y / 9.0))
			draw_multiline_string(f, Vector2(BOX.position.x + 5, y), "+ " + item, HORIZONTAL_ALIGNMENT_LEFT, w, fs, -1, Color("ffe89a"))
			y += lines * 9.0 + 3.0

	var missing := _missing_hints(grp if grp != "" else "a1")
	for m in missing:
		if y > BOX.end.y - 8.0:
			break
		var lines := maxi(1, roundi(f.get_multiline_string_size("? " + m, HORIZONTAL_ALIGNMENT_LEFT, w, fs).y / 9.0))
		draw_multiline_string(f, Vector2(BOX.position.x + 5, y), "? " + m, HORIZONTAL_ALIGNMENT_LEFT, w, fs, -1, Color("ff8a6a"))
		y += lines * 9.0 + 2.0
