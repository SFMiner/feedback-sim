class_name ExperimentBase
extends ModuleBase
## Shared frame for the two interactive biology modules: set up -> run -> results.
## It owns the clock, the recording, and the synchronised replay. A subclass supplies the model,
## the view and its own controls by overriding the `_exp_*` hooks.
##
## Replay works from recorded state snapshots (one per model step): the cursor time picks the
## snapshot for the picture and the same time positions the marker on the graph, so both always
## show the same moment. Click or drag on the graph to scrub.

# === ENUMS ===
enum Phase { SETUP, RUNNING, RESULTS }

# === PUBLIC VARIABLES ===
var phase: Phase = Phase.SETUP
## False while an experiment is paused.
var running: bool = false
var replaying: bool = false
var cursor: float = 0.0
var graph: GraphView = null
var prompt_index: int = 0
var frame_shown: bool = false

# === PRIVATE VARIABLES ===
var _view_frame: PanelContainer = null
var _setup_box: VBoxContainer = null
var _results_box: VBoxContainer = null
var _start_button: Button = null
var _results_button: Button = null
var _replay_button: Button = null
var _info: Label = null
var _prompt_row: HBoxContainer = null
var _frame_button: Button = null


# === LIFECYCLE METHODS ===
func _ready() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	# Left: controls (set-up controls, or results controls).
	var left: PanelContainer = UI.panel()
	left.custom_minimum_size = Vector2(262.0, 0.0)
	row.add_child(left)
	var left_box: VBoxContainer = VBoxContainer.new()
	left.add_child(left_box)
	_setup_box = VBoxContainer.new()
	_setup_box.add_theme_constant_override("separation", 5)
	left_box.add_child(_setup_box)
	_exp_build_setup(_setup_box)
	var run_row: HBoxContainer = HBoxContainer.new()
	run_row.add_theme_constant_override("separation", 5)
	_setup_box.add_child(run_row)
	_start_button = UI.button("Start Experiment", toggle_run)
	_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	run_row.add_child(_start_button)
	run_row.add_child(UI.button("Reset", reset_experiment, 70.0))
	_results_button = UI.button("View Results", show_results)
	_setup_box.add_child(_results_button)
	_results_box = VBoxContainer.new()
	_results_box.add_theme_constant_override("separation", 5)
	left_box.add_child(_results_box)
	_results_box.add_child(UI.label("RESULTS", 18, UI.FOCUS))
	_results_box.add_child(UI.label("Replay the experiment. The picture and the graph move together. Click the graph to jump.", 13, UI.TEXT, true))
	_replay_button = UI.button("Replay", toggle_replay)
	_results_box.add_child(_replay_button)
	var jump: HBoxContainer = HBoxContainer.new()
	jump.add_theme_constant_override("separation", 5)
	_results_box.add_child(jump)
	var back: Button = UI.button("Back", nudge_cursor.bind(-1.0))
	var forward: Button = UI.button("Forward", nudge_cursor.bind(1.0))
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	forward.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jump.add_child(back)
	jump.add_child(forward)
	_exp_build_results(_results_box)
	_results_box.add_child(UI.button("Try Another Experiment", reset_experiment))
	# Centre: the simulated scene.
	_view_frame = UI.panel(Color(0.96, 0.90, 0.86, 1), UI.PANEL_EDGE)
	_view_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view_frame.size_flags_stretch_ratio = 1.35
	row.add_child(_view_frame)
	_view_frame.add_child(_exp_build_view())
	# Right: graph and the text panel (hints, then reflection prompts).
	var side: VBoxContainer = VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 6)
	row.add_child(side)
	graph = GraphView.new()
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.recorder = recorder
	graph.scrubbed.connect(_on_scrubbed)
	side.add_child(graph)
	var cap: Array = caption_panel(15)
	var cap_panel: PanelContainer = cap[0]
	cap_panel.custom_minimum_size = Vector2(0.0, 112.0)
	side.add_child(cap_panel)
	_info = cap[1]
	_prompt_row = HBoxContainer.new()
	_prompt_row.add_theme_constant_override("separation", 6)
	side.add_child(_prompt_row)
	_frame_button = UI.button("Sentence Starter", toggle_frame)
	var next_q: Button = UI.button("Next Question", next_prompt)
	_frame_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_q.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prompt_row.add_child(_frame_button)
	_prompt_row.add_child(next_q)
	_exp_configure_graph()
	reset_experiment()


func _process(delta: float) -> void:
	if phase == Phase.RUNNING and running:
		var steps: int = consume_steps(delta * _exp_rate(), _exp_dt())
		for i: int in range(steps):
			_exp_step()
			if _exp_finished():
				show_results()
				return
		if steps > 0:
			_exp_show(recorder.snapshot_at(recorder.duration()))
			_info.text = _exp_live_caption()
	elif phase == Phase.RESULTS and replaying:
		cursor += delta * _exp_rate()
		if cursor >= recorder.duration():
			cursor = recorder.duration()
			replaying = false
			_refresh()
		_show_cursor()


