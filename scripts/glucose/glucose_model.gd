class_name GlucoseModel
extends RefCounted
## Simplified discrete-time model of blood glucose regulation (GDD 6.5). No drawing or sound.
## Units are classroom units, NOT clinical values: glucose runs 0-100 with a target range of
## 40-60, hormone "activity" runs 0-1, glycogen is 0-100 % of the liver's store. Time is in
## simulated minutes.
##
## Each step:
##   * The pancreas moves insulin and glucagon activity toward levels set by blood glucose, at a
##     finite rate (so responses lag). Both hormones are graded and both are present at rest;
##     neither is an on/off switch.
##   * Tissues take up glucose: a basal part that needs no insulin (brain and others), an
##     insulin-driven part, and an exercise part (working muscle takes up glucose without insulin).
##   * The liver stores glucose as glycogen when insulin is high (limited by space), and releases
##     glucose when glucagon is high: glycogen breakdown (limited by what is stored) plus a small
##     amount of newly made glucose. Insulin suppresses liver output.
##   * Food adds glucose: a small steady trickle from digestion (absent when fasting) plus a
##     pulse after each meal.
## Nothing here forces a wave shape; the curve is whatever these rules produce.

# === CONSTANTS ===
const DT: float = 0.25
const TARGET_LOW: float = 40.0
const TARGET_HIGH: float = 60.0
const SET_POINT: float = 50.0
const EXPERIMENT_LENGTH: float = 360.0
const HORMONE_LAG: float = 7.0
const BASAL_USE: float = 0.20
const INSULIN_USE: float = 0.50
const EXERCISE_USE: float = 0.80
const EXERCISE_LENGTH: float = 40.0
const STORE_RATE: float = 0.60
const LIVER_BASAL_OUT: float = 0.10
const LIVER_GLUCAGON_OUT: float = 0.90
const NEW_GLUCOSE: float = 0.06
const GLYCOGEN_PER_GLUCOSE: float = 0.45
const DIGESTION_TRICKLE: float = 0.165
const MEAL_TOTAL: float = 62.0
const MEAL_LENGTH: float = 45.0
const REDUCED_RESPONSE: float = 0.3

# === PUBLIC VARIABLES ===
var blood_glucose: float = SET_POINT
var insulin_activity: float = 0.3
var glucagon_activity: float = 0.3
var liver_glycogen: float = 60.0
## Current flows, in glucose units per simulated minute (read by the view and the tests).
var dietary_glucose_input: float = 0.0
var tissue_glucose_use: float = 0.0
var liver_glucose_output: float = 0.0
var liver_glucose_storage: float = 0.0
var time: float = 0.0
var fasting: bool = false
var exercising: bool = false
## 1.0 = normal response, REDUCED_RESPONSE = reduced (Advanced panel).
var insulin_response: float = 1.0
var glucagon_response: float = 1.0
var finished: bool = false
## Events from the latest step: {"type": "insulin_up"|"glucagon_up"|"back_in_range"|"left_range"|
## "exercise_end"|"finished", ...}.
var events: Array[Dictionary] = []

# === PRIVATE VARIABLES ===
var _meals: Array[float] = []
var _exercise_left: float = 0.0
var _insulin_flag: bool = false
var _glucagon_flag: bool = false
var _out_of_range: bool = false


# === PUBLIC METHODS ===
func setup(p_insulin_reduced: bool, p_glucagon_reduced: bool) -> void:
	insulin_response = REDUCED_RESPONSE if p_insulin_reduced else 1.0
	glucagon_response = REDUCED_RESPONSE if p_glucagon_reduced else 1.0
	insulin_activity = _insulin_target(blood_glucose)
	glucagon_activity = _glucagon_target(blood_glucose)
	_update_flows()


## Disturbance: a meal starts arriving in the blood over MEAL_LENGTH minutes. Ignored while fasting.
func eat_meal() -> bool:
	if fasting or finished:
		return false
	_meals.append(time)
	return true


## Disturbance: muscles work hard for EXERCISE_LENGTH minutes.
func start_exercise() -> bool:
	if finished:
		return false
	_exercise_left = EXERCISE_LENGTH
	exercising = true
	return true


