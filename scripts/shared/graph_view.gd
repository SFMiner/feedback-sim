class_name GraphView
extends Control
## The one graph component used by all four modules. It only ever plots what is in a
## TimelineRecorder, so a curve cannot differ from the simulation that produced it.
## Supports several series, threshold lines, a shaded target band, annotated events, a live or
## replay cursor, and click-to-scrub.

# === SIGNALS ===
signal scrubbed(t: float)

# === CONSTANTS ===
const STYLE_SOLID: int = 0
const STYLE_DASHED: int = 1
const STYLE_DOTTED: int = 2
const PLOT_BG: Color = Color(0.05, 0.07, 0.11, 1)
const GRID: Color = Color(1, 1, 1, 0.10)
const AXIS: Color = Color(0.80, 0.85, 0.92, 1)

# === PUBLIC VARIABLES ===
var recorder: TimelineRecorder = null
var title: String = ""
var x_label: String = "Time (seconds)"
var y_label: String = ""
var y_min: float = 0.0
var y_max: float = 100.0
## The x axis always covers at least this much time; it grows to fit longer recordings.
var x_span_min: float = 30.0
## Series to plot: {"key", "label", "color", "style", "visible"}.
var series: Array[Dictionary] = []
## Horizontal reference lines: {"value", "label", "color"}.
var lines: Array[Dictionary] = []
## Shaded band: {"lo", "hi", "label", "color"} or empty.
var band: Dictionary = {}
## Time shown by the marker. Negative = follow the newest recorded value.
var cursor: float = -1.0
var show_event_labels: bool = true
var scrub_enabled: bool = false

# === PRIVATE VARIABLES ===
var _dragging: bool = false


# === LIFECYCLE METHODS ===
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not scrub_enabled or recorder == null or recorder.size() == 0:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			if mb.pressed:
				scrubbed.emit(time_at_x(mb.position.x))
	elif event is InputEventMouseMotion and _dragging:
		var mm: InputEventMouseMotion = event
		scrubbed.emit(time_at_x(mm.position.x))


