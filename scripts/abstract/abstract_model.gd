class_name AbstractModel
extends RefCounted
## Models for the abstract demonstrations (GDD 4). No drawing or sound here.
##
## NEGATIVE: a quantity drifts. A sensor notices when it passes the upper or lower threshold, and
## after a DELAY a corrector pushes it back the other way until it is moving away again. Because the
## correction arrives late and keeps going, the quantity overshoots the target and the other
## corrector has to act: a response-and-delay loop, not a drawn sine wave. Push strength varies a
## little each time, so no two swings are identical.
##
## POSITIVE: a small nudge moves the quantity away from its starting level. At regular beats a
## booster adds a further change in the SAME direction, sized in proportion to how far the quantity
## has already moved (so each boost is bigger than the last), and scaled down by the room left
## before a hard limit (so growth slows and stops there). Works upward or downward.

# === CONSTANTS ===
const DT: float = 1.0 / 30.0
const MODE_NEGATIVE: String = "negative"
const MODE_POSITIVE_UP: String = "positive_up"
const MODE_POSITIVE_DOWN: String = "positive_down"
const TARGET: float = 50.0
const UPPER: float = 68.0
const LOWER: float = 32.0
const DELAY: float = 0.45
const DRIFT: float = 14.0
const PUSH_ACCEL: float = 70.0
const NEGATIVE_LENGTH: float = 26.0
const BASELINE: float = 50.0
const LIMIT_HIGH: float = 95.0
const LIMIT_LOW: float = 5.0
const NUDGE: float = 3.0
const GAIN: float = 0.55
const BOOST_EVERY: float = 0.9
const MIN_BOOST: float = 0.5

# === PUBLIC VARIABLES ===
var mode: String = MODE_NEGATIVE
var value: float = TARGET
var velocity: float = 0.0
var time: float = 0.0
var finished: bool = false
## Negative mode: -1 / +1 while a corrector is pushing down / up, else 0.
var correcting: int = 0
## Negative mode: direction of a correction that has been triggered but has not arrived yet.
var pending: int = 0
## Positive mode: size of the latest boost and how many have fired.
var last_boost: float = 0.0
var boost_count: int = 0
var at_limit: bool = false
## Events from the latest step: {"type": "sense"|"correct"|"nudge"|"boost"|"limit"|"finished", ...}.
var events: Array[Dictionary] = []

# === PRIVATE VARIABLES ===
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _pending_t: float = 0.0
var _push_speed: float = DRIFT
var _goal: float = BASELINE
var _direction: float = 1.0
var _beat: float = 0.0
var _nudged: bool = false
var _end_timer: float = 0.0


# === PUBLIC METHODS ===
func setup(p_mode: String, rng_seed: int) -> void:
	mode = p_mode
	_rng.seed = rng_seed
	if mode == MODE_NEGATIVE:
		value = TARGET
		velocity = DRIFT
	else:
		value = BASELINE
		_goal = BASELINE
		_direction = 1.0 if mode == MODE_POSITIVE_UP else -1.0


func step() -> void:
	events.clear()
	if finished:
		return
	time += DT
	if mode == MODE_NEGATIVE:
		_step_negative()
	else:
		_step_positive()


func limit() -> float:
	return LIMIT_HIGH if _direction > 0.0 else LIMIT_LOW


# === PRIVATE METHODS ===
func _step_negative() -> void:
	value += velocity * DT
	if correcting == 0 and pending == 0:
		if value > UPPER and velocity > 0.0:
			pending = -1
		elif value < LOWER and velocity < 0.0:
			pending = 1
		if pending != 0:
			_pending_t = DELAY
			events.append({"type": "sense", "dir": pending})
	elif pending != 0:
		_pending_t -= DT
		if _pending_t <= 0.0:
			correcting = pending
			pending = 0
			_push_speed = DRIFT * _rng.randf_range(0.8, 1.3)
			events.append({"type": "correct", "dir": correcting})
	if correcting != 0:
		velocity += float(correcting) * PUSH_ACCEL * DT
		if velocity * float(correcting) >= _push_speed:
			correcting = 0
	value = clampf(value, 0.0, 100.0)
	if time >= NEGATIVE_LENGTH:
		finished = true
		events.append({"type": "finished"})


func _step_positive() -> void:
	if not _nudged:
		if time >= 1.2:
			_nudged = true
			_goal = BASELINE + _direction * NUDGE
			_beat = BOOST_EVERY
			events.append({"type": "nudge", "dir": int(_direction)})
	elif not at_limit:
		_beat -= DT
		if _beat <= 0.0:
			_beat = BOOST_EVERY
			var moved: float = absf(_goal - BASELINE)
			var room: float = 1.0 - moved / absf(limit() - BASELINE)
			var boost: float = GAIN * moved * room
			if boost < MIN_BOOST:
				at_limit = true
				_end_timer = 3.0
				events.append({"type": "limit"})
			else:
				_goal += _direction * boost
				last_boost = boost
				boost_count += 1
				events.append({"type": "boost", "size": boost, "dir": int(_direction)})
	else:
		_end_timer -= DT
		if _end_timer <= 0.0:
			finished = true
			events.append({"type": "finished"})
	value += (_goal - value) * minf(1.0, 9.0 * DT)
