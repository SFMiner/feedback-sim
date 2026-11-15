class_name AbstractModule
extends ModuleBase
## Module 2, Abstract Feedback: three short automated parts played in order.
##   1. Negative feedback (delayed, threshold-triggered corrections: BIP / BOOP).
##   2. Positive feedback, first nudge upward.
##   3. Positive feedback, first nudge downward (so "positive" is not mistaken for "going up").
## Each part runs its own AbstractModel; the graph plots exactly what that model produced.

# === CONSTANTS ===
const SEED: int = 9051
const PARTS: Array[Dictionary] = [
	{
		"mode": "negative", "heading": "Part 1 of 3: Negative feedback",
		"caption": "Too high? A push down: BIP! Too low? A push up: BOOP! Each push comes a little late, so the ball overshoots.",
		"after": "Negative feedback opposes a change. Sometimes delayed corrections make a system rise and fall repeatedly.",
	},
	{
		"mode": "positive_up", "heading": "Part 2 of 3: Positive feedback",
		"caption": "A small nudge up. Each boost pushes the same way, and every boost is bigger than the last.",
		"after": "Positive feedback amplifies a change. It stopped only when it hit a limit: no room left.",
	},
	{
		"mode": "positive_down", "heading": "Part 3 of 3: Positive feedback (downward)",
		"caption": "This time the first nudge is DOWN. Watch which way the boosts push.",
		"after": "Positive feedback amplifies a change in whichever direction it started. It does not just mean 'going up'.",
	},
]
const CAPTION_START: String = "Press Play. Watch the ball and the graph."
const CAPTION_DONE: String = "Negative feedback opposes a change. Positive feedback amplifies a change. Real systems do not always make these exact curves."
const INTERMISSION: float = 4.0

# === PUBLIC VARIABLES ===
var model: AbstractModel = null
var view: AbstractView = null
var graph: GraphView = null
var playing: bool = false
var part: int = 0
var all_done: bool = false

# === PRIVATE VARIABLES ===
var _heading: Label = null
var _caption: Label = null
var _play_button: Button = null
var _skip_button: Button = null
var _started: bool = false
var _wait: float = 0.0


# === LIFECYCLE METHODS ===
func _ready() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var frame: PanelContainer = UI.panel(Color(0.10, 0.13, 0.22, 1), UI.PANEL_EDGE)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_stretch_ratio = 0.62
	row.add_child(frame)
	view = AbstractView.new()
	frame.add_child(view)
	var side: VBoxContainer = VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 6)
	row.add_child(side)
	_heading = UI.label("", 18, UI.TEXT)
	side.add_child(_heading)
	graph = GraphView.new()
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.y_label = "Quantity"
	graph.recorder = recorder
	side.add_child(graph)
	var cap: Array = caption_panel(16)
	var cap_panel: PanelContainer = cap[0]
	cap_panel.custom_minimum_size = Vector2(0.0, 82.0)
	side.add_child(cap_panel)
	_caption = cap[1]
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	side.add_child(buttons)
	_play_button = UI.button("Play", toggle_play)
	_skip_button = UI.button("Skip Part", skip)
	for b: Button in [_play_button, UI.button("Replay", replay), _skip_button]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(b)
	reset()


func _process(delta: float) -> void:
	view.reduced = reduced_motion()
	if not playing:
		return
	var steps: int = consume_steps(delta, AbstractModel.DT)
	for i: int in range(steps):
		_step()


# === PUBLIC METHODS ===
func module_title() -> String:
	return "Watch: Abstract Feedback"


func reset() -> void:
	playing = false
	_started = false
	all_done = false
	_load_part(0)
	_caption.text = CAPTION_START
	_refresh()


func toggle_play() -> void:
	if all_done:
		replay()
		return
	playing = not playing
	if playing and not _started:
		_caption.text = str(PARTS[part]["caption"])
	_started = true
	_refresh()
	print("feedback: abstract " + ("play" if playing else "pause"))


func replay() -> void:
	reset()
	toggle_play()


## Jumps to the next part (or to the end after the last one).
func skip() -> void:
	if all_done:
		return
	_started = true
	_next_part()
	print("feedback: abstract skip")


# === PRIVATE METHODS ===
func _load_part(index: int) -> void:
	part = index
	_wait = 0.0
	reset_steps()
	var cfg: Dictionary = PARTS[index]
	model = AbstractModel.new()
	model.setup(str(cfg["mode"]), SEED + index)
	view.model = model
	view.reset_view()
	recorder.clear()
	recorder.record(0.0, {"value": model.value})
	graph.series.clear()
	if model.mode == AbstractModel.MODE_NEGATIVE:
		graph.title = "Negative feedback"
		graph.x_span_min = AbstractModel.NEGATIVE_LENGTH
		graph.add_series("value", "Quantity", Color("ffd166"))
		graph.lines = [
			{"value": AbstractModel.UPPER, "label": "Too high", "color": UI.NEG},
			{"value": AbstractModel.TARGET, "label": "Target", "color": UI.GOOD},
			{"value": AbstractModel.LOWER, "label": "Too low", "color": UI.NEG},
		]
	else:
		graph.title = "Positive feedback"
		graph.x_span_min = 14.0
		graph.add_series("value", "Quantity", Color("ffd166"))
		graph.lines = [
			{"value": AbstractModel.LIMIT_HIGH, "label": "Limit", "color": UI.WARN},
			{"value": AbstractModel.BASELINE, "label": "Start", "color": UI.TEXT_DIM},
			{"value": AbstractModel.LIMIT_LOW, "label": "Limit", "color": UI.WARN},
		]
	_heading.text = str(cfg["heading"])
	_heading.add_theme_color_override("font_color", UI.NEG if model.mode == AbstractModel.MODE_NEGATIVE else UI.POS)
	_caption.text = str(cfg["caption"])
	say(str(cfg["heading"]))


func _next_part() -> void:
	if part + 1 < PARTS.size():
		_load_part(part + 1)
		playing = true
	else:
		all_done = true
		playing = false
		_caption.text = CAPTION_DONE
		print("feedback: abstract finished")
	_refresh()


func _step() -> void:
	if model.finished:
		# Short pause on the finished graph, then the next part starts by itself.
		_wait -= AbstractModel.DT
		if _wait <= 0.0:
			_next_part()
		return
	model.step()
	recorder.record(model.time, {"value": model.value})
	view.advance(AbstractModel.DT)
	for e: Dictionary in model.events:
		match str(e["type"]):
			"correct":
				var down: bool = int(e["dir"]) == -1
				sfx.cue("bip" if down else "boop")
				view.show_cue("BIP!" if down else "BOOP!", int(e["dir"]))
				recorder.add_event(model.time, "BIP" if down else "BOOP")
			"nudge":
				sfx.cue("pop")
				view.show_cue("nudge", int(e["dir"]))
				recorder.add_event(model.time, "Nudge")
			"boost":
				var size_now: float = e["size"]
				sfx.cue("boost", 0.45 + size_now / 14.0, 0.75 + size_now / 16.0)
				view.show_cue("BOOST!", int(e["dir"]))
			"limit":
				recorder.add_event(model.time, "Limit reached")
				_caption.text = str(PARTS[part]["after"])
			"finished":
				_caption.text = str(PARTS[part]["after"])
				_wait = INTERMISSION
				say(str(PARTS[part]["after"]))


func _refresh() -> void:
	if all_done:
		_play_button.text = "Play Again"
	elif playing:
		_play_button.text = "Pause"
	else:
		_play_button.text = "Play" if not _started else "Resume"
	_skip_button.disabled = all_done
