extends "res://tests/test_base.gd"
## Headless end-to-end checks of the running application: navigation, every exposed control,
## graph-versus-model agreement, pause, reset, replay, sound triggering and the keyboard boundary.
## Run:  Godot --headless --path . --script tests/test_app.gd
## (Sound is checked by counting what the audio controller was asked to play; nothing is heard.)

const EXPECTED: int = 96

var _main: Node = null


func _init() -> void:
	test_name = "test_app"
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1180, 500)
	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await _frames(3)
	await _menu_and_bar()
	await _classroom()
	await _abstract()
	await _clotting()
	await _glucose()
	await _keyboard()
	finish(EXPECTED)


## Waits n frames and at least n/60 s: headless frames are not tied to a display, so a frame
## count alone can be almost no time at all (a "wait 30 frames" check failed once that way).
func _frames(n: int) -> void:
	var until: int = Time.get_ticks_msec() + int(float(n) * 1000.0 / 60.0)
	var done: int = 0
	while done < n or Time.get_ticks_msec() < until:
		await process_frame
		done += 1


func _buttons(node: Node, out: Array[Button]) -> void:
	for child: Node in node.get_children():
		if child is Control and not (child as Control).visible:
			continue
		if child is Button:
			out.append(child)
		_buttons(child, out)


func _button(text: String) -> Button:
	var all: Array[Button] = []
	_buttons(_main, all)
	for b: Button in all:
		if b.text.replace("\n", " ") == text:
			return b
	return null


func _press(text: String) -> bool:
	var b: Button = _button(text)
	if b == null or b.disabled:
		return false
	b.pressed.emit()
	return true


func _total_plays() -> int:
	var n: int = 0
	for key: String in _main.sfx.play_counts:
		n += int(_main.sfx.play_counts[key])
	return n


# === MENU AND TOP BAR ===
func _menu_and_bar() -> void:
	check(_main.current_id == "" and _button("Watch: Classroom Chatter") != null, "menu: shown at start with the module buttons")
	for id: String in ["classroom", "abstract", "clotting", "glucose"]:
		_main.open_menu()
		await _frames(1)
		var ok: bool = _press(str(_main.MODULE_TITLES[id]))
		await _frames(2)
		check(ok and _main.current_id == id and _main.current_module != null, "menu: '%s' opens its module" % str(_main.MODULE_TITLES[id]))
	check(_press("Next Module") and _main.current_id == "classroom", "bar: Next Module goes on from the last module to the first")
	await _frames(1)
	check(_press("Menu") and _main.current_id == "", "bar: Menu returns to the main menu")
	check(_button("Menu").disabled and _button("Next Module").disabled, "bar: Menu and Next Module are disabled on the menu itself")
	_press("Sound: On")
	check(AudioServer.is_bus_mute(0) and _button("Sound: Off") != null, "bar: Sound button mutes the master bus")
	_press("Sound: Off")
	check(not AudioServer.is_bus_mute(0), "bar: Sound button unmutes")
	var before: float = AudioServer.get_bus_volume_db(0)
	_press("Vol -")
	var lower: float = AudioServer.get_bus_volume_db(0)
	_press("Vol +")
	check(lower < before and is_equal_approx(AudioServer.get_bus_volume_db(0), before), "bar: Vol - and Vol + change the master volume")
	for i: int in range(6):
		_press("Vol -")
	check(AudioServer.is_bus_mute(0), "bar: volume 0 is silent")
	for i: int in range(4):
		_press("Vol +")
	_press("Motion: Full")
	check(_main.reduced_motion and _button("Motion: Reduced") != null, "bar: Motion button switches to reduced motion")
	_press("Motion: Reduced")
	check(not _main.reduced_motion, "bar: Motion button switches back")
	_main.sfx.play_counts.clear()