# === PUBLIC METHODS ===
func reset_experiment() -> void:
	phase = Phase.SETUP
	running = false
	replaying = false
	cursor = 0.0
	prompt_index = 0
	frame_shown = false
	reset_steps()
	sfx.stop_all()
	recorder.clear()
	_exp_new()
	graph.cursor = -1.0
	graph.scrub_enabled = false
	_exp_show(recorder.snapshot_at(0.0))
	_info.text = _exp_setup_hint()
	_refresh()
	print("feedback: %s reset" % _exp_name())


func toggle_run() -> void:
	if phase == Phase.RESULTS:
		return
	if phase == Phase.SETUP:
		phase = Phase.RUNNING
		running = true
		_exp_started()
		print("feedback: %s start" % _exp_name())
	else:
		running = not running
		print("feedback: %s %s" % [_exp_name(), "resume" if running else "pause"])
	_refresh()


func show_results() -> void:
	if phase != Phase.RUNNING:
		return
	phase = Phase.RESULTS
	running = false
	replaying = false
	sfx.stop_all()
	cursor = recorder.duration()
	graph.scrub_enabled = true
	_exp_results_ready()
	_show_cursor()
	_show_prompt()
	_refresh()
	say("Results. " + _info.text)
	print("feedback: %s results" % _exp_name())


func toggle_replay() -> void:
	if phase != Phase.RESULTS:
		return
	replaying = not replaying
	if replaying and cursor >= recorder.duration() - 0.001:
		cursor = 0.0
	_refresh()
	print("feedback: %s replay %s" % [_exp_name(), "on" if replaying else "off"])


## Moves the replay cursor by a tenth of the recording (keyboard alternative to clicking the graph).
func nudge_cursor(direction: float) -> void:
	replaying = false
	cursor = clampf(cursor + direction * recorder.duration() * 0.1, 0.0, recorder.duration())
	_show_cursor()
	_refresh()


func toggle_frame() -> void:
	frame_shown = not frame_shown
	_show_prompt()


func next_prompt() -> void:
	prompt_index = (prompt_index + 1) % _exp_prompts().size()
	frame_shown = false
	_show_prompt()


func is_setup() -> bool:
	return phase == Phase.SETUP


# === HOOKS FOR SUBCLASSES ===
func _exp_name() -> String:
	return "experiment"


## Model step length, in model time units.
func _exp_dt() -> float:
	return 1.0 / 30.0


## Model time units per real second. `consume_steps` is fed real seconds times this rate.
func _exp_rate() -> float:
	return 1.0


func _exp_build_setup(_box: VBoxContainer) -> void:
	pass


func _exp_build_results(_box: VBoxContainer) -> void:
	pass


func _exp_build_view() -> Control:
	return Control.new()


func _exp_configure_graph() -> void:
	pass


## Create a fresh model from the current settings and record its first row.
func _exp_new() -> void:
	pass


func _exp_started() -> void:
	pass


## Advance the model one step and record it.
func _exp_step() -> void:
	pass


func _exp_finished() -> bool:
	return false


## Show one recorded snapshot in the view.
func _exp_show(_snapshot: Variant) -> void:
	pass


func _exp_results_ready() -> void:
	pass


func _exp_setup_hint() -> String:
	return ""


func _exp_live_caption() -> String:
	return ""


## Reflection prompts: [{"q": question, "frame": sentence starter}].
func _exp_prompts() -> Array[Dictionary]:
	return []


## Called whenever buttons may need enabling/disabling. `locked` = settings can no longer change.
func _exp_refresh(_locked: bool) -> void:
	pass


# === PRIVATE METHODS ===
func _on_scrubbed(t: float) -> void:
	if phase != Phase.RESULTS:
		return
	replaying = false
	cursor = t
	_show_cursor()
	_refresh()


func _show_cursor() -> void:
	graph.cursor = cursor
	_exp_show(recorder.snapshot_at(cursor))


func _show_prompt() -> void:
	var prompts: Array[Dictionary] = _exp_prompts()
	if prompts.is_empty():
		return
	var p: Dictionary = prompts[prompt_index]
	var text: String = "Think about it (%d of %d):\n%s" % [prompt_index + 1, prompts.size(), str(p["q"])]
	if frame_shown:
		text += "\n" + str(p["frame"])
	_info.text = text
	_frame_button.text = "Hide Starter" if frame_shown else "Sentence Starter"


func _refresh() -> void:
	_setup_box.visible = phase != Phase.RESULTS
	_results_box.visible = phase == Phase.RESULTS
	_prompt_row.visible = phase == Phase.RESULTS
	if phase == Phase.SETUP:
		_start_button.text = "Start Experiment"
	else:
		_start_button.text = "Pause" if running else "Resume"
	_results_button.disabled = phase != Phase.RUNNING
	_replay_button.text = "Pause Replay" if replaying else "Replay"
	_exp_refresh(phase != Phase.SETUP)
