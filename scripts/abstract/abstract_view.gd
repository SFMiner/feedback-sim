class_name AbstractView
extends Control
## Arcade-style picture of the abstract models: a ball on a vertical track (its height is the
## quantity), the correctors that knock it back (negative feedback) or the booster that shoves it
## further (positive feedback). Reads an AbstractModel; never changes it.

# === CONSTANTS ===
const DESIGN: Vector2 = Vector2(300.0, 390.0)
const TRACK_X: float = 150.0
const Y_ZERO: float = 352.0
const Y_SCALE: float = 3.1
const BALL_R: float = 14.0

# === PUBLIC VARIABLES ===
var model: AbstractModel = null
var reduced: bool = false
## Caption for the latest sound cue, and seconds since it fired.
var cue_text: String = ""
var cue_age: float = 99.0
var cue_dir: int = 0

# === PRIVATE VARIABLES ===
var _top_paddle: float = 0.0
var _bottom_paddle: float = 0.0


# === LIFECYCLE METHODS ===
func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	if model == null:
		return
	var s: float = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	draw_set_transform((size - DESIGN * s) * 0.5, 0.0, Vector2(s, s))
	UI.round_rect(self, Rect2(TRACK_X - 34.0, _y(100.0) - 8.0, 68.0, _y(0.0) - _y(100.0) + 16.0), Color(0.05, 0.07, 0.11, 1), UI.PANEL_EDGE, 2, 12)
	if model.mode == AbstractModel.MODE_NEGATIVE:
		_draw_negative()
	else:
		_draw_positive()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# === PUBLIC METHODS ===
func show_cue(text: String, dir: int) -> void:
	cue_text = text
	cue_dir = dir
	cue_age = 0.0


func reset_view() -> void:
	cue_age = 99.0
	_top_paddle = _y(100.0) - 26.0
	_bottom_paddle = _y(0.0) + 26.0


## Advances presentation-only animation (paddle travel, cue fade). Called once per model step.
func advance(dt: float) -> void:
	cue_age += dt
	var ball_y: float = _y(model.value)
	var top_rest: float = _y(100.0) - 26.0
	var bottom_rest: float = _y(0.0) + 26.0
	var top_goal: float = ball_y - BALL_R - 11.0 if model.correcting == -1 else top_rest
	var bottom_goal: float = ball_y + BALL_R + 11.0 if model.correcting == 1 else bottom_rest
	var k: float = 1.0 if reduced else minf(1.0, 18.0 * dt)
	_top_paddle = lerpf(_top_paddle, top_goal, k)
	_bottom_paddle = lerpf(_bottom_paddle, bottom_goal, k)


# === PRIVATE METHODS ===
func _y(v: float) -> float:
	return Y_ZERO - v * Y_SCALE


func _level_line(v: float, label: String, color: Color, right_side: bool) -> void:
	var y: float = _y(v)
	draw_dashed_line(Vector2(TRACK_X - 44.0, y), Vector2(TRACK_X + 44.0, y), color, 2.5, 6.0)
	if right_side:
		UI.text(self, Vector2(TRACK_X + 50.0, y + 5.0), label, 14, color)
	else:
		UI.text(self, Vector2(TRACK_X - 50.0, y + 5.0), label, 14, color, 1)


func _draw_ball(color: Color) -> void:
	var c: Vector2 = Vector2(TRACK_X, _y(model.value))
	draw_circle(c, BALL_R + 2.5, Color.WHITE)
	draw_circle(c, BALL_R, color)
	draw_circle(c + Vector2(-4.0, -5.0), 4.0, Color(1, 1, 1, 0.55))