# === CLASSROOM ===
func _classroom() -> void:
	_main.open_module("classroom")
	var m: ClassroomModule = _main.current_module
	await _frames(40)
	check(m.recorder.size() == 1 and _total_plays() == 0 and not m.playing, "classroom: nothing plays or moves before Play is pressed")
	_press("Play")
	await _frames(30)
	check(m.playing and m.recorder.size() > 5, "classroom: Play starts the demonstration")
	check(is_equal_approx(m.recorder.latest("noise"), m.model.noise_level) and is_equal_approx(m.recorder.duration(), m.model.time), "classroom: the graph's newest point is the model's current noise level")
	_press("Pause")
	var size_paused: int = m.recorder.size()
	var anim_paused: float = m.view.anim_t
	await _frames(20)
	check(not m.playing and m.recorder.size() == size_paused and m.view.anim_t == anim_paused, "classroom: Pause freezes the model, the graph and the animation")
	check(_press("Resume") and m.playing, "classroom: Resume continues")
	# Drive the model step by step (with sound) through the first intervention.
	m.playing = false
	_main.sfx.play_counts.clear()
	var noise_at_whomps: Array[float] = []
	var guard: int = 0
	while m.model.cycles_done < 1 and guard < 3000:
		m._step(true)
		guard += 1
		if m.view.whomp_age == 0.0:
			noise_at_whomps.append(m.recorder.latest("noise"))
	check(int(_main.sfx.play_counts.get("teacher", 0)) == 3, "classroom: the teacher's voice plays exactly three times in an intervention")
	check(noise_at_whomps.size() == 3 and noise_at_whomps[0] > noise_at_whomps[1] and noise_at_whomps[1] > noise_at_whomps[2] and noise_at_whomps[2] == 0.0, "classroom: each WHOMP lands on the same step as a drop in the graph, ending at zero")
	check(m.recorder.events.size() == 1 and str(m.recorder.events[0]["label"]) == "Teacher steps in", "classroom: the intervention is marked on the graph")
	check(_press("Skip Ahead") and m.model.teacher2_present and not m.model.finished, "classroom: Skip Ahead jumps to the second teacher's arrival")
	check(_press("Skip Ahead") and m.model.finished, "classroom: Skip Ahead again jumps to the end")
	var first_curve: PackedFloat32Array = (m.recorder.series["noise"] as PackedFloat32Array).duplicate()
	var first_looks: String = str(m.view.looks())
	check(m.recorder.latest("noise") >= 95.0 and not m.model.teacher_active, "classroom: the run ends near maximum noise with negative feedback off")
	check(_button("Play Again") != null and _button("Skip Ahead").disabled, "classroom: at the end the buttons offer Play Again")
	_press("Replay")
	check(m.playing and m.recorder.size() <= 2, "classroom: Replay restarts from the beginning")
	m.playing = false
	_main.sfx.play_counts.clear()
	while not m.model.finished:
		m._step(true)
	var voices_heard: int = 0
	for v: int in range(4):
		if _main.sfx.chatter_requests[v] > 20:
			voices_heard += 1
	check(voices_heard == 4, "classroom: all four student voices are called on many times over a full run: " + str(_main.sfx.chatter_requests))
	var chatter_played: int = 0
	for v: int in range(4):
		chatter_played += int(_main.sfx.play_counts.get("voice_%d" % v, 0))
	check(chatter_played == AudioController.CHATTER_PLAYERS, "classroom: with no time passing, only %d chatter voices can sound at once (the loudness cap)" % AudioController.CHATTER_PLAYERS)
	check(m.recorder.series["noise"] == first_curve, "classroom: the replay reproduces the same recorded curve, value for value")
	check(str(m.view.looks()) == first_looks, "classroom: the replay shows the same student appearances")
	_main.sfx.play_counts.clear()


