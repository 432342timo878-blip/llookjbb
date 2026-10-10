extends SceneTree
## Dev tool (the voice prototype, GDD 4.3.1 R4 follow-up): which text-to-speech voices does this PC have, and does speaking
## work? Needs a window (the headless display has no speech):
##   godot --path . --rendering-driver opengl3 -s res://tools/voice_check.gd
## Lists every voice (id, name, language), then speaks one line with each of the three roles (commentator, expert, coach)
## at your voice level and reports whether the system started speaking. LISTEN: you should hear three short lines, one after
## the other, in (possibly) different voices. Reads stderr too.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var Voice = load("res://scripts/ui/voice_over.gd")
	print("text to speech supported by this display: ", DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH))
	var voices := DisplayServer.tts_get_voices()
	print("%d voices:" % voices.size())
	for v in voices:
		print("   %s | %s | %s" % [v.id, v.name, v.language])
	print("English voices: ", Voice._english_voices())
	print("supported (can speak): ", Voice.supported(), "   voice level now: ", Voice.NAMES[Voice.level()])
	if not Voice.supported():
		quit()
		return
	Voice._level = 2   # (in memory only: the tool never changes the player's saved setting)
	var lines := [
		{"voice": "tv", "text": "Korhonen kicks! Two hundred and twenty nine to go.", "banner": "x"},
		{"voice": "expert", "text": "That's early. From that far out it is a very long way home.", "banner": "x"},
		{"voice": "coach", "text": "Stay on her shoulder. Don't go yet.", "banner": "x"},
	]
	for l in lines:
		Voice.speak(l, 1.0)
		var waited := 0.0
		await create_timer(0.3).timeout
		print("  speaking (%s): %s" % [l.voice, DisplayServer.tts_is_speaking()])
		while DisplayServer.tts_is_speaking() and waited < 12.0:
			await create_timer(0.25).timeout
			waited += 0.25
		print("  done after about %.1f s" % waited)
		# (the next line would interrupt this one if it were still speaking: here they follow each other)
	Voice.stop()
	print("voice_check: finished")
	quit()
