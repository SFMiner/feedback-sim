class_name TimelineRecorder
extends RefCounted
## Shared timeline: every module records its measured values here, one row per fixed model step.
## Graphs draw from it, and replays read state snapshots back out of it, so the animation and the
## graph always agree.

# === PUBLIC VARIABLES ===
## Time of each recorded row (model time; seconds or simulated minutes, the module decides).
var times: PackedFloat32Array = PackedFloat32Array()
## Series name -> PackedFloat32Array, one value per row.
var series: Dictionary = {}
## Annotated events: {"t": float, "label": String}.
var events: Array[Dictionary] = []
## Optional state snapshot per row (whatever the view needs to redraw that moment).
var snapshots: Array = []


# === PUBLIC METHODS ===
func clear() -> void:
	times = PackedFloat32Array()
	series = {}
	events = []
	snapshots = []


func record(t: float, values: Dictionary, snapshot: Variant = null) -> void:
	times.append(t)
	for key: String in values:
		if not series.has(key):
			series[key] = PackedFloat32Array()
		var arr: PackedFloat32Array = series[key]
		arr.append(float(values[key]))
		series[key] = arr
	snapshots.append(snapshot)


func add_event(t: float, label: String) -> void:
	events.append({"t": t, "label": label})


func size() -> int:
	return times.size()


func duration() -> float:
	return 0.0 if times.is_empty() else times[times.size() - 1]


## Index of the last row at or before time t (0 if t is before the first row, -1 if empty).
func index_at(t: float) -> int:
	var n: int = times.size()
	if n == 0:
		return -1
	var lo: int = 0
	var hi: int = n - 1
	while lo < hi:
		var mid: int = (lo + hi + 1) >> 1
		if times[mid] <= t:
			lo = mid
		else:
			hi = mid - 1
	return lo


func value_at(key: String, t: float) -> float:
	var i: int = index_at(t)
	if i < 0 or not series.has(key):
		return 0.0
	var arr: PackedFloat32Array = series[key]
	return arr[i] if i < arr.size() else 0.0


func latest(key: String) -> float:
	if not series.has(key):
		return 0.0
	var arr: PackedFloat32Array = series[key]
	return 0.0 if arr.is_empty() else arr[arr.size() - 1]


func snapshot_at(t: float) -> Variant:
	var i: int = index_at(t)
	if i < 0 or i >= snapshots.size():
		return null
	return snapshots[i]
