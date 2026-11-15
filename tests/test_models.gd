extends "res://tests/test_base.gd"
## Headless checks of the four simulation models (no scenes, no rendering).
## Run:  Godot --headless --path . --script tests/test_models.gd

const EXPECTED: int = 58


func _init() -> void:
	test_name = "test_models"
	_classroom()
	_abstract()
	_clotting()
	_glucose()
	finish(EXPECTED)


# === CLASSROOM ===
func _run_classroom(rng_seed: int) -> Dictionary:
	var m: ClassroomModel = ClassroomModel.new()
	m.setup(rng_seed)
	var noise: PackedFloat32Array = PackedFloat32Array()
	var whomps: int = 0
	var interventions: int = 0
	var zero_after_third: int = 0
	var peak_before: float = 0.0
	var peak_after: float = 0.0
	var step_ok: bool = true
	var level_at_intervene: float = 0.0
	var distracted_at: float = -1.0
	var guard: int = 0
	while not m.finished and guard < 30 * 400:
		m.step()
		guard += 1
		noise.append(m.noise_level)
		if m.teacher_distracted:
			peak_after = maxf(peak_after, m.noise_level)
		else:
			peak_before = maxf(peak_before, m.noise_level)
		for e: Dictionary in m.events:
			match str(e["type"]):
				"intervene":
					interventions += 1
					level_at_intervene = m.noise_level
				"whomp":
					whomps += 1
					var want: float = level_at_intervene * [0.6667, 0.3333, 0.0][int(e["index"])]
					if absf(m.noise_level - want) > 0.6:
						step_ok = false
					if int(e["index"]) == 2 and m.noise_level < 0.001:
						zero_after_third += 1
				"distracted":
					distracted_at = m.time
	return {"noise": noise, "whomps": whomps, "interventions": interventions, "zero": zero_after_third,
		"peak_before": peak_before, "peak_after": peak_after, "time": m.time, "finished": m.finished,
		"step_ok": step_ok, "distracted_at": distracted_at, "voices": m.student_voice_id, "threshold": m.teacher_threshold}


func _classroom() -> void:
	var a: Dictionary = _run_classroom(4172)
	var b: Dictionary = _run_classroom(4172)
	var c: Dictionary = _run_classroom(77)
	note("classroom: %d interventions, %d whomps, peak before %.1f, after %.1f, distracted at %.1f s, length %.1f s" % [a["interventions"], a["whomps"], a["peak_before"], a["peak_after"], a["distracted_at"], a["time"]])
	check(a["finished"], "classroom: the demonstration reaches its end")
	check(a["interventions"] == 3, "classroom: the teacher intervenes exactly three times")
	check(a["whomps"] == 9, "classroom: three corrections per intervention")
	check(a["zero"] == 3, "classroom: noise is zero after every third correction")
	check(a["step_ok"], "classroom: noise falls in three equal steps (2/3, 1/3, 0 of the level at intervention)")
	check(float(a["peak_before"]) < float(a["threshold"]) + 8.0, "classroom: while the teacher listens, noise never runs far past the threshold")
	check(float(a["peak_after"]) >= 95.0, "classroom: with the teacher distracted, noise climbs to near the maximum")
	check(float(a["peak_after"]) <= 100.0, "classroom: noise never exceeds the maximum")
	check(float(a["time"]) > 35.0 and float(a["time"]) < 110.0, "classroom: runs between 35 and 110 seconds (%.1f)" % float(a["time"]))
	check(a["noise"] == b["noise"], "classroom: the same seed reproduces the same curve exactly")
	check(a["noise"] != c["noise"], "classroom: a different seed gives a different curve")
	check(c["interventions"] == 3 and float(c["peak_after"]) >= 95.0, "classroom: another seed still shows three cycles then escalation")
	var voices: PackedInt32Array = a["voices"]
	var seen: Dictionary = {}
	for v: int in voices:
		seen[v] = true
	check(seen.size() == 4, "classroom: all four voice presets are in use for the demo seed")


