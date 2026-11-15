extends SceneTree
## Developer tool, not a test: drives the app into a set of states and saves a screenshot of each.
## Needs a real renderer, so run it windowed (no --headless):
##   Godot --path . --resolution 1180x500 --script tests/shot.gd -- <output folder> [reduced]
## Save screenshots OUTSIDE the project folder (anything inside would be imported and exported).

var _main: Node = null
var _out: String = "."


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "."
	var reduced: bool = args.size() > 1 and args[1] == "reduced"
	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await process_frame
	_main.sfx.set_muted(true)
	_main.reduced_motion = reduced
	await _shot("menu")
	# Classroom.
	_main.open_module("classroom")
	var c: ClassroomModule = _main.current_module
	await _shot("classroom_start")
	c.toggle_play()
	c.playing = false
	_steps(c, 30 * 6)
	await _shot("classroom_spreading")
	while c.view.whomp_age > 0.1:
		c._step(false)
	await _shot("classroom_whomp")
	while not c.model.teacher_distracted:
		c._step(false)
	_steps(c, 30 * 6)
	await _shot("classroom_distracted")
	while not c.model.finished:
		c._step(false)
	await _shot("classroom_end")
	# Abstract.
	_main.open_module("abstract")
	var a: AbstractModule = _main.current_module
	a.toggle_play()
	a.playing = false
	_steps(a, 30 * 5 + 20)
	await _shot("abstract_negative_mid")
	_steps(a, 30 * 21)
	await _shot("abstract_negative_end")
	a.skip()
	a.playing = false
	_steps(a, 30 * 6)
	await _shot("abstract_positive_up")
	a.skip()
	a.playing = false
	_steps(a, 30 * 17)
	await _shot("abstract_positive_down_end")
	# Clotting.
	_main.open_module("clotting")
	var k: ClottingModule = _main.current_module
	await _shot("clotting_setup")
	k.toggle_run()
	k.running = false
	_exp_steps(k, 30 * 7)
	await _shot("clotting_running")
	_exp_steps(k, 30 * 60)
	await _shot("clotting_results")
	k.nudge_cursor(-1.0)
	k.nudge_cursor(-1.0)
	k.nudge_cursor(-1.0)
	k.nudge_cursor(-1.0)
	k.toggle_frame()
	await _shot("clotting_replay_scrub")
	k.reset_experiment()
	k.cycle_signaling()
	k.cycle_signaling()
	k.toggle_run()
	k.running = false
	_exp_steps(k, 30 * 60)
	await _shot("clotting_blocked_results")
	# Glucose.
	_main.open_module("glucose")
	var g: GlucoseModule = _main.current_module
	g.toggle_advanced()
	await _shot("glucose_setup_advanced")
	g.toggle_advanced()
	g.toggle_run()
	g.running = false
	_exp_steps(g, 100)
	g.eat_meal()
	_exp_steps(g, 130)
	await _shot("glucose_after_meal")
	_exp_steps(g, 400)
	g.exercise()
	_exp_steps(g, 120)
	await _shot("glucose_exercise")
	_exp_steps(g, 4000)
	g.toggle_layer("insulin")
	g.toggle_layer("glucagon")
	g.next_prompt()
	g.toggle_frame()
	await _shot("glucose_results_layers")
	quit(0)


func _steps(module: Node, count: int) -> void:
	for i: int in range(count):
		module.call("_step") if module is AbstractModule else module.call("_step", false)


func _exp_steps(module: ExperimentBase, count: int) -> void:
	for i: int in range(count):
		if module.phase != ExperimentBase.Phase.RUNNING:
			return
		module._exp_step()
		if module._exp_finished():
			module.show_results()
			return
	module._exp_show(module.recorder.snapshot_at(module.recorder.duration()))
	module._info.text = module._exp_live_caption()


func _shot(name: String) -> void:
	for i: int in range(4):
		await process_frame
	var image: Image = root.get_texture().get_image()
	var path: String = _out.path_join(name + ".png")
	image.save_png(path)
	print("saved " + path)
