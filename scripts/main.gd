extends Control
## Application shell: top bar (navigation, sound, motion), the main menu, and the current module.
## Everything is built in code. Modules are swapped inside `_content`; none is locked.

# === CONSTANTS ===
const MODULE_IDS: Array[String] = ["classroom", "abstract", "clotting", "glucose"]
const MODULE_SCRIPTS: Dictionary = {
	"classroom": preload("res://scripts/classroom/classroom_module.gd"),
	"abstract": preload("res://scripts/abstract/abstract_module.gd"),
	"clotting": preload("res://scripts/clotting/clotting_module.gd"),
	"glucose": preload("res://scripts/glucose/glucose_module.gd"),
}
const MODULE_TITLES: Dictionary = {
	"classroom": "Watch: Classroom Chatter",
	"abstract": "Watch: Abstract Feedback",
	"clotting": "Experiment: Blood Clotting",
	"glucose": "Experiment: Blood Glucose",
}
## Kept clear for the host site's floating Full screen button (top-right corner).
const RESERVED_CORNER: float = 200.0

# === PUBLIC VARIABLES ===
var sfx: AudioController = null
var announcer: Announcer = null
var keyboard: KeyboardExit = null
var reduced_motion: bool = false
var current_id: String = ""
var current_module: ModuleBase = null

# === PRIVATE VARIABLES ===
var _content: Control = null
var _menu: Control = null
var _title: Label = null
var _menu_button: Button = null
var _next_button: Button = null
var _sound_button: Button = null
var _volume_label: Label = null
var _motion_button: Button = null


# === LIFECYCLE METHODS ===
func _ready() -> void:
	theme = UI.build_theme()
	sfx = AudioController.new()
	add_child(sfx)
	announcer = Announcer.new()
	add_child(announcer)
	keyboard = KeyboardExit.new()
	keyboard.ring_provider = _focus_ring
	add_child(keyboard)
	_build()
	if OS.has_feature("web"):
		reduced_motion = bool(JavaScriptBridge.eval("window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches ? true : false"))
	_refresh_bar()
	var start: String = _module_from_address()
	if start == "":
		open_menu()
	else:
		open_module(start)
	print("feedback: boot ok")


# === PUBLIC METHODS ===
func open_menu() -> void:
	_close_module()
	current_id = ""
	_menu.visible = true
	_title.text = "FEEDBACK!"
	_refresh_bar()
	print("feedback: menu")


func open_module(id: String) -> void:
	if not MODULE_SCRIPTS.has(id):
		return
	_close_module()
	_menu.visible = false
	current_id = id
	var script: GDScript = MODULE_SCRIPTS[id]
	current_module = script.new()
	current_module.setup(self)
	current_module.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(current_module)
	_title.text = str(MODULE_TITLES[id])
	_refresh_bar()
	announcer.say(str(MODULE_TITLES[id]))
	print("feedback: module " + id)


func next_module() -> void:
	var i: int = MODULE_IDS.find(current_id)
	open_module(MODULE_IDS[(i + 1) % MODULE_IDS.size()])


func toggle_sound() -> void:
	sfx.set_muted(not sfx.muted)
	_refresh_bar()
	print("feedback: sound " + ("off" if sfx.muted else "on"))


func change_volume(delta: int) -> void:
	sfx.change_volume(delta)
	_refresh_bar()
	sfx.cue("bip", 0.7)
	print("feedback: volume %d" % sfx.volume_step)


func toggle_motion() -> void:
	reduced_motion = not reduced_motion
	_refresh_bar()
	print("feedback: motion " + ("reduced" if reduced_motion else "full"))


# === PRIVATE METHODS ===
func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 8.0
	root.offset_top = 6.0
	root.offset_right = -8.0
	root.offset_bottom = -6.0
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	var bar: HBoxContainer = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	root.add_child(bar)
	_menu_button = UI.button("Menu", open_menu, 76.0)
	bar.add_child(_menu_button)
	_next_button = UI.button("Next Module", next_module, 118.0)
	bar.add_child(_next_button)
	_title = UI.label("FEEDBACK!", 22, UI.TEXT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.clip_text = true
	bar.add_child(_title)
	_sound_button = UI.button("Sound: On", toggle_sound, 112.0)
	bar.add_child(_sound_button)
	bar.add_child(UI.button("Vol -", change_volume.bind(-1), 58.0))
	_volume_label = UI.label("4/5", 15, UI.TEXT)
	_volume_label.custom_minimum_size = Vector2(34.0, 0.0)
	_volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(_volume_label)
	bar.add_child(UI.button("Vol +", change_volume.bind(1), 58.0))
	_motion_button = UI.button("Motion: Full", toggle_motion, 150.0)
	bar.add_child(_motion_button)
	var corner: Control = Control.new()
	corner.custom_minimum_size = Vector2(RESERVED_CORNER, 0.0)
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(corner)
	_content = Control.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.clip_contents = true
	root.add_child(_content)
	var menu_script: GDScript = preload("res://scripts/main_menu.gd")
	_menu = menu_script.new()
	_menu.set("app", self)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(_menu)


func _close_module() -> void:
	if current_module != null:
		current_module.on_leave()
		_content.remove_child(current_module)
		current_module.queue_free()
		current_module = null
	sfx.stop_all()


func _refresh_bar() -> void:
	var in_module: bool = current_id != ""
	_menu_button.disabled = not in_module
	_next_button.disabled = not in_module
	_sound_button.text = "Sound: Off" if sfx.muted else "Sound: On"
	_volume_label.text = "%d/%d" % [sfx.volume_step, AudioController.VOLUME_STEPS]
	_motion_button.text = "Motion: Reduced" if reduced_motion else "Motion: Full"


## Every visible, enabled control in tree order: the Tab ring for the keyboard boundary.
func _focus_ring() -> Array:
	var ring: Array = []
	_collect_focusable(self, ring)
	return ring


func _collect_focusable(node: Node, ring: Array) -> void:
	for child: Node in node.get_children():
		if child is Control:
			var c: Control = child
			if not c.visible:
				continue
			if c is BaseButton and c.focus_mode == Control.FOCUS_ALL:
				ring.append(c)
		_collect_focusable(child, ring)


## Class setting (sims site): index.html?module=classroom|abstract|clotting|glucose opens that
## module directly. Anything unknown is ignored.
func _module_from_address() -> String:
	if not OS.has_feature("web"):
		return ""
	var raw: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('module') || ''")
	var value: String = str(raw) if raw != null else ""
	return value if MODULE_IDS.has(value) else ""