func _draw_negative() -> void:
	_level_line(AbstractModel.UPPER, "Too high", UI.NEG, true)
	_level_line(AbstractModel.TARGET, "Target", UI.GOOD, true)
	_level_line(AbstractModel.LOWER, "Too low", UI.NEG, true)
	# Sensor lamps: lit during the delay between "too far" and the push arriving.
	for dir: int in [-1, 1]:
		var lamp: Vector2 = Vector2(TRACK_X - 70.0, _y(AbstractModel.UPPER if dir == -1 else AbstractModel.LOWER))
		var lit: bool = model.pending == dir
		draw_circle(lamp, 11.0, UI.FOCUS if lit else Color(0.25, 0.28, 0.34, 1))
		draw_arc(lamp, 11.0, 0.0, TAU, 20, Color.WHITE, 1.5, true)
		UI.text(self, lamp + Vector2(0.0, 6.0), "!", 17, UI.INK if lit else Color(0.5, 0.54, 0.6, 1), 0)
	UI.text(self, Vector2(TRACK_X - 70.0, _y(AbstractModel.UPPER) - 18.0), "sensor", 11, UI.TEXT_DIM, 0)
	# Correctors: two paddles on rods.
	_draw_paddle(_top_paddle, -1)
	_draw_paddle(_bottom_paddle, 1)
	_draw_ball(Color("ffd166"))
	_draw_cue()


func _draw_paddle(y: float, dir: int) -> void:
	var anchor_y: float = _y(100.0) - 34.0 if dir == -1 else _y(0.0) + 34.0
	draw_line(Vector2(TRACK_X, anchor_y), Vector2(TRACK_X, y), Color(0.7, 0.75, 0.82, 1), 5.0)
	var active: bool = model.correcting == dir
	var col: Color = UI.NEG if active else UI.NEG.darkened(0.35)
	UI.round_rect(self, Rect2(TRACK_X - 30.0, y - 9.0, 60.0, 18.0), col, Color.WHITE, 2, 6)
	# Arrow on the paddle shows which way it pushes (shape cue, not colour).
	var tip: Vector2 = Vector2(TRACK_X, y - float(dir) * 6.0)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-7.0, float(dir) * 9.0), tip + Vector2(7.0, float(dir) * 9.0)]), UI.INK)


func _draw_positive() -> void:
	var up: bool = model.mode == AbstractModel.MODE_POSITIVE_UP
	_level_line(AbstractModel.LIMIT_HIGH, "Limit", UI.WARN, true)
	_level_line(AbstractModel.BASELINE, "Start", UI.TEXT_DIM, true)
	_level_line(AbstractModel.LIMIT_LOW, "Limit", UI.WARN, true)
	var c: Vector2 = Vector2(TRACK_X, _y(model.value))
	var dir: float = -1.0 if up else 1.0
	# Booster: a wedge behind the ball. Its size is the size of the latest boost.
	var boost: float = model.last_boost
	var fresh: bool = cue_age < 0.35 and cue_text.begins_with("BOOST")
	var base: Vector2 = c - Vector2(0.0, dir * (BALL_R + 6.0))
	var bw: float = 14.0 + boost * 2.2
	var bh: float = 10.0 + boost * 2.6
	var col: Color = Color.WHITE if fresh else UI.POS
	draw_colored_polygon(PackedVector2Array([base, base - Vector2(bw, dir * bh), base - Vector2(-bw, dir * bh)]), col)
	draw_polyline(PackedVector2Array([base, base - Vector2(bw, dir * bh), base - Vector2(-bw, dir * bh), base]), UI.INK, 2.0, true)
	# Arrow beside the track: how far the quantity has moved from where it started.
	var start: Vector2 = Vector2(TRACK_X - 44.0, _y(AbstractModel.BASELINE))
	if absf(c.y - start.y) > 6.0:
		UI.arrow(self, start, Vector2(start.x, c.y), UI.POS, 5.0)
	_draw_ball(Color("ffd166"))
	if model.at_limit:
		UI.text(self, Vector2(TRACK_X, _y(model.limit()) + (-16.0 if up else 36.0)), "No room left!", 15, UI.WARN, 0)
	_draw_cue()


func _draw_cue() -> void:
	if cue_age > 0.7:
		return
	var k: float = cue_age / 0.7
	var c: Vector2 = Vector2(TRACK_X - 104.0, _y(model.value) + 34.0)
	if model.mode == AbstractModel.MODE_NEGATIVE:
		c = Vector2(TRACK_X + 92.0, _y(88.0) if cue_dir == -1 else _y(10.0))
	var fsize: int = 24 if reduced else int(20.0 + 10.0 * (1.0 - k))
	UI.text(self, c + Vector2(1.5, 1.5), cue_text, fsize, UI.INK, 0)
	UI.text(self, c, cue_text, fsize, Color.WHITE, 0)
