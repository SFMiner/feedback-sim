class_name GlucoseModule
extends ExperimentBase
## Module 4, Blood Glucose Regulation: students start the body "at rest", then disturb it (meal,
## exercise, fasting) and watch insulin and glucagon bring glucose back. An Advanced panel weakens
## either hormone response. Time runs at RATE simulated minutes per real second.

# === CONSTANTS ===
const RATE: float = 5.0
const PROMPTS: Array[Dictionary] = [
	{"q": "What happened when blood glucose moved away from its normal range?", "frame": "When glucose became ______, the pancreas responded by ______, causing glucose to move ______."},
	{"q": "Why is this an example of negative feedback?", "frame": "It is negative feedback because the body's response ______ the change."},
	{"q": "What did the liver's glycogen store do during your experiment?", "frame": "The glycogen store went ______ when ______."},
]

# === PUBLIC VARIABLES ===
var model: GlucoseModel = null
var view: GlucoseView = null
var insulin_reduced: bool = false
var glucagon_reduced: bool = false
var fasting: bool = false
var advanced_open: bool = false

# === PRIVATE VARIABLES ===
var _meal_button: Button = null
var _exercise_button: Button = null
var _fast_button: Button = null
var _advanced_button: Button = null
var _insulin_button: Button = null
var _glucagon_button: Button = null
var _summary: Label = null
var _layer_buttons: Dictionary = {}
var _layers: Dictionary = {"insulin": false, "glucagon": false, "glycogen": false}


# === PUBLIC METHODS ===
func module_title() -> String:
	return "Experiment: Blood Glucose"


func eat_meal() -> void:
	if phase == Phase.RUNNING and model.eat_meal():
		recorder.add_event(model.time, "Meal")
		sfx.cue("pop")
		say("Meal eaten.")
		print("feedback: glucose meal")
	_refresh()


func exercise() -> void:
	if phase == Phase.RUNNING and model.start_exercise():
		recorder.add_event(model.time, "Exercise")
		sfx.cue("pop")
		say("Exercise started.")
		print("feedback: glucose exercise")
	_refresh()


func toggle_fasting() -> void:
	if phase == Phase.RESULTS:
		return
	fasting = not fasting
	model.set_fasting(fasting)
	if phase == Phase.RUNNING:
		recorder.add_event(model.time, "Fasting starts" if fasting else "Fasting ends")
	else:
		_restart_record()
	print("feedback: glucose fasting " + ("on" if fasting else "off"))
	_refresh()


func toggle_advanced() -> void:
	advanced_open = not advanced_open
	_refresh()


func toggle_insulin_response() -> void:
	insulin_reduced = not insulin_reduced
	reset_experiment()


func toggle_glucagon_response() -> void:
	glucagon_reduced = not glucagon_reduced
	reset_experiment()


func toggle_layer(key: String) -> void:
	_layers[key] = not bool(_layers[key])
	graph.set_series_visible(key, bool(_layers[key]))
	_refresh()


# === HOOKS ===
func _exp_name() -> String:
	return "glucose"


func _exp_dt() -> float:
	return GlucoseModel.DT


func _exp_rate() -> float:
	return RATE


func _exp_build_setup(box: VBoxContainer) -> void:
	box.add_child(UI.label("Start, then disturb the body:", 14, UI.TEXT_DIM))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	box.add_child(row)
	_meal_button = UI.button("Eat a Meal", eat_meal)
	_exercise_button = UI.button("Exercise", exercise)
	_meal_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_exercise_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_meal_button)
	row.add_child(_exercise_button)
	_fast_button = UI.button("", toggle_fasting)
	box.add_child(_fast_button)
	_advanced_button = UI.button("", toggle_advanced)
	box.add_child(_advanced_button)
	_insulin_button = UI.button("", toggle_insulin_response)
	box.add_child(_insulin_button)
	_glucagon_button = UI.button("", toggle_glucagon_response)
	box.add_child(_glucagon_button)


func _exp_build_results(box: VBoxContainer) -> void:
	_summary = UI.label("", 13, UI.TEXT, true)
	box.add_child(_summary)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	box.add_child(row)
	for key: String in ["insulin", "glucagon"]:
		var b: Button = UI.button("", toggle_layer.bind(key))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 13)
		row.add_child(b)
		_layer_buttons[key] = b
	var g: Button = UI.button("", toggle_layer.bind("glycogen"))
	box.add_child(g)
	_layer_buttons["glycogen"] = g


func _exp_build_view() -> Control:
	view = GlucoseView.new()
	return view


