class_name Announcer
extends Node
## Mirrors significant events to the hidden live regions in web/shell.html, so a screen reader has
## something to read. Outside a web export it only records what would have been said.
## Not tested with a screen reader.

# === CONSTANTS ===
const HISTORY_SIZE: int = 30

# === PUBLIC VARIABLES ===
## The last messages sent, newest last. Read by tests.
var history: Array[String] = []


# === PUBLIC METHODS ===
func say(text: String) -> void:
	var clean: String = text.strip_edges()
	if clean.is_empty():
		return
	history.append(clean)
	while history.size() > HISTORY_SIZE:
		history.pop_front()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (window.fbAnnounce) window.fbAnnounce(%s, false)" % JSON.stringify(clean))
