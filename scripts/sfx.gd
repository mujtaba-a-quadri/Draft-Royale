class_name DDSfx
extends Node

## Card sounds. Every file is a Pixabay recording, credited in its own name.
##
## "opening hand" is one take containing EIGHT card draws. A four card deal takes
## a random window of four of those eight, so the opening never sounds identical
## twice; a single draw (the 8 second hand growth) takes one slice the same way.

const DRAW_FILE := "res://SFX/freesound_community opening hand.mp3"
const PLACE_FILE := "res://SFX/oxidvideos-place cardmp3.mp3"
const DRAW_SLICES := 8
const VOICES := 6

var draw_stream: AudioStream = null
var place_stream: AudioStream = null
var slice_seconds := 0.0
var voices: Array[AudioStreamPlayer] = []


func _ready() -> void:
	draw_stream = load(DRAW_FILE)
	place_stream = load(PLACE_FILE)
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
	get_tree().create_timer(length).timeout.connect(func() -> void:
		if is_instance_valid(voice) and voice.playing:
			voice.stop())


func place_card() -> void:
	if place_stream == null:
		return
	var voice := _voice()
	if voice == null:
		return
	voice.stream = place_stream
	voice.play()


## A free voice, or the first one if everything is busy (a card game never needs
## more than a handful at once).
func _voice() -> AudioStreamPlayer:
	for v in voices:
		if not v.playing:
			return v
	return voices[0] if not voices.is_empty() else null
