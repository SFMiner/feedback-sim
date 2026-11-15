class_name ClassroomView
extends Control
## Draws the classroom from a ClassroomModel: procedural stick-figure students at desks, the
## teacher, the visiting second teacher, speech marks and the WHOMP! caption. Pure presentation:
## it reads the model and never changes it. Student looks come from their own seeded generator,
## independent of the behaviour generator, so appearance never predicts who talks.

# === CONSTANTS ===
const DESIGN: Vector2 = Vector2(700.0, 400.0)
const SKIN_TONES: Array[Color] = [
	Color("3b2219"), Color("4f2f22"), Color("6a4230"), Color("7d5238"), Color("8d5b3e"), Color("a36c48"),
	Color("b98155"), Color("c68f65"), Color("d4a276"), Color("e0b48c"), Color("ecc6a2"), Color("f4d7bd"),
]
const HAIR_COLORS: Array[Color] = [
	Color("15110f"), Color("15110f"), Color("2a1b12"), Color("3d2616"), Color("5a3a1e"), Color("7a4a22"),
	Color("a8642a"), Color("d8b25a"), Color("a33a1f"), Color("2f4fa8"),
]
const SHIRTS: Array[Color] = [
	Color("e4572e"), Color("17bebb"), Color("ffc914"), Color("76b041"), Color("4d7ea8"), Color("b565a7"),
	Color("f28f3b"), Color("2e86ab"), Color("d1495b"), Color("66a182"), Color("8f6bc8"), Color("e8e8e8"),
]
const HAIR_STYLES: int = 8
const TEACHER_X: float = 58.0
const FLOOR_Y: float = 152.0
const DOOR_X: float = 640.0
const STUDENT_SHIRT: Color = Color("1f2f5c")
## At most this many students wear a head covering; any others the seed produces get one of the
## replacement hair styles instead.
const MAX_HEAD_COVERINGS: int = 1
const KEEP_COVERING_FROM: int = 1
const REPLACEMENT_STYLES: Array[int] = [6, 0, 3, 4]
const TEACHER2_HAIR: Color = Color("3fd6b4")
const VOICE_COLORS: Array[Color] = [Color("ffd166"), Color("ef8354"), Color("06d6a0"), Color("9bd1ff")]

# === PUBLIC VARIABLES ===
var model: ClassroomModel = null
var reduced: bool = false
## Animation clock, advanced by the module only while playing (so Pause freezes the picture).
var anim_t: float = 0.0
## Seconds of speech mark left for each student, and the word to show.
var talk_left: PackedFloat32Array = PackedFloat32Array()
var talk_word: PackedStringArray = PackedStringArray()
## Seconds since the last WHOMP (large = none showing).
var whomp_age: float = 99.0

# === PRIVATE VARIABLES ===
var _looks: Array[Dictionary] = []
var _teacher_look: Dictionary = {}
var _teacher2_look: Dictionary = {}


# === LIFECYCLE METHODS ===
func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	if model == null:
		return
	var s: float = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	var origin: Vector2 = (size - DESIGN * s) * 0.5
	draw_set_transform(origin, 0.0, Vector2(s, s))
	_draw_room()
	_draw_teachers()
	for i: int in range(ClassroomModel.COUNT):
		_draw_student(i)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# === PUBLIC METHODS ===