func _exp_configure_graph() -> void:
	graph.title = "Blood Glucose"
	graph.x_label = "Time (simulated minutes)"
	graph.y_label = "Glucose (classroom units)"
	graph.x_span_min = 120.0
	graph.band = {"lo": GlucoseModel.TARGET_LOW, "hi": GlucoseModel.TARGET_HIGH, "label": "Target range", "color": UI.GOOD}
	graph.add_series("glucose", "Glucose", Color("ffd166"))
	graph.add_series("insulin", "Insulin %", Color("7fb0ff"), GraphView.STYLE_DASHED, false)
	graph.add_series("glucagon", "Glucagon %", Color("ff9a6b"), GraphView.STYLE_DOTTED, false)
	graph.add_series("glycogen", "Glycogen %", Color("e6e6e6"), GraphView.STYLE_DASHED, false)


func _exp_new() -> void:
	model = GlucoseModel.new()
	model.setup(insulin_reduced, glucagon_reduced)
	model.set_fasting(fasting)
	_record()


func _exp_step() -> void:
	model.step()
	_record()
	for e: Dictionary in model.events:
		match str(e["type"]):
			"insulin_up":
				recorder.add_event(model.time, "Insulin rises")
				sfx.cue("bip", 0.8)
			"glucagon_up":
				recorder.add_event(model.time, "Glucagon rises")
				sfx.cue("boop", 0.8)
			"back_in_range":
				recorder.add_event(model.time, "Back in range")
			"exercise_end":
				_refresh()


func _exp_finished() -> bool:
	return model.finished


func _exp_show(snapshot: Variant) -> void:
	view.reduced = reduced_motion()
	if snapshot is Dictionary:
		view.frame = snapshot


func _exp_results_ready() -> void:
	var data: PackedFloat32Array = recorder.series["glucose"]
	var top: float = 0.0
	var low: float = 100.0
	var inside: int = 0
	for v: float in data:
		top = maxf(top, v)
		low = minf(low, v)
		if v >= GlucoseModel.TARGET_LOW and v <= GlucoseModel.TARGET_HIGH:
			inside += 1
	_summary.text = "Highest glucose: %d. Lowest: %d. In the target range %d%% of the time." % [int(round(top)), int(round(low)), int(round(100.0 * float(inside) / float(maxi(1, data.size()))))]


func _exp_setup_hint() -> String:
	return "The body is at rest. Press Start Experiment, then try Eat a Meal, Exercise or Fasting. Predict first: which way will glucose move?"


func _exp_live_caption() -> String:
	if model.blood_glucose > GlucoseModel.TARGET_HIGH:
		return "Glucose is HIGH. The pancreas releases more insulin. Cells take in more glucose and the liver stores it."
	if model.blood_glucose < GlucoseModel.TARGET_LOW:
		if model.liver_glycogen < 2.0:
			return "Glucose is LOW and the liver's glycogen store is empty. Glucagon cannot release what is not there."
		return "Glucose is LOW. The pancreas releases more glucagon. The liver breaks down glycogen and releases glucose."
	return "Glucose is in the target range. A little of both hormones keeps it steady."


func _exp_prompts() -> Array[Dictionary]:
	return PROMPTS


func _exp_refresh(locked: bool) -> void:
	var live: bool = phase == Phase.RUNNING
	_meal_button.disabled = not live or fasting
	_exercise_button.disabled = not live or model.exercising
	_fast_button.text = "Fasting: On" if fasting else "Fasting: Off"
	_advanced_button.text = "Advanced: Hide" if advanced_open else "Advanced: Show"
	_insulin_button.visible = advanced_open
	_glucagon_button.visible = advanced_open
	_insulin_button.text = "Insulin Response: " + ("Reduced" if insulin_reduced else "Normal")
	_glucagon_button.text = "Glucagon Response: " + ("Reduced" if glucagon_reduced else "Normal")
	_insulin_button.disabled = locked
	_glucagon_button.disabled = locked
	var names: Dictionary = {"insulin": "Insulin", "glucagon": "Glucagon", "glycogen": "Liver Glycogen"}
	for key: String in _layer_buttons:
		var b: Button = _layer_buttons[key]
		b.text = "%s Line: %s" % [str(names[key]), "On" if bool(_layers[key]) else "Off"]


# === PRIVATE METHODS ===
func _record() -> void:
	recorder.record(model.time, {
		"glucose": model.blood_glucose, "insulin": model.insulin_activity * 100.0,
		"glucagon": model.glucagon_activity * 100.0, "glycogen": model.liver_glycogen,
	}, model.snapshot())


## Set-up only: re-records the first row so the picture shows the changed setting.
func _restart_record() -> void:
	recorder.clear()
	_record()
	_exp_show(recorder.snapshot_at(0.0))