# === ABSTRACT ===
func _abstract() -> void:
	_main.open_module("abstract")
	var m: AbstractModule = _main.current_module
	await _frames(30)
	check(m.recorder.size() == 1 and _total_plays() == 0, "abstract: nothing plays before Play is pressed")
	_press("Play")
	await _frames(20)
	check(m.playing and m.recorder.size() > 3 and is_equal_approx(m.recorder.latest("value"), m.model.value), "abstract: Play starts part 1 and the graph follows the model")
	_press("Pause")
	var held: int = m.recorder.size()
	await _frames(15)
	check(m.recorder.size() == held, "abstract: Pause freezes it")
	m.playing = false
	while not m.model.finished:
		m._step()
	var corrections: int = 0
	for e: Dictionary in m.recorder.events:
		if str(e["label"]) == "BIP" or str(e["label"]) == "BOOP":
			corrections += 1
	check(corrections >= 4 and int(_main.sfx.play_counts.get("bip", 0)) + int(_main.sfx.play_counts.get("boop", 0)) == corrections, "abstract: one BIP or BOOP sound per correction marked on the graph")
	check(_press("Skip Part") and m.part == 1 and m.model.mode == AbstractModel.MODE_POSITIVE_UP and m.recorder.size() == 1, "abstract: Skip Part moves to positive feedback with a fresh graph")
	m.playing = false
	while not m.model.finished:
		m._step()
	check(int(_main.sfx.play_counts.get("boost", 0)) == m.model.boost_count and m.model.boost_count > 5, "abstract: one boost sound per boost")
	check(m.recorder.latest("value") > 85.0, "abstract: the upward run ends near the upper limit on the graph")
	for i: int in range(int(AbstractModule.INTERMISSION * 30.0) + 2):
		m._step()
	check(m.part == 2 and m.model.mode == AbstractModel.MODE_POSITIVE_DOWN, "abstract: the next part starts by itself after a short pause")
	m.playing = false
	while not m.model.finished:
		m._step()
	check(m.recorder.latest("value") < 15.0, "abstract: the downward run ends near the lower limit")
	for i: int in range(int(AbstractModule.INTERMISSION * 30.0) + 2):
		m._step()
	check(m.all_done and _button("Play Again") != null, "abstract: the demonstration ends after part 3")
	_press("Replay")
	check(m.part == 0 and m.playing and not m.all_done, "abstract: Replay restarts at part 1")
	_main.sfx.play_counts.clear()


# === CLOTTING ===
func _run_experiment(m: ExperimentBase) -> void:
	m.running = false
	var guard: int = 0
	while m.phase == ExperimentBase.Phase.RUNNING and guard < 5000:
		m._exp_step()
		guard += 1
		if m._exp_finished():
			m.show_results()


func _clotting() -> void:
	_main.open_module("clotting")
	var m: ClottingModule = _main.current_module
	await _frames(30)
	check(m.is_setup() and m.recorder.size() == 1 and _total_plays() == 0, "clotting: waits in set-up; nothing runs by itself")
	check(_press("Wound Size: Medium") and m.wound_size == 2 and m.model.slot_count() == ClottingModel.WOUND_SLOTS[2], "clotting: Wound Size changes the wound")
	check(_press("Platelet Supply: Normal") and m.platelet_level == 2 and m.model.pos.size() == ClottingModel.PLATELET_COUNTS[2], "clotting: Platelet Supply changes the number of platelets")
	check(_press("Recruit Signals: Normal") and m.signaling == 1, "clotting: Recruit Signals changes signalling")
	_press("Wound Size: Large")
	_press("Wound Size: Small")
	_press("Platelet Supply: High")
	_press("Platelet Supply: Low")
	_press("Recruit Signals: Reduced")
	_press("Recruit Signals: Blocked")
	check(m.wound_size == 1 and m.platelet_level == 1 and m.signaling == 0, "clotting: each setting cycles through three values")
	check(_button("View Results").disabled, "clotting: View Results is unavailable before the experiment starts")
	_press("Start Experiment")
	await _frames(30)
	check(m.phase == ExperimentBase.Phase.RUNNING and m.recorder.size() > 5 and _button("Wound Size: Medium").disabled, "clotting: Start runs the experiment and locks the settings")
	_press("Pause")
	var held: int = m.recorder.size()
	await _frames(15)
	check(m.recorder.size() == held and _press("Resume"), "clotting: Pause freezes the experiment; Resume continues")
	_run_experiment(m)
	check(m.phase == ExperimentBase.Phase.RESULTS and m.model.finished, "clotting: the experiment ends in the results view")
	var data: PackedFloat32Array = m.recorder.series["attached"]
	check(int(data[data.size() - 1]) == m.model.attached and m.model.attached > 10, "clotting: the graph's final value is the model's attached-platelet count")
	var labels: Array[String] = []
	for e: Dictionary in m.recorder.events:
		labels.append(str(e["label"]))
	check(labels == ["Injury", "First platelet sticks", "Recruitment speeds up", "Wound covered: plug formed"], "clotting: the four events are annotated in order: " + str(labels))
	check(int(_main.sfx.play_counts.get("boost", 0)) == m.model.recruited, "clotting: one recruit sound per recruited platelet")
	_press("Replay")
	await _frames(20)
	var t: float = m.cursor
	check(m.replaying and t > 0.0 and t < m.recorder.duration(), "clotting: Replay plays the recording from the start")
	check(int(m.view.frame["attached"]) == int(m.recorder.value_at("attached", t)) and is_equal_approx(m.graph.cursor, t), "clotting: during replay the picture and the graph marker show the same moment")
	_press("Pause Replay")
	m.graph.scrubbed.emit(m.recorder.duration() * 0.5)
	check(not m.replaying and int(m.view.frame["attached"]) == int(m.recorder.value_at("attached", m.cursor)), "clotting: clicking the graph jumps the picture to that moment")
	var at: float = m.cursor
	_press("Back")
	check(m.cursor < at, "clotting: Back steps the replay backwards")
	_press("Forward")
	check(is_equal_approx(m.cursor, at), "clotting: Forward steps it forwards")
	var info: Label = m._info
	var q1: String = info.text
	_press("Sentence Starter")
	check(info.text.contains("The first platelets released signals that caused") and q1.contains("How did the first platelets"), "clotting: reflection prompt and optional sentence starter are shown")
	_press("Next Question")
	check(info.text.contains("What changed when platelet recruitment signals were blocked?"), "clotting: Next Question shows the second prompt")
	var normal_attached: int = m.model.attached
	_press("Try Another Experiment")
	check(m.is_setup() and m.recorder.size() == 1 and m.model.attached == 0, "clotting: Try Another Experiment resets without restarting the app")
	_press("Recruit Signals: Normal")
	_press("Recruit Signals: Reduced")
	_press("Start Experiment")
	_run_experiment(m)
	check(m.model.recruited == 0 and m.model.attached < normal_attached and m.model.adhered_direct > 0, "clotting: blocking signals leaves only first-contact adhesion (%d vs %d attached)" % [m.model.attached, normal_attached])
	_press("Try Another Experiment")
	_press("Start Experiment")
	_press("Reset")
	check(m.is_setup() and m.recorder.size() == 1, "clotting: Reset during a run returns to set-up")
	_main.sfx.play_counts.clear()


