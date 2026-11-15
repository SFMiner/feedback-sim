extends Control
## Main menu: title, subtitle and the four modules, grouped into "Watch" (demonstrations) and
## "Experiment" (interactive). Any module can be opened at any time.

# === CONSTANTS ===
const WATCH: Color = Color(0.45, 0.33, 0.70, 1)
const EXPERIMENT: Color = Color(0.16, 0.50, 0.42, 1)

# === PUBLIC VARIABLES ===
var app: Node = null


# === LIFECYCLE METHODS ===
func _ready() -> void:
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	center.add_child(col)
	var title: Label = UI.label("FEEDBACK!", 50, UI.POS)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color(0.20, 0.10, 0.02, 1))
	col.add_child(title)
	var sub: Label = UI.label("What happens when a system responds to change?", 20, UI.TEXT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0.0, 8.0)
	col.add_child(gap)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	row.add_child(_group("PART 1: WATCH", "Demonstrations. Press Play and watch.", WATCH,
		[["classroom", "Watch:\nClassroom Chatter"], ["abstract", "Watch:\nAbstract Feedback"]]))
	row.add_child(_group("PART 2: EXPERIMENT", "Interactive. You change things and test.", EXPERIMENT,
		[["clotting", "Experiment:\nBlood Clotting"], ["glucose", "Experiment:\nBlood Glucose"]]))
	var hint: Label = UI.label("You can open any part in any order.", 14, UI.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)


# === PRIVATE METHODS ===
func _group(heading: String, note: String, color: Color, items: Array) -> PanelContainer:
	var p: PanelContainer = UI.panel(Color(color.r * 0.35, color.g * 0.35, color.b * 0.35, 1), color.lightened(0.35))
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var h: Label = UI.label(heading, 19, Color.WHITE)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(h)
	var n: Label = UI.label(note, 14, UI.TEXT)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	for item: Array in items:
		var id: String = item[0]
		var b: Button = UI.button(str(item[1]), _open.bind(id), 215.0)
		b.custom_minimum_size = Vector2(215.0, 96.0)
		b.add_theme_font_size_override("font_size", 19)
		b.add_theme_stylebox_override("normal", UI.box(color, color.lightened(0.5), 2))
		b.add_theme_stylebox_override("hover", UI.box(color.lightened(0.15), Color.WHITE, 2))
		b.add_theme_stylebox_override("pressed", UI.box(color.darkened(0.2), Color.WHITE, 2))
		row.add_child(b)
	return p


func _open(id: String) -> void:
	app.open_module(id)
