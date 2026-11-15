class_name GlucoseView
extends Control
## Draws one moment of the glucose experiment from a snapshot Dictionary (GlucoseModel.snapshot()).
## Every particle position is computed from the snapshot's time and flow rates, never stored, so
## live play and replay look identical for the same recorded moment. The number of particles on a
## path shows the size of that flow. Shapes carry the meaning (hexagon = glucose, square = insulin,
## triangle = glucagon); colour only reinforces it. Artwork in assets/bio/ replaces the
## procedural organs and particles when present.

# === CONSTANTS ===
const DESIGN: Vector2 = Vector2(560.0, 352.0)
const VESSEL: Rect2 = Rect2(76.0, 150.0, 476.0, 62.0)
const PANCREAS: Rect2 = Rect2(92.0, 34.0, 168.0, 72.0)
const LIVER: Rect2 = Rect2(362.0, 24.0, 186.0, 92.0)
const MUSCLE: Rect2 = Rect2(338.0, 258.0, 210.0, 62.0)
const FOOD: Rect2 = Rect2(92.0, 258.0, 150.0, 62.0)
const METER: Rect2 = Rect2(22.0, 46.0, 26.0, 262.0)
const C_GLUCOSE: Color = Color("f2b318")
const C_INSULIN: Color = Color("2f6fd0")
const C_GLUCAGON: Color = Color("c2410c")
const C_BLOOD: Color = Color("f6c9c4")
const C_BLOOD_EDGE: Color = Color("a8434b")

# === PUBLIC VARIABLES ===
var frame: Dictionary = {}
var reduced: bool = false


# === LIFECYCLE METHODS ===
func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var s: float = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	draw_set_transform((size - DESIGN * s) * 0.5, 0.0, Vector2(s, s))
	draw_rect(Rect2(Vector2.ZERO, DESIGN), Color("fdf3ea"))
	if frame.is_empty():
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var t: float = frame["time"]
	var glucose: float = frame["glucose"]
	var insulin: float = frame["insulin"]
	var glucagon: float = frame["glucagon"]
	var phase: float = 0.35 if reduced else fposmod(t * 0.11, 1.0)
	_draw_organs(frame)
	# Bloodstream.
	UI.round_rect(self, VESSEL, C_BLOOD, C_BLOOD_EDGE, 3, 20)
	UI.text(self, Vector2(VESSEL.position.x + 14.0, VESSEL.position.y + 16.0), "Bloodstream", 13, Color("7a2a33"))
	var drift: float = 0.0 if reduced else t * 13.0
	_blood_particles(int(round(glucose * 0.42)), 0, drift)
	_blood_particles(int(round(insulin * 12.0)), 1, drift)
	_blood_particles(int(round(glucagon * 12.0)), 2, drift)
	# Flows between the blood and each organ.
	_flow(Vector2(FOOD.get_center().x, FOOD.position.y), Vector2(FOOD.get_center().x, VESSEL.end.y - 8.0), float(frame["diet"]), 0, phase)
	_flow(Vector2(MUSCLE.get_center().x, VESSEL.end.y - 8.0), Vector2(MUSCLE.get_center().x, MUSCLE.position.y + 14.0), float(frame["use"]), 0, phase)
	_flow(Vector2(LIVER.position.x + 50.0, VESSEL.position.y + 8.0), Vector2(LIVER.position.x + 50.0, LIVER.end.y - 14.0), float(frame["liver_store"]), 0, phase)
	_flow(Vector2(LIVER.end.x - 40.0, LIVER.end.y - 14.0), Vector2(LIVER.end.x - 40.0, VESSEL.position.y + 8.0), float(frame["liver_out"]), 0, phase)
	_flow(Vector2(PANCREAS.position.x + 46.0, PANCREAS.end.y - 6.0), Vector2(PANCREAS.position.x + 46.0, VESSEL.position.y + 10.0), insulin * 0.6, 1, phase)
	_flow(Vector2(PANCREAS.end.x - 46.0, PANCREAS.end.y - 6.0), Vector2(PANCREAS.end.x - 46.0, VESSEL.position.y + 10.0), glucagon * 0.6, 2, phase)
	_draw_meter(glucose)
	_draw_legend()
	var hours: int = int(t) / 60
	var minutes: int = int(t) % 60
	var clock: String = "Time: %d h %02d min" % [hours, minutes]
	if bool(frame["fasting"]):
		clock += "   FASTING"
	if bool(frame["exercising"]):
		clock += "   EXERCISING"
	UI.text(self, Vector2(DESIGN.x - 8.0, 16.0), clock, 13, UI.INK, 1)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# === PRIVATE METHODS ===