# === GLUCOSE ===
func _glucose() -> void:
	_main.open_module("glucose")
	var m: GlucoseModule = _main.current_module
	await _frames(30)
	check(m.is_setup() and m.recorder.size() == 1 and _total_plays() == 0, "glucose: waits in set-up; nothing runs by itself")
	check(_button("Eat a Meal").disabled and _button("Exercise").disabled, "glucose: disturbances wait until the experiment has started")
	check(_button("Insulin Response: Normal") == null and _press("Advanced: Show") and _button("Insulin Response: Normal") != null, "glucose: the Advanced panel is hidden until opened")
	check(_press("Insulin Response: Normal") and m.insulin_reduced and m.model.insulin_response < 1.0, "glucose: Insulin Response switches to Reduced")
	check(_press("Glucagon Response: Normal") and m.glucagon_reduced and m.model.glucagon_response < 1.0, "glucose: Glucagon Response switches to Reduced")
	_press("Insulin Response: Reduced")
	_press("Glucagon Response: Reduced")
	_press("Advanced: Hide")
	check(not m.insulin_reduced and not m.glucagon_reduced and _button("Insulin Response: Normal") == null, "glucose: both switch back, and the panel hides again")
	_press("Start Experiment")
	await _frames(30)
	check(m.phase == ExperimentBase.Phase.RUNNING and m.recorder.size() > 5, "glucose: Start runs the experiment")
	check(is_equal_approx(m.recorder.latest("glucose"), m.model.blood_glucose), "glucose: the graph's newest point is the model's blood glucose")
	_press("Pause")
	var held: int = m.recorder.size()
	await _frames(15)
	check(m.recorder.size() == held, "glucose: Pause freezes the experiment")
	m.running = false
	var before_meal: float = m.model.blood_glucose
	check(_press("Eat a Meal"), "glucose: Eat a Meal is available while running")
	for i: int in range(160):
		m._exp_step()
	check(m.model.blood_glucose > before_meal + 10.0 and m.model.insulin_activity > 0.6, "glucose: the meal raises glucose and insulin responds")
	for i: int in range(500):
		m._exp_step()
	check(m.model.in_range(), "glucose: glucose comes back into the target range")
	var before_ex: float = m.model.tissue_glucose_use
	check(_press("Exercise") and m.model.exercising and _button("Exercise").disabled, "glucose: Exercise starts (and cannot be stacked)")
	for i: int in range(80):
		m._exp_step()
	check(m.model.tissue_glucose_use > before_ex * 1.5 and m.model.glucagon_activity > 0.35, "glucose: exercise raises glucose use and glucagon responds")
	check(_press("Fasting: Off") and m.model.fasting and _button("Eat a Meal").disabled, "glucose: Fasting switches on and blocks meals")
	m._exp_step()
	check(m.model.dietary_glucose_input == 0.0, "glucose: fasting removes dietary glucose input")
	_press("Fasting: On")
	check(not m.model.fasting, "glucose: Fasting switches off again")
	check(_press("View Results") and m.phase == ExperimentBase.Phase.RESULTS, "glucose: View Results ends the experiment early")
	var labels: Array[String] = []
	for e: Dictionary in m.recorder.events:
		labels.append(str(e["label"]))
	check(labels.has("Meal") and labels.has("Insulin rises") and labels.has("Back in range") and labels.has("Exercise") and labels.has("Fasting starts"), "glucose: disturbances and responses are annotated: " + str(labels))
	var visible_before: bool = bool(m.graph.series[1]["visible"])
	_press("Insulin Line: Off")
	_press("Glucagon Line: Off")
	_press("Liver Glycogen Line: Off")
	check(not visible_before and bool(m.graph.series[1]["visible"]) and bool(m.graph.series[2]["visible"]) and bool(m.graph.series[3]["visible"]), "glucose: hormone and glycogen lines are hidden by default and can be switched on")
	_press("Replay")
	await _frames(20)
	check(m.replaying and is_equal_approx(float(m.view.frame["glucose"]), m.recorder.value_at("glucose", m.cursor)), "glucose: during replay the picture and the graph show the same recorded glucose")
	m.graph.scrubbed.emit(m.recorder.duration() * 0.25)
	check(is_equal_approx(float(m.view.frame["glycogen"]), m.recorder.value_at("glycogen", m.cursor)), "glucose: clicking the graph jumps the picture to that moment")
	check((m._info as Label).text.contains("What happened when blood glucose moved away from its normal range?"), "glucose: the reflection prompt is shown")
	_press("Try Another Experiment")
	check(m.is_setup() and is_equal_approx(m.model.blood_glucose, GlucoseModel.SET_POINT), "glucose: Try Another Experiment resets")
	_main.sfx.play_counts.clear()


