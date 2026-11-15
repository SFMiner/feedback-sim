class_name UI
extends RefCounted
## Shared look: colours, the code-built theme, and small drawing helpers used by every view.
## Colour convention across all modules: orange = positive feedback (amplify),
## blue = negative feedback (oppose). Shapes and words always back the colour up.

# === CONSTANTS ===
const BG: Color = Color(0.08, 0.11, 0.17, 1)
const TEXT: Color = Color(0.95, 0.96, 0.98, 1)
const TEXT_DIM: Color = Color(0.76, 0.81, 0.87, 1)
const INK: Color = Color(0.10, 0.12, 0.18, 1)
const PANEL_BG: Color = Color(0.12, 0.16, 0.24, 1)
const PANEL_EDGE: Color = Color(0.36, 0.45, 0.58, 1)
const BUTTON_BG: Color = Color(0.17, 0.26, 0.40, 1)
const BUTTON_HOVER: Color = Color(0.23, 0.34, 0.52, 1)
const BUTTON_PRESSED: Color = Color(0.11, 0.17, 0.27, 1)
const BUTTON_EDGE: Color = Color(0.62, 0.74, 0.90, 1)
const FOCUS: Color = Color(1.0, 0.85, 0.29, 1)
const POS: Color = Color(1.0, 0.66, 0.22, 1)
const NEG: Color = Color(0.36, 0.78, 0.96, 1)
const GOOD: Color = Color(0.45, 0.86, 0.55, 1)
const WARN: Color = Color(1.0, 0.45, 0.42, 1)
const FONT_SIZE: int = 15
const TOUCH: float = 44.0


# === PUBLIC METHODS ===
static func build_theme() -> Theme:
	var t: Theme = Theme.new()
	t.default_font_size = FONT_SIZE
	t.set_stylebox("normal", "Button", box(BUTTON_BG, BUTTON_EDGE, 2))
	t.set_stylebox("hover", "Button", box(BUTTON_HOVER, Color.WHITE, 2))
	t.set_stylebox("pressed", "Button", box(BUTTON_PRESSED, Color.WHITE, 2))
	t.set_stylebox("disabled", "Button", box(Color(0.13, 0.16, 0.22, 1), Color(0.33, 0.39, 0.47, 1), 2))
	var focus: StyleBoxFlat = box(Color(0, 0, 0, 0), FOCUS, 4)
	focus.draw_center = false
	focus.expand_margin_left = 2.0
	focus.expand_margin_right = 2.0
	focus.expand_margin_top = 2.0
	focus.expand_margin_bottom = 2.0
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.62, 0.67, 0.72, 1))
	t.set_color("font_color", "Label", TEXT)
	var panel: StyleBoxFlat = box(PANEL_BG, PANEL_EDGE, 2)
	panel.set_content_margin_all(10.0)
	t.set_stylebox("panel", "PanelContainer", panel)
	return t


static func box(bg: Color, edge: Color, border: int, radius: int = 8) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 5.0
	sb.content_margin_bottom = 5.0
	return sb


static func button(text: String, on_press: Callable, min_width: float = 0.0) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, TOUCH)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(on_press)
	return b


static func label(text: String, size: int = FONT_SIZE, color: Color = TEXT, wrap: bool = false) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func panel(bg: Color = PANEL_BG, edge: Color = PANEL_EDGE) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = box(bg, edge, 2)
	sb.set_content_margin_all(10.0)
	p.add_theme_stylebox_override("panel", sb)
	return p


static func font() -> Font:
	return ThemeDB.fallback_font


## Draws text. `align`: -1 left of pos, 0 centred on pos.x, 1 right-aligned to pos.x. pos.y is the baseline.
static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, color: Color, align: int = -1) -> void:
	var f: Font = font()
	var w: float = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x: float = pos.x
	if align == 0:
		x -= w * 0.5
	elif align == 1:
		x -= w
	ci.draw_string(f, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func text_width(s: String, size: int) -> float:
	return font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func ellipse_points(c: Vector2, rx: float, ry: float, steps: int = 20) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(steps):
		var a: float = TAU * float(i) / float(steps)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, color: Color, outline: Color = Color(0, 0, 0, 0), width: float = 1.5) -> void:
	var pts: PackedVector2Array = ellipse_points(c, rx, ry)
	ci.draw_colored_polygon(pts, color)
	if outline.a > 0.0:
		pts.append(pts[0])
		ci.draw_polyline(pts, outline, width, true)


static func round_rect(ci: CanvasItem, r: Rect2, color: Color, edge: Color = Color(0, 0, 0, 0), border: int = 0, radius: int = 8) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = edge
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(radius)
	ci.draw_style_box(sb, r)


## Regular polygon (n sides) used for particle symbols.
static func ngon(ci: CanvasItem, c: Vector2, r: float, n: int, color: Color, rot: float = 0.0, outline: Color = Color(0, 0, 0, 0)) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(n):
		var a: float = rot + TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, color)
	if outline.a > 0.0:
		pts.append(pts[0])
		ci.draw_polyline(pts, outline, 1.5, true)


static func arrow(ci: CanvasItem, from: Vector2, to: Vector2, color: Color, width: float = 3.0) -> void:
	var d: Vector2 = to - from
	if d.length() < 1.0:
		return
	var n: Vector2 = d.normalized()
	var side: Vector2 = Vector2(-n.y, n.x)
	var head: float = width * 3.0
	ci.draw_line(from, to - n * head, color, width, true)
	ci.draw_colored_polygon(PackedVector2Array([to, to - n * head + side * head * 0.6, to - n * head - side * head * 0.6]), color)