# === ABSTRACT ===
func _abstract() -> void:
	var m: AbstractModel = AbstractModel.new()
	m.setup(AbstractModel.MODE_NEGATIVE, 9051)
	var corrections: Array[int] = []
	var sense_time: float = 0.0
	var delay_ok: bool = true
	var peaks: Array[float] = []
	var hi: float = 0.0
	var lo: float = 100.0
	var prev_v: float = m.velocity
	while not m.finished:
		m.step()
		hi = maxf(hi, m.value)
		lo = minf(lo, m.value)
		if signf(prev_v) != signf(m.velocity) and prev_v != 0.0:
			peaks.append(m.value)
		prev_v = m.velocity
		for e: Dictionary in m.events:
			if str(e["type"]) == "sense":
				sense_time = m.time
			elif str(e["type"]) == "correct":
				corrections.append(int(e["dir"]))
				if m.time - sense_time < AbstractModel.DELAY - 0.05:
					delay_ok = false
	var alternates: bool = corrections.size() >= 4
	for i: int in range(1, corrections.size()):
		if corrections[i] == corrections[i - 1]:
			alternates = false
	var distinct: Dictionary = {}
	for p: float in peaks:
		distinct[snappedf(p, 0.1)] = true
	note("abstract negative: %d corrections, range %.1f-%.1f, %d distinct turning points of %d" % [corrections.size(), lo, hi, distinct.size(), peaks.size()])
	check(alternates, "abstract negative: at least four corrections, alternating down / up")
	check(corrections.size() > 0 and corrections[0] == -1, "abstract negative: the first correction pushes down (quantity was too high)")
	check(delay_ok, "abstract negative: every correction arrives after the sensing delay")
	check(hi > AbstractModel.UPPER and lo < AbstractModel.LOWER, "abstract negative: overshoots both thresholds")
	check(hi < 100.0 and lo > 0.0, "abstract negative: stays inside the scale")
	check(distinct.size() >= 3, "abstract negative: swings differ from one another (not a fixed sine wave)")
	for mode: String in [AbstractModel.MODE_POSITIVE_UP, AbstractModel.MODE_POSITIVE_DOWN]:
		var p: AbstractModel = AbstractModel.new()
		p.setup(mode, 1)
		var up: bool = mode == AbstractModel.MODE_POSITIVE_UP
		var boosts: Array[float] = []
		var monotonic: bool = true
		var last: float = p.value
		while not p.finished:
			p.step()
			if (up and p.value < last - 0.0001) or (not up and p.value > last + 0.0001):
				monotonic = false
			last = p.value
			for e: Dictionary in p.events:
				if str(e["type"]) == "boost":
					boosts.append(float(e["size"]))
		var biggest: int = boosts.find(boosts.max())
		note("abstract %s: %d boosts, biggest is number %d, ends at %.1f after %.1f s" % [mode, boosts.size(), biggest + 1, p.value, p.time])
		check(boosts.size() >= 6 and boosts[1] > boosts[0] and boosts[2] > boosts[1] and boosts[3] > boosts[2], mode + ": early boosts grow (amplification)")
		check(boosts[boosts.size() - 1] < boosts[biggest] * 0.5, mode + ": late boosts shrink as the limit nears")
		check(monotonic, mode + ": the quantity only ever moves in the direction of the first nudge")
		if up:
			check(p.value > 85.0 and p.value <= AbstractModel.LIMIT_HIGH, mode + ": levels off just under the upper limit")
		else:
			check(p.value < 15.0 and p.value >= AbstractModel.LIMIT_LOW, mode + ": levels off just above the lower limit")


# === CLOTTING ===
func _run_clot(wound: int, platelets: int, signaling: int, rng_seed: int) -> ClottingModel:
	var m: ClottingModel = ClottingModel.new()
	m.setup(wound, platelets, signaling, rng_seed)
	var guard: int = 0
	while not m.finished and guard < 30 * 60:
		m.step()
		guard += 1
	return m


func _clot_average(wound: int, platelets: int, signaling: int) -> Dictionary:
	var attached: float = 0.0
	var recruited: float = 0.0
	var direct: float = 0.0
	var covered: int = 0
	var cover_time: float = 0.0
	var length: float = 0.0
	var runs: int = 12
	for s: int in range(runs):
		var m: ClottingModel = _run_clot(wound, platelets, signaling, 500 + s)
		attached += float(m.attached)
		recruited += float(m.recruited)
		direct += float(m.adhered_direct)
		length += m.time
		cover_time += m.covered_time if m.covered_time >= 0.0 else ClottingModel.MAX_TIME
		if m.covered_time >= 0.0:
			covered += 1
	return {"attached": attached / runs, "recruited": recruited / runs, "direct": direct / runs,
		"covered": covered, "cover_time": cover_time / runs, "length": length / runs}


