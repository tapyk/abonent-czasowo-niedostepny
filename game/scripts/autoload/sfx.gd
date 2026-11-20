extends Node
## Sound effects by name + procedural radio static (no asset needed for static).

const SOUNDS := {
	"shoot": "res://assets/audio/pistol_shot.ogg",
	"empty": "res://assets/audio/gun_empty_click.ogg",
	"melee": "res://assets/audio/melee_swing.ogg",
	"hit": "res://assets/audio/hit_flesh.ogg",
	"enemy_hurt": "res://assets/audio/enemy_hurt.ogg",
	"enemy_die": "res://assets/audio/enemy_die.ogg",
	"pickup": "res://assets/audio/pickup.ogg",
	"jump": "res://assets/audio/jump.ogg",
	"hurt": "res://assets/audio/player_hurt.ogg",
	"beep": "res://assets/audio/ui_beep.ogg",
	"error": "res://assets/audio/error_buzz.ogg",
	"shutdown": "res://assets/audio/power_down.ogg",
	"step": "res://assets/audio/footstep.ogg",
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in SOUNDS:
		var path: String = SOUNDS[key]
		for candidate in [path, path.get_basename() + ".wav"]:
			if ResourceLoader.exists(candidate):
				_streams[key] = load(candidate)
				break
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_setup_static()


func play(sound: String, pitch_jitter := 0.08, volume_db := 0.0) -> void:
	if not _streams.has(sound) or Game.dev.has("mute"):
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = _streams[sound]
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


func _process(delta: float) -> void:
	_static_level = move_toward(_static_level, _static_target, delta * 2.0)
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
