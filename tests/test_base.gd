extends SceneTree
## Shared helpers for the headless tests. Each test script extends this, implements run(), and
## reports the exact number of checks it expects, so a test that stops early cannot pass quietly.
## Run:  Godot --headless --path . --script tests/<name>.gd

# === PUBLIC VARIABLES ===
var passed: int = 0
var failures: int = 0
var test_name: String = "test"


# === PUBLIC METHODS ===
func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failures += 1
		print("  FAIL: " + label)


func note(text: String) -> void:
	print("  . " + text)


func finish(expected_total: int) -> void:
	var total: int = passed + failures
	var ok: bool = failures == 0 and total == expected_total
	print("%s: %d/%d passed (expected %d checks) -> %s" % [test_name, passed, total, expected_total,
		"PASS" if ok else "FAIL"])
	quit(0 if ok else 1)
