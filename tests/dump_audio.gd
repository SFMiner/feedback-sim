extends SceneTree
## Developer tool: writes every synthesised sound to a .wav file so it can be listened to or
## measured outside the game.
##   Godot --headless --path . --script tests/dump_audio.gd -- <output folder>


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "."
	var sfx: AudioController = AudioController.new()
	root.add_child(sfx)
	sfx._ready()
	var streams: Dictionary = sfx._streams
	for key: String in streams:
		var wav: AudioStreamWAV = streams[key]
		wav.save_to_wav(out.path_join(key + ".wav"))
	print("saved %d sounds to %s" % [streams.size(), out])
	quit(0)
