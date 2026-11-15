class_name ClottingModel
extends RefCounted
## Simplified model of platelet plug formation (primary hemostasis; GDD 5.5). No drawing or sound.
## It is a small particle model, not a fitted curve:
##
##  * Platelets drift along the vessel with the blood; the supply is finite and recirculates.
##  * INITIAL ADHESION: after the injury, a resting platelet passing close to EXPOSED wound surface
##    may stick to it and becomes activated. This does not need chemical signals, so it still
##    happens when signalling is blocked. It only works on bare wound, so it slows as the wound
##    is covered.
##  * SIGNALLING: every attached, activated platelet releases signal particles (ADP and similar),
##    which drift and fade. Release fades as a platelet ages and stops once the wound is covered
##    (stand-in for the local processes that limit a real plug).
##  * RECRUITMENT (the positive feedback): a resting platelet near signal particles may become
##    activated, steer to the plug and attach, then release signals of its own.
##  * PHYSICAL ACCUMULATION: attached platelets stack in columns ("slots") over the wound, at most
##    MAX_LAYERS deep. Coverage is the share of slots holding at least one platelet.
##
## Growth is limited by wound coverage, plug depth, fading signals and the finite platelet supply.

# === CONSTANTS ===
const DT: float = 1.0 / 30.0
const WIDTH: float = 600.0
const HEIGHT: float = 180.0
const SLOT_WIDTH: float = 13.0
const MAX_LAYERS: int = 3
const FREE: int = 0
const ACTIVE: int = 1
const ATTACHED: int = 2
const INJURY_TIME: float = 1.5
const MAX_TIME: float = 45.0
const WOUND_SLOTS: Array[int] = [5, 9, 14]
const PLATELET_COUNTS: Array[int] = [22, 46, 80]
const SIGNAL_FACTORS: Array[float] = [1.0, 0.3, 0.0]
const ADHERE_ZONE: float = 16.0
const ADHERE_RATE: float = 0.45
const EMIT_RATE: float = 1.3
const EMIT_FADE: float = 7.0
const SIGNAL_LIFE: float = 2.6
const SIGNAL_RADIUS: float = 42.0
const ACTIVATE_RATE: float = 0.35
const MAX_SIGNALS: int = 160
const HOMING_SPEED: float = 95.0
const SHUTDOWN_TIME: float = 4.0

# === PUBLIC VARIABLES ===
## Experiment settings, each 0-2 (see the option arrays above).
var wound_size: int = 1
var platelet_level: int = 1
var signaling: int = 0
var time: float = 0.0
var injured: bool = false
var finished: bool = false
var pos: PackedVector2Array = PackedVector2Array()
var state: PackedByteArray = PackedByteArray()
var signal_pos: PackedVector2Array = PackedVector2Array()
var signal_age: PackedFloat32Array = PackedFloat32Array()
## Platelets stacked in each wound slot.
var slot_heights: PackedByteArray = PackedByteArray()
var attached: int = 0
var adhered_direct: int = 0
var recruited: int = 0
## Platelets that attached during the last whole second.
var new_per_interval: int = 0
var coverage: float = 0.0
var covered_time: float = -1.0
## Events from the latest step: {"type": "injury"|"adhere"|"recruit"|"first_adhesion"|
## "recruitment_up"|"covered"|"finished"}.
var events: Array[Dictionary] = []

# === PRIVATE VARIABLES ===
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _target: PackedInt32Array = PackedInt32Array()
var _attach_time: PackedFloat32Array = PackedFloat32Array()
var _active_time: PackedFloat32Array = PackedFloat32Array()
var _interval_count: int = 0
var _interval_recruits: int = 0
var _interval_t: float = 0.0
var _last_attach: float = 0.0
var _recruit_flagged: bool = false


