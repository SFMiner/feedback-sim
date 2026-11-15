class_name KeyboardExit
extends Node
## Focus boundary for the sims site (GDD 8.3): the game owns Tab, so it must hand focus back.
## - Tab / Shift+Tab walk a ring of live controls that is rebuilt on every key press, so organelles
##   that were just added, removed or moved are always in the right place in the order.
## - Tab past the last control, Shift+Tab before the first, and Escape with nothing open all leave
##   the game: focus is released and the host page is told with a `sims:leave-game` message.
## - Escape with an overlay open closes only the innermost overlay.
## Keys are caught in _input (not _unhandled_input) because the GUI consumes Tab first.

# === SIGNALS ===
signal left_game

# === PUBLIC VARIABLES ===
## Returns the Array[Control] to walk, in order. Supplied by the game controller.
var ring_provider: Callable = Callable()
## Closes the innermost open overlay and returns true, or returns false if nothing is open.
var close_topmost: Callable = Callable()
## Returns true while a modal overlay is open (arrow keys then stay inside its ring).
var modal_active: Callable = Callable()
## How many times the game has been left. Read by tests.
var leave_count: int = 0


# === LIFECYCLE METHODS ===
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	if event.is_action_pressed("ui_focus_next", true, true):
		move_focus(1, event.is_echo())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_focus_prev", true, true):
		move_focus(-1, event.is_echo())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		escape()
		get_viewport().set_input_as_handled()
	elif modal_active.is_valid() and bool(modal_active.call()):
		# Keep arrow-key focus movement inside the open overlay.
		if event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_down", true):
			move_focus(1, true)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_up", true):
			move_focus(-1, true)
			get_viewport().set_input_as_handled()


# === PUBLIC METHODS ===
## The controls Tab can reach right now, in order.
func current_ring() -> Array[Control]:
	var ring: Array[Control] = []
	if not ring_provider.is_valid():
		return ring
	var raw: Array = ring_provider.call()
	for item: Variant in raw:
		if not (item is Control):
			continue
		var c: Control = item
		if not is_instance_valid(c) or c.is_queued_for_deletion() or not c.is_visible_in_tree():
			continue
		if c.focus_mode == Control.FOCUS_NONE:
			continue
		if c is BaseButton and (c as BaseButton).disabled:
			continue
		ring.append(c)
	return ring


## Moves focus one step. With `stay_inside` (a held key or an arrow key) it stops at the ends
## instead of leaving, so a key held down cannot throw the player out of the game.
func move_focus(direction: int, stay_inside: bool = false) -> void:
	var ring: Array[Control] = current_ring()
	if ring.is_empty():
		if not stay_inside:
			leave_game()
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	var index: int = ring.find(focused)
	var target: int = 0
	if index < 0:
		# Nothing focused yet (for example after a mouse click on the canvas).
		target = 0 if direction > 0 else ring.size() - 1
	else:
		target = index + direction
	if target < 0 or target >= ring.size():
		if not stay_inside:
			leave_game()
		return
	ring[target].grab_focus()


## Escape: close the innermost overlay, or leave the game when none is open.
func escape() -> void:
	if close_topmost.is_valid() and bool(close_topmost.call()):
		return
	leave_game()


## Releases focus and tells a same-origin host page that the player wants out.
func leave_game() -> void:
	get_viewport().gui_release_focus()
	leave_count += 1
	left_game.emit()
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			"if (window.parent !== window) window.parent.postMessage({type: 'sims:leave-game'}, location.origin)")