# === KEYBOARD BOUNDARY ===
func _keyboard() -> void:
	_main.open_menu()
	await _frames(2)
	var kb: KeyboardExit = _main.keyboard
	var ring: Array[Control] = kb.current_ring()
	check(ring.size() == 8, "keyboard: the menu's Tab ring holds the 4 bar buttons that are enabled and the 4 module buttons (%d)" % ring.size())
	kb.move_focus(1)
	check(root.gui_get_focus_owner() == ring[0], "keyboard: Tab with nothing focused lands on the first control")
	for i: int in range(ring.size() - 1):
		kb.move_focus(1)
	check(root.gui_get_focus_owner() == ring[ring.size() - 1] and kb.leave_count == 0, "keyboard: Tab walks every control without leaving")
	kb.move_focus(1)
	check(kb.leave_count == 1 and root.gui_get_focus_owner() == null, "keyboard: Tab past the last control leaves the game")
	kb.move_focus(-1)
	check(root.gui_get_focus_owner() == ring[ring.size() - 1], "keyboard: Shift+Tab with nothing focused lands on the last control")
	ring[0].grab_focus()
	kb.move_focus(-1)
	check(kb.leave_count == 2, "keyboard: Shift+Tab before the first control leaves the game")
	kb.escape()
	check(kb.leave_count == 3, "keyboard: Escape leaves the game")
	var all_focusable: bool = true
	for id: String in ["classroom", "abstract", "clotting", "glucose"]:
		_main.open_module(id)
		await _frames(2)
		var shown: Array[Button] = []
		_buttons(_main, shown)
		var module_ring: Array[Control] = kb.current_ring()
		for b: Button in shown:
			if not b.disabled and not module_ring.has(b):
				all_focusable = false
	check(all_focusable, "keyboard: in every module, every enabled button is in the Tab ring")