# === PUBLIC METHODS ===
func setup(p_wound: int, p_platelets: int, p_signaling: int, rng_seed: int) -> void:
	wound_size = clampi(p_wound, 0, 2)
	platelet_level = clampi(p_platelets, 0, 2)
	signaling = clampi(p_signaling, 0, 2)
	_rng.seed = rng_seed
	var n: int = PLATELET_COUNTS[platelet_level]
	pos.resize(n)
	state.resize(n)
	_target.resize(n)
	_attach_time.resize(n)
	_active_time.resize(n)
	for i: int in range(n):
		pos[i] = Vector2(_rng.randf_range(0.0, WIDTH), _rng.randf_range(8.0, HEIGHT - 4.0))
		state[i] = FREE
		_target[i] = -1
	slot_heights.resize(WOUND_SLOTS[wound_size])
	slot_heights.fill(0)


func slot_count() -> int:
	return slot_heights.size()


func wound_left() -> float:
	return WIDTH * 0.5 - float(slot_count()) * SLOT_WIDTH * 0.5


func wound_right() -> float:
	return wound_left() + float(slot_count()) * SLOT_WIDTH


## Where a platelet sits when it is layer `layer` (0 = on the wound) of slot `slot`.
func slot_position(slot: int, layer: int) -> Vector2:
	var x: float = wound_left() + (float(slot) + 0.5) * SLOT_WIDTH + (SLOT_WIDTH * 0.25 if layer % 2 == 1 else 0.0)
	return Vector2(x, HEIGHT - 6.0 - float(layer) * 11.0)


func free_count() -> int:
	var n: int = 0
	for s: int in state:
		if s != ATTACHED:
			n += 1
	return n


func capacity() -> int:
	return slot_count() * MAX_LAYERS


func signal_strength() -> float:
	if covered_time < 0.0:
		return SIGNAL_FACTORS[signaling]
	return SIGNAL_FACTORS[signaling] * maxf(0.0, 1.0 - (time - covered_time) / SHUTDOWN_TIME)


func step() -> void:
	events.clear()
	if finished:
		return
	time += DT
	if not injured and time >= INJURY_TIME:
		injured = true
		_last_attach = time
		events.append({"type": "injury"})
	_emit_signals()
	_move_signals()
	_move_platelets()
	_update_counts()
	_check_finished()


## Everything a view needs to redraw this moment (also what a replay stores).
func snapshot() -> Dictionary:
	return {
		"time": time, "injured": injured, "pos": pos.duplicate(), "state": state.duplicate(),
		"signals": signal_pos.duplicate(), "slots": slot_heights.duplicate(), "coverage": coverage,
		"attached": attached, "wound_left": wound_left(), "wound_right": wound_right(),
		"signal_strength": signal_strength(), "covered_time": covered_time,
	}


# === PRIVATE METHODS ===
func _emit_signals() -> void:
	var strength: float = signal_strength()
	if strength <= 0.0:
		return
	for i: int in range(pos.size()):
		if state[i] != ATTACHED or signal_pos.size() >= MAX_SIGNALS:
			continue
		var rate: float = EMIT_RATE * strength * exp(-(time - _attach_time[i]) / EMIT_FADE)
		if _rng.randf() < rate * DT:
			signal_pos.append(pos[i] + Vector2(_rng.randf_range(-4.0, 4.0), -6.0))
			signal_age.append(0.0)


func _move_signals() -> void:
	var i: int = signal_pos.size() - 1
	while i >= 0:
		signal_age[i] += DT
		var p: Vector2 = signal_pos[i]
		p += Vector2(9.0 + _rng.randfn(0.0, 30.0), _rng.randfn(-6.0, 30.0)) * DT * 4.0
		p.y = clampf(p.y, 6.0, HEIGHT - 3.0)
		signal_pos[i] = p
		if signal_age[i] > SIGNAL_LIFE or p.x < 0.0 or p.x > WIDTH:
			signal_pos.remove_at(i)
			signal_age.remove_at(i)
		i -= 1


func _flow_speed(y: float) -> float:
	var u: float = clampf(y / HEIGHT, 0.0, 1.0)
	return 34.0 + 300.0 * u * (1.0 - u)


