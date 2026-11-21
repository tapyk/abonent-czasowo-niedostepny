extends Node
## Player settings, kept in user://settings.cfg and applied at start and on every change.

const PATH := "user://settings.cfg"
const TOUCH_MODES := ["auto", "on", "off"]

## Master volume, 0-100 %.
var volume := 80
var fullscreen := false
## Camera shake on hits, shots and the crash.
var shake := true
## On-screen touch controls: "auto" (phones / first touch), "on" (always), "off" (never).
var touch := "auto"


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		volume = clampi(int(cfg.get_value("settings", "volume", volume)), 0, 100)
		fullscreen = bool(cfg.get_value("settings", "fullscreen", fullscreen))
		shake = bool(cfg.get_value("settings", "shake", shake))
		var t := str(cfg.get_value("settings", "touch", touch))
		touch = t if t in TOUCH_MODES else "auto"
	apply()


## Fullscreen only makes sense in a desktop window (phones always are, web has its own).
func can_fullscreen() -> bool:
	return not OS.has_feature("mobile") and not OS.has_feature("web") and DisplayServer.get_name() != "headless"


func apply() -> void:
	AudioServer.set_bus_mute(0, volume == 0)
	AudioServer.set_bus_volume_db(0, linear_to_db(volume / 100.0) if volume > 0 else -80.0)
	if can_fullscreen():
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want:
			DisplayServer.window_set_mode(want)
	if is_instance_valid(get_node_or_null("/root/Touch")):
		get_node("/root/Touch").set_mode(touch)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "volume", volume)
	cfg.set_value("settings", "fullscreen", fullscreen)
	cfg.set_value("settings", "shake", shake)
	cfg.set_value("settings", "touch", touch)
	cfg.save(PATH)
