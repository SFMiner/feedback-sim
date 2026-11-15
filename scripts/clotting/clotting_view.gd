class_name ClottingView
extends Control
## Draws one moment of the clotting experiment from a snapshot Dictionary (ClottingModel.snapshot()).
## Live play and replay both go through here, so a replay shows exactly what was recorded.
## Red blood cells and the leak are decoration computed from the snapshot's time, so they also
## replay identically. Artwork in assets/bio/ replaces the procedural shapes when present.

# === CONSTANTS ===
const DESIGN: Vector2 = Vector2(600.0, 352.0)
const LUMEN_TOP: float = 78.0
const WALL: float = 22.0
const RBC_COUNT: int = 16
const C_BLOOD: Color = Color("fbe3df")
const C_WALL: Color = Color("d98a8a")
const C_WALL_EDGE: Color = Color("8f3f47")
const C_TISSUE: Color = Color("f6d6c2")
const C_RBC: Color = Color("d6453d")
const C_PLATELET: Color = Color("fff1b8")
const C_ACTIVE: Color = Color("f08a24")
const C_ATTACHED: Color = Color("8a4fc7")
const C_SIGNAL: Color = Color("14915f")

# === PUBLIC VARIABLES ===
## The moment to draw. Empty = nothing recorded yet.
var frame: Dictionary = {}
var reduced: bool = false


