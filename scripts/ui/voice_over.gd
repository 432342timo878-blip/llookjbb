class_name VoiceOver
extends RefCounted
## A first, simple voice for the race commentary (user 2026-10-10: "AI commentary with sound", English first): the key
## moments (the lines that get a banner: moves, kicks, falls, the bell, the finish) and the coach's shouts are read aloud
## with the text-to-speech voices the device has (Godot's DisplayServer.tts_*; Windows, Android, iOS, macOS, Linux). It
## speaks the finished sentence, so names and times come out as written. Quality and voices depend on the device. Three
## voices by pitch / rate / voice id: commentator, expert, coach. Silent at 4x (the race outruns the voice). The player's
## setting (off / low / mid / high) is kept in user://settings.cfg [audio] voice. Later steps (GDD / ROADMAP "Audio"):
## natural voices, other sounds.

const LEVELS := [0, 35, 65, 100]   # volume in percent for off / low / mid / high
const NAMES := ["Voice off", "Voice low", "Voice mid", "Voice high"]
const PATH := "user://settings.cfg"
## Per voice role: pitch and rate (1.0 = the voice's own) and which of the device's English voices it takes (by index, wrapped).
const ROLES := {
	"tv": {"pitch": 1.0, "rate": 1.15, "voice": 0},
	"announcer": {"pitch": 1.0, "rate": 1.05, "voice": 0},
	"expert": {"pitch": 0.88, "rate": 1.0, "voice": 1},
	"coach": {"pitch": 1.18, "rate": 1.2, "voice": 2},
}

static var _level := -1
static var _voices: Array = []
static var _loaded_voices := false


## Can this device speak at all?
static func supported() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH) and not DisplayServer.tts_get_voices().is_empty()


## 0 (off) .. 3 (high); read from the settings file on first use.
static func level() -> int:
	if _level < 0:
		var cfg := ConfigFile.new()
		_level = 2   # (mid until the player says otherwise)
		if cfg.load(PATH) == OK:
			_level = clampi(int(cfg.get_value("audio", "voice", 2)), 0, LEVELS.size() - 1)
	return _level


static func set_level(l: int) -> void:
	_level = clampi(l, 0, LEVELS.size() - 1)
	var cfg := ConfigFile.new()
	cfg.load(PATH)   # (keep the other settings, if any)
	cfg.set_value("audio", "voice", _level)
	cfg.save(PATH)
	if _level == 0:
		stop()


## Off -> low -> mid -> high -> off; returns the new level.
static func cycle() -> int:
	set_level((level() + 1) % LEVELS.size())
	return _level


## Reads a commentary line aloud when it is worth it: a key moment (it has a banner) or a coach's shout, at 1x or 2x only.
## A key moment interrupts what is being said; anything else is skipped when the voice is busy (no backlog).
static func speak(line: Dictionary, speed: float) -> void:
	if level() == 0 or speed > 2.0 or not supported():
		return
	var voice := str(line.voice)
	var key_moment: bool = line.has("banner")
	if not key_moment and voice != "coach":
		return
	if not key_moment and DisplayServer.tts_is_speaking():
		return
	var role: Dictionary = ROLES.get(voice, ROLES.tv)
	var ids := _english_voices()
	var id := "" if ids.is_empty() else str(ids[int(role.voice) % ids.size()])
	DisplayServer.tts_speak(str(line.text), id, LEVELS[level()], float(role.pitch), float(role.rate), 0, key_moment)


static func stop() -> void:
	if supported():
		DisplayServer.tts_stop()


## Pause / resume together with the race.
static func pause(on: bool) -> void:
	if not supported():
		return
	if on:
		DisplayServer.tts_pause()
	else:
		DisplayServer.tts_resume()


## The device's English voices (else just its first voice), in the order the system gives them. On Windows English voices are
## added in Settings > Time & language > Speech > Add voices; this PC had only Finnish and Russian ones (voice_check.gd lists them).
static func _english_voices() -> Array:
	if not _loaded_voices:
		_loaded_voices = true
		_voices = Array(DisplayServer.tts_get_voices_for_language("en"))
		if _voices.is_empty():   # (no English voice installed: the first voice of the device reads everything, told apart by pitch and rate)
			_voices = [DisplayServer.tts_get_voices()[0].id]
	return _voices
