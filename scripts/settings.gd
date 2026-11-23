extends RefCounted

## Player options kept in user://settings.cfg (the same file DDSfx keeps the
## master volume in): sound and music levels, and each side's colour. No
## class_name: preload it (`const Settings := preload("res://scripts/settings.gd")`).
##
## A side's colour is either a fixed pick from PALETTE (or any colour set by
## hand) or, with `commander` on, the colour of whichever commander that side
## gets in the match (arena.commander_color). The title screen's axes show the
## fixed picks, since no commander is chosen there yet.

const FILE := "user://settings.cfg"

## the defaults are the arena's own Left_Color / Right_Color
const LEFT_DEFAULT := Color(0.306, 0.517, 0.151)
const RIGHT_DEFAULT := Color(0.168, 0.578, 0.523)

## The swatches the options page offers.
const PALETTE := [
	Color(0.306, 0.517, 0.151), Color(0.168, 0.578, 0.523), Color(0.12, 0.47, 0.86),
	Color(0.36, 0.25, 0.65), Color(0.72, 0.3, 0.85), Color(0.86, 0.22, 0.42),
	Color(0.82, 0.22, 0.14), Color(0.94, 0.47, 0.1), Color(0.85, 0.68, 0.12),
	Color(0.45, 0.33, 0.22), Color(0.4, 0.42, 0.48), Color(0.16, 0.13, 0.2),
]

static var _loaded := false
static var sfx := 1.0
static var music := 1.0
## [left, right]
static var colors: Array = [LEFT_DEFAULT, RIGHT_DEFAULT]
static var commander: Array = [false, false]


static func ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(FILE) != OK:
		return
	sfx = clampf(float(cfg.get_value("audio", "sfx", 1.0)), 0.0, 1.0)
	music = clampf(float(cfg.get_value("audio", "music", 1.0)), 0.0, 1.0)
	colors = [cfg.get_value("colors", "left", LEFT_DEFAULT), cfg.get_value("colors", "right", RIGHT_DEFAULT)]
	for i in 2:
		if not (colors[i] is Color):
			colors[i] = [LEFT_DEFAULT, RIGHT_DEFAULT][i]
	commander = [bool(cfg.get_value("colors", "left_commander", false)),
		bool(cfg.get_value("colors", "right_commander", false))]


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(FILE)  # keep the keys other code owns (the master volume)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("audio", "music", music)
	cfg.set_value("colors", "left", colors[0])
	cfg.set_value("colors", "right", colors[1])
	cfg.set_value("colors", "left_commander", commander[0])
	cfg.set_value("colors", "right_commander", commander[1])
	cfg.save(FILE)


static func side_color(side: int) -> Color:
	ensure()
	return colors[clampi(side, 0, 1)]


## A 0..1 level as a dB offset, squared like the master slider so the middle
## sounds like half.
static func level_db(v: float) -> float:
	return linear_to_db(maxf(v * v, 0.0001))
