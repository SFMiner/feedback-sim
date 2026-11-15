class_name ClottingModule
extends ExperimentBase
## Module 3, Blood Clotting: students set wound size, platelet supply and signalling, run the
## ClottingModel, then replay it against the graph of attached platelets.
## The same settings always use the same random seed, so an experiment can be repeated exactly.

# === CONSTANTS ===
const WOUND_NAMES: Array[String] = ["Small", "Medium", "Large"]
const PLATELET_NAMES: Array[String] = ["Low", "Normal", "High"]
const SIGNAL_NAMES: Array[String] = ["Normal", "Reduced", "Blocked"]
const PROMPTS: Array[Dictionary] = [
	{"q": "How did the first platelets cause more platelets to gather?", "frame": "The first platelets released signals that caused ______."},
	{"q": "What changed when platelet recruitment signals were blocked?", "frame": "With signals blocked, the plug ______ because ______."},
	{"q": "Why did the plug stop growing?", "frame": "The plug stopped growing when ______."},
]

# === PUBLIC VARIABLES ===
var model: ClottingModel = null
var view: ClottingView = null
var wound_size: int = 1
var platelet_level: int = 1
var signaling: int = 0
var last_summary: String = ""

# === PRIVATE VARIABLES ===
var _wound_button: Button = null
var _platelet_button: Button = null
var _signal_button: Button = null
var _summary: Label = null
var _stage: String = ""
var _boost_pitch: float = 0.8


# === PUBLIC METHODS ===
func module_title() -> String:
	return "Experiment: Blood Clotting"


func cycle_wound() -> void:
	wound_size = (wound_size + 1) % 3
	reset_experiment()


func cycle_platelets() -> void:
	platelet_level = (platelet_level + 1) % 3
	reset_experiment()


func cycle_signaling() -> void:
	signaling = (signaling + 1) % 3
	reset_experiment()


func settings_text() -> String:
	return "%s wound, %s platelets, signals %s" % [WOUND_NAMES[wound_size].to_lower(), PLATELET_NAMES[platelet_level].to_lower(), SIGNAL_NAMES[signaling].to_lower()]


# === HOOKS ===
func _exp_name() -> String:
	return "clotting"


func _exp_dt() -> float:
	return ClottingModel.DT


func _exp_build_setup(box: VBoxContainer) -> void:
	box.add_child(UI.label("Choose, predict, then start:", 14, UI.TEXT_DIM))
	_wound_button = UI.button("", cycle_wound)
	_platelet_button = UI.button("", cycle_platelets)
	_signal_button = UI.button("", cycle_signaling)
	box.add_child(_wound_button)
	box.add_child(_platelet_button)
	box.add_child(_signal_button)


func _exp_build_results(box: VBoxContainer) -> void:
	_summary = UI.label("", 13, UI.TEXT, true)
	box.add_child(_summary)


func _exp_build_view() -> Control:
	view = ClottingView.new()
	return view


func _exp_configure_graph() -> void:
	graph.title = "Attached Platelets"
	graph.y_label = "Platelets in the plug"
	graph.y_max = 48.0
	graph.x_span_min = 20.0
	graph.add_series("attached", "Attached", Color("c9a2ff"))


func _exp_new() -> void:
	model = ClottingModel.new()
	model.setup(wound_size, platelet_level, signaling, 1000 + wound_size * 100 + platelet_level * 10 + signaling)
	_stage = "healthy"
	_boost_pitch = 0.8
	_record()


func _exp_step() -> void:
	model.step()
	_record()
	for e: Dictionary in model.events:
		match str(e["type"]):
			"injury":
				recorder.add_event(model.time, "Injury")
				_stage = "injury"
				sfx.cue("boop", 0.8)
			"first_adhesion":
				recorder.add_event(model.time, "First platelet sticks")
				_stage = "first"
			"adhere":
				sfx.cue("pop", 0.6)
			"recruit":
				_boost_pitch = minf(_boost_pitch + 0.03, 1.5)
				sfx.cue("boost", 0.35, _boost_pitch)
			"recruitment_up":
				recorder.add_event(model.time, "Recruitment speeds up")
				_stage = "recruit"
			"covered":
				recorder.add_event(model.time, "Wound covered: plug formed")
				_stage = "covered"
				sfx.cue("bip", 0.8)


func _exp_finished() -> bool:
	return model.finished


func _exp_show(snapshot: Variant) -> void:
	view.reduced = reduced_motion()
	if snapshot is Dictionary:
		view.frame = snapshot


func _exp_results_ready() -> void:
	var covered: String = "Wound covered at %d s." % int(round(model.covered_time)) if model.covered_time >= 0.0 else "Wound only %d%% covered when the test ended." % int(round(model.coverage))
	var text: String = "%d platelets attached: %d by touching the bare wound, %d recruited by signals. %s" % [model.attached, model.adhered_direct, model.recruited, covered]
	_summary.text = text
	last_summary = "Last test (%s): %s" % [settings_text(), text]


func _exp_setup_hint() -> String:
	var hint: String = "Predict: how fast will a plug form with these settings? Then press Start Experiment."
	if last_summary != "":
		hint = last_summary + "\nChange ONE setting and test again."
	return hint


func _exp_live_caption() -> String:
	match _stage:
		"healthy":
			return "Blood is flowing normally. Platelets drift past."
		"injury":
			return "Injury! Bare wound surface is exposed. Passing platelets can stick to it."
		"first":
			if signaling == 2:
				return "Signals are blocked. Only platelets that touch bare wound can stick."
			return "Stuck platelets become activated and release signals (green diamonds)."
		"recruit":
			return "Signals activate more platelets. More platelets -> more signals -> even more platelets. Positive feedback!"
		"covered":
			return "The wound is covered. The signals fade and the plug stops growing."
	return ""


func _exp_prompts() -> Array[Dictionary]:
	return PROMPTS


func _exp_refresh(locked: bool) -> void:
	for b: Button in [_wound_button, _platelet_button, _signal_button]:
		b.disabled = locked
	_wound_button.text = "Wound Size: " + WOUND_NAMES[wound_size]
	_platelet_button.text = "Platelet Supply: " + PLATELET_NAMES[platelet_level]
	_signal_button.text = "Recruit Signals: " + SIGNAL_NAMES[signaling]


# === PRIVATE METHODS ===
func _record() -> void:
	recorder.record(model.time, {"attached": model.attached, "new": model.new_per_interval, "coverage": model.coverage}, model.snapshot())
