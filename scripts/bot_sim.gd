class_name DDBotSim
extends Node

## Headless A/B harness for bot tuning.
##
##   godot --headless --path . --fixed-fps 60 -- --botsim=<seed>
##
## Player 0 and player 1 both run a bot; one of them is DDBot2 and the other the
## baseline DDBot. Which side is decided by seed parity, so running even numbers
## of seeds cancels lane bias. Prints one BOTSIM line and quits.

const TIME_LIMIT := 170.0   ## safety net; the arena ends a 150 s match itself

var arena = null
var seed_value := 0
var v2_team := 0
var elapsed := 0.0
var started := false


func setup(a, s: int) -> void:
	arena = a
	seed_value = s


func _ready() -> void:
	# seed >= 100 is a control run: baseline vs baseline, to separate "my bot is
	# better" from "this side of the board is easier"
	if seed_value >= 100:
		_control(seed_value - 100)
		return
	v2_team = seed_value % 2
	arena.bot_players = [true, true]
	arena.match_over = false
	arena.winner = -1
	# reproducible decks, and the two abilities handed out evenly across seeds so
	# neither bot gets the better hero power
	arena._build_decks(seed_value * 977 + 31)
	var ability_first := int(float(seed_value) / 2.0) % 2 == 0
	arena.ability = ["tentacle", "shiesty"] if ability_first else ["shiesty", "tentacle"]
	arena._setup_bots()
	var other = arena.bots[v2_team]
	if other != null and is_instance_valid(other):
		other.queue_free()
	var b := DDBot2.new()
	b.enabled = true
	b.setup(arena, v2_team, 4242 + seed_value * 13)
	arena.add_child(b)
	arena.bots[v2_team] = b
	started = true
	print("BOTSIM start seed=%d v2=%d" % [seed_value, v2_team])


func _control(s: int) -> void:
	seed_value = s
	v2_team = -1
	arena.bot_players = [true, true]
	arena.match_over = false
	arena.winner = -1
	arena._build_decks(s * 977 + 31)
	arena.ability = ["tentacle", "shiesty"] if int(float(s) / 2.0) % 2 == 0 else ["shiesty", "tentacle"]
	arena._setup_bots()
	started = true
	print("BOTSIM start seed=%d v2=-1" % seed_value)


func _process(delta: float) -> void:
	if arena == null or not started:
		return
	elapsed += delta
	if arena.match_over or elapsed >= TIME_LIMIT:
		_finish()


func _finish() -> void:
	started = false
	set_process(false)
	var hp := [0.0, 0.0]
	var towers_left := [0, 0]
	for tw in arena.towers:
		if is_instance_valid(tw) and not tw.dead:
			hp[int(tw.team)] += float(tw.hp)
			towers_left[int(tw.team)] += 1
	var plays := [0, 0]
	var spent := [0.0, 0.0]
	for p in 2:
		if arena.bots[p] != null and is_instance_valid(arena.bots[p]):
			plays[p] = int(arena.bots[p].plays)
			spent[p] = float(arena.bots[p].gold_spent)
	print("BOTSIM result seed=%d v2=%d winner=%d time=%.1f hp0=%.0f hp1=%.0f tow0=%d tow1=%d plays0=%d plays1=%d gold0=%.0f gold1=%.0f" % [
		seed_value, v2_team, int(arena.winner), elapsed, hp[0], hp[1],
		towers_left[0], towers_left[1], plays[0], plays[1], spent[0], spent[1]])
	get_tree().quit()
