class_name DDSfx
extends Node

## Card sounds. Every file is a Pixabay recording, credited in its own name.
##
## "opening hand" is one take containing EIGHT card draws. A four card deal takes
## a random window of four of those eight, so the opening never sounds identical
## twice; a single draw (the 8 second hand growth) takes one slice the same way.

const DRAW_FILE := "res://SFX/freesound_community opening hand.mp3"
const PLACE_FILE := "res://SFX/oxidvideos-place cardmp3.mp3"
## A single card drawn into either hand: one of three takes, picked at random.
const TAKE_FILES := [
	"res://SFX/oxidvideos-taking-playing-card-522520.mp3",
	"res://SFX/oxidvideos-taking-playing-card-2-522516.mp3",
	"res://SFX/oxidvideos-taking-playing-card-3-522513.mp3",
]
## Draws this many physics frames apart count as one: both hands draw on the same
## clock, and the two players should not hear a doubled sound.
const TAKE_SAME_FRAMES := 3
const DRAW_SLICES := 8
const VOICES := 6
## Match music: once the opening hand is dealt, one of these (picked at random,
## a cosmetic roll) plays on a loop for the rest of the fight. Every track in
## MUSIC_DIR is in the pool: drop a file in (or take one out) and the next match
## picks it up, no list to edit. Placeholders until real tracks replace them.
const MUSIC_DIR := "res://musictoreplace/"
const MUSIC_EXTS := ["mp3", "ogg", "wav"]


## Every track in MUSIC_DIR, sorted. ResourceLoader.list_directory (not DirAccess)
## so it still sees the files in an exported build, where only .import remaps exist.
static func music_files() -> Array:
	var out: Array = []
	for f in ResourceLoader.list_directory(MUSIC_DIR):
		if String(f).get_extension().to_lower() in MUSIC_EXTS:
			out.append(MUSIC_DIR + String(f))
	out.sort()
	return out
const MUSIC_DB := -12.0
var music: AudioStreamPlayer = null

## Master volume, 0..1, set by the slider in the match HUD. It drives the Master
## bus (music and sounds alike) and is kept in user://settings.cfg between plays.
const SETTINGS_FILE := "user://settings.cfg"
const VOLUME_DEFAULT := 0.8
static var volume := -1.0

var draw_stream: AudioStream = null
var place_stream: AudioStream = null
var take_streams: Array[AudioStream] = []
var last_take_frame := -1000
var slice_seconds := 0.0
var voices: Array[AudioStreamPlayer] = []


func _ready() -> void:
	draw_stream = load(DRAW_FILE)
	place_stream = load(PLACE_FILE)
	for path in TAKE_FILES:
		var s: AudioStream = load(path)
		if s != null:
			take_streams.append(s)
	if draw_stream != null:
		slice_seconds = draw_stream.get_length() / float(DRAW_SLICES)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		voices.append(p)


## Deal `count` cards: a random run of that many draws out of the eight in the take.
func draw_hand(count: int = 4) -> void:
	if draw_stream == null or slice_seconds <= 0.0:
		return
	var n: int = clampi(count, 1, DRAW_SLICES)
	var voice := _voice()
	if voice == null:
		return
	# any start slice that still leaves n draws inside the take
	var start := randi_range(0, DRAW_SLICES - n)
	voice.stream = draw_stream
	voice.play(float(start) * slice_seconds)
	var length: float = float(n) * slice_seconds
	# a child timer, not a SceneTree one: it goes with this node when the scene is
	# reloaded (a run moving to its next fight) instead of firing into freed nodes
	var stopper := Timer.new()
	stopper.one_shot = true
	stopper.wait_time = maxf(0.01, length)
	add_child(stopper)
	stopper.timeout.connect(func() -> void:
		if is_instance_valid(voice) and voice.playing:
			voice.stop()
		stopper.queue_free())
	stopper.start()


## Start the match music `delay` seconds from now (after the deal). A child
## timer, so a reloaded scene takes it along instead of it firing late.
func start_music(delay: float) -> void:
	var paths: Array = music_files()
	if paths.is_empty():
		return
	var path := String(paths[randi() % paths.size()])
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(0.01, delay)
	add_child(timer)
	timer.timeout.connect(func() -> void:
		var s: AudioStream = load(path)
		if s != null:
			if "loop" in s:
				s.set("loop", true)
			music = AudioStreamPlayer.new()
			music.volume_db = MUSIC_DB
			music.stream = s
			add_child(music)
			music.play()
			print("[music] playing %s" % path.get_file())
		timer.queue_free())
	timer.start()


func place_card() -> void:
	if place_stream == null:
		return
	var voice := _voice()
	if voice == null:
		return
	voice.stream = place_stream
	voice.play()


## One card drawn (either player). Simultaneous draws play once. The pick is a
## cosmetic roll, so it never touches the seeded match.
func take_card() -> void:
	if take_streams.is_empty():
		return
	var frame := Engine.get_physics_frames()
	if frame - last_take_frame <= TAKE_SAME_FRAMES:
		return
	last_take_frame = frame
	var voice := _voice()
	if voice == null:
		return
	voice.stream = take_streams[randi() % take_streams.size()]
	voice.play()


## The saved volume (read once, then applied to the Master bus).
static func get_volume() -> float:
	if volume < 0.0:
		volume = VOLUME_DEFAULT
		var cfg := ConfigFile.new()
		if cfg.load(SETTINGS_FILE) == OK:
			volume = clampf(float(cfg.get_value("audio", "volume", VOLUME_DEFAULT)), 0.0, 1.0)
		_apply_volume()
	return volume


static func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	_apply_volume()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_FILE)
	cfg.set_value("audio", "volume", volume)
	cfg.save(SETTINGS_FILE)


## Squared, so the slider's middle sounds like half volume rather than nearly full.
static func _apply_volume() -> void:
	AudioServer.set_bus_mute(0, volume <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume * volume, 0.0001)))


## A free voice, or the first one if everything is busy (a card game never needs
## more than a handful at once).
func _voice() -> AudioStreamPlayer:
	for v in voices:
		if not v.playing:
			return v
	return voices[0] if not voices.is_empty() else null