func _draw() -> void:
	var plot: Rect2 = plot_rect()
	UI.round_rect(self, Rect2(Vector2.ZERO, size), UI.PANEL_BG, UI.PANEL_EDGE, 2)
	draw_rect(plot, PLOT_BG)
	UI.text(self, Vector2(plot.position.x, 18.0), title, 15, UI.TEXT)
	var x_max: float = x_range()
	# Target band.
	if not band.is_empty():
		var y_hi: float = _y(float(band["hi"]), plot)
		var y_lo: float = _y(float(band["lo"]), plot)
		var bc: Color = band["color"]
		draw_rect(Rect2(plot.position.x, y_hi, plot.size.x, y_lo - y_hi), Color(bc.r, bc.g, bc.b, 0.22))
		UI.text(self, Vector2(plot.end.x - 4.0, y_hi + 13.0), str(band["label"]), 11, bc, 1)
	# Grid and axis numbers.
	for i: int in range(5):
		var v: float = lerpf(y_min, y_max, float(i) / 4.0)
		var y: float = _y(v, plot)
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), GRID, 1.0)
		UI.text(self, Vector2(plot.position.x - 5.0, y + 4.0), str(int(round(v))), 11, AXIS, 1)
	var step: float = _nice_step(x_max)
	var tx: float = 0.0
	while tx <= x_max + 0.001:
		var x: float = _x(tx, plot, x_max)
		draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), GRID, 1.0)
		UI.text(self, Vector2(x, plot.end.y + 13.0), str(int(round(tx))), 11, AXIS, 0)
		tx += step
	draw_rect(plot, AXIS, false, 1.5)
	UI.text(self, Vector2(plot.get_center().x, size.y - 5.0), x_label, 12, UI.TEXT_DIM, 0)
	if y_label != "":
		draw_set_transform(Vector2(13.0, plot.get_center().y), -PI * 0.5, Vector2.ONE)
		UI.text(self, Vector2.ZERO, y_label, 12, UI.TEXT_DIM, 0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Reference lines.
	for ln: Dictionary in lines:
		var ly: float = _y(float(ln["value"]), plot)
		var lc: Color = ln["color"]
		draw_dashed_line(Vector2(plot.position.x, ly), Vector2(plot.end.x, ly), lc, 2.0, 7.0)
		UI.text(self, Vector2(plot.end.x - 4.0, ly - 4.0), str(ln["label"]), 11, lc, 1)
	if recorder == null or recorder.size() == 0:
		return
	var t_now: float = recorder.duration() if cursor < 0.0 else minf(cursor, recorder.duration())
	var i_now: int = recorder.index_at(t_now)
	# Events.
	_draw_events(plot, x_max, t_now)
	# Series: bright up to the cursor, faint after it (replay shows where the run is heading).
	var n: int = recorder.size()
	var stride: int = maxi(1, int(float(n) / maxf(plot.size.x, 1.0)))
	var legend_x: float = plot.position.x + 6.0
	for s: Dictionary in series:
		if not bool(s.get("visible", true)) or not recorder.series.has(s["key"]):
			continue
		var data: PackedFloat32Array = recorder.series[s["key"]]
		var color: Color = s["color"]
		var style: int = int(s.get("style", STYLE_SOLID))
		var before: PackedVector2Array = PackedVector2Array()
		var after: PackedVector2Array = PackedVector2Array()
		var i: int = 0
		while i < n:
			var p: Vector2 = Vector2(_x(recorder.times[i], plot, x_max), _y(data[i], plot))
			if i <= i_now:
				before.append(p)
			else:
				if after.is_empty() and not before.is_empty():
					after.append(before[before.size() - 1])
				after.append(p)
			if i < i_now and i + stride > i_now:
				i = i_now
			else:
				i += stride
		_polyline(after, Color(color.r, color.g, color.b, 0.28), 2.0, style)
		_polyline(before, color, 3.0, style)
		if series.size() > 1:
			var sample: PackedVector2Array = PackedVector2Array([Vector2(legend_x, plot.position.y + 10.0), Vector2(legend_x + 22.0, plot.position.y + 10.0)])
			_polyline(sample, color, 3.0, style)
			UI.text(self, Vector2(legend_x + 26.0, plot.position.y + 14.0), str(s["label"]), 11, color)
			legend_x += 34.0 + UI.text_width(str(s["label"]), 11)
		# Moving marker: the current value.
		var mv: float = data[i_now]
		var mp: Vector2 = Vector2(_x(recorder.times[i_now], plot, x_max), _y(mv, plot))
		draw_circle(mp, 6.0, Color.WHITE)
		draw_circle(mp, 4.0, color)
	if cursor >= 0.0:
		var cx: float = _x(t_now, plot, x_max)
		draw_line(Vector2(cx, plot.position.y), Vector2(cx, plot.end.y), Color(1, 1, 1, 0.75), 1.5)


# === PUBLIC METHODS ===
func plot_rect() -> Rect2:
	var top: float = 26.0 + (36.0 if show_event_labels else 0.0)
	return Rect2(44.0, top, maxf(size.x - 56.0, 10.0), maxf(size.y - top - 34.0, 10.0))


func x_range() -> float:
	var d: float = 0.0 if recorder == null else recorder.duration()
	return maxf(x_span_min, d)


func time_at_x(px: float) -> float:
	var plot: Rect2 = plot_rect()
	var u: float = clampf((px - plot.position.x) / plot.size.x, 0.0, 1.0)
	return minf(u * x_range(), recorder.duration())


func add_series(key: String, label: String, color: Color, style: int = STYLE_SOLID, visible_now: bool = true) -> void:
	series.append({"key": key, "label": label, "color": color, "style": style, "visible": visible_now})


func set_series_visible(key: String, visible_now: bool) -> void:
	for s: Dictionary in series:
		if s["key"] == key:
			s["visible"] = visible_now


# === PRIVATE METHODS ===
func _x(t: float, plot: Rect2, x_max: float) -> float:
	return plot.position.x + plot.size.x * clampf(t / x_max, 0.0, 1.0)


func _y(v: float, plot: Rect2) -> float:
	return plot.end.y - plot.size.y * clampf((v - y_min) / (y_max - y_min), 0.0, 1.0)


func _nice_step(x_max: float) -> float:
	for s: float in [5.0, 10.0, 15.0, 30.0, 60.0, 120.0, 240.0]:
		if x_max / s <= 8.0:
			return s
	return 480.0


func _polyline(pts: PackedVector2Array, color: Color, width: float, style: int) -> void:
	if pts.size() < 2:
		return
	if style == STYLE_SOLID:
		draw_polyline(pts, color, width, true)
		return
	# Dashed / dotted: walk the line by distance so the pattern is even at any sampling rate.
	var on_len: float = 9.0 if style == STYLE_DASHED else 3.0
	var off_len: float = 6.0 if style == STYLE_DASHED else 5.0
	var acc: float = 0.0
	var drawing: bool = true
	var seg_start: Vector2 = pts[0]
	for i: int in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var length: float = a.distance_to(b)
		var pos: float = 0.0
		while pos < length:
			var limit: float = on_len if drawing else off_len
			var take: float = minf(limit - acc, length - pos)
			pos += take
			acc += take
			if acc >= limit - 0.0001:
				var p: Vector2 = a.lerp(b, pos / length)
				if drawing:
					draw_line(seg_start, p, color, width, true)
				seg_start = p
				drawing = not drawing
				acc = 0.0
		if drawing:
			draw_line(seg_start, b, color, width, true)
			seg_start = b


func _draw_events(plot: Rect2, x_max: float, t_now: float) -> void:
	var row_end: Array[float] = [-1000.0, -1000.0, -1000.0]
	for e: Dictionary in recorder.events:
		var et: float = e["t"]
		var x: float = _x(et, plot, x_max)
		var passed: bool = et <= t_now + 0.0001
		var c: Color = Color(1, 1, 1, 0.85 if passed else 0.3)
		draw_dashed_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), Color(1, 1, 1, 0.35 if passed else 0.15), 1.0, 4.0)
		draw_colored_polygon(PackedVector2Array([Vector2(x, plot.position.y + 1.0), Vector2(x - 5.0, plot.position.y - 7.0), Vector2(x + 5.0, plot.position.y - 7.0)]), c)
		if not show_event_labels:
			continue
		var label: String = e["label"]
		var w: float = UI.text_width(label, 11)
		var lx: float = clampf(x - w * 0.5, plot.position.x, plot.end.x - w)
		for row: int in range(3):
			if lx > row_end[row] + 6.0:
				UI.text(self, Vector2(lx, plot.position.y - 10.0 - 12.0 * float(2 - row) + 0.0), label, 11, c)
				row_end[row] = lx + w
				break