func _clotting() -> void:
	var normal: Dictionary = _clot_average(1, 1, 0)
	var reduced: Dictionary = _clot_average(1, 1, 1)
	var blocked: Dictionary = _clot_average(1, 1, 2)
	var small: Dictionary = _clot_average(0, 1, 0)
	var large: Dictionary = _clot_average(2, 1, 0)
	var few: Dictionary = _clot_average(1, 0, 0)
	var many: Dictionary = _clot_average(1, 2, 0)
	for pair: Array in [["normal", normal], ["reduced signal", reduced], ["blocked signal", blocked], ["small wound", small], ["large wound", large], ["low platelets", few], ["high platelets", many]]:
		var d: Dictionary = pair[1]
		note("clotting %-15s attached %.1f (direct %.1f, recruited %.1f), covered %d/12 at %.1f s, length %.1f s" % [pair[0], d["attached"], d["direct"], d["recruited"], d["covered"], d["cover_time"], d["length"]])
	check(int(normal["covered"]) == 12, "clotting: normal settings always cover the wound")
	check(float(normal["recruited"]) > float(normal["direct"]), "clotting: with normal signals, most platelets are recruited by signals")
	check(float(blocked["recruited"]) == 0.0, "clotting: blocked signals recruit nobody")
	check(float(blocked["direct"]) >= 3.0, "clotting: blocked signals still allow initial adhesion")
	check(float(blocked["attached"]) < float(reduced["attached"]) and float(reduced["attached"]) < float(normal["attached"]), "clotting: attached platelets: blocked < reduced < normal")
	check(float(blocked["cover_time"]) > float(normal["cover_time"]) + 5.0, "clotting: blocked signals cover the wound much later (or not at all)")
	check(float(small["attached"]) < float(normal["attached"]) and float(normal["attached"]) < float(large["attached"]), "clotting: a larger wound gathers more platelets")
	check(float(small["cover_time"]) < float(large["cover_time"]), "clotting: a larger wound takes longer to cover")
	check(float(many["cover_time"]) < float(few["cover_time"]), "clotting: more platelets cover the wound sooner")
	var one: ClottingModel = ClottingModel.new()
	one.setup(1, 1, 0, 1110)
	var series: PackedInt32Array = PackedInt32Array()
	var over_capacity: bool = false
	while not one.finished:
		one.step()
		series.append(one.attached)
		if one.attached > one.capacity() or one.attached > one.pos.size():
			over_capacity = true
	var two: ClottingModel = _run_clot(1, 1, 0, 1110)
	# Acceleration: the fastest 3 s of growth comes after a slower first 3 s; growth stops at the end.
	var window: int = 90
	var first_at: int = 0
	while first_at < series.size() and series[first_at] == 0:
		first_at += 1
	var early: int = series[mini(first_at + window, series.size() - 1)] - series[first_at]
	var best: int = 0
	for i: int in range(first_at, series.size() - window):
		best = maxi(best, series[i + window] - series[i])
	var tail: int = series[series.size() - 1] - series[maxi(0, series.size() - 46)]
	note("clotting demo run: %d attached, first 3 s after first adhesion +%d, fastest 3 s +%d, last 1.5 s +%d" % [one.attached, early, best, tail])
	check(not over_capacity, "clotting: attached never exceeds plug capacity or the platelet supply")
	check(best > early, "clotting: accumulation accelerates after the first adhesions")
	check(tail == 0, "clotting: accumulation has stopped by the end")
	check(one.attached == two.attached and is_equal_approx(one.time, two.time), "clotting: the same settings and seed repeat exactly")


# === GLUCOSE ===
func _run_glucose(insulin_reduced: bool, glucagon_reduced: bool, script: Dictionary) -> Dictionary:
	var m: GlucoseModel = GlucoseModel.new()
	m.setup(insulin_reduced, glucagon_reduced)
	if script.get("fast", false):
		m.set_fasting(true)
	var top: float = m.blood_glucose
	var low: float = m.blood_glucose
	var insulin_top: float = m.insulin_activity
	var glucagon_top: float = m.glucagon_activity
	var above: float = 0.0
	var below: float = 0.0
	var bounds_ok: bool = true
	var glycogen_start: float = m.liver_glycogen
	var glycogen_low: float = m.liver_glycogen
	var use_at_exercise: float = 0.0
	var use_before: float = 0.0
	var diet_top: float = 0.0
	while not m.finished:
		if script.has("meal") and absf(m.time - float(script["meal"])) < 0.01:
			m.eat_meal()
		if script.has("exercise") and absf(m.time - float(script["exercise"])) < 0.01:
			use_before = m.tissue_glucose_use
			m.start_exercise()
		m.step()
		if script.has("exercise") and absf(m.time - float(script["exercise"]) - 1.0) < 0.01:
			use_at_exercise = m.tissue_glucose_use
		top = maxf(top, m.blood_glucose)
		low = minf(low, m.blood_glucose)
		insulin_top = maxf(insulin_top, m.insulin_activity)
		glucagon_top = maxf(glucagon_top, m.glucagon_activity)
		glycogen_low = minf(glycogen_low, m.liver_glycogen)
		diet_top = maxf(diet_top, m.dietary_glucose_input)
		if m.blood_glucose > GlucoseModel.TARGET_HIGH:
			above += GlucoseModel.DT
		if m.blood_glucose < GlucoseModel.TARGET_LOW:
			below += GlucoseModel.DT
		if m.liver_glycogen < 0.0 or m.liver_glycogen > 100.0 or m.blood_glucose < 0.0 or m.blood_glucose > 100.0 or m.insulin_activity < 0.0 or m.insulin_activity > 1.0 or m.glucagon_activity < 0.0 or m.glucagon_activity > 1.0:
			bounds_ok = false
	return {"top": top, "low": low, "insulin_top": insulin_top, "glucagon_top": glucagon_top, "above": above, "below": below,
		"final": m.blood_glucose, "bounds_ok": bounds_ok, "glycogen_start": glycogen_start, "glycogen_low": glycogen_low,
		"glycogen_final": m.liver_glycogen, "use_before": use_before, "use_at_exercise": use_at_exercise, "diet_top": diet_top,
		"insulin_final": m.insulin_activity, "glucagon_final": m.glucagon_activity}


