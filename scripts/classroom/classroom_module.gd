class_name ClassroomModule
extends ModuleBase
## Module 1, Classroom Chatter: an automated demonstration. The module owns the clock; it steps the
## ClassroomModel at a fixed rate, records the noise level, and turns model events into sound,
## captions and graph marks in the same step, which keeps picture, sound and graph together.
## Replay re-runs the same seed, so it reproduces the same curve and the same faces.

# === CONSTANTS ===
const SEED: int = 4172
const CAPTION_START: String = "Press Play. Watch the students and the graph."
const CAPTION_SPREAD: String = "Talking spreads. More talking makes even MORE talking. That is positive feedback."
const CAPTION_TEACHER: String = "Too loud! The teacher pushes the noise back down. That is negative feedback."
const CAPTION_QUIET: String = "Quiet again... but the talking soon starts over."
const CAPTION_ENTER: String = "A second teacher walks in."
const CAPTION_DISTRACTED: String = "The teachers are chatting. Nobody is watching the noise."
const CAPTION_MESSAGE: String = "The positive feedback is still working. What happened to the negative feedback?"
const CAPTION_DONE: String = "The noise stopped rising only because every student was already at full volume. Press Replay to watch again."

# === PUBLIC VARIABLES ===
var model: ClassroomModel = null
var view: ClassroomView = null
var graph: GraphView = null
var playing: bool = false

# === PRIVATE VARIABLES ===
var _caption: Label = null
var _play_button: Button = null
var _replay_button: Button = null
var _skip_button: Button = null
var _pos_badge: Label = null
var _neg_badge: Label = null
var _next_talk: PackedFloat32Array = PackedFloat32Array()
var _talk_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _started: bool = false


# === LIFECYCLE METHODS ===
func _ready() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var frame: PanelContainer = UI.panel(Color("e9d8b4"), UI.PANEL_EDGE)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_stretch_ratio = 1.55
	row.add_child(frame)
	view = ClassroomView.new()
	frame.add_child(view)
	var side: VBoxContainer = VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 6)
	row.add_child(side)
	graph = GraphView.new()
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.title = "Classroom Noise"
	graph.y_label = "Noise"
	graph.x_span_min = 40.0
	graph.recorder = recorder
	graph.add_series("noise", "Noise", UI.POS)
	side.add_child(graph)
	var badges: HBoxContainer = HBoxContainer.new()
	badges.add_theme_constant_override("separation", 6)
	side.add_child(badges)
	_pos_badge = UI.label("", 13, UI.POS)
	_pos_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badges.add_child(_pos_badge)
	_neg_badge = UI.label("", 13, UI.NEG)
	_neg_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_neg_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badges.add_child(_neg_badge)
	var cap: Array = caption_panel(16)
	var cap_panel: PanelContainer = cap[0]
	cap_panel.custom_minimum_size = Vector2(0.0, 82.0)
	side.add_child(cap_panel)
	_caption = cap[1]
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	side.add_child(buttons)
	_play_button = UI.button("Play", toggle_play)
	_replay_button = UI.button("Replay", replay)
	_skip_button = UI.button("Skip Ahead", skip)
	for b: Button in [_play_button, _replay_button, _skip_button]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(b)
	reset()


func _process(delta: float) -> void:
	view.reduced = reduced_motion()
	if not playing:
		return
	var steps: int = consume_steps(delta, ClassroomModel.DT)
	for i: int in range(steps):
		_step(true)


# === PUBLIC METHODS ===
func module_title() -> String:
	return "Watch: Classroom Chatter"


func reset() -> void:
	playing = false
	_started = false
	sfx.stop_all()
	reset_steps()
	model = ClassroomModel.new()
	model.setup(SEED)
	_talk_rng.seed = SEED + 99
	_next_talk.resize(ClassroomModel.COUNT)
	for i: int in range(ClassroomModel.COUNT):
		_next_talk[i] = _talk_rng.randf_range(0.0, 0.6)
	recorder.clear()
	recorder.record(0.0, {"noise": 0.0})
	graph.lines = [{"value": model.teacher_threshold, "label": "Teacher's limit", "color": UI.NEG}]
	view.model = model
	view.generate_looks(SEED)
	view.anim_t = 0.0
	view.whomp_age = 99.0
	_caption.text = CAPTION_START
	_refresh()


