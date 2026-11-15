class_name AudioController
extends Node
## All sound for the application: four student "horn" voices, the deep teacher voice, and the
## shared feedback cues (BIP / BOOP / boost). Sounds are synthesised once (see Synth) and played
## through a small pool of players, so overlapping chatter can never exceed a fixed number of
## voices; each extra voice is also turned down. Volume and mute act on the master bus.

# === CONSTANTS ===
const VOLUME_STEPS: int = 5
const CHATTER_PLAYERS: int = 5
const FX_PLAYERS: int = 4
const VARIANTS: int = 3
## Voice presets A-D (GDD 3.4) and their caption syllables.
const VOICES: Array[Dictionary] = [
	{"name": "A", "word": "womp", "f0": 147.0, "syllables": 2, "syl": 0.30, "gap": 0.07, "cut_lo": 180.0, "cut_hi": 900.0, "attack": 0.18, "decay_pow": 0.9, "bend": 0.10},
	{"name": "B", "word": "wah", "f0": 196.0, "syllables": 2, "syl": 0.25, "gap": 0.06, "cut_lo": 260.0, "cut_hi": 1500.0, "attack": 0.22, "decay_pow": 0.7, "bend": 0.05},
	{"name": "C", "word": "wah", "f0": 277.0, "syllables": 3, "syl": 0.19, "gap": 0.05, "cut_lo": 350.0, "cut_hi": 2100.0, "attack": 0.20, "decay_pow": 0.7, "bend": 0.03},
	{"name": "D", "word": "wap", "f0": 370.0, "syllables": 3, "syl": 0.12, "gap": 0.05, "cut_lo": 500.0, "cut_hi": 2600.0, "attack": 0.08, "decay_pow": 1.6, "bend": 0.0},
]
const TEACHER: Dictionary = {"f0": 62.0, "syllables": 1, "syl": 0.50, "gap": 0.0, "cut_lo": 110.0, "cut_hi": 780.0, "attack": 0.10, "decay_pow": 1.0, "bend": 0.22, "spread": 0.0}

# === PUBLIC VARIABLES ===
var volume_step: int = 4
var muted: bool = false
## Name -> number of times played since start. Read by tests.
var play_counts: Dictionary = {}

# === PRIVATE VARIABLES ===
var _streams: Dictionary = {}
var _chatter: Array[AudioStreamPlayer] = []
var _fx: Array[AudioStreamPlayer] = []
var _teacher: AudioStreamPlayer = null
var _fx_next: int = 0


# === LIFECYCLE METHODS ===
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261114
	for v: int in range(VOICES.size()):
		for k: int in range(VARIANTS):
			_streams["voice_%d_%d" % [v, k]] = Synth.to_stream(Synth.brass(VOICES[v], rng), 0.5)
	_streams["teacher"] = Synth.to_stream(Synth.brass(TEACHER, rng), 0.9)
	_streams["bip"] = Synth.to_stream(Synth.tone(990.0, 880.0, 0.13, 0.5, 1.5), 0.5)
	_streams["boop"] = Synth.to_stream(Synth.tone(330.0, 250.0, 0.20, 0.3, 1.2), 0.6)
	_streams["boost"] = Synth.to_stream(Synth.tone(420.0, 900.0, 0.16, 0.25, 0.8), 0.5)
	_streams["pop"] = Synth.to_stream(Synth.tone(620.0, 520.0, 0.07, 0.0, 1.5), 0.4)
	for i: int in range(CHATTER_PLAYERS):
		_chatter.append(_new_player())
	for i: int in range(FX_PLAYERS):
		_fx.append(_new_player())
	_teacher = _new_player()
	_apply()


# === PUBLIC METHODS ===
## Plays one burst of student voice `voice` (0-3). Returns its length in seconds, or 0.0 when every
## chatter player is busy (the cap that keeps a loud classroom from distorting).
func chatter(voice: int, gain: float, pitch: float, variant: int) -> float:
	var busy: int = 0
	var free_player: AudioStreamPlayer = null
	for p: AudioStreamPlayer in _chatter:
		if p.playing:
			busy += 1
		elif free_player == null:
			free_player = p
	if free_player == null:
		return 0.0
	var key: String = "voice_%d_%d" % [voice, variant % VARIANTS]
	var stream: AudioStreamWAV = _streams[key]
	free_player.stream = stream
	free_player.pitch_scale = pitch
	free_player.volume_db = linear_to_db(clampf(gain, 0.05, 1.0) * 0.55 / sqrt(float(busy + 1)))
	free_player.play()
	_count("voice_%d" % voice)
	return stream.get_length() / pitch


func teacher_whomp() -> void:
	_teacher.stream = _streams["teacher"]
	_teacher.volume_db = 0.0
	_teacher.play()
	_count("teacher")


## Plays a feedback cue: "bip", "boop", "boost" or "pop".
func cue(sound: String, gain: float = 1.0, pitch: float = 1.0) -> void:
	if not _streams.has(sound):
		return
	var p: AudioStreamPlayer = _fx[_fx_next]
	_fx_next = (_fx_next + 1) % _fx.size()
	p.stream = _streams[sound]
	p.pitch_scale = pitch
	p.volume_db = linear_to_db(clampf(gain, 0.05, 1.0) * 0.8)
	p.play()
	_count(sound)


func stop_all() -> void:
	for p: AudioStreamPlayer in _chatter:
		p.stop()
	for p: AudioStreamPlayer in _fx:
		p.stop()
	_teacher.stop()


func set_muted(value: bool) -> void:
	muted = value
	_apply()


func change_volume(delta: int) -> void:
	volume_step = clampi(volume_step + delta, 0, VOLUME_STEPS)
	_apply()


func voice_word(voice: int) -> String:
	return str(VOICES[voice]["word"])


func stream_length(key: String) -> float:
	var s: AudioStreamWAV = _streams.get(key)
	return 0.0 if s == null else s.get_length()


# === PRIVATE METHODS ===
func _new_player() -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	add_child(p)
	return p


func _count(sound: String) -> void:
	play_counts[sound] = int(play_counts.get(sound, 0)) + 1


func _apply() -> void:
	var linear: float = float(volume_step) / float(VOLUME_STEPS)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(0, muted or volume_step == 0)
