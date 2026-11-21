extends Control
## Notes box for the hard mode (left side).

const BOX := Rect2(4, 25, 156, 148)

var hard_panel: Control = null
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


func _missing_hints(grp: String, skip: Array = []) -> Array[String]:
	var miss: Array[String] = []
	var all := _missing_all(grp)
	for k in all:
		if not skip.has(k):
			miss.append(all[k])
	return miss


## clue id -> where to find it, for the clues of `grp` not collected yet.
func _missing_all(grp: String) -> Dictionary:
	var miss := {}
	match grp:
		"a1":
			if not Game.note_ids.has("a1_floor"):
				miss["a1_floor"] = "Sprawdź rachunek w mieszkaniu lub tabliczkę dachu"
			if not Game.note_ids.has("a1_tech"):
				miss["a1_tech"] = "Przeszukaj technika na dachu [E]"
			if not Game.note_ids.has("a1_freq"):
				miss["a1_freq"] = "Sprawdź tabliczkę obok anteny na dachu [E]"
		"a2":
			if not Game.note_ids.has("a2_farmer"):
				miss["a2_farmer"] = "Pogadaj z Fasti Farmerem w stodole"
			if not Game.note_ids.has("a2_base"):
				miss["a2_base"] = "Przeczytaj schemat zworek przy palmach [E]"
			if not Game.note_ids.has("a2_math"):
				miss["a2_math"] = "Przeczytaj instrukcję lampki obok Anteny 2 [E]"
		"a3":
			if not Game.note_ids.has("a3_rule"):
				miss["a3_rule"] = "Braun w Trybunale zna kolejność"
			if not Game.note_ids.has("a3_main"):
				miss["a3_main"] = "Odczytaj główny licznik w ogrodzie (północ) [E]"
			if not Game.note_ids.has("a3_tr"):
				miss["a3_tr"] = "Odczytaj tabliczki T1-T3 w ogrodzie (południe) [E]"
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
	var skip: Array = []
	if Game.hacking and is_instance_valid(hard_panel) and hard_panel.active:
		y = _section(f, fs, y, "CO ZROBIĆ:", Color("9fd8ff"), hard_panel.how_to(), Color("ffffff"), "")
		y += 2.0
		skip = hard_panel.COVERED_BY_HOW_TO
	var list: Array[String] = []
	for n in Game.notes:
		if (not Game.hacking or n.get("group", "") == grp) and not skip.has(n.get("id", "")):
			list.append(str(n.get("text", "")))
	if list.is_empty():
		y = _section(f, fs, y, "NOTATKI:", Color("9fd8ff"), ["Brak zebranych notatek."] as Array[String], Color("9aa3ad"), "")
	else:
		y = _section(f, fs, y, "NOTATKI:", Color("9fd8ff"), list, Color("ffe89a"), "+ ")
	var missing := _missing_hints(grp if grp != "" else "a1", skip)
	if not missing.is_empty():
		_section(f, fs, y + 2.0, "BRAKUJE:", Color("ff8a6a"), missing, Color("ff8a6a"), "? ")


## A titled list; returns the y below it. Stops at the bottom of the box.
func _section(f: Font, fs: int, y: float, title: String, title_col: Color, items: Array[String],
		col: Color, bullet: String) -> float:
	var w := BOX.size.x - 10.0
	if y > BOX.end.y - 12.0:
		return y
	draw_string(f, Vector2(BOX.position.x + 5, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, title_col)
	y += 10.0
	for item in items:
		var text := bullet + item
		var lines := maxi(1, roundi(f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w, fs).y / 9.0))
		if y + (lines - 1) * 9.0 > BOX.end.y - 4.0:
			break
		draw_multiline_string(f, Vector2(BOX.position.x + 5, y), text, HORIZONTAL_ALIGNMENT_LEFT, w, fs, -1, col)
		y += lines * 9.0 + 1.0
	return y
