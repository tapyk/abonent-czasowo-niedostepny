extends Node
## Sound effects by name + procedural radio static (no asset needed for static).

const A := "res://assets/audio/"
## name -> list of files (one picked at random per play).
const SOUNDS := {
	"shoot": ["pistol_shot.ogg", "pistol_shot_alt.ogg"],
	"empty": ["gun_empty_click.ogg"],
	"melee": ["melee_swing.wav", "melee_swing_light.wav"],
	"hit": ["hit_flesh.ogg", "hit_flesh_2.ogg"],
	"enemy_hurt": ["zombie_hurt.wav"],
	"enemy_die": ["zombie_death.wav"],
	"growl": ["zombie_growl_1.wav", "zombie_growl_2.wav"],
	"pickup": ["pickup.ogg"],
	"jump": ["jump.ogg"],
	"hurt": ["melee_punch.ogg"],
	"beep": ["ui_beep.ogg"],
	"confirm": ["ui_confirm.ogg"],
	"error": ["ui_error.ogg"],
	"shutdown": ["power_down.ogg"],
	"step": ["footstep_concrete_1.ogg", "footstep_concrete_2.ogg", "footstep_concrete_3.ogg"],
}

const POOL_SIZE := 10
const MIX_RATE := 22050.0

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _static_player: AudioStreamPlayer
var _static_playback: AudioStreamGeneratorPlayback
var _static_level := 0.0
var _static_target := 0.0
var _lp := 0.0
var _hum_playback: AudioStreamGeneratorPlayback
var _hum_level := 0.0
var _hum_phase := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in SOUNDS:
		var list: Array = []
		for file in SOUNDS[key]:
			if ResourceLoader.exists(A + file):
				list.append(load(A + file))
		if not list.is_empty():
			_streams[key] = list
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_setup_static()
	_setup_hum()


func play(sound: String, pitch_jitter := 0.08, volume_db := 0.0) -> void:
	if not _streams.has(sound) or Game.dev.has("mute"):
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	var list: Array = _streams[sound]
	p.stream = list[randi() % list.size()]
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.volume_db = volume_db
	p.play()


func has_sound(sound: String) -> bool:
	return _streams.has(sound)


## 0..1 — volume of the radio static hiss.
func set_static(level: float) -> void:
	_static_target = clampf(level, 0.0, 1.0)


func _setup_static() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.15
	_static_player = AudioStreamPlayer.new()
	_static_player.stream = gen
	_static_player.volume_db = -14.0
	add_child(_static_player)
	_static_player.play()
	_static_playback = _static_player.get_stream_playback()


func _setup_hum() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.15
	var p := AudioStreamPlayer.new()
	p.stream = gen
	p.volume_db = -12.0
	add_child(p)
	p.play()
	_hum_playback = p.get_stream_playback()


## Electrical buzz of active antennas: louder the closer Johnny is.
func _fill_hum(delta: float) -> void:
	var target := 0.0
	if is_instance_valid(Game.player) and not Game.dev.has("mute"):
		for a in Game.active_antennas():
			var d: float = a.global_position.distance_to(Game.player.global_position)
			target = maxf(target, clampf(1.0 - d / 420.0, 0.0, 1.0))
	_hum_level = move_toward(_hum_level, target, delta)
	var frames := _hum_playback.get_frames_available()
	var amp := _hum_level * _hum_level * 0.25
	for i in frames:
		_hum_phase = fmod(_hum_phase + 100.0 / MIX_RATE, 1.0)
		var t := _hum_phase * TAU
		var v := sin(t) * 0.5 + sin(t * 2.0) * 0.3 + sin(t * 3.0) * 0.2 + sin(t * 5.0) * 0.12
		v = clampf(v * 1.6, -0.8, 0.8)  # soft clip -> gritty buzz
		_hum_playback.push_frame(Vector2(v, v) * amp)


func _process(delta: float) -> void:
	_static_level = move_toward(_static_level, _static_target, delta * 2.0)
	if _hum_playback:
		_fill_hum(delta)
	if _static_playback == null:
		return
	var frames := _static_playback.get_frames_available()
	var amp := 0.0 if Game.dev.has("mute") else _static_level * 0.35
	for i in frames:
		# Band-limited crackly noise: low-passed white noise + random pops.
		var n := randf_range(-1.0, 1.0)
		_lp = lerpf(_lp, n, 0.35)
		var s := _lp * amp
		if randf() < 0.0008:
			s += randf_range(-0.6, 0.6) * amp
		_static_playback.push_frame(Vector2(s, s))