func _draw_organs(f: Dictionary) -> void:
	var insulin: float = f["insulin"]
	var glucagon: float = f["glucagon"]
	# Pancreas with one gauge per hormone.
	if not Art.draw(self, "pancreas", PANCREAS):
		UI.round_rect(self, PANCREAS, Color("f3c98b"), Color("9a6a2a"), 3, 26)
	UI.text(self, Vector2(PANCREAS.get_center().x, PANCREAS.position.y - 5.0), "Pancreas", 14, UI.INK, 0)
	_gauge(Rect2(PANCREAS.position.x + 12.0, PANCREAS.position.y + 30.0, 66.0, 12.0), insulin, C_INSULIN, "Insulin", 1)
	_gauge(Rect2(PANCREAS.end.x - 78.0, PANCREAS.position.y + 30.0, 66.0, 12.0), glucagon, C_GLUCAGON, "Glucagon", 2)
	# Liver with its glycogen store.
	if not Art.draw(self, "liver", LIVER):
		var pts: PackedVector2Array = PackedVector2Array([
			LIVER.position + Vector2(8.0, 30.0), LIVER.position + Vector2(40.0, 4.0), LIVER.position + Vector2(130.0, 0.0),
			LIVER.position + Vector2(180.0, 22.0), LIVER.position + Vector2(184.0, 56.0), LIVER.position + Vector2(140.0, 86.0),
			LIVER.position + Vector2(50.0, 90.0), LIVER.position + Vector2(10.0, 66.0),
		])
		draw_colored_polygon(pts, Color("b5533c"))
		pts.append(pts[0])
		draw_polyline(pts, Color("6b2a1c"), 3.0, true)
	UI.text(self, Vector2(LIVER.position.x + 16.0, LIVER.position.y - 5.0), "Liver", 14, UI.INK)
	var glycogen: float = f["glycogen"]
	var store: Rect2 = Rect2(LIVER.position.x + 28.0, LIVER.position.y + 30.0, 130.0, 16.0)
	draw_rect(store, Color(0.2, 0.08, 0.05, 1))
	var blocks: int = int(round(glycogen / 10.0))
	for b: int in range(10):
		var cell: Rect2 = Rect2(store.position.x + 2.0 + 12.8 * float(b), store.position.y + 2.0, 10.8, 12.0)
		if b < blocks:
			draw_rect(cell, C_GLUCOSE)
		else:
			draw_rect(cell, Color(1, 1, 1, 0.25), false, 1.0)
	UI.text(self, Vector2(store.get_center().x, store.position.y - 4.0), "Glycogen store: %d%%" % int(round(glycogen)), 12, Color.WHITE, 0)
	var net: float = float(f["liver_out"]) - float(f["liver_store"])
	var status: String = "balanced"
	if net > 0.06:
		status = "releasing glucose" if glycogen > 1.0 else "store empty!"
	elif net < -0.06:
		status = "storing glucose"
	UI.text(self, Vector2(store.get_center().x, store.end.y + 16.0), status, 13, Color.WHITE, 0)
	# Body cells.
	if not Art.draw(self, "muscle", MUSCLE):
		UI.round_rect(self, MUSCLE, Color("d9707f"), Color("7e2a3a"), 3, 22)
		for k: int in range(4):
			var y: float = MUSCLE.position.y + 14.0 + 11.0 * float(k)
			draw_line(Vector2(MUSCLE.position.x + 18.0, y), Vector2(MUSCLE.end.x - 18.0, y), Color(1, 1, 1, 0.25), 2.0)
	var busy: String = "Body cells (muscle): working hard!" if bool(f["exercising"]) else "Body cells (muscle) use glucose"
	UI.text(self, Vector2(MUSCLE.get_center().x, MUSCLE.end.y + 16.0), busy, 13, UI.INK, 0)
	# Food.
	UI.round_rect(self, FOOD, Color("cfe8b9"), Color("4d7a2c"), 3, 16)
	var food_text: String = "No food (fasting)" if bool(f["fasting"]) else "Food (digesting)"
	UI.text(self, Vector2(FOOD.get_center().x, FOOD.end.y + 16.0), food_text, 13, UI.INK, 0)
	if bool(f["fasting"]):
		draw_line(FOOD.position + Vector2(20.0, 12.0), FOOD.end - Vector2(20.0, 12.0), Color("7a1f2b"), 5.0, true)
		draw_line(Vector2(FOOD.end.x - 20.0, FOOD.position.y + 12.0), Vector2(FOOD.position.x + 20.0, FOOD.end.y - 12.0), Color("7a1f2b"), 5.0, true)
	else:
		UI.ellipse(self, FOOD.get_center() + Vector2(-26.0, 4.0), 20.0, 15.0, Color("e2574c"), Color("7a1f2b"))
		UI.ellipse(self, FOOD.get_center() + Vector2(24.0, 6.0), 26.0, 13.0, Color("e7b56a"), Color("7a4a1c"))


func _gauge(r: Rect2, level: float, color: Color, label: String, kind: int) -> void:
	draw_rect(r, Color.WHITE)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(level, 0.0, 1.0), r.size.y)), color)
	draw_rect(r, UI.INK, false, 1.5)
	_particle(Vector2(r.position.x + 6.0, r.position.y - 9.0), kind, 1.0)
	UI.text(self, Vector2(r.position.x + 15.0, r.position.y - 4.0), label, 12, UI.INK)