func _glucose() -> void:
	var rest: Dictionary = _run_glucose(false, false, {})
	var meal: Dictionary = _run_glucose(false, false, {"meal": 30.0})
	var meal_weak: Dictionary = _run_glucose(true, false, {"meal": 30.0})
	var ex: Dictionary = _run_glucose(false, false, {"exercise": 30.0})
	var ex_weak: Dictionary = _run_glucose(false, true, {"exercise": 30.0})
	var fast: Dictionary = _run_glucose(false, false, {"fast": true})
	for pair: Array in [["rest", rest], ["meal", meal], ["meal, weak insulin", meal_weak], ["exercise", ex], ["exercise, weak glucagon", ex_weak], ["fasting", fast]]:
		var d: Dictionary = pair[1]
		note("glucose %-24s glucose %.1f-%.1f (final %.1f), insulin max %.2f, glucagon max %.2f, above %.0f min, below %.0f min, glycogen %.0f -> low %.0f -> %.0f" % [pair[0], d["low"], d["top"], d["final"], d["insulin_top"], d["glucagon_top"], d["above"], d["below"], d["glycogen_start"], d["glycogen_low"], d["glycogen_final"]])
	check(float(rest["low"]) > 44.0 and float(rest["top"]) < 56.0, "glucose: at rest, glucose stays near the middle of the target range for six hours")
	check(float(rest["insulin_final"]) > 0.1 and float(rest["glucagon_final"]) > 0.1, "glucose: at rest both hormones are present (not on/off switches)")
	check(float(meal["top"]) > 62.0, "glucose: a meal raises blood glucose above the target range")
	check(float(meal["diet_top"]) > float(rest["diet_top"]) * 3.0, "glucose: a meal increases dietary glucose input")
	check(float(meal["insulin_top"]) > float(rest["insulin_top"]) + 0.3, "glucose: insulin rises after a meal")
	check(float(meal["final"]) <= GlucoseModel.TARGET_HIGH and float(meal["final"]) >= GlucoseModel.TARGET_LOW and float(meal["above"]) < 150.0, "glucose: after a meal, glucose returns to the target range")
	check(float(meal["glycogen_final"]) > float(rest["glycogen_final"]) + 2.0, "glucose: the liver stores some of the meal as glycogen")
	check(float(meal_weak["top"]) > float(meal["top"]) + 3.0 and float(meal_weak["above"]) > float(meal["above"]) * 1.5, "glucose: a reduced insulin response gives a higher, longer glucose peak")
	check(float(ex["use_at_exercise"]) > float(ex["use_before"]) * 1.5, "glucose: exercise increases glucose use by tissue")
	check(float(ex["low"]) < 42.0, "glucose: exercise lowers blood glucose")
	check(float(ex["glucagon_top"]) > float(rest["glucagon_top"]) + 0.2, "glucose: glucagon rises when glucose falls")
	check(float(ex["glycogen_low"]) < float(rest["glycogen_low"]) - 3.0, "glucose: the liver releases glycogen during exercise")
	check(float(ex["final"]) >= GlucoseModel.TARGET_LOW, "glucose: after exercise, glucose returns to the target range")
	check(float(ex_weak["low"]) < float(ex["low"]) - 2.0, "glucose: a reduced glucagon response lets glucose fall further")
	check(float(fast["diet_top"]) == 0.0, "glucose: fasting removes dietary glucose input")
	check(float(fast["glycogen_final"]) < float(rest["glycogen_final"]) - 10.0 and float(fast["glucagon_top"]) > float(rest["glucagon_top"]), "glucose: fasting draws down glycogen under raised glucagon")
	var all_ok: bool = true
	for d: Dictionary in [rest, meal, meal_weak, ex, ex_weak, fast]:
		if not bool(d["bounds_ok"]):
			all_ok = false
	check(all_ok, "glucose: glucose, hormones and glycogen always stay inside their scales")
	var none: GlucoseModel = GlucoseModel.new()
	none.setup(true, false)
	none.insulin_response = 0.0
	none.insulin_activity = 0.0
	none.step()
	check(none.tissue_glucose_use > 0.1, "glucose: tissues still take up glucose with no insulin at all")