# === LIFECYCLE METHODS ===
func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var s: float = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	draw_set_transform((size - DESIGN * s) * 0.5, 0.0, Vector2(s, s))
	var bottom: float = LUMEN_TOP + ClottingModel.HEIGHT
	draw_rect(Rect2(0.0, 0.0, DESIGN.x, DESIGN.y), C_TISSUE)
	draw_rect(Rect2(0.0, LUMEN_TOP, DESIGN.x, ClottingModel.HEIGHT), C_BLOOD)
	draw_rect(Rect2(0.0, LUMEN_TOP - WALL, DESIGN.x, WALL), C_WALL)
	draw_rect(Rect2(0.0, bottom, DESIGN.x, WALL), C_WALL)
	draw_line(Vector2(0.0, LUMEN_TOP), Vector2(DESIGN.x, LUMEN_TOP), C_WALL_EDGE, 2.0)
	draw_line(Vector2(0.0, bottom), Vector2(DESIGN.x, bottom), C_WALL_EDGE, 2.0)
	UI.text(self, Vector2(8.0, LUMEN_TOP - 6.0), "Blood vessel wall", 12, Color("5a1f28"))
	UI.arrow(self, Vector2(470.0, LUMEN_TOP + 14.0), Vector2(560.0, LUMEN_TOP + 14.0), Color("b0555a"), 3.0)
	UI.text(self, Vector2(464.0, LUMEN_TOP + 19.0), "blood flow", 12, Color("8f3f47"), 1)
	_draw_legend()
	if frame.is_empty():
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var t: float = frame["time"]
	var injured: bool = frame["injured"]
	var left: float = frame["wound_left"]
	var right: float = frame["wound_right"]
	var slots: PackedByteArray = frame["slots"]
	if injured:
		# The wound: a gap in the wall with rough exposed tissue.
		draw_rect(Rect2(left, bottom, right - left, WALL), Color("7a1f2b"))
		var x: float = left
		while x < right:
			draw_line(Vector2(x, bottom + 2.0), Vector2(x + 5.0, bottom + WALL - 3.0), Color("c96a5f"), 2.0)
			x += 9.0
		UI.text(self, Vector2(right + 10.0, bottom + WALL + 17.0), "Wound", 14, Color("7a1f2b"))
		# Blood escapes through every uncovered part of the wound.
		for sl: int in range(slots.size()):
			if slots[sl] > 0:
				continue
			var sx: float = left + (float(sl) + 0.5) * ClottingModel.SLOT_WIDTH
			var drip: float = 8.0 if reduced else fposmod(t * 34.0 + float(sl) * 13.0, 26.0)
			UI.ellipse(self, Vector2(sx, bottom + WALL + drip), 3.5, 5.0, C_RBC)
	_draw_red_cells(t)
	var signals: PackedVector2Array = frame["signals"]
	for q: Vector2 in signals:
		UI.ngon(self, q + Vector2(0.0, LUMEN_TOP), 4.0, 4, C_SIGNAL, 0.0, Color("0b4a31"))
	var pos: PackedVector2Array = frame["pos"]
	var state: PackedByteArray = frame["state"]
	for i: int in range(pos.size()):
		_draw_platelet(pos[i] + Vector2(0.0, LUMEN_TOP), state[i], float(i))
	# Fibrin mesh: appears once the wound has been covered for a moment (clot stabilising).
	var covered_time: float = frame["covered_time"]
	if covered_time >= 0.0 and t - covered_time > 2.5:
		var mesh: Color = Color(1, 1, 1, 0.75)
		var top: float = bottom - 40.0
		var mx: float = left - 8.0
		while mx < right + 4.0:
			draw_line(Vector2(mx, bottom), Vector2(mx + 22.0, top), mesh, 1.5, true)
			draw_line(Vector2(mx + 22.0, bottom), Vector2(mx, top), mesh, 1.5, true)
			mx += 14.0
		UI.text(self, Vector2((left + right) * 0.5, top - 6.0), "fibrin mesh", 12, Color("4a4a66"), 0)
	var hud: String = "Attached platelets: %d    Wound covered: %d%%" % [int(frame["attached"]), int(round(float(frame["coverage"])))]
	UI.round_rect(self, Rect2(8.0, DESIGN.y - 30.0, UI.text_width(hud, 14) + 16.0, 24.0), Color(1, 1, 1, 0.9), C_WALL_EDGE, 2, 6)
	UI.text(self, Vector2(16.0, DESIGN.y - 13.0), hud, 14, UI.INK)
	if not injured:
		UI.text(self, Vector2(DESIGN.x * 0.5, bottom + WALL + 17.0), "Healthy vessel... injury coming", 14, Color("7a1f2b"), 0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# === PRIVATE METHODS ===
func _draw_legend() -> void:
	var y: float = 20.0
	UI.round_rect(self, Rect2(4.0, 4.0, DESIGN.x - 8.0, 32.0), Color(1, 1, 1, 0.85), C_WALL_EDGE, 1, 6)
	_draw_platelet(Vector2(20.0, y), ClottingModel.FREE, 0.0)
	UI.text(self, Vector2(32.0, y + 5.0), "resting platelet", 12, UI.INK)
	_draw_platelet(Vector2(150.0, y), ClottingModel.ACTIVE, 0.0)
	UI.text(self, Vector2(163.0, y + 5.0), "activated (moving)", 12, UI.INK)
	_draw_platelet(Vector2(296.0, y), ClottingModel.ATTACHED, 0.0)
	UI.text(self, Vector2(309.0, y + 5.0), "attached", 12, UI.INK)
	UI.ngon(self, Vector2(384.0, y), 4.0, 4, C_SIGNAL, 0.0, Color("0b4a31"))
	UI.text(self, Vector2(393.0, y + 5.0), "signal (ADP)", 12, UI.INK)
	_draw_red_cell(Vector2(490.0, y), 0.7)
	UI.text(self, Vector2(504.0, y + 5.0), "red blood cell", 12, UI.INK)


func _draw_red_cells(t: float) -> void:
	for i: int in range(RBC_COUNT):
		var lane: float = 16.0 + fposmod(float(i) * 37.0, ClottingModel.HEIGHT - 44.0)
		var u: float = lane / ClottingModel.HEIGHT
		var speed: float = 40.0 + 320.0 * u * (1.0 - u)
		var travel: float = 0.0 if reduced else t * speed
		var x: float = fposmod(float(i) * 91.0 + travel, DESIGN.x + 60.0) - 30.0
		_draw_red_cell(Vector2(x, LUMEN_TOP + lane), 1.0)


func _draw_red_cell(c: Vector2, k: float) -> void:
	if Art.draw(self, "red_blood_cell", Rect2(c.x - 13.0 * k, c.y - 9.0 * k, 26.0 * k, 18.0 * k)):
		return
	UI.ellipse(self, c, 13.0 * k, 9.0 * k, C_RBC, Color("8f2420"), 1.5)
	UI.ellipse(self, c, 6.0 * k, 3.5 * k, Color("b8322c"))


func _draw_platelet(c: Vector2, kind: int, spin: float) -> void:
	if kind == ClottingModel.FREE:
		if Art.draw(self, "platelet", Rect2(c.x - 7.0, c.y - 5.0, 14.0, 10.0)):
			return
		UI.ellipse(self, c, 7.0, 4.5, C_PLATELET, Color("8a6a1f"), 1.5)
		return
	var tint: Color = C_ACTIVE if kind == ClottingModel.ACTIVE else C_ATTACHED
	if Art.draw(self, "platelet_active", Rect2(c.x - 9.0, c.y - 9.0, 18.0, 18.0), Color.WHITE if kind == ClottingModel.ACTIVE else Color(0.8, 0.7, 1.0, 1)):
		return
	# Activated platelets change shape: spiky, with arms that help them stick together.
	var pts: PackedVector2Array = PackedVector2Array()
	for k: int in range(14):
		var a: float = spin + TAU * float(k) / 14.0
		var r: float = 8.5 if k % 2 == 0 else 4.5
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, tint)
	pts.append(pts[0])
	draw_polyline(pts, tint.darkened(0.5), 1.5, true)