## Disturbance: no food arrives at all while fasting is on.
func set_fasting(on: bool) -> void:
	fasting = on
	if on:
		_meals.clear()
	_update_flows()


func step() -> void:
	events.clear()
	if finished:
		return
	time += DT
	if exercising:
		_exercise_left -= DT
		if _exercise_left <= 0.0:
			exercising = false
			events.append({"type": "exercise_end"})
	# Pancreas: finite-rate response to the current glucose level.
	var k: float = minf(1.0, DT / HORMONE_LAG)
	insulin_activity += (_insulin_target(blood_glucose) - insulin_activity) * k
	glucagon_activity += (_glucagon_target(blood_glucose) - glucagon_activity) * k
	_update_flows()
	var change: float = dietary_glucose_input + liver_glucose_output - tissue_glucose_use - liver_glucose_storage
	blood_glucose = clampf(blood_glucose + change * DT, 0.0, 100.0)
	var glycogen_out: float = _glycogen_release()
	liver_glycogen = clampf(liver_glycogen + (liver_glucose_storage - glycogen_out) * GLYCOGEN_PER_GLUCOSE * DT, 0.0, 100.0)
	_flag_events()
	if time >= EXPERIMENT_LENGTH:
		finished = true
		events.append({"type": "finished"})


func in_range() -> bool:
	return blood_glucose >= TARGET_LOW and blood_glucose <= TARGET_HIGH


func snapshot() -> Dictionary:
	return {
		"time": time, "glucose": blood_glucose, "insulin": insulin_activity, "glucagon": glucagon_activity,
		"glycogen": liver_glycogen, "diet": dietary_glucose_input, "use": tissue_glucose_use,
		"liver_out": liver_glucose_output, "liver_store": liver_glucose_storage,
		"fasting": fasting, "exercising": exercising,
	}


# === PRIVATE METHODS ===
func _insulin_target(g: float) -> float:
	return insulin_response / (1.0 + exp(-(g - 55.0) / 6.0))


func _glucagon_target(g: float) -> float:
	return glucagon_response / (1.0 + exp(-(45.0 - g) / 6.0))


func _glycogen_release() -> float:
	var available: float = liver_glycogen / (liver_glycogen + 10.0)
	return (LIVER_BASAL_OUT + LIVER_GLUCAGON_OUT * glucagon_activity) * (1.0 - 0.8 * insulin_activity) * available


func _update_flows() -> void:
	var level: float = blood_glucose / SET_POINT
	dietary_glucose_input = 0.0 if fasting else DIGESTION_TRICKLE
	for start: float in _meals:
		var u: float = (time - start) / MEAL_LENGTH
		if u >= 0.0 and u < 1.0:
			# A hump: slow start, peak, tail. Its area is MEAL_TOTAL.
			dietary_glucose_input += MEAL_TOTAL / MEAL_LENGTH * 6.0 * u * (1.0 - u)
	tissue_glucose_use = BASAL_USE * minf(1.0, level * 2.0) + INSULIN_USE * insulin_activity * level
	if exercising:
		tissue_glucose_use += EXERCISE_USE * level
	liver_glucose_storage = STORE_RATE * insulin_activity * level * (1.0 - liver_glycogen / 100.0)
	liver_glucose_output = _glycogen_release() + NEW_GLUCOSE * glucagon_activity * (1.0 - 0.8 * insulin_activity)


func _flag_events() -> void:
	if not _insulin_flag and insulin_activity > 0.55:
		_insulin_flag = true
		events.append({"type": "insulin_up"})
	elif _insulin_flag and insulin_activity < 0.40:
		_insulin_flag = false
	if not _glucagon_flag and glucagon_activity > 0.55:
		_glucagon_flag = true
		events.append({"type": "glucagon_up"})
	elif _glucagon_flag and glucagon_activity < 0.40:
		_glucagon_flag = false
	if not _out_of_range and (blood_glucose > TARGET_HIGH + 2.0 or blood_glucose < TARGET_LOW - 2.0):
		_out_of_range = true
		events.append({"type": "left_range", "high": blood_glucose > SET_POINT})
	elif _out_of_range and in_range():
		_out_of_range = false
		events.append({"type": "back_in_range"})