## Builds the cast. The same seed always gives the same faces (so a replay shows the same class).
func generate_looks(rng_seed: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed * 7919 + 13
	_looks.clear()
	for i: int in range(ClassroomModel.COUNT):
		_looks.append(_random_look(rng))
	# Uniform shirts. A head covering keeps the colour the seed gave that student.
	var coverings: int = 0
	var replaced: int = 0
	for look: Dictionary in _looks:
		look["scarf"] = look["shirt"]
		look["shirt"] = STUDENT_SHIRT
		if int(look["style"]) == 7:
			coverings += 1
			if coverings <= KEEP_COVERING_FROM or coverings > KEEP_COVERING_FROM + MAX_HEAD_COVERINGS:
				look["style"] = REPLACEMENT_STYLES[replaced % REPLACEMENT_STYLES.size()]
				replaced += 1
	# The two teachers are fixed characters (owner's brief); the first teacher's shirt and skin tone come from the seed.
	_teacher_look = _random_look(rng)
	_teacher2_look = _random_look(rng)
	_teacher_look.merge({"hair": Color("15110f"), "style": 0, "w": 0.58, "h": 1.06, "glasses": true}, true)
	_teacher2_look.merge({"skin": Color("f4d7bd"), "hair": TEACHER2_HAIR, "style": 0, "w": 1.16, "h": 0.93,
		"shirt": Color("8b9199"),
		"glasses": true, "beard": true}, true)
	talk_left.resize(ClassroomModel.COUNT)
	talk_left.fill(0.0)
	talk_word.resize(ClassroomModel.COUNT)


func desk_position(i: int) -> Vector2:
	var col: int = i % ClassroomModel.COLS
	var row: int = i / ClassroomModel.COLS
	return Vector2(110.0 + 122.0 * float(col) + (14.0 if row == 1 else 0.0), 214.0 + 78.0 * float(row))


func looks() -> Array[Dictionary]:
	return _looks


# === PRIVATE METHODS ===
func _random_look(rng: RandomNumberGenerator) -> Dictionary:
	return {
		"skin": SKIN_TONES[rng.randi_range(0, SKIN_TONES.size() - 1)],
		"hair": HAIR_COLORS[rng.randi_range(0, HAIR_COLORS.size() - 1)],
		"style": rng.randi_range(0, HAIR_STYLES - 1),
		"shirt": SHIRTS[rng.randi_range(0, SHIRTS.size() - 1)],
		"w": rng.randf_range(0.85, 1.25),
		"h": rng.randf_range(0.85, 1.15),
		"phase": rng.randf_range(0.0, TAU),
		"tempo": rng.randf_range(0.8, 1.25),
	}


func _draw_room() -> void:
	draw_rect(Rect2(0.0, 0.0, DESIGN.x, FLOOR_Y), Color("cfe3ee"))
	draw_rect(Rect2(0.0, FLOOR_Y, DESIGN.x, DESIGN.y - FLOOR_Y), Color("e9d8b4"))
	draw_line(Vector2(0.0, FLOOR_Y), Vector2(DESIGN.x, FLOOR_Y), Color("8d7a55"), 3.0)
	# Board.
	UI.round_rect(self, Rect2(235.0, 22.0, 280.0, 86.0), Color("2f5d50"), Color("7a5a36"), 5, 4)
	UI.text(self, Vector2(375.0, 60.0), "Science", 20, Color(1, 1, 1, 0.85), 0)
	draw_line(Vector2(300.0, 78.0), Vector2(450.0, 78.0), Color(1, 1, 1, 0.5), 2.0)
	# Door.
	UI.round_rect(self, Rect2(DOOR_X - 32.0, 30.0, 64.0, FLOOR_Y - 30.0), Color("9c6b3f"), Color("5f3d1f"), 4, 3)
	draw_circle(Vector2(DOOR_X - 20.0, 96.0), 4.0, Color("f2d16b"))
	# Clock.
	draw_circle(Vector2(575.0, 40.0), 15.0, Color.WHITE)
	draw_arc(Vector2(575.0, 40.0), 15.0, 0.0, TAU, 24, UI.INK, 2.0)
	draw_line(Vector2(575.0, 40.0), Vector2(575.0, 30.0), UI.INK, 2.0)
	draw_line(Vector2(575.0, 40.0), Vector2(582.0, 43.0), UI.INK, 2.0)


func _draw_teachers() -> void:
	var motion: float = 0.0 if reduced else 1.0
	var facing: int = 1
	var mouth: float = 0.0
	if whomp_age < 0.45:
		mouth = 1.0
	elif model.teacher_distracted:
		mouth = 0.5 * absf(sin(anim_t * 5.0))
	_draw_adult(Vector2(TEACHER_X, FLOOR_Y + 22.0), _teacher_look, model.teacher_arms, facing, mouth, 0.0)
	if model.teacher2_present:
		var x: float = lerpf(DOOR_X, TEACHER_X + 78.0, model.teacher2_progress)
		var walking: bool = model.teacher2_progress < 1.0
		var swing: float = sin(anim_t * 9.0) * 7.0 * motion if walking else 0.0
		var mouth2: float = 0.5 * absf(sin(anim_t * 4.3 + 1.0)) if model.teacher_distracted else 0.0
		_draw_adult(Vector2(x, FLOOR_Y + 22.0), _teacher2_look, 0.0, -1, mouth2, swing)
		if model.teacher_distracted:
			var bubble: Vector2 = Vector2(TEACHER_X + 39.0, 42.0)
			UI.round_rect(self, Rect2(bubble.x - 34.0, bubble.y - 15.0, 68.0, 26.0), Color.WHITE, UI.INK, 2, 10)
			UI.text(self, Vector2(bubble.x, bubble.y + 4.0), "psst...", 14, UI.INK, 0)
	# Teacher's ear: a marker that shows whether the corrective response is switched on.
	var tag: String = "Teacher is listening" if model.teacher_active else "Teacher is distracted!"
	var tag_color: Color = Color("1f5f8b") if model.teacher_active else Color("a12a2a")
	var tw: float = UI.text_width(tag, 13) + 14.0
	UI.round_rect(self, Rect2(6.0, 4.0, tw, 22.0), Color(1, 1, 1, 0.92), tag_color, 2, 6)
	UI.text(self, Vector2(13.0, 20.0), tag, 13, tag_color)
	if whomp_age < 0.6:
		var k: float = whomp_age / 0.6
		var pos: Vector2 = Vector2(TEACHER_X + 100.0, 128.0)
		if not reduced:
			draw_arc(Vector2(TEACHER_X, 80.0), 40.0 + 160.0 * k, -0.9, 0.9, 20, Color(0.2, 0.3, 0.7, 1.0 - k), 5.0)
		var fsize: int = 34 if reduced else int(26.0 + 14.0 * (1.0 - k))
		UI.text(self, pos + Vector2(2.0, 2.0), "WHOMP!", fsize, Color(1, 1, 1, 0.9), 0)
		UI.text(self, pos, "WHOMP!", fsize, Color("1c2f7a"), 0)


## A standing adult. `arms` 0 = down, 1 = raised. `facing` 1 = looks right, -1 = looks left.
func _draw_adult(feet: Vector2, look: Dictionary, arms: float, facing: int, mouth: float, swing: float) -> void:
	var skin: Color = look["skin"]
	var shirt: Color = look["shirt"]
	var w: float = look["w"]
	var h: float = look["h"]
	var hip: Vector2 = feet + Vector2(0.0, -44.0 * h)
	var torso: Vector2 = hip + Vector2(0.0, -24.0 * h)
	var head: Vector2 = torso + Vector2(0.0, -27.0 * h - 15.0)
	draw_line(hip + Vector2(-6.0, 0.0), feet + Vector2(-9.0 + swing, 0.0), UI.INK, 5.0, true)
	draw_line(hip + Vector2(6.0, 0.0), feet + Vector2(9.0 - swing, 0.0), UI.INK, 5.0, true)
	for side: int in [-1, 1]:
		var shoulder: Vector2 = torso + Vector2(float(side) * 15.0 * w, -16.0 * h)
		var ang: float = lerpf(1.25, -1.15, arms)
		var hand: Vector2 = shoulder + Vector2(float(side) * cos(ang), sin(ang)) * 36.0
		draw_line(shoulder, hand, skin.darkened(0.15), 5.0, true)
		draw_circle(hand, 4.5, skin)
	UI.ellipse(self, torso, 18.0 * w, 28.0 * h, shirt, UI.INK, 2.0)
	_draw_head(head, 15.0, look, float(facing) * 3.0, mouth, 1.0 if arms > 0.5 else 0.0)


func _draw_student(i: int) -> void:
	var look: Dictionary = _looks[i]
	var a: float = model.student_activity[i]
	var desk: Vector2 = desk_position(i)
	var motion: float = 0.0 if reduced else 1.0
	var w: float = look["w"]
	var h: float = look["h"]
	var skin: Color = look["skin"]
	var phase: float = look["phase"]
	var tempo: float = look["tempo"]
	var startled: bool = model.teacher_intervening
	var t: float = anim_t * tempo
	# Head movement grows with activity; each student has their own phase and tempo.
	var bob_speed: float = 2.5 + 9.0 * a
	var bob: Vector2 = Vector2(sin(t * bob_speed * 0.6 + phase) * 5.0 * a, sin(t * bob_speed + phase * 1.7) * 4.5 * a) * motion
	if startled:
		bob = Vector2.ZERO
	var torso: Vector2 = desk + Vector2(0.0, -20.0 * h)
	var head: Vector2 = torso + Vector2(0.0, -20.0 * h - 13.0) + bob
	# Chair back and legs under the desk.
	draw_line(desk + Vector2(-7.0, 10.0), desk + Vector2(-9.0, 34.0), UI.INK, 4.0, true)
	draw_line(desk + Vector2(7.0, 10.0), desk + Vector2(9.0, 34.0), UI.INK, 4.0, true)
	UI.ellipse(self, torso, 15.0 * w, 21.0 * h, look["shirt"], UI.INK, 2.0)
	# Arms: on the desk when quiet, gesturing when talking, waving overhead when excited.
	var lift: float = clampf((a - 0.3) / 0.7, 0.0, 1.0)
	for side: int in [-1, 1]:
		var shoulder: Vector2 = torso + Vector2(float(side) * 13.0 * w, -10.0 * h)
		var rest: Vector2 = desk + Vector2(float(side) * 22.0, -3.0)
		var wave: float = sin(t * (4.0 + 7.0 * a) + phase + float(side)) * motion
		var up: Vector2 = shoulder + Vector2(float(side) * (20.0 + 6.0 * wave), -8.0 - 30.0 * lift - 8.0 * wave * lift)
		var hand: Vector2 = rest.lerp(up, lift)
		if startled:
			hand = rest
		draw_line(shoulder, hand, skin.darkened(0.15), 4.0, true)
		draw_circle(hand, 3.5, skin)
	# Desk in front of the body.
	UI.round_rect(self, Rect2(desk.x - 44.0, desk.y, 88.0, 11.0), Color("c9965a"), Color("7a5a36"), 2, 3)
	draw_line(desk + Vector2(-38.0, 11.0), desk + Vector2(-38.0, 34.0), Color("7a5a36"), 3.0)
	draw_line(desk + Vector2(38.0, 11.0), desk + Vector2(38.0, 34.0), Color("7a5a36"), 3.0)
	var mouth: float = 0.0
	if a >= 0.2 and not startled:
		mouth = (0.35 + 0.65 * a) * absf(sin(t * (6.0 + 6.0 * a) + phase))
		if reduced:
			mouth = 0.4 + 0.5 * a
	_draw_head(head, 13.0, look, 0.0, mouth, 1.0 if startled else 0.0)
	# Loudness bars above the head: a motion-free, colour-free cue for how active this student is.
	var bars: int = 0 if a < 0.2 else (1 if a < 0.5 else (2 if a < 0.8 else 3))
	for b: int in range(bars):
		var bh: float = 5.0 + 4.0 * float(b)
		draw_rect(Rect2(head.x + 17.0 + 5.0 * float(b), head.y - 12.0 - bh, 3.5, bh), UI.INK)
	if talk_left[i] > 0.0:
		var vc: Color = VOICE_COLORS[model.student_voice_id[i]]
		var word: String = talk_word[i]
		var tw: float = UI.text_width(word, 12) + 10.0
		var bp: Vector2 = head + Vector2(-tw - 12.0, -24.0)
		UI.round_rect(self, Rect2(bp.x, bp.y, tw, 17.0), Color(1, 1, 1, 0.95), vc.darkened(0.45), 2, 7)
		UI.text(self, Vector2(bp.x + 5.0, bp.y + 13.0), word, 12, UI.INK)


func _draw_head(c: Vector2, r: float, look: Dictionary, eye_shift: float, mouth: float, surprise: float) -> void:
	var skin: Color = look["skin"]
	var hair: Color = look["hair"]
	var style: int = look["style"]
	var cloth: Color = look.get("scarf", look["shirt"])
	# Hair that sits behind the head.
	match style:
		1:
			draw_circle(c + Vector2(0.0, -3.0), r * 1.45, hair)
		2:
			# Long hair: two locks falling past the shoulders, open under the chin.
			UI.round_rect(self, Rect2(c.x - r * 1.2, c.y - r * 0.9, r * 0.75, r * 2.5), hair, Color(0, 0, 0, 0), 0, 5)
			UI.round_rect(self, Rect2(c.x + r * 0.45, c.y - r * 0.9, r * 0.75, r * 2.5), hair, Color(0, 0, 0, 0), 0, 5)
		3:
			UI.ellipse(self, c + Vector2(r * 1.2, r * 0.2), r * 0.45, r * 0.9, hair)
		5:
			draw_circle(c + Vector2(-r * 0.85, -r * 0.9), r * 0.55, hair)
			draw_circle(c + Vector2(r * 0.85, -r * 0.9), r * 0.55, hair)
		6:
			for k: int in range(7):
				var lx: float = c.x - r + float(k) * r / 3.0
				draw_line(Vector2(lx, c.y - r * 0.5), Vector2(lx, c.y + r * 1.25), hair, 3.0, true)
		7:
			UI.ellipse(self, c + Vector2(0.0, 2.0), r * 1.3, r * 1.45, cloth.darkened(0.25))
	draw_circle(c, r, skin)
	draw_arc(c, r, 0.0, TAU, 24, UI.INK, 1.5, true)
	# Hair on top of the head.
	if style == 4:
		for k: int in range(6):
			var ang: float = PI + PI * (float(k) + 0.5) / 6.0
			draw_circle(c + Vector2(cos(ang), sin(ang)) * r * 0.95, r * 0.36, hair)
	elif style == 7:
		var cover: PackedVector2Array = PackedVector2Array()
		for k: int in range(13):
			var ang2: float = PI + PI * float(k) / 12.0
			cover.append(c + Vector2(cos(ang2) * r * 1.05, sin(ang2) * r * 1.08 - 1.0))
		cover.append(c + Vector2(r * 0.8, -r * 0.35))
		cover.append(c + Vector2(-r * 0.8, -r * 0.35))
		draw_colored_polygon(cover, cloth.darkened(0.25))
	else:
		var cap: PackedVector2Array = PackedVector2Array()
		for k: int in range(13):
			var ang3: float = PI + PI * float(k) / 12.0
			cap.append(c + Vector2(cos(ang3) * r * 1.04, sin(ang3) * r * 1.06 - 1.0))
		cap.append(c + Vector2(r * 0.75, -r * 0.5))
		cap.append(c + Vector2(-r * 0.75, -r * 0.5))
		draw_colored_polygon(cap, hair)
	if bool(look.get("beard", false)):
		# Full beard: covers the jaw from ear to ear; the mouth is drawn on top of it.
		var beard: PackedVector2Array = PackedVector2Array()
		for k: int in range(13):
			var ang4: float = -0.12 + (PI + 0.24) * float(k) / 12.0
			beard.append(c + Vector2(cos(ang4) * r * 1.1, sin(ang4) * r * 1.22))
		beard.append(c + Vector2(-r * 0.62, r * 0.22))
		beard.append(c + Vector2(r * 0.62, r * 0.22))
		draw_colored_polygon(beard, hair)
	# Face.
	var eye_r: float = 1.8 + 1.2 * surprise
	draw_circle(c + Vector2(-r * 0.38 + eye_shift, -r * 0.05), eye_r, UI.INK)
	draw_circle(c + Vector2(r * 0.38 + eye_shift, -r * 0.05), eye_r, UI.INK)
	if bool(look.get("glasses", false)):
		var left_lens: Vector2 = c + Vector2(-r * 0.38 + eye_shift, -r * 0.05)
		var right_lens: Vector2 = c + Vector2(r * 0.38 + eye_shift, -r * 0.05)
		draw_circle(left_lens, r * 0.3, Color(1, 1, 1, 0.3))
		draw_circle(right_lens, r * 0.3, Color(1, 1, 1, 0.3))
		draw_arc(left_lens, r * 0.3, 0.0, TAU, 16, UI.INK, 1.6, true)
		draw_arc(right_lens, r * 0.3, 0.0, TAU, 16, UI.INK, 1.6, true)
		draw_line(left_lens + Vector2(r * 0.3, 0.0), right_lens - Vector2(r * 0.3, 0.0), UI.INK, 1.6, true)
		draw_line(left_lens - Vector2(r * 0.3, 0.0), c + Vector2(-r, -r * 0.15), UI.INK, 1.6, true)
		draw_line(right_lens + Vector2(r * 0.3, 0.0), c + Vector2(r, -r * 0.15), UI.INK, 1.6, true)
	var mp: Vector2 = c + Vector2(eye_shift * 0.6, r * 0.5)
	if mouth > 0.05:
		UI.ellipse(self, mp, r * 0.30, maxf(1.2, r * 0.42 * mouth), Color("5a1420"))
	elif surprise > 0.5:
		draw_circle(mp, 2.2, Color("5a1420"))
	else:
		draw_arc(mp + Vector2(0.0, -2.0), r * 0.32, 0.25, PI - 0.25, 8, UI.INK, 1.5, true)