func toggle_play() -> void:
	if model.finished:
		replay()
		return
	playing = not playing
	_started = true
	if not playing:
		sfx.stop_all()
	_refresh()
	print("feedback: classroom " + ("play" if playing else "pause"))


func replay() -> void:
	reset()
	playing = true
	_started = true
	_refresh()
	print("feedback: classroom replay")


## Skips ahead without sound: to the second teacher's arrival, or (if already there) to the end.
## The skipped part is still simulated step by step, so the graph stays a true record.
func skip() -> void:
	sfx.stop_all()
	_started = true
	var to_end: bool = model.teacher2_present
	var guard: int = 0
	while not model.finished and guard < 20000:
		_step(false)
		guard += 1
		if not to_end and model.teacher2_present:
			break
	if not model.finished:
		playing = true
	_refresh()
	print("feedback: classroom skip")


# === PRIVATE METHODS ===
func _step(with_sound: bool) -> void:
	model.step()
	recorder.record(model.time, {"noise": model.noise_level})
	view.anim_t += ClassroomModel.DT
	view.whomp_age += ClassroomModel.DT
	for e: Dictionary in model.events:
		_on_event(e, with_sound)
	_step_chatter(with_sound)
	if model.finished:
		playing = false
		sfx.stop_all()
		_refresh()


func _on_event(e: Dictionary, with_sound: bool) -> void:
	match str(e["type"]):
		"spark":
			_caption.text = CAPTION_DISTRACTED if model.teacher_distracted else CAPTION_SPREAD
		"intervene":
			_caption.text = CAPTION_TEACHER
			recorder.add_event(model.time, "Teacher steps in")
			say("The teacher steps in.")
		"whomp":
			view.whomp_age = 0.0
			if with_sound:
				sfx.teacher_whomp()
		"quiet":
			_caption.text = CAPTION_QUIET
		"teacher2_enters":
			_caption.text = CAPTION_ENTER
		"distracted":
			_caption.text = CAPTION_DISTRACTED
			recorder.add_event(model.time, "Teacher distracted")
			say("The teacher is distracted.")
		"message":
			_caption.text = CAPTION_MESSAGE
			say(CAPTION_MESSAGE)
		"finished":
			_caption.text = CAPTION_DONE
			print("feedback: classroom finished")
	_refresh_badges()


## Presentation only: decides when each talking student makes a sound and shows a speech mark.
## Busier, louder students speak more often; timing is irregular and independent per student.
func _step_chatter(with_sound: bool) -> void:
	var dt: float = ClassroomModel.DT
	for i: int in range(ClassroomModel.COUNT):
		view.talk_left[i] = maxf(0.0, view.talk_left[i] - dt)
		var a: float = model.student_activity[i]
		if a < 0.2 or model.teacher_intervening:
			continue
		_next_talk[i] -= dt
		if _next_talk[i] > 0.0:
			continue
		_next_talk[i] = lerpf(2.6, 0.7, a) * _talk_rng.randf_range(0.6, 1.5)
		var voice: int = model.student_voice_id[i]
		var pitch: float = _talk_rng.randf_range(0.9, 1.12)
		var variant: int = _talk_rng.randi_range(0, AudioController.VARIANTS - 1)
		var length: float = 0.5
		if with_sound:
			var played: float = sfx.chatter(voice, 0.3 + 0.7 * a, pitch, variant)
			if played > 0.0:
				length = played
		view.talk_left[i] = length
		view.talk_word[i] = sfx.voice_word(voice)


func _refresh() -> void:
	if model.finished:
		_play_button.text = "Play Again"
	elif playing:
		_play_button.text = "Pause"
	else:
		_play_button.text = "Play" if not _started else "Resume"
	_skip_button.disabled = model.finished
	_refresh_badges()


func _refresh_badges() -> void:
	_pos_badge.text = "Positive feedback: ON"
	_neg_badge.text = "Negative feedback: ON" if model.teacher_active else "Negative feedback: OFF"
