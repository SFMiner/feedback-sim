class_name ClassroomModel
extends RefCounted
## Model of the noisy classroom (GDD 3.7). No drawing or sound here.
##
## Positive feedback: each student's activity grows faster the more their neighbours are talking
## (spread) and the louder the whole room already is (amplification). It is never switched off.
## Negative feedback: when the noise crosses the teacher's threshold, the teacher answers with three
## timed corrections that bring every student's activity, and so the noise, down to zero.
## After CYCLES interventions a second teacher arrives and distracts the first; the corrective
## response is then disabled and the noise climbs to its ceiling (every student at full volume).

# === CONSTANTS ===
const DT: float = 1.0 / 30.0
const COLS: int = 5
const ROWS: int = 3
const COUNT: int = 15
const MAX_NOISE: float = 100.0
const CYCLES: int = 3
const SPARK_ACTIVITY: float = 0.35
## Seconds after the teacher notices: when each of the three corrections lands.
const WHOMP_TIMES: Array[float] = [0.45, 1.15, 1.85]
## What each correction leaves of the students' activity: two thirds, then half of that, then none.
const WHOMP_KEEP: Array[float] = [0.6667, 0.5, 0.0]
const INTERVENTION_LENGTH: float = 2.4
const TEACHER2_WALK_TIME: float = 3.5
const MESSAGE_AT_NOISE: float = 95.0
const MESSAGE_TIME: float = 7.0

# === PUBLIC VARIABLES ===
var student_activity: PackedFloat32Array = PackedFloat32Array()
var student_voice_id: PackedInt32Array = PackedInt32Array()
var noise_level: float = 0.0
var chatter_spread_rate: float = 0.9
var loudness_amplification: float = 0.55
var teacher_threshold: float = 60.0
## True while the teacher is watching the class (false once distracted).
var teacher_active: bool = true
var teacher_intervening: bool = false
var teacher_distracted: bool = false
## 0 = arms down, 1 = arms fully raised.
var teacher_arms: float = 0.0
## 0 = second teacher at the door, 1 = standing beside the first teacher.
var teacher2_progress: float = 0.0
var teacher2_present: bool = false
var cycles_done: int = 0
var time: float = 0.0
var message_shown: bool = false
var finished: bool = false
## Events raised by the latest step: {"type": "spark"|"intervene"|"whomp"|"quiet"|"teacher2_enters"|
## "distracted"|"message"|"finished", ...}. The module turns these into sound, captions and graph marks.
var events: Array[Dictionary] = []

# === PRIVATE VARIABLES ===
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _neighbors: Array = []
var _intervene_t: float = 0.0
var _whomps_done: int = 0
var _quiet_timer: float = 1.2
var _message_timer: float = 0.0


# === PUBLIC METHODS ===
func setup(rng_seed: int) -> void:
	_rng.seed = rng_seed
	student_activity.resize(COUNT)
	student_activity.fill(0.0)
	student_voice_id.resize(COUNT)
	for i: int in range(COUNT):
		student_voice_id[i] = _rng.randi_range(0, 3)
	_neighbors.clear()
	for i: int in range(COUNT):
		var list: PackedInt32Array = PackedInt32Array()
		var cx: int = i % COLS
		var cy: int = i / COLS
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var nx: int = cx + dx
				var ny: int = cy + dy
				if (dx != 0 or dy != 0) and nx >= 0 and nx < COLS and ny >= 0 and ny < ROWS:
					list.append(ny * COLS + nx)
		_neighbors.append(list)


func step() -> void:
	events.clear()
	if finished:
		return
	time += DT
	if teacher_intervening:
		_step_intervention()
	else:
		teacher_arms = maxf(0.0, teacher_arms - DT / 0.5)
		if teacher2_present and not teacher_distracted:
			teacher2_progress = minf(1.0, teacher2_progress + DT / TEACHER2_WALK_TIME)
			if teacher2_progress >= 1.0:
				teacher_distracted = true
				teacher_active = false
				_quiet_timer = 1.0
				events.append({"type": "distracted"})
		elif _quiet_timer > 0.0:
			_quiet_timer -= DT
			if _quiet_timer <= 0.0:
				_spark()
		else:
			_grow()
	_update_noise()
	if teacher_active and not teacher_intervening and noise_level >= teacher_threshold:
		teacher_intervening = true
		_intervene_t = 0.0
		_whomps_done = 0
		events.append({"type": "intervene"})
	if teacher_distracted and not message_shown and noise_level >= MESSAGE_AT_NOISE:
		message_shown = true
		_message_timer = MESSAGE_TIME
		events.append({"type": "message"})
	if message_shown:
		_message_timer -= DT
		if _message_timer <= 0.0:
			finished = true
			events.append({"type": "finished"})


func active_count() -> int:
	var n: int = 0
	for a: float in student_activity:
		if a >= 0.2:
			n += 1
	return n


# === PRIVATE METHODS ===
func _step_intervention() -> void:
	_intervene_t += DT
	teacher_arms = minf(1.0, _intervene_t / 0.35)
	while _whomps_done < 3 and _intervene_t >= WHOMP_TIMES[_whomps_done]:
		var keep: float = WHOMP_KEEP[_whomps_done]
		for i: int in range(COUNT):
			student_activity[i] *= keep
		events.append({"type": "whomp", "index": _whomps_done})
		_whomps_done += 1
	if _whomps_done >= 3 and _intervene_t >= INTERVENTION_LENGTH:
		teacher_intervening = false
		cycles_done += 1
		_quiet_timer = _rng.randf_range(2.0, 2.8)
		events.append({"type": "quiet"})
		if cycles_done >= CYCLES:
			teacher2_present = true
			events.append({"type": "teacher2_enters"})


func _spark() -> void:
	var i: int = _rng.randi_range(0, COUNT - 1)
	student_activity[i] = SPARK_ACTIVITY
	events.append({"type": "spark", "student": i})


## The positive-feedback rule. Uses last step's values so update order does not matter.
func _grow() -> void:
	var old: PackedFloat32Array = student_activity.duplicate()
	var loudness: float = noise_level / MAX_NOISE
	for i: int in range(COUNT):
		var list: PackedInt32Array = _neighbors[i]
		var near: float = 0.0
		for j: int in list:
			near += old[j]
		near /= float(list.size())
		var a: float = old[i]
		var drive: float = chatter_spread_rate * near + loudness_amplification * a * (0.25 + loudness)
		drive *= _rng.randf_range(0.5, 1.5)
		student_activity[i] = clampf(a + drive * (1.0 - a) * DT, 0.0, 1.0)


func _update_noise() -> void:
	var total: float = 0.0
	for a: float in student_activity:
		total += a
	noise_level = MAX_NOISE * total / float(COUNT)