func _move_platelets() -> void:
	var left: float = wound_left()
	var right: float = wound_right()
	for i: int in range(pos.size()):
		var s: int = state[i]
		if s == ATTACHED:
			continue
		var p: Vector2 = pos[i]
		if s == ACTIVE:
			# Signal-activated platelet: steers to its place on the plug.
			var slot: int = _target[i]
			if slot < 0 or int(slot_heights[slot]) >= MAX_LAYERS:
				slot = _pick_slot(p.x)
				_target[i] = slot
			_active_time[i] += DT
			if slot < 0 or _active_time[i] > 5.0:
				state[i] = FREE
				continue
			var goal: Vector2 = slot_position(slot, int(slot_heights[slot]))
			var to_goal: Vector2 = goal - p
			if to_goal.length() <= HOMING_SPEED * DT + 3.0:
				_attach(i, slot, false)
			else:
				pos[i] = p + to_goal.normalized() * HOMING_SPEED * DT
			continue
		# Resting platelet: carried by the flow, with a little wobble.
		p.x += _flow_speed(p.y) * DT
		p.y = clampf(p.y + _rng.randfn(0.0, 6.0) * DT * 4.0, 6.0, HEIGHT - 4.0)
		if p.x > WIDTH + 12.0:
			p.x = -12.0
			p.y = _rng.randf_range(8.0, HEIGHT - 4.0)
		pos[i] = p
		if not injured:
			continue
		# Initial adhesion to bare wound surface.
		if p.y > HEIGHT - ADHERE_ZONE and p.x >= left and p.x < right:
			var here: int = clampi(int((p.x - left) / SLOT_WIDTH), 0, slot_count() - 1)
			if slot_heights[here] == 0 and _rng.randf() < ADHERE_RATE * DT:
				_attach(i, here, true)
				continue
		# Activation by nearby signal particles.
		if signal_pos.is_empty() or p.x < left - 140.0 or p.x > right + 140.0:
			continue
		var near: int = 0
		for q: Vector2 in signal_pos:
			if absf(q.x - p.x) < SIGNAL_RADIUS and q.distance_squared_to(p) < SIGNAL_RADIUS * SIGNAL_RADIUS:
				near += 1
		if near > 0 and _rng.randf() < ACTIVATE_RATE * float(near) * DT:
			var chosen: int = _pick_slot(p.x)
			if chosen >= 0:
				state[i] = ACTIVE
				_target[i] = chosen
				_active_time[i] = 0.0


## Chooses where an activated platelet should go: the lowest stack, nearest first.
func _pick_slot(x: float) -> int:
	var best: int = -1
	var best_cost: float = INF
	for s: int in range(slot_count()):
		var h: int = slot_heights[s]
		if h >= MAX_LAYERS:
			continue
		var cost: float = float(h) * 60.0 + absf(slot_position(s, h).x - x) * 0.5 + _rng.randf_range(0.0, 20.0)
		if cost < best_cost:
			best_cost = cost
			best = s
	return best


func _attach(i: int, slot: int, direct: bool) -> void:
	var layer: int = slot_heights[slot]
	pos[i] = slot_position(slot, layer)
	state[i] = ATTACHED
	slot_heights[slot] = layer + 1
	_attach_time[i] = time
	_last_attach = time
	attached += 1
	_interval_count += 1
	if direct:
		adhered_direct += 1
		events.append({"type": "adhere"})
	else:
		recruited += 1
		_interval_recruits += 1
		events.append({"type": "recruit"})
	if attached == 1:
		events.append({"type": "first_adhesion"})


func _update_counts() -> void:
	var covered: int = 0
	for h: int in slot_heights:
		if h > 0:
			covered += 1
	coverage = 100.0 * float(covered) / float(slot_count())
	if covered == slot_count() and covered_time < 0.0:
		covered_time = time
		events.append({"type": "covered"})
	_interval_t += DT
	if _interval_t >= 1.0 - 0.0001:
		_interval_t = 0.0
		new_per_interval = _interval_count
		if not _recruit_flagged and _interval_recruits >= 2:
			_recruit_flagged = true
			events.append({"type": "recruitment_up"})
		_interval_count = 0
		_interval_recruits = 0


func _check_finished() -> void:
	var done: bool = time >= MAX_TIME
	if covered_time >= 0.0 and time - covered_time > SHUTDOWN_TIME + 1.5 and time - _last_attach > 2.0:
		done = true
	if attached >= capacity() or attached >= pos.size():
		done = done or time - _last_attach > 1.5
	if done:
		finished = true
		events.append({"type": "finished"})
