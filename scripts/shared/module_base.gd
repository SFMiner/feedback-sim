class_name ModuleBase
extends Control
## Base for the four modules. Supplies the shared fixed time step (so every model advances in equal
## steps whatever the frame rate), access to the app's sound and settings, and a few layout helpers.

# === CONSTANTS ===
const MAX_STEPS_PER_FRAME: int = 5

# === PUBLIC VARIABLES ===
var app: Node = null
var sfx: AudioController = null
var recorder: TimelineRecorder = TimelineRecorder.new()

# === PRIVATE VARIABLES ===
var _accumulator: float = 0.0


# === PUBLIC METHODS ===
func setup(p_app: Node) -> void:
	app = p_app
	sfx = p_app.sfx


func module_title() -> String:
	return ""


## Called when the player leaves the module (menu, next module).
func on_leave() -> void:
	if sfx != null:
		sfx.stop_all()


func reduced_motion() -> bool:
	return app != null and bool(app.reduced_motion)


func say(text: String) -> void:
	if app != null:
		app.announcer.say(text)


## Turns frame time into whole model steps of length `dt`. Always allows at least one step once
## enough time has built up, and drops the backlog after a long stall (hidden tab) instead of racing.
func consume_steps(delta: float, dt: float) -> int:
	_accumulator += delta
	var steps: int = 0
	while _accumulator >= dt and steps < MAX_STEPS_PER_FRAME:
		_accumulator -= dt
		steps += 1
	if _accumulator > dt * 2.0:
		_accumulator = 0.0
	return steps


func reset_steps() -> void:
	_accumulator = 0.0


## A panel with a wrapping caption label inside. Returns [panel, label].
func caption_panel(size_px: int = 16) -> Array:
	var p: PanelContainer = UI.panel()
	var l: Label = UI.label("", size_px, UI.TEXT, true)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return [p, l]
