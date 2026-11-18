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


## A free voice, or the first one if everything is busy (a card game never needs
## more than a handful at once).
func _voice() -> AudioStreamPlayer:
	for v in voices:
		if not v.playing:
			return v
	return voices[0] if not voices.is_empty() else null