func _draw_meter(glucose: float) -> void:
	UI.text(self, Vector2(METER.get_center().x + 6.0, METER.position.y - 22.0), "Blood", 13, UI.INK, 0)
	UI.text(self, Vector2(METER.get_center().x + 6.0, METER.position.y - 8.0), "glucose", 13, UI.INK, 0)
	draw_rect(METER, Color.WHITE)
	var y_low: float = METER.end.y - METER.size.y * GlucoseModel.TARGET_LOW / 100.0
	var y_high: float = METER.end.y - METER.size.y * GlucoseModel.TARGET_HIGH / 100.0
	draw_rect(Rect2(METER.position.x, y_high, METER.size.x, y_low - y_high), Color(0.45, 0.86, 0.55, 0.55))
	var y: float = METER.end.y - METER.size.y * clampf(glucose / 100.0, 0.0, 1.0)
	var in_range: bool = glucose >= GlucoseModel.TARGET_LOW and glucose <= GlucoseModel.TARGET_HIGH
	draw_rect(Rect2(METER.position.x + 7.0, y, METER.size.x - 14.0, METER.end.y - y), C_GLUCOSE.darkened(0.1))
	draw_rect(METER, UI.INK, false, 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(METER.end.x + 2.0, y), Vector2(METER.end.x + 13.0, y - 7.0), Vector2(METER.end.x + 13.0, y + 7.0)]), UI.INK)
	UI.text(self, Vector2(METER.end.x + 16.0, y + 5.0), str(int(round(glucose))), 15, UI.INK)
	var word: String = "OK" if in_range else ("HIGH" if glucose > GlucoseModel.TARGET_HIGH else "LOW")
	UI.text(self, Vector2(METER.get_center().x + 6.0, METER.end.y + 16.0), word, 14, Color("1c6b34") if in_range else Color("a12a2a"), 0)
	UI.text(self, Vector2(METER.position.x - 3.0, (y_low + y_high) * 0.5 + 4.0), "T", 11, Color("1c6b34"), 1)


func _draw_legend() -> void:
	var y: float = DESIGN.y - 9.0
	_particle(Vector2(150.0, y - 4.0), 0, 1.0)
	UI.text(self, Vector2(160.0, y), "glucose", 12, UI.INK)
	_particle(Vector2(232.0, y - 4.0), 1, 1.0)
	UI.text(self, Vector2(242.0, y), "insulin", 12, UI.INK)
	_particle(Vector2(306.0, y - 4.0), 2, 1.0)
	UI.text(self, Vector2(316.0, y), "glucagon", 12, UI.INK)
	UI.text(self, Vector2(390.0, y), "T = target range", 12, Color("1c6b34"))


## kind: 0 glucose (hexagon), 1 insulin (square), 2 glucagon (triangle).
func _particle(c: Vector2, kind: int, k: float) -> void:
	if kind == 0:
		if not Art.draw(self, "glucose", Rect2(c.x - 8.0 * k, c.y - 8.0 * k, 16.0 * k, 16.0 * k)):
			UI.ngon(self, c, 6.0 * k, 6, C_GLUCOSE, 0.0, Color("7a5200"))
	elif kind == 1:
		if not Art.draw(self, "insulin", Rect2(c.x - 8.0 * k, c.y - 8.0 * k, 16.0 * k, 16.0 * k)):
			UI.ngon(self, c, 6.5 * k, 4, C_INSULIN, PI * 0.25, Color("0f2f66"))
	else:
		if not Art.draw(self, "glucagon", Rect2(c.x - 8.0 * k, c.y - 8.0 * k, 16.0 * k, 16.0 * k)):
			UI.ngon(self, c, 7.0 * k, 3, C_GLUCAGON, -PI * 0.5, Color("5a1a05"))


## Particles spread through the bloodstream; how many shows the concentration.
func _blood_particles(count: int, kind: int, drift: float) -> void:
	var inner: Rect2 = VESSEL.grow(-12.0)
	for i: int in range(count):
		var seed_x: float = fposmod(float(i) * 97.3 + float(kind) * 41.0, inner.size.x)
		var x: float = inner.position.x + fposmod(seed_x + drift * (0.8 + 0.05 * float(i % 5)), inner.size.x)
		var y: float = inner.position.y + 10.0 + fposmod(float(i) * 23.7 + float(kind) * 11.0, inner.size.y - 12.0)
		_particle(Vector2(x, y), kind, 0.85)


## Particles marching from `from` to `to`; the count grows with the flow rate.
func _flow(from: Vector2, to: Vector2, rate: float, kind: int, phase: float) -> void:
	var n: int = clampi(int(round(rate * 6.0)), 0, 7)
	if rate > 0.03 and n == 0:
		n = 1
	if n == 0:
		return
	UI.arrow(self, from, to, Color(0.1, 0.12, 0.18, 0.35), 2.0)
	for i: int in range(n):
		var u: float = fposmod(phase + float(i) / float(n), 1.0)
		_particle(from.lerp(to, u), kind, 1.0)
