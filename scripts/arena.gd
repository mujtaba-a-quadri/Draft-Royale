class_name Arena
extends Node2D

## Board shape: 30 rows tall. Rows 1..10 (top) and 19..28 (bottom) are 16 tiles
## wide; the middle band of 8 rows (11..18) bulges out to 18 tiles. The band is
## neutral no-man's land: you may only deploy inside it on tiles your ground
## troops have claimed within the last CLAIM_TIME seconds.

## Board shape and orientation live in DDBoard (scripts/board.gd) so units, bots
## and panels can share them; these aliases keep every TILE / ORIGIN / GRID_W
## reference in this file (and every caller's arena.TILE) working.
const TILE := DDBoard.TILE
const ORIGIN := DDBoard.ORIGIN
const GRID_W := DDBoard.GRID_W
const GRID_H := DDBoard.GRID_H
const OUTER_COL_MIN := DDBoard.OUTER_COL_MIN
const OUTER_COL_MAX := DDBoard.OUTER_COL_MAX
const BAND_TOP := DDBoard.BAND_TOP
const BAND_BOTTOM := DDBoard.BAND_BOTTOM
const RIVER_TOP := 14
const RIVER_BOTTOM := 15
const BRIDGE_COL_A := 5.0
const BRIDGE_COL_B := 13.0
## This match's bridges, each [middle x, half width] in tile columns (see
## BRIDGE_HALF below). Runs, elites, the bot sim and the dev scenarios keep the
## two 3-tile bridges; a plain match has three: a 4-tile one in the middle and a
## 2.5-tile one a tile in from each edge (`--bridges=2|3` forces either).
const TWO_BRIDGES := [[5.0, 1.5], [13.0, 1.5]]
const THREE_BRIDGES := [[2.25, 1.25], [9.0, 2.0], [15.75, 1.25]]
var bridges: Array = TWO_BRIDGES
const CLAIM_TIME := 4.0
const TOWER_BUFFER := 3.5
const ABILITY_COST := 2
const ABILITY_COOLDOWN := 15.0
## The match clock runs in three phases (`phase`, Phase):
##   SINGLE  single gold, `single_len` s (a plain match and run fight 1: 90 s;
##           each later regular run fight +SINGLE_STEP; an elite ELITE_SINGLE)
##   DOUBLE  double gold, half as long. If either side has a tower lead when it
##           ends, the lead wins. Otherwise (and always in an elite fight)...
##   SUDDEN  sudden death, quadruple gold, half as long again (SUDDEN_MIN at the
##           least): the next tower to fall loses the match for its owner. In
##           an elite fight only the commander or the boss ends it.
## From DOUBLE on (`overtime`): half ability cooldowns, draws two seconds faster.
## match_time_left is the time left in the current phase.
enum Phase { SINGLE, DOUBLE, SUDDEN }
const SINGLE_TIME := 90.0
const SINGLE_STEP := 15.0
const ELITE_SINGLE := 120.0
const SUDDEN_MIN := 30.0
const PHASE_GOLD := [1.0, 2.0, 4.0]
const OVERTIME_DRAW_CUT := 2.0
const TENTACLE_HP := 35.0
## the hold squeezes: TENTACLE_DMG on the grab and every TENTACLE_INTERVAL after
const TENTACLE_DMG := 7.0
const TENTACLE_INTERVAL := 1.6
const TENTACLE_TIME := 4.0


## Everything the tentacle's squeezes add up to over a full hold.
static func tentacle_total_damage() -> float:
	return TENTACLE_DMG * float(int(ceil(TENTACLE_TIME / TENTACLE_INTERVAL)))
const GOBLIN_DMG := 30.0

## Every commander's ability, the random pool a match (and a run) draws from.
## tentacle: the jelly; shiesty: the goblin; flame: Flammenmeister; drone:
## Man-Mantis. The last two are aimed: the button arms them, the next click on a
## unit fires them (use_ability_on).
const ABILITIES := ["tentacle", "shiesty", "flame", "drone"]
const AIMED_ABILITIES := ["flame", "drone"]
## Flammenmeister (1 gold): on a friendly unit, FLAME_REGEN hp a second for
## FLAME_REGEN_TIME s; on an enemy unit, a firebolt from his tower with
## FLAME_BOLT_BURN burn (the Firebolt card's is 60).
const FLAME_COST := 1
const FLAME_REGEN := 6.0
const FLAME_REGEN_TIME := 4.0
const FLAME_BOLT_BURN := 30.0
## Man-Mantis (2 gold): the drone eats DRONE_DPS a second out of an enemy unit
## until it dies, then a parasite bursts out on the caster's side. Its size by
## the damage the drone did: up to each PARASITE_TIERS limit, that tier's unit.
const DRONE_DPS := 5.0
const PARASITE_TIERS := [[20.0, "parasite1"], [60.0, "parasite2"], [150.0, "parasite3"], [INF, "parasite4"]]


## A hit of `amount` on a body of `victim_team`, after the attacker's Puissance
## and the victim's Armor. Every direct hit on a unit, tower or boss passes
## through here (their take_damage); damage over time does not (dot_hit). A
## direct hit always comes from the other side, so the attacker is never
## needed. With both at zero the hit is returned untouched, bit for bit.
func scale_hit(amount: float, victim_team: int) -> float:
	if dot_hit:
		# consumed by the tick itself, so anything its death sets off (a
		# snowman's blast) counts as a direct hit again
		dot_hit = false
		return amount
	if amount <= 0.0 or victim_team < 0 or victim_team > 1:
		return amount
	var p: float = float(puissance[1 - victim_team])
	var a: float = float(armor[victim_team])
	if p == 0.0 and a == 0.0:
		return amount
	return maxf(1.0, amount + p - a)


## A damage-over-time tick (burn, poison, the drone) on `body`, from its own
## spot: marked so Puissance and Armor leave it alone.
func tick_damage(body: Node, amount: float) -> void:
	dot_hit = true
	body.take_damage(amount, body.position)
	dot_hit = false


func add_puissance(team: int, n: float) -> void:
	puissance[team] = float(puissance[team]) + n


func add_armor(team: int, n: float) -> void:
	armor[team] = float(armor[team]) + n


# ----------------------------------------   b----------------------------- relics

func has_relic(team: int, id: String) -> bool:
	return team >= 0 and team <= 1 and (relics[team] as Array).has(id)


## The start-of-fight relics: Puissance, Armor, the commander's heal.
func _apply_relics_start() -> void:
	for team in 2:
		for id in relics[team]:
			var d: Dictionary = RELIC_DB.get_relic(String(id))
			if d.has("start_puissance"):
				add_puissance(team, float(d["start_puissance"]))
			if d.has("start_armor"):
				add_armor(team, float(d["start_armor"]))
			if d.has("start_heal"):
				var king: Node = _king_of(team)
				if king != null and is_instance_valid(king):
					king.hp = minf(float(king.max_hp), float(king.hp) + float(d["start_heal"]))


## How much harder `team`'s king tower hits (the Warlord's Horn).
func king_mult(team: int) -> float:
	var m := 1.0
	for id in relics[team]:
		m *= float(RELIC_DB.get_relic(String(id)).get("king_mult", 1.0))
	return m


## A card was just played: the Hourglass starts over, and each windowed relic
## notes the time, drops what has fallen out of its window, and fires (then
## empties) once it holds enough.
func _relics_card_played(team: int) -> void:
	if (relics[team] as Array).is_empty():
		return
	relic_idle[team] = 0.0
	for id in relics[team]:
		var w: Dictionary = RELIC_DB.get_relic(String(id)).get("window", {})
		if w.is_empty():
			continue
		var plays: Array = relic_window(team, String(id))
		plays.append(fight_t)
		if plays.size() >= int(w["need"]):
			plays.clear()
			_relic_fire(team, String(id), String(w["gives"]))
		relic_plays[team][String(id)] = plays


## The plays still inside a windowed relic's window, oldest first (pruned now).
func relic_window(team: int, id: String) -> Array:
	var w: Dictionary = RELIC_DB.get_relic(id).get("window", {})
	var plays: Array = relic_plays[team].get(id, [])
	if w.is_empty():
		return plays
	while not plays.is_empty() and fight_t - float(plays[0]) > float(w["secs"]):
		plays.pop_front()
	relic_plays[team][id] = plays
	return plays


func _tick_relics(team: int, delta: float, income: float, gold_before: float = 0.0) -> void:
	relic_idle[team] = float(relic_idle[team]) + delta
	for id in relics[team]:
		var d: Dictionary = RELIC_DB.get_relic(String(id))
		if d.has("window"):
			# the oldest card falls out of the window on time, not only on a play
			relic_window(team, String(id))
		if d.has("idle"):
			var secs: float = float(d["idle"]["secs"])
			if float(relic_idle[team]) >= secs:
				relic_idle[team] = float(relic_idle[team]) - secs
				_relic_fire(team, String(id), "draw")
		if d.has("ledger"):
			var every: int = int(d["ledger"]["every"])
			var before: int = int(floorf(float(relic_income[team])))
			var after: int = int(floorf(float(relic_income[team]) + income))
			for n in range(before + 1, after + 1):
				if n % every == 0:
					_relic_fire(team, String(id), "gold")
		if d.has("lucky"):
			# only the income itself crossing the line counts, not a gold gift
			var line: float = float(d["lucky"]["at"])
			if gold_before < line and float(gold[team]) >= line:
				_relic_fire(team, String(id), "gold")
		if d.has("pearl"):
			_tick_pearl(team, String(id))
	relic_income[team] = float(relic_income[team]) + income


## The Abyssal Pearl, per team. READY: it waits on the relic bar. The moment
## the team is down to no whole gold it floats down and becomes their first
## gold (BANKED); the gold that was filling carries on as the second. Spent
## (no whole gold again), it floats back up and RESTs until a first gold of
## the team's own has come in, then is READY to drop at the next 0.
const PEARL_READY := 0
const PEARL_BANKED := 1
const PEARL_RESTING := 2
## How long the pearl takes to float between the bar and the purse.
const PEARL_FLIGHT := 0.7
var pearl_state := [PEARL_READY, PEARL_READY]
## clock time the pearl's current flight started (-1: none), and which way
var pearl_fly := [-1.0, -1.0]
var pearl_down := [false, false]
## where side 0's pearl medal was last drawn: the flight's top end
var pearl_bar_at := Vector2(-1.0, -1.0)


func _tick_pearl(team: int, id: String) -> void:
	var g: float = float(gold[team])
	match int(pearl_state[team]):
		PEARL_READY:
			if g < 1.0:
				gold[team] = g + 1.0
				pearl_state[team] = PEARL_BANKED
				_pearl_launch(team, true)
				relic_glow["%d:%s" % [team, id]] = 0.8
				relic_fires[id] = int(relic_fires.get(id, 0)) + 1
		PEARL_BANKED:
			if g < 1.0:
				pearl_state[team] = PEARL_RESTING
				_pearl_launch(team, false)
		PEARL_RESTING:
			if g >= 1.0:
				pearl_state[team] = PEARL_READY


func _pearl_launch(team: int, down: bool) -> void:
	# only side 0 has a relic bar to fly from; the other side's pearl just appears
	if team != 0 or pearl_bar_at.x < 0.0:
		pearl_fly[team] = -1.0
		return
	pearl_fly[team] = clock
	pearl_down[team] = down


## How far through its flight `team`'s pearl is (0..1), or -1 when it is not flying.
func pearl_flight(team: int) -> float:
	if float(pearl_fly[team]) < 0.0:
		return -1.0
	var u: float = (clock - float(pearl_fly[team])) / PEARL_FLIGHT
	if u >= 1.0:
		pearl_fly[team] = -1.0
		return -1.0
	return u


## Is `team`'s pearl sitting in the purse as its first gold (landed, not flying)?
func pearl_in_purse(team: int) -> bool:
	return int(pearl_state[team]) == PEARL_BANKED and pearl_flight(team) < 0.0


## Is `team`'s pearl at home in its medal on the bar?
func pearl_at_bar(team: int) -> bool:
	return int(pearl_state[team]) != PEARL_BANKED and pearl_flight(team) < 0.0


func pearl_coin_at(team: int) -> Vector2:
	return tile_center(17.5, 29.5 if team == 0 else 0.5)


## The pearl on its way between the bar and the purse: an eased drift with a
## slow sideways sway and a few fading glints behind it. Drawn over the coins.
func _draw_pearl_flights() -> void:
	var u: float = pearl_flight(0)
	if u < 0.0:
		return
	var a: Vector2 = pearl_bar_at
	var b: Vector2 = pearl_coin_at(0)
	if not bool(pearl_down[0]):
		var sw := a
		a = b
		b = sw
	var r: float = TILE * 0.3
	for k in range(5, -1, -1):
		var uk: float = clampf(u - float(k) * 0.035, 0.0, 1.0)
		var e: float = uk * uk * (3.0 - 2.0 * uk)
		var p: Vector2 = a.lerp(b, e) + Vector2(sin(uk * PI * 2.0) * TILE * 0.35, 0.0)
		if k == 0:
			draw_circle(p, r * 1.9, Color(0.85, 0.85, 1.0, 0.22))
			DDArt.pearl(self, p, r * 1.05)
		else:
			draw_circle(p, r * (0.5 - 0.06 * float(k)), Color(0.9, 0.9, 1.0, 0.5 - 0.07 * float(k)))


func _relic_fire(team: int, id: String, gives: String) -> void:
	if gives == "gold":
		gold[team] = minf(gold_max, float(gold[team]) + 1.0)
	elif gives == "draw":
		draw_card(team)
	relic_glow["%d:%s" % [team, id]] = 0.8
	relic_fires[id] = int(relic_fires.get(id, 0)) + 1


## How far round a relic's ring is (0..1) and the count it shows (-1: none).
## A windowed relic: the oldest card still counting, as a share of the window,
## and how many cards are in it. The Hourglass: the wait so far. The Ledger:
## progress to the next doubled gold, and which gold of the four it is on.
func relic_progress(team: int, id: String) -> Array:
	var d: Dictionary = RELIC_DB.get_relic(id)
	if d.has("window"):
		var plays: Array = relic_window(team, id)
		if plays.is_empty():
			return [0.0, 0]
		return [clampf((fight_t - float(plays[0])) / float(d["window"]["secs"]), 0.0, 1.0), plays.size()]
	if d.has("idle"):
		return [clampf(float(relic_idle[team]) / float(d["idle"]["secs"]), 0.0, 1.0), -1]
	if d.has("lucky"):
		# the way up to the lucky line; full (and quiet) once past it
		var at := float(d["lucky"]["at"])
		return [clampf(float(gold[team]) / at, 0.0, 1.0) if float(gold[team]) < at else 0.0, -1]
	if d.has("pearl") and int(pearl_state[team]) == PEARL_RESTING:
		# resting: the ring is the first gold of your own coming in
		return [clampf(float(gold[team]), 0.0, 1.0), -1]
	if d.has("ledger"):
		var every := float(d["ledger"]["every"])
		var inc := float(relic_income[team])
		return [fmod(inc, every) / every, int(fmod(inc, every))]
	return [0.0, -1]


## The relic column, in the margin left of the board under the run's lines:
## one column of big medallions with their names while there are a few, two
## columns of medallions once there are more. Ringed relics show their clock.
## The one under the mouse explains itself.
func _draw_relics() -> void:
	relic_hits = []
	var list: Array = relics[0]
	if list.is_empty():
		return
	var font := ThemeDB.fallback_font
	var top: float = ORIGIN.y + 140.0 if (Run.active and not Run.encounter().is_empty()) else ORIGIN.y + 10.0
	var two_cols: bool = list.size() > 6
	var rad: float = 24.0 if two_cols else 26.0
	var row_h: float = 66.0 if two_cols else 68.0
	draw_string(font, Vector2(16.0, top), "RELICS", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.86, 0.55, 0.9))
	for i in list.size():
		var id := String(list[i])
		var col: int = i % 2 if two_cols else 0
		var row: int = int(i / 2) if two_cols else i
		var c := Vector2(16.0 + rad + float(col) * 100.0, top + 18.0 + rad + float(row) * row_h)
		var prog: Array = relic_progress(0, id)
		var empty := false
		if RELIC_DB.get_relic(id).has("pearl"):
			pearl_bar_at = c
			empty = not pearl_at_bar(0)
		DDArt.relic_medal(self, id, c, rad, float(prog[0]), int(prog[1]),
			float(relic_glow.get("0:%s" % id, 0.0)), fight_t, empty)
		if not two_cols:
			draw_string(font, Vector2(c.x + rad + 10.0, c.y + 5.0), RELIC_DB.relic_name(id), HORIZONTAL_ALIGNMENT_LEFT,
				ORIGIN.x - (c.x + rad + 10.0) - 6.0, 14, Color(0.92, 0.9, 0.84))
		relic_hits.append({"id": id, "c": c, "r": rad})
	var m := get_global_mouse_position()
	for h in relic_hits:
		if m.distance_to(h["c"]) <= float(h["r"]):
			_draw_relic_tip(String(h["id"]), h["c"] + Vector2(float(h["r"]) + 10.0, -float(h["r"])))


func _draw_relic_tip(id: String, at: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var w := 280.0
	var body := String(RELIC_DB.get_relic(id).get("text", ""))
	var body_h: float = font.get_multiline_string_size(body, HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, 13).y
	var box := Rect2(at, Vector2(w, 34.0 + body_h))
	draw_rect(box, Color(0.08, 0.07, 0.11, 0.96), true)
	draw_rect(box, Color(1.0, 0.88, 0.5, 0.9), false, 2.0)
	draw_string(font, box.position + Vector2(10.0, 22.0), RELIC_DB.relic_name(id), HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, 16,
		Color(1.0, 0.9, 0.6))
	draw_multiline_string(font, box.position + Vector2(10.0, 42.0), body, HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, 13, -1,
		Color(0.9, 0.9, 0.92))


## Which parasite a drone that did `dealt` damage leaves behind.
static func parasite_for(dealt: float) -> String:
	for tier in PARASITE_TIERS:
		if dealt <= float(tier[0]):
			return String(tier[1])
	return "parasite4"

## Orientation. LANDSCAPE = true  â†’ your half on the LEFT, enemy on the RIGHT,
##                                   hand along the bottom of the screen.
##              LANDSCAPE = false â†’ the original portrait board: your half at the
##                                   BOTTOM, enemy at the top, hands on the sides.
## Everything else (simulation, art, effects) is orientation-agnostic â€” flip this
## one flag and the board turns, provided the HUD is laid out to match.
const LANDSCAPE := DDBoard.LANDSCAPE

##const GRASS_A := Color(0.45, 0.72, 0.38)
##const GRASS_B := Color(0.38, 0.62, 0.32)



const GRASS_A := Color(0.149, 0.42, 0.58, 1.0)
const GRASS_B := Color(0.33, 0.46, 0.24)
var BAND_A := GRASS_A.darkened(TEAM_INK_DARKEN-0.2)
var BAND_B := GRASS_B.darkened(TEAM_INK_DARKEN-0.2)
const WATER := Color(0.678, 0.332, 0.139, 1.0)
const WATER_HI := Color(0.176, 0.007, 0.001, 1.0)
const WOOD := Color(0.62, 0.45, 0.3)
const Left_Color := Color(0.306, 0.517, 0.151, 1.0)
const Right_Color := Color(0.168, 0.578, 0.523, 1.0)

## Team colours are data, not literals: these two entries are the only reason
## you are blue and your opponent is red. Override them from a menu, a relic, a
## match type â€” or --colors=#ff8800,#22ccaa on the command line.
var team_colors: Array = [Left_Color, Right_Color]:
	set(value):
		team_colors = value
		# the control tint is a cached layer: repaint it for a colour change too
		if control_layer != null:
			control_layer.queue_redraw()

## Trial art: side towers drawn as diamonds (--towers=diamond). Looks only; the
## hitbox stays the 0.9-tile circle.
var diamond_towers := false

## The card face's trim (border, art frame, summon coin, description edge) and
## its middle line (the band under the art). Set them here in the inspector, or
## --trim=#hex / --line=#hex on the command line.
@export var card_trim := DDCardFace.TRIM_DEFAULT:
	set(value):
		card_trim = value
		DDCardFace.trim = value
@export var card_line := DDCardFace.LINE_DEFAULT:
	set(value):
		card_line = value
		DDCardFace.line = value

## Every unit, tower and tile tint is drawn in its team colour; unit outlines are
## a darker shade of it instead of black.
const TEAM_INK_DARKEN := 0.45

var towers: Array = []
var units: Array = []
## enemies that killed an ant lately: "antteam:id" -> {node, team, until (frame)}
var ant_marks: Dictionary = {}
var gold := [4.2, 4.2]
var gold_max := 10.0
var gold_rate := 1.0 / 2.4
## Remaining casts for cards that carry more than one (player -> card id -> casts).
## A card is only listed here once it has been used; an absent entry means "full".
var charges := [{}, {}]
## Every card in a hand or deck is one copy with its own id, so a deck can hold
## duplicates. hand_ids / queue_ids run parallel to hands / queues (which stay
## lists of kinds for everything that only asks "what card is this").
var hand_ids := [[], []]
var queue_ids := [[], []]
var next_card_id := 1
## The cards each player's deck is built from; empty means one of every card in
## DDCard.ORDER. Repeats are allowed.
var deck_lists := [[], []]

## Seconds left in the match, and whether the closing window is live.
var match_time_left := SINGLE_TIME
var overtime := false
var phase: int = Phase.SINGLE
var single_len := SINGLE_TIME
## an elite fight: a side tower lead never ends it, it always goes to sudden death
var elite_fight := false
const PHASE_CALL_SCRIPT := preload("res://scripts/phase_call.gd")
var phase_call: Node2D = null
const HAND_MAX := 6
## Cards dealt into each hand at the start of a match.
const OPENING_HAND := 3
## A draw every DRAW_INTERVAL seconds, and every gold spent takes DRAW_PER_GOLD
## seconds off the wait for the next one (spend 5, draw 5 s sooner).
const DRAW_INTERVAL := 10.0
const DRAW_PER_GOLD := 1.0
var draw_timer := [DRAW_INTERVAL, DRAW_INTERVAL]
var hands := [[], []]
var queues := [[], []]
var selected_player := -1
var selected_index := -1

## A placement the player clicked on but cannot pay for yet (they were less than
## one coin short). Nothing is spent until it actually plays itself.
var staged := {"player": -1, "index": -1, "kind": "", "at": Vector2.ZERO}
## Card sounds (DDSfx): the deal and every placement.
var sfx: Node = null

## Re-entrancy guard for reflective damage (hedgehog quills poking back).
var damage_guard := 0

## Card whose cost is flashing after a placement the player cannot afford.
var reject := {"player": -1, "index": -1, "timer": 0.0}
const REJECT_TIME := 0.7
var match_over := false
var winner := -1
var clock := 0.0
var banner_text := ""
var banner_timer := 0.0
var shake_amount := 0.0
var shake_offset := Vector2.ZERO
var panels: Array = []
var volume_slider: HSlider = null
## The all-cards overlay (a reusable filtered, scrolling card grid).
var shelf_grid: DDCardGrid = null
var view_mode := 0
var bots: Array = [null, null]
var bot_players := [false, true]
var debug_shelf := false
var debug_kind := ""
var ability := ["tentacle", "shiesty"]
var ability_cd := [ABILITY_COOLDOWN, ABILITY_COOLDOWN]
## Per player: does the hero ability pay a card when its payload lands
## (tentacle on death, Shiesty home or caught)? Off by default; meant to come
## from a relic. See ability_payoff().
var ability_draws := [false, false]
## The player whose aimed ability (flame, drone) is armed and waiting for a
## click on a unit, or -1. Right-click or Esc puts it away.
var ability_aim := -1
## Per-fight scaling, per team (Slay the Spire's Strength and Dexterity):
## Puissance adds that much to every direct hit the team lands; Armor takes that
## much off every direct hit the team takes (never below 1). Damage over time
## (burn, poison, the drone) is untouched. Both live and die with the arena, so
## every fight starts from the run's base (Run.puissance / Run.armor, for
## relics) and builds from there. See scale_hit().
var puissance := [0.0, 0.0]
var armor := [0.0, 0.0]
## True only while a damage-over-time tick is being dealt (tick_damage), so
## scale_hit leaves it alone.
var dot_hit := false

## Relics (scripts/relic_db.gd), per team: side 0's come from the run (or
## --relics=a,b for a plain match); side 1 has none yet. Their timers run on
## fight_t, the fight's own physics clock, so they are deterministic.
const RELIC_DB := preload("res://scripts/relic_db.gd")
const Settings := preload("res://scripts/settings.gd")
var relics := [[], []]
var fight_t := 0.0
## per team, per windowed relic id: the fight_t of each card played that is
## still inside that relic's window (oldest first)
var relic_plays := [{}, {}]
## per team: seconds since the last card played (the Hourglass)
var relic_idle := [0.0, 0.0]
## per team: gold earned over time this fight, before the cap (Miser's Ledger)
var relic_income := [0.0, 0.0]
## "team:id" -> seconds left of the glow a relic gives off when it fires
var relic_glow := {}
## the relic icons as last drawn, for the tooltip and tests: [{id, c, r}]
var relic_hits: Array = []
var forced_relics: Array = []
## how many times each relic has fired this fight (tests, and the curious)
var relic_fires := {}
var stat_shiesty_escaped := 0
var stat_shiesty_caught := 0
var control := [[], []]
var control_layer: Node2D = null
var preview: Node2D = null
var unit_tiles := {}
var reservations := {}


func _ready() -> void:
	# a pause survives reload_current_scene (R, or a run moving on): never start paused
	get_tree().paused = false
	for t in 2:
		var arr: Array = []
		arr.resize(GRID_W * GRID_H)
		arr.fill(false)
		control[t] = arr
	var forced := ""
	var colors_forced := false
	for a in OS.get_cmdline_user_args():
		# the bot sim and the dev captures keep the stock colours, so their output
		# does not depend on what this machine picked in the options
		if a.begins_with("--botsim=") or a.begins_with("--scenario=") or a.begins_with("--shots=") or a == "--demo":
			colors_forced = true
		if a == "--bots=both":
			bot_players = [true, true]
		elif a == "--bots=off":
			bot_players = [false, false]
		elif a.begins_with("--ability="):
			forced = a.substr(10)
		elif a.begins_with("--relics="):
			for rid in String(a.substr(9)).split(",", false):
				if not RELIC_DB.get_relic(rid).is_empty():
					forced_relics.append(rid)
		elif a.begins_with("--colors="):
			var parts := String(a.substr(9)).split(",")
			if parts.size() == 2:
				colors_forced = true
				team_colors = [
					Color.from_string(String(parts[0]).strip_edges(), Left_Color),
					Color.from_string(String(parts[1]).strip_edges(), Right_Color),
				]
		elif a == "--towers=diamond":
			diamond_towers = true
		elif a.begins_with("--trim="):
			card_trim = Color.from_string(a.substr(7), card_trim)
		elif a.begins_with("--line="):
			card_line = Color.from_string(a.substr(7), card_line)
	# the static colours outlive a scene reload: make them this arena's
	DDCardFace.trim = card_trim
	DDCardFace.line = card_line
	# two different commanders out of the pool; --ability= fixes yours (the enemy
	# still gets a random other one)
	if forced == "goblin":
		forced = "shiesty"
	elif forced == "flammenmeister":
		forced = "flame"
	elif forced == "manmantis" or forced == "mantis":
		forced = "drone"
	var arng := RandomNumberGenerator.new()
	arng.randomize()
	var mine: String = forced if ABILITIES.has(forced) else String(ABILITIES[arng.randi() % ABILITIES.size()])
	var rest: Array = ABILITIES.duplicate()
	rest.erase(mine)
	ability = [mine, String(rest[arng.randi() % rest.size()])]
	var in_run := _apply_run()
	# after the run, which brings its own commanders
	if not colors_forced:
		_apply_color_settings()
	for rid in forced_relics:
		if not (relics[0] as Array).has(rid):
			relics[0].append(rid)
	_pick_bridges(in_run)
	_build_board_state()
	if in_run:
		# the run's commander comes in as wounded as it left the last fight; the
		# side towers (and the enemy's commander) are fresh every time
		var king := _king_of(0)
		if king != null:
			king.hp = minf(float(king.max_hp), float(Run.commander_hp))
	_apply_relics_start()
	_build_control_layer()
	_build_preview()
	_build_decks(Run.deck_seed() if in_run else -1)
	_build_sfx()
	_build_hud()
	_build_shelf()
	_setup_bots()
	# the clock: run fights get longer by SINGLE_STEP per regular fight before
	# this one (an elite resets it to its own as it starts)
	var single := SINGLE_TIME
	if in_run:
		single += SINGLE_STEP * float(Run.battles_before(Run.floor_index))
	setup_clock(single)
	_dev_hook()
	if in_run:
		var elite := String(Run.encounter().get("elite", ""))
		if elite == "spider":
			start_spider_encounter.call_deferred()
		elif elite == "kraken":
			start_kraken_encounter.call_deferred()
		else:
			banner_flash("Fight %d of %d  —  %s" % [Run.floor_index + 1, Run.ACT.size(), String(Run.encounter()["name"])])
	queue_redraw()


## The run layer (scripts/run_state.gd, autoload "Run"). Pressing play starts a
## run; `--match` plays one plain match instead, and the bot sim and dev
## scenarios (`--botsim=`, `--scenario=`, `--shots=`, `--demo`) never start one
## unless `--run` / `--run=<seed>` asks. While a run is going, this match is its
## current fight: your run deck against the encounter's, a bot on the other side,
## abilities from the run. Returns whether this match is part of a run.
func _apply_run() -> bool:
	if not Run.active:
		# the title screen's choice wins; launched straight in, a run is the default
		var want := Run.menu_choice != "match"
		var run_seed := -1
		for a in OS.get_cmdline_user_args():
			if a == "--match" or a.begins_with("--botsim=") or a.begins_with("--scenario=") \
					or a.begins_with("--shots=") or a == "--demo":
				want = false
		for a in OS.get_cmdline_user_args():
			if a == "--run" or a.begins_with("--run="):
				want = true
				if a.begins_with("--run="):
					run_seed = int(a.substr(6))
		if want:
			Run.start(run_seed)
	if not Run.active or Run.encounter().is_empty():
		return false
	deck_lists = [Run.deck.duplicate(), (Run.encounter().get("deck", []) as Array).duplicate()]
	# side 1 is always the encounter's bot; side 0 is yours (or a bot with --bots=both)
	bot_players[1] = true
	ability = [Run.ability, Run.enemy_ability()]
	# the run's base scaling for your side; the fight builds on it
	puissance[0] = float(Run.puissance)
	armor[0] = float(Run.armor)
	relics[0] = (Run.relics as Array).duplicate()
	return true


## Three bridges for a plain match; two for runs, the bot sim and the scenarios
## (which are laid out around them). `--bridges=2|3` overrides.
func _pick_bridges(in_run: bool) -> void:
	var three := not in_run
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--botsim=") or a.begins_with("--scenario=") or a.begins_with("--shots=") or a == "--demo":
			three = false
	for a in OS.get_cmdline_user_args():
		if a == "--bridges=3":
			three = true
		elif a == "--bridges=2":
			three = false
	bridges = THREE_BRIDGES if three else TWO_BRIDGES


## From the result screen: the next fight after a win, a fresh run once this one
## is over (won or lost). Either way the arena scene is rebuilt from the run.
func continue_run() -> void:
	if not Run.active or not match_over:
		return
	if Run.reward_pending():
		# the card has to be picked or skipped first (the reward screen does that)
		return
	if Run.can_continue():
		Run.advance()
	elif Run.over:
		Run.start()
	else:
		return
	get_tree().reload_current_scene()


## Every way a match ends comes through here once (the commander falling, the
## clock), so the run hears about it.
func _match_ended() -> void:
	if not Run.active:
		return
	var king := _king_of(0)
	var left := 0.0
	if king != null and is_instance_valid(king) and not king.dead:
		left = float(king.hp)
	Run.report(int(winner), left)
	if Run.reward_pending():
		_show_reward()


const REWARD_SCRIPT := preload("res://scripts/reward_screen.gd")
var reward_screen: Control = null

const PAUSE_SCRIPT := preload("res://scripts/pause_menu.gd")
var pause_layer: CanvasLayer = null


## Esc pauses the match: the whole tree stops (clock, troops, bots, gold, the
## hand) and pause_menu.gd, which alone keeps processing, offers Resume and the
## volume. Not once the match is over or the reward screen is up.
func set_paused(on: bool) -> void:
	if on and (match_over or get_tree().paused):
		return
	if on:
		clear_selection()
		pause_layer = CanvasLayer.new()
		pause_layer.layer = 60
		pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(pause_layer)
		var menu: Control = PAUSE_SCRIPT.new()
		menu.setup(self)
		pause_layer.add_child(menu)
		get_tree().paused = true
	else:
		get_tree().paused = false
		if pause_layer != null and is_instance_valid(pause_layer):
			pause_layer.queue_free()
		pause_layer = null


func is_paused() -> bool:
	return get_tree().paused


## The card reward after a won fight: its own CanvasLayer, above the board and
## the hand. Picking or skipping moves the run on (continue_run).
func _show_reward() -> void:
	if reward_screen != null and is_instance_valid(reward_screen):
		return
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	reward_screen = REWARD_SCRIPT.new()
	reward_screen.setup(self, Run.reward_choices())
	layer.add_child(reward_screen)
	# the hand is done for this fight; it would only show through the screen
	for pn in panels:
		if is_instance_valid(pn):
			pn.visible = false


func _setup_bots() -> void:
	# retire any bots from an earlier call: dropping them from the array alone left
	# them alive and still playing (the bot sim calls this a second time, which
	# used to leave team 1 with an extra, uncounted v1 bot)
	for old in bots:
		if old != null and is_instance_valid(old):
			old.enabled = false
			old.queue_free()
	bots = [null, null]
	for p in 2:
		if not bool(bot_players[p]):
			continue
		var b = DDBot.new()
		b.setup(self, p, 9001 + p * 7)
		add_child(b)
		bots[p] = b


func toggle_bot(p: int) -> void:
	bot_players[p] = not bool(bot_players[p])
	if bots[p] == null and bool(bot_players[p]):
		_setup_bots()
	elif bots[p] != null:
		bots[p].enabled = bool(bot_players[p])
	banner_flash("Bot %s for player %d" % ["ON" if bool(bot_players[p]) else "OFF", p + 1])


func bot_hover_index(p: int) -> int:
	if view_mode != 1:
		return -1
	if p < 0 or p >= bots.size():
		return -1
	var b = bots[p]
	if b == null or not is_instance_valid(b) or not b.enabled:
		return -1
	return int(b.hover_index)


func bot_target(p: int) -> Vector2:
	if view_mode != 1:
		return Vector2.INF
	if p < 0 or p >= bots.size():
		return Vector2.INF
	var b = bots[p]
	if b == null or not is_instance_valid(b) or not b.enabled or not b.armed:
		return Vector2.INF
	return b.pending_pos


# --------------------------------------------------------------------- teams

## The colour of a side. Everything that reads "blue" or "red" asks here.
func team_color(team: int) -> Color:
	return team_colors[clampi(team, 0, team_colors.size() - 1)]


## Unit and tower outlines: a darker shade of the owner's colour, not black.
func team_ink(team: int) -> Color:
	return team_color(team).darkened(TEAM_INK_DARKEN)


func _dev_hook() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--botsim="):
			var sim := DDBotSim.new()
			sim.setup(self, int(a.substr(9)))
			sim.name = "BotSim"
			add_child(sim)
			return
		if a.begins_with("--shots=") or a == "--demo" or a.begins_with("--scenario="):
			var dev: Node = load("res://scripts/dev_capture.gd").new()
			dev.arena = self
			dev.name = "DevCapture"
			add_child(dev)
			return


func _build_board_state() -> void:
	towers.clear()
	units.clear()
	for t in [
		[1, 9.0, 3.0, true], [1, 5.0, 6.0, false], [1, 13.0, 6.0, false],
		[0, 9.0, 27.0, true], [0, 5.0, 24.0, false], [0, 13.0, 24.0, false],
	]:
		var tw := DDTower.new()
		tw.setup(int(t[0]), self, bool(t[3]))
		tw.position = tile_center(float(t[1]), float(t[2]))
		towers.append(tw)
		add_child(tw)


func _build_preview() -> void:
	var p = DDDeployPreview.new()
	p.arena = self
	p.z_index = 16
	p.visible = false
	add_child(p)
	preview = p


func _build_control_layer() -> void:
	var layer := DDControlLayer.new()
	layer.arena = self
	layer.z_index = 2
	add_child(layer)
	control_layer = layer


## seed_value >= 0 makes the shuffle reproducible (the bot harness A/B needs it);
## the default keeps matches randomised for real play.
func _build_decks(seed_value: int = -1) -> void:
	charges = [{}, {}]
	for p in 2:
		var deck: Array = (deck_lists[p] as Array).duplicate() if not (deck_lists[p] as Array).is_empty() else DDCard.ORDER.duplicate()
		var rng := RandomNumberGenerator.new()
		if seed_value >= 0:
			rng.seed = seed_value + p * 7919
		else:
			rng.randomize()
		for i in range(deck.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = deck[i]
			deck[i] = deck[j]
			deck[j] = tmp
		hands[p] = deck.slice(0, OPENING_HAND)
		queues[p] = deck.slice(OPENING_HAND)
		hand_ids[p] = []
		queue_ids[p] = []
		_sync_ids(p)
		gold[p] = 5.0


func _new_card_id() -> int:
	next_card_id += 1
	return next_card_id - 1


## Keep the id lists the same length as the kind lists. Normal play moves both
## together; anything that rewrites a hand or deck wholesale (an elite clearing
## the opponent, a dev scenario) gets fresh ids for it here.
func _sync_ids(p: int) -> void:
	if (hand_ids[p] as Array).size() != (hands[p] as Array).size():
		hand_ids[p] = (hands[p] as Array).map(func(_k): return _new_card_id())
	if (queue_ids[p] as Array).size() != (queues[p] as Array).size():
		queue_ids[p] = (queues[p] as Array).map(func(_k): return _new_card_id())


## The id of the copy in hand slot i (-1 if there is none).
func hand_id(p: int, i: int) -> int:
	if p < 0 or p > 1:
		return -1
	_sync_ids(p)
	if i < 0 or i >= (hand_ids[p] as Array).size():
		return -1
	return int(hand_ids[p][i])


## Hand slot holding the copy with this id (-1 if it is not in the hand).
func hand_index_of(p: int, id: int) -> int:
	if p < 0 or p > 1:
		return -1
	_sync_ids(p)
	return (hand_ids[p] as Array).find(id)


## The copy currently lifted (-1 if none).
func selection_id() -> int:
	return hand_id(selected_player, selected_index)


## One sound node for the whole match; it also owns the deal sound so the
## OPENING_HAND cards that start the hand are audible.
func _build_sfx() -> void:
	sfx = DDSfx.new()
	add_child(sfx)
	DDSfx.get_volume()
	sfx.draw_hand(OPENING_HAND)
	# the song comes in once the deal has finished
	# (not headless: the bot sim and checks have no one to hear it)
	if DisplayServer.get_name() != "headless":
		sfx.start_music(float(OPENING_HAND) * float(sfx.slice_seconds) + 0.3)


func _build_hud() -> void:
	for p in 2:
		var panel := HandPanel.new()
		panel.name = "HandPanel%d" % p
		panel.player = p
		panel.arena = self
		if p == 0:
			panel.compact = false
			panel.size = Vector2(1600.0, 196.0)
			panel.position = Vector2(0.0, 804.0)
		else:
			panel.compact = true
			# Tab view: the opponent's hand is a column down the right edge
			panel.size = Vector2(214.0, 700.0)
			panel.position = Vector2(1382.0, 56.0)
		add_child(panel)
		panels.append(panel)
	panels[1].visible = true
	_build_volume()


## Volume slider in the empty top-left corner. It never takes keyboard focus, so
## the arrow keys and hotkeys stay with the match.
func _build_volume() -> void:
	var label := Label.new()
	label.name = "VolumeLabel"
	label.text = "VOLUME"
	label.position = Vector2(24.0, 14.0)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.62, 0.66, 0.74))
	add_child(label)
	volume_slider = HSlider.new()
	volume_slider.name = "VolumeSlider"
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.01
	volume_slider.value = DDSfx.get_volume()
	volume_slider.focus_mode = Control.FOCUS_NONE
	volume_slider.position = Vector2(92.0, 14.0)
	volume_slider.size = Vector2(170.0, 20.0)
	volume_slider.value_changed.connect(DDSfx.set_volume)
	add_child(volume_slider)


## The debug all-cards overlay. It is a DDCardGrid so the collection screen and
## the deck view can be built out of the same component.
func _build_shelf() -> void:
	shelf_grid = DDCardGrid.new()
	shelf_grid.name = "ShelfGrid"
	shelf_grid.position = Vector2(150.0, 636.0)
	shelf_grid.size = Vector2(1300.0, 360.0)
	shelf_grid.set_kinds(DDCard.all_kinds())
	shelf_grid.visible = false
	shelf_grid.card_pressed.connect(_on_shelf_card)
	add_child(shelf_grid)


func _on_shelf_card(kind: String) -> void:
	pick_debug_card(kind)


func _sync_shelf_selection() -> void:
	if shelf_grid != null:
		shelf_grid.selected_kind = debug_kind


## Called by the hand panel when a dragged card is dropped on the board.
## One coin per tile, laid along the bottom-left edge for blue and mirrored for
## red. Full coins are solid, spent ones grey, and the one filling right now is
## drawn larger with a near-white arc that only turns gold when it completes.
func _draw_gold_pieces() -> void:
	var maxp := int(gold_max)
	var r := TILE * 0.3
	for team in 2:
		var full: bool = float(gold[team]) >= gold_max - 0.001
		for i in maxp:
			# blue runs along the bottom-left UI strip, red mirrored across the
			# vertical so it sits on their side of the board
			var ty := 29.5 - float(i) if team == 0 else 0.5 + float(i)
			var at: Vector2 = tile_center(17.5, ty)
			var filled: float = clampf(float(gold[team]) - float(i), 0.0, 1.0)
			if i == 0 and int(pearl_state[team]) == PEARL_BANKED:
				# the Abyssal Pearl is this team's first gold: the pearl sits in
				# the slot once it has landed (an empty slot while it floats down)
				if pearl_in_purse(team):
					draw_circle(at, r * 1.5, Color(0.8, 0.82, 1.0, 0.18 + 0.08 * sin(clock * 2.5)))
					DDArt.pearl(self, at, r * 1.05)
				else:
					draw_circle(at, r, Color(0.28, 0.28, 0.32))
					draw_arc(at, r, 0.0, TAU, 18, Color(0.44, 0.44, 0.5), 1.2, true)
				continue
			if filled >= 1.0:
				if full:
					# a full purse rattles: each coin jitters on its own beat
					at += Vector2(sin(clock * 47.0 + float(i) * 2.3), cos(clock * 53.0 + float(i) * 1.7)) * 1.4
				draw_circle(at, r, Color(0.98, 0.78, 0.22))
				draw_circle(at + Vector2(-r * 0.3, -r * 0.3), r * 0.4, Color(1.0, 0.94, 0.62, 0.9))
				draw_arc(at, r, 0.0, TAU, 20, Color(0.55, 0.38, 0.05), 1.6, true)
				var started: float = float(coin_twinkle[team][i]) if i < (coin_twinkle[team] as Array).size() else -1.0
				var since: float = clock - started if started >= 0.0 else -1.0
				if since >= 0.0 and since < TWINKLE_FRAME * float(TWINKLE_SIZES.size()):
					_draw_twinkle(at + Vector2(r * 0.35, -r * 0.35), r,
						float(TWINKLE_SIZES[int(since / TWINKLE_FRAME)]))
			elif filled > 0.0:
				draw_circle(at, r * 1.35, Color(0.3, 0.3, 0.34, 0.95))
				draw_arc(at, r * 1.35, -PI * 0.5, -PI * 0.5 + TAU * filled, 22, Color(1.0, 1.0, 0.84), 3.2, true)
				draw_arc(at, r * 1.35, 0.0, TAU, 22, Color(0.52, 0.52, 0.58), 1.2, true)
			else:
				draw_circle(at, r, Color(0.28, 0.28, 0.32))
				draw_arc(at, r, 0.0, TAU, 18, Color(0.44, 0.44, 0.5), 1.2, true)


## Coin twinkle, all picture: a four-point glint stepped through a few held
## frames. It plays on a coin the moment it is minted, and on every coin, a
## little apart, each TWINKLE_FULL_EVERY seconds while the purse is full.
const TWINKLE_FRAME := 0.06
const TWINKLE_SIZES := [0.35, 0.8, 1.2, 0.9, 0.45]
const TWINKLE_FULL_EVERY := 1.6
const TWINKLE_STAGGER := 0.05
## [team][coin] -> clock time its current twinkle started (-1 = none)
var coin_twinkle := [[], []]
var coins_whole := [0, 0]
var full_twinkle_at := [0.0, 0.0]


func _tick_coin_twinkle() -> void:
	var maxp := int(gold_max)
	for team in 2:
		if (coin_twinkle[team] as Array).size() != maxp:
			coin_twinkle[team] = []
			for i in maxp:
				coin_twinkle[team].append(-1.0)
		var whole := clampi(int(floor(float(gold[team]) + 0.0001)), 0, maxp)
		if whole > int(coins_whole[team]):
			for i in range(int(coins_whole[team]), whole):
				coin_twinkle[team][i] = clock
		coins_whole[team] = whole
		if whole >= maxp:
			if clock >= float(full_twinkle_at[team]):
				full_twinkle_at[team] = clock + TWINKLE_FULL_EVERY
				for i in maxp:
					coin_twinkle[team][i] = clock + TWINKLE_STAGGER * float(i)
		else:
			# the first rattle of the next full purse comes a beat after it fills
			full_twinkle_at[team] = clock + TWINKLE_FULL_EVERY * 0.5


func _draw_twinkle(at: Vector2, r: float, size: float) -> void:
	var arm: float = r * 0.9 * size
	var white := Color(1.0, 1.0, 0.92, 0.95)
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -arm), at + Vector2(arm * 0.18, -arm * 0.18),
		at + Vector2(arm, 0), at + Vector2(arm * 0.18, arm * 0.18), at + Vector2(0, arm),
		at + Vector2(-arm * 0.18, arm * 0.18), at + Vector2(-arm, 0), at + Vector2(-arm * 0.18, -arm * 0.18)]), white)
	draw_circle(at, arm * 0.22, Color(1.0, 1.0, 1.0))


## Cards tick in every DRAW_INTERVAL seconds; drawing with a full hand throws
## away the leftmost card (the one furthest from where new cards arrive).
func draw_card(team: int) -> bool:
	if queues[team].is_empty():
		return false
	_sync_ids(team)
	if hands[team].size() >= HAND_MAX:
		var dropped: String = hands[team][0]
		if team < panels.size() and panels[team] != null and is_instance_valid(panels[team]):
			panels[team].note_discard(dropped)
		hands[team].remove_at(0)
		queues[team].append(dropped)
		queue_ids[team].append(hand_ids[team].pop_front())
		# the hand shifted left by one: follow the same card, not the same index
		if selected_player == team:
			if selected_index == 0:
				# the card being held is the one thrown away
				clear_selection()
			elif selected_index > 0:
				selected_index -= 1
		if int(staged["player"]) == team:
			if int(staged["index"]) == 0:
				clear_staged()
			elif int(staged["index"]) > 0:
				staged["index"] = int(staged["index"]) - 1
	var k: String = queues[team].pop_front()
	var kid: int = int(queue_ids[team].pop_front())
	hands[team].append(k)
	hand_ids[team].append(kid)
	_reset_charges(team, kid)
	if sfx != null:
		sfx.take_card()
	return true


func _tick_draw(delta: float) -> void:
	if match_over:
		return
	for p in 2:
		draw_timer[p] = float(draw_timer[p]) - delta
		# a big spend can push the clock past more than one draw: each one lands,
		# and whatever is left over counts toward the next
		while float(draw_timer[p]) <= 0.0:
			draw_timer[p] = float(draw_timer[p]) + draw_interval()
			draw_card(p)


## Spending gold pulls the next draw closer: DRAW_PER_GOLD seconds per gold.
## Every spend goes through here (cards, each Firebolt cast, abilities, the hero).
func spend_gold_draw(player: int, amount: float) -> void:
	if player < 0 or player > 1 or amount <= 0.0:
		return
	draw_timer[player] = float(draw_timer[player]) - amount * DRAW_PER_GOLD


## True when any living unit stands inside this screen-space rect. Used to let
## the enlarged hover card fade so it does not hide the board (occlusion).
func any_units_under(rect: Rect2) -> bool:
	for u in units:
		if not is_instance_valid(u) or u.dead:
			continue
		if rect.has_point(u.position):
			return true
	return false


## The enemy body a unit-locking card (the Firebolt) has locked onto under the
## cursor: a troop, building, tower or boss. Such a card can only be played
## while it is locked on (try_deploy_at).
func aim_lock(world: Vector2) -> Node:
	var kind := selection_kind()
	if kind == "" or not bool(DDCard.get_card(kind).get("unit_lock", false)):
		return null
	var e := _hovered_entity(world)
	if e == null:
		return null
	if int(e.get("team")) == selection_owner():
		return null
	if e.get("untargetable") == true:
		return null
	return e


## Point an armed card's preview and its placement aim at: a locked troop's live
## position (so it follows the troop smoothly), otherwise the snapped tile.
func aim_point(world: Vector2) -> Vector2:
	var locked := aim_lock(world)
	if locked != null:
		return locked.position
	var kind := selection_kind()
	if kind == "":
		return world
	var open := deploy_point(selection_owner(), kind, world)
	if open != Vector2.INF:
		world = open
	var t := tile_of(world)
	var fp: Array = DDCard.get_card(kind).get("footprint", [1, 1])
	if int(fp[0]) > 1 or int(fp[1]) > 1:
		return footprint_layout(t, fp)["center"]
	return tile_center(float(t.x) + 0.5, float(t.y) + 0.5)


## Cards that cannot be played yet: card id -> physics frame they free up. A
## card with `arrive_lock` in its data gets it when another card's play puts it
## in the hand (the whelps swapping: 3 s before the new one can go).
var card_lock := {}


func lock_left(id: int) -> float:
	if not card_lock.has(id):
		return 0.0
	var left := float(int(card_lock[id]) - Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)
	if left <= 0.0:
		card_lock.erase(id)
		return 0.0
	return left


func card_locked(player: int, index: int) -> bool:
	return lock_left(hand_id(player, index)) > 0.0


func _lock_card(id: int, seconds: float) -> void:
	if seconds > 0.0:
		card_lock[id] = Engine.get_physics_frames() + int(ceilf(seconds * float(Engine.physics_ticks_per_second)))


## Every placement lands here: the board click, the dragged release and a queued
## placement all go through the same affordability rules.
func try_deploy_at(world: Vector2) -> void:
	if match_over or selection_kind() == "":
		return
	if not board_rect().has_point(world):
		return
	if debug_kind != "":
		deploy_debug(world)
		return
	if selected_player < 0 or selected_index < 0:
		return
	if card_locked(selected_player, selected_index):
		# still settling into the hand (a whelp that just swapped in)
		reject_placement(selected_player, selected_index)
		return
	var kind := selection_kind()
	# a unit-locking card casts on the troop it is aimed at, not on the tile
	var at: Vector2 = world
	if bool(DDCard.get_card(kind).get("unit_lock", false)):
		# nothing under the cursor to lock on to: the click does nothing
		if aim_lock(world) == null:
			return
		at = aim_point(world)
	else:
		# past where this card may go: it lands on the closest tile that is open
		var open := deploy_point(selected_player, kind, world)
		if open != Vector2.INF:
			at = open
	var missing: float = float(DDCard.cost(kind)) - float(gold[selected_player])
	if missing <= 0.0:
		deploy(selected_player, selected_index, at)
	elif missing < 1.0:
		# less than a coin away: hold the placement and play it on arrival
		stage_placement(selected_player, selected_index, at)
	else:
		# nothing is spent on a placement that cannot happen: flash the cost
		reject_placement(selected_player, selected_index)


## Hold a placement for the moment the gold arrives. The card keeps its slot in
## the hand, so nothing is spent and it can still be swapped out.
func stage_placement(player: int, index: int, world: Vector2) -> void:
	if player < 0 or index < 0 or index >= hands[player].size():
		return
	var kind := String(hands[player][index])
	staged = {"player": player, "index": index, "kind": kind, "at": world}
	banner_flash("Queued %s â€” %.1f gold short" % [DDCard.pretty(kind),
		float(DDCard.cost(kind)) - float(gold[player])])


func clear_staged() -> void:
	staged = {"player": -1, "index": -1, "kind": "", "at": Vector2.ZERO}


func staged_index(player: int) -> int:
	return int(staged["index"]) if int(staged["player"]) == player else -1


## Fire the queued placement once it is paid for. Picking another card, losing
## the selection or the card moving in the hand all cancel it.
func _tick_staged() -> void:
	var p := int(staged["player"])
	if p < 0:
		return
	var i := int(staged["index"])
	var kind := String(staged["kind"])
	if selected_player != p or selected_index != i:
		clear_staged()
		return
	if i < 0 or i >= hands[p].size() or String(hands[p][i]) != kind:
		clear_staged()
		return
	if float(gold[p]) < float(DDCard.cost(kind)):
		return
	var at: Vector2 = staged["at"]
	clear_staged()
	deploy(p, i, at)


## Flash a card's cost: the player asked to place something they cannot pay for.
func reject_placement(player: int, index: int) -> void:
	reject = {"player": player, "index": index, "timer": REJECT_TIME}
	shake(1.5)


func set_view_mode(m: int) -> void:
	view_mode = m
	if panels.size() == 2:
		panels[1].visible = true
		if m == 0:
			panels[1].size = Vector2(214.0, 700.0)
			panels[1].position = Vector2(1382.0, 56.0)
		else:
			panels[1].size = Vector2(214.0, 700.0)
			panels[1].position = Vector2(1382.0, 56.0)
	if m == 0 and selected_player == 1:
		selected_player = -1
		selected_index = -1
	queue_redraw()


# --------------------------------------------------------------------- clock

## Gold per second a player earns right now.
func gold_rate_now() -> float:
	return gold_rate * float(PHASE_GOLD[clampi(phase, 0, PHASE_GOLD.size() - 1)])


## How long a card draw takes right now (one second faster in the closing window).
func draw_interval() -> float:
	return maxf(1.0, DRAW_INTERVAL - (OVERTIME_DRAW_CUT if overtime else 0.0))


## How long an ability cooldown started right now will be (halved in the window).
func ability_cooldown_time() -> float:
	return ABILITY_COOLDOWN * (0.5 if overtime else 1.0)


## How many casts this copy has left (1 for normal cards). Without an id it asks
## about the first copy of `kind` in the hand.
func charges_of(player: int, kind: String, id: int = -1) -> int:
	var total := int(DDCard.get_card(kind).get("uses", 1))
	if total <= 1 or player < 0 or player > 1:
		return 1
	if id < 0:
		id = hand_id(player, (hands[player] as Array).find(kind))
	return int((charges[player] as Dictionary).get(id, total))


func _reset_charges(team: int, id: int) -> void:
	if team >= 0 and team <= 1:
		(charges[team] as Dictionary).erase(id)


## Seconds each phase lasts: [single, double, sudden death].
func phase_lengths() -> Array:
	return [single_len, single_len * 0.5, maxf(SUDDEN_MIN, single_len * 0.25)]


## Start the clock over at SINGLE with `single` seconds of single gold.
func setup_clock(single: float) -> void:
	single_len = single
	phase = Phase.SINGLE
	overtime = false
	match_time_left = single
	_call_phase()


func _tick_clock(delta: float) -> void:
	match_time_left = maxf(0.0, match_time_left - delta)
	if match_time_left > 0.0:
		return
	if phase == Phase.SINGLE:
		_enter_phase(Phase.DOUBLE)
	elif phase == Phase.DOUBLE:
		# a tower lead at the end of double gold wins it (never in an elite fight)
		if not elite_fight:
			var lost := towers_lost()
			if lost[0] != lost[1]:
				_finish_on_towers()
				return
		_enter_phase(Phase.SUDDEN)
	else:
		_finish_on_towers()


func _enter_phase(p: int) -> void:
	phase = p
	match_time_left = float(phase_lengths()[p])
	if not overtime:
		overtime = true
		# a cooldown already running gets shortened too, so the switch is felt
		ability_cd = [minf(float(ability_cd[0]), ability_cooldown_time()),
			minf(float(ability_cd[1]), ability_cooldown_time())]
	_call_phase()


## Towers each side has lost: [team 0, team 1]. A kraken tentacle counts once it
## is `down` (its `dead` flickers while it burrows).
func towers_lost() -> Array:
	var lost := [0, 0]
	for tw in towers:
		if not is_instance_valid(tw):
			continue
		var gone: bool = bool(tw.get("down")) if tw.get("down") != null else bool(tw.dead)
		if gone:
			lost[int(tw.team)] += 1
	return lost


## The phase announced in the middle of the board (phase_call.gd).
func _call_phase() -> void:
	if phase_call == null or not is_instance_valid(phase_call):
		phase_call = PHASE_CALL_SCRIPT.new()
		phase_call.name = "PhaseCall"
		phase_call.arena = self
		add_child(phase_call)
	var secs := int(round(float(phase_lengths()[phase])))
	var dur := "%d:%02d" % [int(floorf(float(secs) / 60.0)), secs % 60]
	match phase:
		Phase.SINGLE:
			phase_call.show_call("SINGLE GOLD", dur, Color(1.0, 0.93, 0.7))
		Phase.DOUBLE:
			phase_call.show_call("DOUBLE GOLD", dur + "  ·  a tower lead wins at the end" if not elite_fight else dur,
				Color(1.0, 0.78, 0.35))
		_:
			var sub := "next tower to fall loses" if not elite_fight else "commander or boss"
			phase_call.show_call("SUDDEN DEATH", "quadruple gold  ·  " + sub + "  ·  " + dur, Color(1.0, 0.4, 0.3))


## Time up: whoever has had more towers destroyed loses. Only if that is level
## does it go to whoever has more tower HP left, and only if that is level too is
## it a draw. (A kraken tentacle counts as destroyed once it is `down`; its
## `dead` also flickers while it burrows.)
func _finish_on_towers() -> void:
	if match_over:
		return
	var hp := [0.0, 0.0]
	var lost := [0, 0]
	for tw in towers:
		if not is_instance_valid(tw):
			continue
		var gone: bool = bool(tw.get("down")) if tw.get("down") != null else bool(tw.dead)
		if gone:
			lost[int(tw.team)] += 1
		elif not tw.dead:
			hp[int(tw.team)] += float(tw.hp)
	match_over = true
	banner_timer = 999.0
	if elite_fight:
		# an elite has to be killed: sudden death running out is the boss's win,
		# whatever towers or tentacles fell on the way
		winner = 1
		banner_text = "TIME  —  THE BOSS HOLDS: KILL IT BEFORE SUDDEN DEATH RUNS OUT"
		_match_ended()
		return
	if Run.active:
		# a run fight has to be won, not waited out: on the clock you win only if
		# you have taken more towers than you have lost. Level is a loss, and
		# tower HP never decides it.
		winner = 0 if lost[1] > lost[0] else 1
		if winner == 0:
			banner_text = "TIME  —  YOU WIN: %d TOWERS TAKEN TO %d LOST" % [lost[1], lost[0]]
		else:
			banner_text = "TIME  —  YOU LOSE: TAKE MORE TOWERS THAN YOU LOSE (%d TAKEN, %d LOST)" % [lost[1], lost[0]]
		_match_ended()
		return
	if lost[0] != lost[1]:
		winner = 0 if lost[0] < lost[1] else 1
		banner_text = "TIME  —  PLAYER %d WINS: %d TOWERS DOWN TO %d" % [winner + 1, maxi(lost[0], lost[1]), mini(lost[0], lost[1])]
		_match_ended()
		return
	if is_equal_approx(hp[0], hp[1]):
		winner = -1
		banner_text = "TIME  —  DRAW (%d towers down each, %.0f  ·  %.0f HP)" % [lost[0], hp[0], hp[1]]
		_match_ended()
		return
	winner = 0 if hp[0] > hp[1] else 1
	banner_text = "TIME  —  PLAYER %d WINS ON TOWER HP (%.0f  ·  %.0f HP)" % [winner + 1, hp[0], hp[1]]
	_match_ended()


func _process(delta: float) -> void:
	clock += delta
	_tick_coin_twinkle()
	if banner_timer > 0.0:
		banner_timer = maxf(0.0, banner_timer - delta)
	if float(reject["timer"]) > 0.0:
		reject["timer"] = maxf(0.0, float(reject["timer"]) - delta)
	if shake_amount > 0.0:
		shake_amount = maxf(0.0, shake_amount - delta * 40.0)
		shake_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amount
	else:
		shake_offset = Vector2.ZERO
	queue_redraw()


func _physics_process(delta: float) -> void:
	if match_over:
		return
	_tick_clock(delta)
	if match_over:
		return
	fight_t += delta
	for k in relic_glow.keys():
		relic_glow[k] = float(relic_glow[k]) - delta
		if float(relic_glow[k]) <= 0.0:
			relic_glow.erase(k)
	for p in 2:
		var income: float = gold_rate_now() * delta
		var gold_before: float = float(gold[p])
		gold[p] = minf(gold_max, gold[p] + income)
		ability_cd[p] = maxf(0.0, float(ability_cd[p]) - delta)
		if not (relics[p] as Array).is_empty():
			_tick_relics(p, delta, income, gold_before)
	_tick_control(delta)
	_tick_pockets()
	separate_units()
	_tick_draw(delta)
	_tick_staged()
	_tick_reservations(delta)


# ------------------------------------------------------------------ geometry

## The board's own geometry is in DDBoard (pure static functions). These thin
## wrappers keep this file's API stable â€” units, bots and panels all call here.
func row_is_band(row: int) -> bool:
	return DDBoard.row_is_band(row)


func col_min(row: int) -> int:
	return DDBoard.col_min(row)


func col_max(row: int) -> int:
	return DDBoard.col_max(row)


func tile_of(world: Vector2) -> Vector2i:
	return DDBoard.tile_of(world)


## tx/ty are tile coordinates where the centre of tile (col,row) is (col+0.5, row+0.5).
func tile_center(tx: float, ty: float) -> Vector2:
	return DDBoard.tile_center(tx, ty)


func tile_rect(col: int, row: int) -> Rect2:
	return DDBoard.tile_rect(col, row)


## Screen rect covering cols c0..c1 of a single row (orientation agnostic).
func row_span(c0: int, c1: int, row: int) -> Rect2:
	return DDBoard.row_span(c0, c1, row)


## Building covering this tile. Footprints are explicit tile lists, so a 2x2 can
## sit centred on the corner between four tiles.
func building_at(t: Vector2i) -> Node:
	for u in units:
		if not is_instance_valid(u) or u.dead:
			continue
		if u.get("stationary") != true:
			continue
		var occ = u.get("occupied_tiles")
		if occ != null and (occ as Array).size() > 0:
			if (occ as Array).has(t):
				return u
			continue
		if tile_of(u.position) == t:
			return u
	return null


## Tiles a building of this footprint covers, anchored at the clicked tile, plus
## the screen position its art should sit at (corner-centred for 2x2).
func footprint_layout(t: Vector2i, fp: Array) -> Dictionary:
	return DDBoard.footprint_layout(t, fp)


## Nearest free tile centre, diagonals included.
func free_spot_near(at: Vector2) -> Vector2:
	if building_at(tile_of(at)) == null:
		return at
	var t := tile_of(at)
	var best := at
	var best_d := INF
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var nt := Vector2i(t.x + dx, t.y + dy)
			if not valid_tile(nt) or building_at(nt) != null:
				continue
			var c := tile_center(float(nt.x) + 0.5, float(nt.y) + 0.5)
			var dd := c.distance_squared_to(at)
			if dd < best_d:
				best_d = dd
				best = c
	return best


func valid_tile(t: Vector2i) -> bool:
	return DDBoard.valid_tile(t)


func band_index(t: Vector2i) -> int:
	return DDBoard.band_index(t)


func rect_for_arena() -> Rect2:
	return DDBoard.board_rect()


func board_rect() -> Rect2:
	return DDBoard.board_rect()


# ------------------------------------------------------------------- control

const CONTROL_REACH := 3


## Control is presence based: a ground unit holds the tiles 3 across to each
## side and 3 back toward its own half. It never contests the enemy's â€” both
## teams can hold the same tile.
func _tick_control(_delta: float) -> void:
	# only rebuild when some unit has actually changed tile (cheap cache)
	var seen := {}
	var changed := false
	for u in units:
		if not is_instance_valid(u) or u.dead:
			continue
		if u.get("flying") == true:
			continue
		if u.get("gives_presence") == false:
			continue
		var t := tile_of(u.position)
		var id: int = u.get_instance_id()
		seen[id] = t
		if unit_tiles.get(id) != t:
			changed = true
	if seen.size() != unit_tiles.size():
		changed = true
	if not changed:
		return
	unit_tiles = seen
	_rebuild_control()


var control_rebuilds := 0


func _rebuild_control() -> void:
	control_rebuilds += 1
	for t in 2:
		var arr: Array = control[t]
		for i in arr.size():
			arr[i] = false
	for u in units:
		if not is_instance_valid(u) or u.dead:
			continue
		if u.get("flying") == true:
			continue
		if u.get("gives_presence") == false:
			continue
		var ut := int(u.team)
		var back := 1 if ut == 0 else -1
		var base := tile_of(u.position)
		var shift := 0
		if u.get("presence_shift") != null:
			shift = int(u.get("presence_shift"))
		# cone: 3 tiles wide at the unit, then 5, 7, 9 going back toward its own half,
		# but never the tile the unit is standing on
		for k in range(0, CONTROL_REACH + 1):
			var half := 1 + k
			var ty: int = base.y + (k - shift) * back
			if ty < 0 or ty >= GRID_H:
				continue
			for dx in range(-half, half + 1):
				var tx: int = base.x + dx
				if tx < 0 or tx >= GRID_W:
					continue
				if tx == base.x and ty == base.y:
					continue
				if not valid_tile(Vector2i(tx, ty)) or is_water(Vector2i(tx, ty)):
					continue
				control[ut][ty * GRID_W + tx] = true
	if control_layer != null:
		control_layer.queue_redraw()


## Units push past each other instead of stacking: overlap is split by mass
## (radius) and buildings never give ground.
func separate_units() -> void:
	var n := units.size()
	for i in n:
		var a = units[i]
		if not is_instance_valid(a) or a.dead:
			continue
		if a.get("stationary") == true:
			continue
		# a dart frog in mid-leap is in the air: it lands on its prey and bursts
		# without shoving anything on the way
		if a.get("frog_leaping") == true:
			continue
		var ra: float = float(a.get_radius_t())
		for j in range(i + 1, n):
			var b = units[j]
			if not is_instance_valid(b) or b.dead or b.get("frog_leaping") == true:
				continue
			if bool(a.get("flying")) != bool(b.get("flying")):
				continue
			var rb: float = float(b.get_radius_t())
			var need: float = (ra + rb) * 0.85 * TILE
			var d: Vector2 = b.position - a.position
			var dist := d.length()
			if dist >= need or dist < 0.001:
				continue
			var overlap := (need - dist) * 0.5
			var dir := d / dist
			if b.get("stationary") == true:
				a.position -= dir * overlap * 2.0
			else:
				# heavier body wins the contest
				var wa := rb / (ra + rb)
				var wb := ra / (ra + rb)
				a.position -= dir * overlap * 2.0 * wa
				b.position += dir * overlap * 2.0 * wb


func controlled(team: int, t: Vector2i) -> bool:
	if not valid_tile(t):
		return false
	return bool(control[team][band_index(t)])


## A bridge deck runs BRIDGE_HALF tiles either side of its middle line x = bx:
## 3 tiles wide, the whole tiles bx-1 and bx plus half of bx-2 and bx+1. Those
## two half tiles are still water for placing and presence (is_water), but
## ground for walking on (on_bridge_deck), so a body shoved a little off the
## middle of the bridge stays on it instead of being sent back to its bank.
const BRIDGE_HALF := 1.5


## The bridge's middle in tile columns (x = bx), for a world position.
func col_f(world: Vector2) -> float:
	return (world.y - ORIGIN.y) / TILE if LANDSCAPE else (world.x - ORIGIN.x) / TILE


## On a bridge deck (inside the river rows, within BRIDGE_HALF of a bridge's middle).
func on_bridge_deck(world: Vector2) -> bool:
	var t := tile_of(world)
	if t.y < RIVER_TOP or t.y > RIVER_BOTTOM:
		return false
	var c := col_f(world)
	for b in bridges:
		if absf(c - float(b[0])) <= float(b[1]):
			return true
	return false


## The deck's screen rect, for drawing. `half` defaults to BRIDGE_HALF.
func bridge_rect(bx: float, half: float = BRIDGE_HALF) -> Rect2:
	var p0: Vector2 = tile_center(bx - half, float(RIVER_TOP))
	var p1: Vector2 = tile_center(bx + half, float(RIVER_BOTTOM) + 1.0)
	return Rect2(Vector2(minf(p0.x, p1.x), minf(p0.y, p1.y)), (p1 - p0).abs())


## Half the deck width of the bridge whose middle is bx (BRIDGE_HALF if none is).
func bridge_half(bx: float) -> float:
	for b in bridges:
		if is_equal_approx(float(b[0]), bx):
			return float(b[1])
	return BRIDGE_HALF


## River water: the two river rows except the tiles lying wholly on a bridge
## deck. Nothing is placed there and no presence reaches it (a deck's part
## tiles at its edges count as water here, so nothing is played on them).
func is_water(t: Vector2i) -> bool:
	if t.y < RIVER_TOP or t.y > RIVER_BOTTOM:
		return false
	for b in bridges:
		if float(t.x) >= float(b[0]) - float(b[1]) - 0.001 and float(t.x) + 1.0 <= float(b[0]) + float(b[1]) + 0.001:
			return false
	return true


## The lane pocket: once a side tower falls, the team that took it may place in
## that lane on both sides of the river (and a little way past the ruin, along
## the edge), presence or not. Given as [row, first col, last col] for team 0
## taking the top-lane tower; mirrored by row for team 1 and by column for the
## bottom lane. River water is never part of it.
const POCKET := [[16, 0, 5], [13, 0, 5], [12, 0, 5], [11, 0, 5], [10, 0, 2], [9, 0, 2], [8, 0, 2]]
## per team: tile (Vector2i) -> true
var pocket_tiles := [{}, {}]
var _pocket_key := ""


func in_pocket(team: int, t: Vector2i) -> bool:
	return (pocket_tiles[team] as Dictionary).has(t)


## Rebuilt only when the set of fallen side towers changes.
func _tick_pockets() -> void:
	var fallen: Array = []
	var key := ""
	for tw in towers:
		if is_instance_valid(tw) and tw is DDTower and not tw.crown and tw.dead:
			fallen.append(tw)
			key += "%d:%d;" % [int(tw.team), tile_of(tw.position).x]
	if key == _pocket_key:
		return
	_pocket_key = key
	pocket_tiles = [{}, {}]
	for tw in fallen:
		var taker: int = 1 - int(tw.team)
		var bottom_lane: bool = tile_of(tw.position).x >= GRID_W / 2
		for p in POCKET:
			var row: int = int(p[0]) if taker == 0 else GRID_H - 1 - int(p[0])
			for c in range(int(p[1]), int(p[2]) + 1):
				var t := Vector2i(GRID_W - 1 - c if bottom_lane else c, row)
				if valid_tile(t) and not is_water(t):
					pocket_tiles[taker][t] = true
	if control_layer != null:
		control_layer.queue_redraw()


func control_counts() -> Array:
	var out := [0, 0, 0]
	for row in range(BAND_TOP, BAND_BOTTOM + 1):
		for col in range(col_min(row), col_max(row) + 1):
			var t := Vector2i(col, row)
			var a := controlled(0, t)
			var b := controlled(1, t)
			if a and b:
				out[2] += 1
			elif a:
				out[0] += 1
			elif b:
				out[1] += 1
	return out


# ---------------------------------------------------------------- targeting api

func tiles_between(a: Vector2, b: Vector2) -> float:
	return a.distance_to(b) / TILE


func gap_between(a: Vector2, b: Vector2, ra: float, rb: float) -> float:
	return a.distance_to(b) / TILE - ra - rb


func enemy_entities(team: int) -> Array:
	var out: Array = []
	for u in units:
		if is_instance_valid(u) and not u.dead and int(u.team) != team:
			if u.get("untargetable") == true:
				continue
			out.append(u)
	for t in towers:
		if is_instance_valid(t) and not t.dead and int(t.team) != team:
			out.append(t)
	return out


func enemy_units(team: int) -> Array:
	var out: Array = []
	for u in units:
		if is_instance_valid(u) and not u.dead and int(u.team) != team:
			if u.get("untargetable") == true:
				continue
			out.append(u)
	return out


func nearest_enemy_tower(team: int, pos: Vector2) -> Node:
	var best: Node = null
	var best_d := INF
	for t in towers:
		if not is_instance_valid(t) or t.dead or int(t.team) == team:
			continue
		var d := pos.distance_squared_to(t.position)
		if d < best_d:
			best_d = d
			best = t
	return best


func crown_tower(team: int) -> Node:
	for t in towers:
		if is_instance_valid(t) and not t.dead and int(t.team) == team and bool(t.get("crown")):
			return t
	return null


func nearest_own_tower(team: int, pos: Vector2) -> Node:
	var best: Node = null
	var best_d := INF
	for t in towers:
		if not is_instance_valid(t) or t.dead or int(t.team) != team:
			continue
		var d := pos.distance_squared_to(t.position)
		if d < best_d:
			best_d = d
			best = t
	return best


const GIANT_KINDS := ["dragon"]
const GROUND_FIRE_SCRIPT := preload("res://scripts/ground_fire.gd")


func apply_burn_at(center: Vector2, radius_t: float, burn: float, team: int, ticks: int = 4) -> void:
	if burn <= 0.0:
		return
	for e in enemy_entities(team):
		if not is_instance_valid(e) or e.dead or not e.has_method("apply_burn"):
			continue
		var d: float = tiles_between(center, e.position)
		if radius_t <= 0.0:
			if d <= float(e.get_radius_t()) + 0.25:
				e.apply_burn(burn, ticks)
		elif d <= radius_t + float(e.get_radius_t()) * 0.5:
			e.apply_burn(burn, ticks)


## radius_t 0 is a single-target spell: `only` if given (the body it homed on),
## otherwise the one nearest body the point is inside.
func spell_blast(center: Vector2, radius_t: float, dmg: float, team: int, tower_mult: float,
		burn: float, knock_tiles: float, kind: String, burn_ticks: int = 4, only: Node = null) -> void:
	var hits: Array = []
	if only != null:
		hits = [only]
	elif radius_t <= 0.0:
		var best: Node = null
		var best_d := INF
		for e in enemy_entities(team):
			if not is_instance_valid(e) or e.dead:
				continue
			var d0: float = tiles_between(center, e.position)
			if d0 <= float(e.get_radius_t()) and d0 < best_d:
				best_d = d0
				best = e
		if best != null:
			hits = [best]
	else:
		hits = enemy_entities(team).duplicate()
	for e in hits:
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = tiles_between(center, e.position)
		if only == null and radius_t > 0.0 and d > radius_t + float(e.get_radius_t()) * 0.5:
			continue
		var amount := dmg
		if e.is_tower() and tower_mult != 1.0:
			amount = dmg * tower_mult
		if amount > 0.0:
			e.take_damage(amount, center)
		if burn > 0.0 and e.has_method("apply_burn"):
			e.apply_burn(burn, burn_ticks)
		if knock_tiles > 0.0 and not e.is_tower():
			var kind_s := String(e.get("kind"))
			if e.get("stationary") == true or GIANT_KINDS.has(kind_s):
				continue
			var dir: Vector2 = e.position - center
			if dir.length() > 0.01 and e.has_method("apply_impulse"):
				e.apply_impulse(dir.normalized(), knock_tiles, 0.28)
	# some spells leave the ground burning (Fireball): drawn under the units
	var gf: Dictionary = DDCard.get_card(kind).get("ground_fire", {})
	if not gf.is_empty():
		var fire: Node2D = GROUND_FIRE_SCRIPT.new()
		fire.setup(self, center, team, radius_t, gf)
		add_child(fire)
		move_child(fire, 0)
	var col := Color(1.0, 0.55, 0.15) if kind == "fireball" else Color(1.0, 0.8, 0.3)
	var b := DDBurst.new()
	b.setup(self, maxf(radius_t, 0.6), col)
	b.position = center
	add_child(b)
	shake(7.0 if kind == "fireball" else 3.0)


func register_unit(u: Node) -> void:
	if not units.has(u):
		units.append(u)


func unregister(u: Node) -> void:
	units.erase(u)


# -------------------------------------------------------------- reservations
# Damage promised to a unit by an attack already in flight. Target selection
# skips units whose remaining HP is already covered, so two shooters do not
# both waste a shot on the same doomed troop.

func reserve_damage(attacker_id: int, target: Node, amount: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	release_reservation(attacker_id)
	if target.get("incoming") == null:
		return
	target.incoming = float(target.incoming) + amount
	reservations[attacker_id] = {"target": target, "amount": amount, "ttl": 0.9}


func release_reservation(attacker_id: int) -> void:
	var r = reservations.get(attacker_id)
	if r == null:
		return
	reservations.erase(attacker_id)
	var t = r["target"]
	if is_instance_valid(t) and t.get("incoming") != null:
		t.incoming = maxf(0.0, float(t.incoming) - float(r["amount"]))


func _tick_reservations(delta: float) -> void:
	for k in reservations.keys():
		var r = reservations[k]
		r["ttl"] = float(r["ttl"]) - delta
		if float(r["ttl"]) <= 0.0:
			release_reservation(k)


func is_doomed(t: Node) -> bool:
	if t == null or not is_instance_valid(t):
		return true
	if t.get("incoming") == null:
		return false
	return float(t.incoming) >= float(t.get("hp"))


# ------------------------------------------------------------------- movement

## bridge_col: cross by this bridge rather than the nearest one (an ant that
## has changed lanes); -1 for the nearest.
func route_point(from: Vector2, goal: Vector2, bridge_col: float = -1.0) -> Vector2:
	var f := tile_of(from)
	var g := tile_of(goal)
	var toward_enemy := g.y < RIVER_TOP and f.y >= RIVER_TOP
	var toward_home := g.y > RIVER_BOTTOM and f.y <= RIVER_BOTTOM
	if not toward_enemy and not toward_home:
		return goal
	var bc := nearest_bridge_col(f.x) if bridge_col < 0.0 else bridge_col
	# the crossing runs down the deck's middle line (x = bc)
	var lane: Vector2 = tile_center(bc, float(RIVER_TOP) + 0.5).lerp(tile_center(bc, float(RIVER_BOTTOM) + 0.5), 0.5)
	var far_bank: Vector2 = tile_center(bc, float(RIVER_TOP) - 1.2) if toward_enemy else tile_center(bc, float(RIVER_BOTTOM) + 1.2)
	# line up with the bridge lane first (the axis the bridge runs along),
	# then step across; never aim at the lane from the wrong side or units
	# oscillate on the bank forever. Anything still over the deck counts as
	# lined up, so a shove sideways on the bridge does not send it back.
	var off := absf(from.y - lane.y) if LANDSCAPE else absf(from.x - lane.x)
	if off > TILE * (bridge_half(bc) - 0.3):
		# aim at the bridge mouth on our own bank so the walk in is diagonal
		var bank: Vector2 = tile_center(bc, float(RIVER_BOTTOM) + 1.0) if toward_enemy else tile_center(bc, float(RIVER_TOP) - 1.0)
		return bank
	return far_bank


## Bridges span cols (bx-1, bx), so a bridge's middle is the line x = bx, and
## the board's midline (between the two) splits the lanes. Measure from the
## tile's centre (col + 0.5): measuring from its edge put the first column
## south of the midline at an exact tie, which went to the north bridge.
## With three bridges the distance is to the deck's edge, so the wide middle
## bridge takes the columns it spans and the ones nearer it than a side deck.
func nearest_bridge_col(col: int) -> float:
	var c := float(col) + 0.5
	var best := float(bridges[0][0])
	var best_d := INF
	for b in bridges:
		var d: float = absf(float(b[0]) - c) if bridges.size() == 2 else maxf(0.0, absf(float(b[0]) - c) - float(b[1]))
		if d < best_d:
			best_d = d
			best = float(b[0])
	return best


# --------------------------------------------------------------------- spawns

func spawn_projectile(from: Vector2, to: Vector2, team: int, dmg: float, splash: float, kind: String,
		owner_id: int = 0, mode: String = "bolt", pierce: bool = false, owner_node: Node = null,
		speed_px: float = 0.0, target_node: Node = null, payload: Dictionary = {}) -> void:
	var p := DDProjectile.new()
	p.setup(self, from, to, team, dmg, splash, kind, owner_id, mode, pierce, owner_node, speed_px, target_node, payload)
	add_child(p)


func spawn_trail(at: Vector2, facing: float, team: int) -> void:
	var t := DDTrail.new()
	t.setup(self, facing, team)
	t.position = at
	add_child(t)


## A dying unit's confetti: the card's accent plus the owner's team colour,
## thrown further the bigger the body was.
func spawn_unit_confetti(at: Vector2, kind: String, team: int, radius_t: float) -> void:
	var accent: Color = DDCard.get_card(kind).get("accent", Color(0.8, 0.8, 0.8))
	var c := DDConfetti.new()
	c.setup([accent, team_color(team)], radius_t)
	c.position = at
	add_child(c)


func spawn_splash_burst(center: Vector2, radius_t: float, dmg: float, team: int, color: Color, tower_mult: float = 1.0) -> void:
	damage_at_point(center, radius_t, dmg, team, tower_mult)
	var b := DDBurst.new()
	b.setup(self, radius_t, color)
	b.position = center
	add_child(b)


## How a splash attack shows where it landed: a light circle in the attacker's
## colour, on screen for SPLASH_RING_FRAMES physics frames. Picture only.
const SPLASH_RING_FRAMES := 12


func spawn_splash_ring(center: Vector2, radius_t: float, team: int) -> void:
	var ring := Node2D.new()
	ring.position = center
	ring.z_index = 11
	var col: Color = team_color(team).lightened(0.45)
	var px: float = radius_t * float(TILE)
	ring.draw.connect(func() -> void:
		ring.draw_circle(Vector2.ZERO, px, Color(col.r, col.g, col.b, 0.38))
		ring.draw_arc(Vector2.ZERO, px, 0.0, TAU, 32, Color(col.r, col.g, col.b, 0.95), 2.0, true))
	add_child(ring)
	# counted on physics ticks, so it is the same 12 frames at any frame rate
	get_tree().create_timer(float(SPLASH_RING_FRAMES) / 60.0, false, true).timeout.connect(ring.queue_free)


func damage_at_point(center: Vector2, radius_t: float, dmg: float, team: int, tower_mult: float = 1.0) -> void:
	for e in enemy_entities(team):
		if not is_instance_valid(e):
			continue
		var amount := dmg
		if tower_mult != 1.0 and e.is_tower():
			amount = dmg * tower_mult
		var d: float = tiles_between(center, e.position)
		if radius_t <= 0.0:
			if d <= float(e.get_radius_t()) + 0.25:
				e.take_damage(amount, center)
		elif d <= radius_t + float(e.get_radius_t()) * 0.5:
			e.take_damage(amount, center)


func show_damage() -> bool:
	return view_mode == 1


func spawn_damage_text(at: Vector2, amount: float, tint: Color) -> void:
	if not show_damage():
		return
	var d = DDDamageText.new()
	d.setup(self, at, amount, tint)
	add_child(d)


func death_aoe(center: Vector2, radius_t: float, dmg: float, slow_amount: float, slow_time: float, owner_team: int) -> void:
	# troops only â€” the blast does not chip towers
	for e in enemy_units(owner_team).duplicate():
		if not is_instance_valid(e) or e.dead:
			continue
		if tiles_between(center, e.position) > radius_t + float(e.get_radius_t()) * 0.5:
			continue
		e.take_damage(dmg, center)
		if e.has_method("slow"):
			e.slow(slow_amount, slow_time)
	var b := DDBurst.new()
	b.setup(self, radius_t, Color(0.35, 0.55, 1.0))
	b.position = center
	add_child(b)
	shake(4.0)


const BOULDER_DIRECTIONS := 16


const BOULDER_RUNUP := 2.5


func spawn_boulder(from: Vector2, dir: Vector2, team: int) -> void:
	var b := DDBoulder.new()
	var snap := snap_direction(dir)
	# it breaks loose 2.5 tiles behind the idol so it rolls through the spot
	b.setup(self, snap, team, 1.0, from)
	b.position = from - snap * BOULDER_RUNUP * TILE
	add_child(b)


func snap_direction(dir: Vector2) -> Vector2:
	if dir.length() < 0.001:
		return Vector2(0, -1)
	var step := TAU / float(BOULDER_DIRECTIONS)
	var snapped := roundf(dir.angle() / step) * step
	return Vector2(cos(snapped), sin(snapped))


func shake(amount: float) -> void:
	shake_amount = maxf(shake_amount, amount)


func banner_flash(text: String) -> void:
	banner_text = text
	banner_timer = 2.0


# ------------------------------------------------------------------ card play

# --------------------------------------------------------------- hero abilities

func ability_name(player: int) -> String:
	match String(ability[player]):
		"tentacle":
			return "TENTACLE"
		"flame":
			return "KINDLE"
		"drone":
			return "DRONE"
	return "SHIESTY"


## Each commander's own colour, for a side that plays in its commander's colour
## (the options page): taken from the art (jelly core, goblin skin, the flame,
## the mantis's red).
const COMMANDER_COLORS := {
	"tentacle": Color(0.55, 0.35, 0.95),
	"shiesty": Color(0.42, 0.62, 0.24),
	"flame": Color(0.95, 0.45, 0.08),
	"drone": Color(0.82, 0.22, 0.14),
}


static func commander_color(kind: String) -> Color:
	return COMMANDER_COLORS.get(kind, Left_Color)


## The options page's side colours: a fixed pick, or that side's commander's.
func _apply_color_settings() -> void:
	Settings.ensure()
	var cols: Array = []
	for side in 2:
		cols.append(commander_color(String(ability[side])) if bool(Settings.commander[side])
			else Settings.side_color(side))
	team_colors = cols


## The commander behind each ability, for banners and the hover inspector.
static func commander_name(kind: String) -> String:
	match kind:
		"tentacle":
			return "Celestial Jelly"
		"flame":
			return "Flammenmeister"
		"drone":
			return "Man-Mantis"
	return "Goblin Warlord"


func ability_cost(player: int) -> int:
	return FLAME_COST if String(ability[player]) == "flame" else ABILITY_COST


func ability_aimed(player: int) -> bool:
	return AIMED_ABILITIES.has(String(ability[player]))


func ability_status(player: int) -> String:
	if match_over:
		return "-"
	if float(ability_cd[player]) > 0.0:
		return "%ds" % int(ceil(float(ability_cd[player])))
	if float(gold[player]) < float(ability_cost(player)):
		return "%dg" % ability_cost(player)
	if ability_aim == player:
		return "PICK"
	if String(ability[player]) == "tentacle" and _highest_hp_enemy_unit(player) == null:
		return "no target"
	if String(ability[player]) == "shiesty" and _highest_hp_enemy_tower(player) == null:
		return "no tower"
	if ability_aimed(player) and ability_targets(player).is_empty():
		return "no target"
	return "READY"


func ability_valid(player: int) -> bool:
	if match_over:
		return false
	if float(ability_cd[player]) > 0.0:
		return false
	if float(gold[player]) < float(ability_cost(player)):
		return false
	if String(ability[player]) == "tentacle":
		return _highest_hp_enemy_unit(player) != null
	if ability_aimed(player):
		return not ability_targets(player).is_empty()
	return _highest_hp_enemy_tower(player) != null


## Can `player`'s aimed ability be fired at `u`? Flammenmeister: any troop or
## building on the board, either side. Man-Mantis: an enemy one not already
## carrying a drone. Only real units (DDUnit): not towers, Shiesty, tentacles.
func ability_can_target(player: int, u: Node) -> bool:
	if u == null or not is_instance_valid(u) or not (u is DDUnit) or u.dead or u.held:
		return false
	if u.get("untargetable") == true:
		return false
	match String(ability[player]):
		"flame":
			return true
		"drone":
			return int(u.team) != player and int(u.drone_team) < 0
	return false


## Every unit the aimed ability could be fired at right now.
func ability_targets(player: int) -> Array:
	var out: Array = []
	for u in units:
		if ability_can_target(player, u):
			out.append(u)
	return out


## The aimed ability's target under a board point: the nearest valid body whose
## circle (plus a little slack) holds it.
func ability_target_at(player: int, world: Vector2) -> Node:
	var best: Node = null
	var best_d := INF
	for u in ability_targets(player):
		var d: float = tiles_between(world, u.position)
		if d <= float(u.get_radius_t()) + 0.35 and d < best_d:
			best_d = d
			best = u
	return best


## Circular ability button under the feet of the player's commander (goblin or
## jelly alike), clear of his head and HP bar. Clicking the commander himself
## works too: see the mouse handler.
func ability_button_rect(player: int) -> Rect2:
	var k: Node = _king_of(player)
	var at: Vector2 = k.position if is_instance_valid(k) else tile_center(9.5, 27.5)
	var sz := 46.0
	return Rect2(at + Vector2(-sz * 0.5, float(TILE) * 1.2), Vector2(sz, sz))


func _draw_ability_button(player: int) -> void:
	var r := ability_button_rect(player)
	var ready := ability_ready(player)
	var total: float = maxf(ability_cooldown_time(), float(ability_cd[player]))
	var f: float = clampf(1.0 - float(ability_cd[player]) / total, 0.0, 1.0)
	draw_circle(r.get_center(), 23.0, Color(0.1, 0.1, 0.14, 0.95))
	draw_arc(r.get_center(), 23.0, 0.0, TAU, 28, Color(0.35, 0.75, 0.45) if ready else Color(0.45, 0.45, 0.55), 2.5, true)
	if not ready:
		draw_arc(r.get_center(), 23.0, -PI * 0.5, -PI * 0.5 + TAU * f, 28, Color(0.55, 0.85, 1.0), 3.0, true)
	draw_string(ThemeDB.fallback_font, Vector2(r.position.x - 30.0, r.end.y + 14.0), ability_name(player),
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 60.0, 11,
		Color(0.85, 0.95, 0.85) if ready else Color(0.7, 0.7, 0.8))


## While an aimed ability is armed: a faint ring round everything it could hit,
## a bright one round the body under the cursor (green: Flammenmeister's warmth
## on a friend; orange: his fire on a foe; red: Man-Mantis's drone).
func _draw_ability_aim() -> void:
	if ability_aim < 0 or match_over:
		return
	var p: int = ability_aim
	var mouse := get_global_mouse_position()
	var hot: Node = ability_target_at(p, mouse)
	for u in ability_targets(p):
		var col := Color(1.0, 0.25, 0.2)
		if String(ability[p]) == "flame":
			col = Color(0.45, 0.95, 0.5) if int(u.team) == p else Color(1.0, 0.6, 0.15)
		var rad: float = (float(u.get_radius_t()) + 0.25) * float(TILE)
		if u == hot:
			draw_arc(u.position, rad, 0.0, TAU, 32, col, 3.0, true)
			draw_circle(u.position, rad, Color(col.r, col.g, col.b, 0.15))
		else:
			draw_arc(u.position, rad, 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.35), 1.5, true)
	# the cursor: a small reticle
	var rc := Color(1, 1, 1, 0.8)
	draw_arc(mouse, 10.0, 0.0, TAU, 20, rc, 1.5, true)
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(mouse + d * 6.0, mouse + d * 14.0, rc, 1.5, true)


func ability_ready(player: int) -> bool:
	if player < 0 or player > 1:
		return false
	return float(ability_cd[player]) <= 0.0


## An ability's payload has landed: a card for `team`, if it has the draw
## (ability_draws, the relic's hook).
func ability_payoff(team: int) -> void:
	if team >= 0 and team <= 1 and bool(ability_draws[team]):
		draw_card(team)


func use_ability(player: int) -> bool:
	if ability_aimed(player):
		# the button arms it (or puts it away again); the click on a unit fires it
		if ability_aim == player:
			ability_aim = -1
			return false
		if not ability_valid(player):
			return false
		clear_selection()
		ability_aim = player
		banner_flash("%s: pick a unit" % commander_name(String(ability[player])) if String(ability[player]) == "drone"
			else "%s: pick a friendly unit to heal, or an enemy to burn" % commander_name("flame"))
		return true
	if not ability_valid(player):
		return false
	if String(ability[player]) == "tentacle":
		var victim: Node = _highest_hp_enemy_unit(player)
		if victim == null:
			return false
		gold[player] = float(gold[player]) - float(ABILITY_COST)
		spend_gold_draw(player, float(ABILITY_COST))
		ability_cd[player] = ability_cooldown_time()
		var t := DDTentacle.new()
		t.hp = TENTACLE_HP
		t.max_hp = TENTACLE_HP
		t.life = TENTACLE_TIME
		t.dmg = TENTACLE_DMG
		t.interval = TENTACLE_INTERVAL
		t.setup(self, player, victim)
		t.position = victim.position
		units.append(t)
		add_child(t)
		# no reveal hit any more: the tentacle squeezes on its own clock
		if victim.get("stunned") != null:
			victim.stunned = TENTACLE_TIME
		banner_flash("Tentacle grabs %s!" % DDCard.pretty(String(victim.kind)))
		return true
	var tower: Node = _highest_hp_enemy_tower(player)
	if tower == null:
		return false
	gold[player] = float(gold[player]) - float(ABILITY_COST)
	spend_gold_draw(player, float(ABILITY_COST))
	ability_cd[player] = ability_cooldown_time()
	var king := _king_of(player)
	var g := DDShiesty.new()
	g.dmg = GOBLIN_DMG
	g.setup(self, player, tower, king)
	units.append(g)
	add_child(g)
	# cosmetic: the goblin commander scoops him up and throws him
	if is_instance_valid(king) and king.has_method("play_toss"):
		king.play_toss()
	banner_flash("Shiesty is on the job!")
	return true


## Fire `player`'s aimed ability at `u` (the click after arming it, or the bot
## directly). Pays and starts the cooldown only if it goes off.
func use_ability_on(player: int, u: Node) -> bool:
	if ability_aim == player:
		ability_aim = -1
	if not ability_aimed(player) or not ability_valid(player) or not ability_can_target(player, u):
		return false
	var cost := float(ability_cost(player))
	gold[player] = float(gold[player]) - cost
	spend_gold_draw(player, cost)
	ability_cd[player] = ability_cooldown_time()
	var king := _king_of(player)
	if String(ability[player]) == "flame":
		if int(u.team) == player:
			u.start_regen(FLAME_REGEN, FLAME_REGEN_TIME)
			banner_flash("Flammenmeister warms %s" % DDCard.pretty(String(u.kind)))
		else:
			# a weaker Firebolt, out of his own tower, homing on the unit
			var origin: Vector2 = u.position
			if is_instance_valid(king):
				origin = king.position + Vector2(0.0, -float(TILE) * 0.9)
			var fb: Dictionary = DDCard.get_card("firebolt")
			spawn_projectile(origin, u.position, player, 0.0, 0.0, "firebolt", 0, "bolt", false, null, 0.0, null,
				{"burn": FLAME_BOLT_BURN, "burn_ticks": int(fb.get("burn_ticks", 4)),
				"tower_mult": float(fb.get("tower_mult", 1.0)), "spell": true, "seek": u})
			banner_flash("Flammenmeister hurls fire at %s" % DDCard.pretty(String(u.kind)))
		ability_payoff(player)
	else:
		u.infect_drone(player)
		banner_flash("Man-Mantis plants a drone in %s" % DDCard.pretty(String(u.kind)))
	if is_instance_valid(king) and king.has_method("play_cast"):
		king.play_cast(u.position)
	return true


func _highest_hp_enemy_unit(player: int) -> Node:
	var best: Node = null
	var best_hp := -1.0
	for u in units:
		if not is_instance_valid(u) or u.dead:
			continue
		if int(u.team) == player:
			continue
		if u.get("hp") == null:
			continue
		var uhp := float(u.get("hp"))
		if uhp > best_hp:
			best_hp = uhp
			best = u
	return best


func _highest_hp_enemy_tower(player: int) -> Node:
	var best: Node = null
	var best_hp := -1.0
	for t in towers:
		if not is_instance_valid(t) or t.dead or int(t.team) == player:
			continue
		var thp := float(t.hp)
		if thp > best_hp + 0.001:
			best = t
			best_hp = thp
		elif absf(thp - best_hp) <= 0.001 and best != null and t.position.x < best.position.x:
			best = t
			best_hp = thp
	return best


func clear_selection() -> void:
	selected_player = -1
	selected_index = -1
	debug_kind = ""
	ability_aim = -1
	_sync_shelf_selection()


func selection_kind() -> String:
	if debug_kind != "":
		return debug_kind
	if selected_player >= 0 and selected_index >= 0:
		var h: Array = hands[selected_player]
		if selected_index < h.size():
			return String(h[selected_index])
	return ""


func selection_owner() -> int:
	return 0 if debug_kind != "" else selected_player


func pick_debug_card(kind: String) -> void:
	if kind == "":
		return
	if debug_kind == kind:
		clear_selection()
		return
	debug_kind = kind
	selected_player = 0
	selected_index = -1
	_sync_shelf_selection()


func toggle_debug_shelf() -> void:
	debug_shelf = not debug_shelf
	debug_kind = ""
	if shelf_grid != null:
		shelf_grid.visible = debug_shelf
		shelf_grid.selected_kind = ""
	banner_flash("DEBUG: all-cards shelf %s" % ("ON" if debug_shelf else "OFF"))


func deploy_debug(world: Vector2) -> void:
	if debug_kind == "" or match_over:
		return
	var t := tile_of(world)
	var team := 0
	if t.y <= BAND_TOP - 1:
		team = 1
	elif row_is_band(t.y):
		var c0 := controlled(0, t)
		var c1 := controlled(1, t)
		if c0 and c1:
			team = randi() % 2
		elif c1:
			team = 1
		elif c0:
			team = 0
		else:
			team = 0 if t.y >= BAND_BOTTOM - 1 else 1
	else:
		team = 0
	if not can_deploy(team, debug_kind, world):
		banner_flash("No room for %s there for player %d" % [DDCard.pretty(debug_kind), team + 1])
		return
	spawn_troop(debug_kind, team, world)
	banner_flash("DEBUG: %s for player %d" % [DDCard.pretty(debug_kind), team + 1])


## Debug cheat (Tab view, keys 1-3): 2 gold and a card for this player.
const DEBUG_GOLD := 2.0


func _debug_gold(player: int, message: String) -> void:
	gold[player] = minf(gold_max, float(gold[player]) + DEBUG_GOLD)
	draw_card(player)
	if message != "":
		banner_flash(message)


func pick_card(player: int, index: int) -> void:
	if match_over:
		return
	if view_mode == 0 and player == 1:
		return
	if index < 0:
		clear_selection()
		return
	if selected_player == player and selected_index == index:
		selected_player = -1
		selected_index = -1
		return
	var hand: Array = hands[player]
	if index < 0 or index >= hand.size():
		return
	# a card you cannot pay for can still be picked up and aimed â€” the gold is
	# only checked when the placement actually lands
	selected_player = player
	selected_index = index
	# picking a card puts an armed ability away
	ability_aim = -1


func can_deploy(team: int, kind: String, world: Vector2) -> bool:
	var t := tile_of(world)
	if not valid_tile(t):
		return false
	if DDCard.is_spell(kind):
		return true
	if is_water(t):
		return false
	# a building may not hang over the water either
	var card_fp: Array = DDCard.get_card(kind).get("footprint", [1, 1])
	if int(card_fp[0]) * int(card_fp[1]) > 1:
		for ft in DDBoard.footprint_layout(t, card_fp)["tiles"]:
			if is_water(ft):
				return false
	# a 1x1 building blocks its tile outright; a 2x2 lets you in and shoves you off
	var b := building_at(t)
	if b != null:
		var fp: Array = b.get("footprint") if b.get("footprint") != null else [1, 1]
		if int(fp[0]) * int(fp[1]) == 1:
			return false
	for tw in towers:
		if is_instance_valid(tw) and not tw.dead and int(tw.team) != team:
			if tiles_between(world, tw.position) < TOWER_BUFFER:
				return false
	if team == 0:
		if t.y >= BAND_BOTTOM + 1:
			return true
		if t.y >= BAND_BOTTOM - 1:
			return true
	else:
		if t.y <= BAND_TOP - 1:
			return true
		if t.y <= BAND_TOP + 1:
			return true
	if in_pocket(team, t):
		return true
	if row_is_band(t.y):
		return controlled(team, t)
	return false


## Where a card aimed at `world` actually lands: `world` itself if it can be
## deployed there, otherwise the centre of the closest tile that can (so hovering
## past your half pins the preview to the edge of it, and the click lands there).
## Vector2.INF when no tile at all is open to this card.
func deploy_point(team: int, kind: String, world: Vector2) -> Vector2:
	if kind == "" or can_deploy(team, kind, world):
		return world
	var best := Vector2.INF
	var best_d := INF
	for row in GRID_H:
		for col in range(col_min(row), col_max(row) + 1):
			var c := tile_center(float(col) + 0.5, float(row) + 0.5)
			var d := c.distance_squared_to(world)
			if d < best_d and can_deploy(team, kind, c):
				best_d = d
				best = c
	return best


func deploy(team: int, index: int, world: Vector2) -> void:
	var hand: Array = hands[team]
	if index < 0 or index >= hand.size():
		return
	var kind: String = hand[index]
	if gold[team] < DDCard.cost(kind):
		return
	if card_locked(team, index):
		return
	if not can_deploy(team, kind, world):
		banner_flash("Claim the middle to deploy there")
		return
	gold[team] -= DDCard.cost(kind)
	# a card that draws when played (Hero, Hot Chicken, Snowman) gives exactly
	# that card and nothing more: its gold does not pull the next draw closer
	if int(DDCard.get_card(kind).get("draws", 0)) <= 0:
		spend_gold_draw(team, float(DDCard.cost(kind)))
	if sfx != null:
		sfx.place_card()
	spawn_troop(kind, team, world)
	_relics_card_played(team)
	_sync_ids(team)
	var id: int = int(hand_ids[team][index])
	# a card with uses left (Firebolt) stays in the hand AND stays lifted, so the
	# next click casts it again; right click puts it back with the charge intact
	var total_uses := int(DDCard.get_card(kind).get("uses", 1))
	if total_uses > 1:
		var left := charges_of(team, kind, id) - 1
		if left > 0:
			charges[team][id] = left
			return
		charges[team].erase(id)
	hand.remove_at(index)
	hand_ids[team].remove_at(index)
	var cd: Dictionary = DDCard.get_card(kind)
	var becomes := String(cd.get("becomes", ""))
	var gives := String(cd.get("gives", ""))
	var arrives := becomes if becomes != "" else gives
	if arrives != "":
		# "becomes" (the whelps, which swap every play) or "gives" (Penny -> Pen):
		# the new card takes the played one's slot straight away and flies in from
		# where it was played. It is a new card with its own id.
		var new_id := _new_card_id()
		hand.insert(index, arrives)
		hand_ids[team].insert(index, new_id)
		_lock_card(new_id, float(DDCard.get_card(arrives).get("arrive_lock", 0.0)))
		for pn in panels:
			if is_instance_valid(pn) and int(pn.player) == team:
				pn.note_arrival(new_id, world, id)
	if becomes == "" and not bool(cd.get("spent", false)):
		# no automatic draw: the same copy cycles to the back of the deck. A card
		# that became another leaves the deck, and a spent one (Pen) is just gone.
		queues[team].append(kind)
		queue_ids[team].append(id)
	# a card that draws when played (Hero, Hot Chicken, Snowman): the next card
	# comes in now, and the draw clock stays exactly where it was
	for _i in int(cd.get("draws", 0)):
		if draw_card(team):
			# the drawn card flies in face down from the play and flips over in the
			# hand with a flash, so the draw is seen as the card's doing
			var drawn_id: int = int((hand_ids[team] as Array).back())
			for pn in panels:
				if is_instance_valid(pn) and int(pn.player) == team:
					pn.note_arrival(drawn_id, world, id, true)
	# only clear the selection that belongs to the player who played
	if selected_player == team:
		clear_selection()


func spawn_troop(kind: String, team: int, world: Vector2, single: bool = false) -> Node:
	var dominion: Dictionary = DDCard.get_card(kind).get("dominion", {})
	if not dominion.is_empty():
		# a Dominion card: the stat goes up for the rest of the fight, nothing lands
		var amt := float(dominion.get("amount", 1.0))
		if String(dominion["stat"]) == "puissance":
			add_puissance(team, amt)
		else:
			add_armor(team, amt)
		var king: Node = _king_of(team)
		if is_instance_valid(king):
			spawn_splash_ring(king.position, 1.6, team)
		banner_flash("%s: %s %d" % [DDCard.pretty(kind), "Puissance" if String(dominion["stat"]) == "puissance" else "Armor",
			int(puissance[team] if String(dominion["stat"]) == "puissance" else armor[team])])
		return null
	if DDCard.is_spell(kind):
		if kind == "snowball":
			# a rolling lane cleaner, not a bolt from a tower
			var sb := DDSnowball.new()
			sb.setup(self, team, world)
			add_child(sb)
			return sb
		var s := DDSpell.new()
		s.setup(self, kind, team)
		s.position = world
		add_child(s)
		return s
	var data: Dictionary = DDCard.get_card(kind)
	var world_tile := tile_of(world)
	var snapped := tile_center(float(world_tile.x) + 0.5, float(world_tile.y) + 0.5)
	var fp: Array = data.get("footprint", [1, 1])
	var occupied: Array = []
	if int(fp[0]) > 1 or int(fp[1]) > 1:
		# 2x2 buildings sit centred on the corner between four tiles and claim all four
		var layout := footprint_layout(world_tile, fp)
		snapped = layout["center"]
		occupied = layout["tiles"]
	else:
		# a building under our feet shoves the body off to the nearest free tile
		snapped = free_spot_near(snapped)
	if data.has("partner") and not single and data.has("partner_behind"):
		# a pair in file (the Mated Mantises): the card's own unit on the deploy
		# tile, the partner partner_behind tiles back towards its own side (team 0
		# holds the high rows). Kept on the board and pulled forward off water.
		var lead_m: Node = spawn_troop(kind, team, snapped, true)
		var back: float = float(data["partner_behind"]) * (1.0 if team == 0 else -1.0)
		var row: float = clampf(float(world_tile.y) + 0.5 + back, 0.5, float(GRID_H) - 0.5)
		while is_water(Vector2i(world_tile.x, int(floorf(row)))) and absf(row - (float(world_tile.y) + 0.5)) >= 1.0:
			row -= signf(back)
		var mate_at := free_spot_near(tile_center(float(world_tile.x) + 0.5, row))
		var mate_m: Node = spawn_troop(String(data["partner"]), team, mate_at, true)
		# spawn_troop snaps to a tile centre: put her back on the exact spot
		mate_m.position = mate_at
		lead_m.mate = mate_m
		mate_m.mate = lead_m
		return lead_m
	if data.has("partner") and not single:
		# a pair card (Gilgamesh & Enkidu): the card's own unit and its partner
		# land side by side across the lane, half the gap each way
		var half_gap := float(data.get("partner_gap", 1.0)) * 0.5 * TILE
		var lead: Node = spawn_troop(kind, team, snapped, true)
		var mate: Node = spawn_troop(String(data["partner"]), team, snapped, true)
		lead.position = snapped + Vector2(0.0, -half_gap)
		mate.position = snapped + Vector2(0.0, half_gap)
		return lead
	var offsets: Array = data.get("swarm_offsets", [])
	if offsets.is_empty() or single:
		var u := DDUnit.new()
		u.setup(kind, team, self)
		u.position = snapped
		u.occupied_tiles = occupied
		units.append(u)
		add_child(u)
		return u
	# swarm: spawn every bird of the formation, lead bird at the front
	var first: Node = null
	# mirror the formation on both axes: the lead bird stays at the FRONT of
	# the push, whichever side of the board the flock is deployed on
	var ydir := -1.0 if team == 0 else 1.0
	var xdir := 1.0 if team == 0 else -1.0
	# a pack card (the Wolf Pack): one shared dictionary is the whole pack's mind
	var pack: Dictionary = {}
	if data.has("pack"):
		pack = {"members": []}
	for i in offsets.size():
		var off: Array = offsets[i]
		var b := DDUnit.new()
		b.setup(kind, team, self)
		if data.has("pack"):
			b.pack = pack
			(pack["members"] as Array).append(b)
		if i == 0 and data.has("lead_hp"):
			var lead_hp := float(data["lead_hp"])
			b.max_hp = lead_hp
			b.hp = lead_hp
			b.bird_lead = true
			b.radius_t = float(data["radius"]) * 1.3
		b.position = snapped + Vector2(float(off[0]) * xdir, float(off[1]) * ydir) * TILE
		units.append(b)
		add_child(b)
		if first == null:
			first = b
	return first


# ------------------------------------------------------------- dragon / hero

func airborne_dragon_of(team_who_owns_it: int) -> Node:
	for u in units:
		if not is_instance_valid(u) or u.dead:
			continue
		if u.get("flying") != true:
			continue
		if int(u.team) == team_who_owns_it and String(u.kind) == "dragon":
			return u
	return null


func _king_of(owner: int) -> Node:
	for t in towers:
		if is_instance_valid(t) and not t.dead and int(t.team) == owner and bool(t.get("crown")):
			return t
	return null


func hero_prompt_active(player: int) -> bool:
	if match_over:
		return false
	if view_mode == 0 and player == 1:
		return false
	if gold[player] < 3.0:
		return false
	return airborne_dragon_of(1 - player) != null


func hero_prompt_rect(player: int) -> Rect2:
	var king: Node = _king_of(player)
	var base := tile_center(9.0, 27.0 if player == 0 else 3.0)
	if king != null:
		base = king.position
	var y: float = base.y - 128.0 if player == 0 else base.y + 92.0
	var board := board_rect()
	var x: float = clampf(base.x - 118.0, board.position.x + 8.0, board.end.x - 244.0)
	return Rect2(x, clampf(y, board.position.y + 6.0, board.end.y - 50.0), 236.0, 44.0)


func launch_hero(player: int) -> void:
	var dragon: Node = airborne_dragon_of(1 - player)
	if dragon == null or gold[player] < 3.0:
		return
	gold[player] -= 3.0
	spend_gold_draw(player, 3.0)
	var king: Node = _king_of(player)
	var src: Vector2 = king.position if king != null else dragon.position + Vector2(0.0, 240.0)
	var leapt := DDLeap.new()
	leapt.setup(self, src, dragon, player)
	add_child(leapt)
	banner_flash("A hero rides out against the dragon!")


## The first elite encounter. Until the run map exists it is started from the
## debug view (Tab, then S): the opponent, their three towers, their troops,
## their hand and their bot all go, and the ballista spider takes their place as
## the one "tower" on that side. See scripts/spider.gd and NOTES §9.
const SPIDER_SCRIPT := preload("res://scripts/spider.gd")
var spider: Node = null


func start_spider_encounter() -> void:
	if match_over or (spider != null and is_instance_valid(spider)) or (kraken != null and is_instance_valid(kraken)):
		return
	var enemy := 1
	for t in towers.duplicate():
		if is_instance_valid(t) and int(t.team) == enemy:
			towers.erase(t)
			t.queue_free()
	for u in units.duplicate():
		if is_instance_valid(u) and int(u.team) == enemy:
			u.dead = true
			units.erase(u)
			u.queue_free()
	bot_players[enemy] = false
	if bots[enemy] != null and is_instance_valid(bots[enemy]):
		bots[enemy].enabled = false
	if selected_player == enemy:
		clear_selection()
	hands[enemy] = []
	queues[enemy] = []
	# no opponent left to use it
	ability_cd[enemy] = 1.0e9
	var s: Node = SPIDER_SCRIPT.new()
	s.name = "Spider"
	s.setup(self, enemy)
	towers.append(s)
	add_child(s)
	spider = s
	_start_elite_clock()
	banner_flash("ELITE  —  the Ballista Matriarch")


## An elite fight starts the clock over with ELITE_SINGLE of single gold, and
## never ends on a side-tower lead: it always goes to sudden death.
func _start_elite_clock() -> void:
	elite_fight = true
	setup_clock(ELITE_SINGLE)


## The second elite encounter (Tab, then K): the same swap, but what takes the
## opponent's place is five tentacles, with the body under water until they are
## all down. See scripts/kraken.gd and NOTES §10.
const KRAKEN_SCRIPT := preload("res://scripts/kraken.gd")
var kraken: Node = null


func start_kraken_encounter() -> void:
	if match_over or (kraken != null and is_instance_valid(kraken)) or (spider != null and is_instance_valid(spider)):
		return
	var enemy := 1
	for t in towers.duplicate():
		if is_instance_valid(t) and int(t.team) == enemy:
			towers.erase(t)
			t.queue_free()
	for u in units.duplicate():
		if is_instance_valid(u) and int(u.team) == enemy:
			u.dead = true
			units.erase(u)
			u.queue_free()
	bot_players[enemy] = false
	if bots[enemy] != null and is_instance_valid(bots[enemy]):
		bots[enemy].enabled = false
	if selected_player == enemy:
		clear_selection()
	hands[enemy] = []
	queues[enemy] = []
	ability_cd[enemy] = 1.0e9
	var k: Node = KRAKEN_SCRIPT.new()
	k.name = "Kraken"
	k.setup(self, enemy)
	add_child(k)
	# the body joins `towers` itself when it surfaces; until then the tentacles
	# are the only things on that side to walk at
	for arm in k.arms:
		towers.append(arm)
		add_child(arm)
	kraken = k
	_start_elite_clock()
	banner_flash("ELITE  —  the South Sea Kraken")


func on_tower_destroyed(tower: Node) -> void:
	banner_flash("A tower falls!")
	var owner_team := int(tower.team)
	var alive := 0
	for t in towers:
		if is_instance_valid(t) and int(t.team) == owner_team and not t.dead:
			alive += 1
	# the commander tower is the whole objective now: taking it ends the match
	if bool(tower.get("crown")) and not match_over:
		match_over = true
		winner = 1 - owner_team
		banner_text = "PLAYER %d WINS" % (winner + 1)
		banner_timer = 999.0
		_match_ended()
		return
	# sudden death: the next tower to fall loses the match for its owner (an
	# elite fight is only ever ended by the commander or the boss)
	if phase == Phase.SUDDEN and not elite_fight and not match_over:
		match_over = true
		winner = 1 - owner_team
		banner_text = "SUDDEN DEATH  —  PLAYER %d WINS" % (winner + 1)
		banner_timer = 999.0
		_match_ended()


# ---------------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		# a held card (or an armed ability) is dropped first; with nothing held, Esc pauses
		if selected_index >= 0 or debug_kind != "" or ability_aim >= 0:
			clear_selection()
		else:
			set_paused(true)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		clear_selection()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		set_view_mode(1 - view_mode)
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_A and view_mode == 1:
		toggle_debug_shelf()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_B:
		toggle_bot(1)
		return
	# solo view: 1-8 pick a card straight out of the hand, 9 fires the ability
	if event is InputEventKey and event.pressed and not event.echo and view_mode == 0:
		if event.keycode >= KEY_1 and event.keycode <= KEY_8:
			if not panels.is_empty():
				panels[0].select_index(int(event.keycode - KEY_1))
			return
		if event.keycode == KEY_9:
			use_ability(0)
			return
	# debug cheats â€” only while both hands are on screen (Tab)
	if event is InputEventKey and event.pressed and not event.echo and view_mode == 1:
		if event.keycode == KEY_1:
			_debug_gold(0, "+2 gold and a card: PLAYER 1")
			return
		if event.keycode == KEY_2:
			_debug_gold(0, "+2 gold and a card: BOTH")
			_debug_gold(1, "")
			return
		if event.keycode == KEY_3:
			_debug_gold(1, "+2 gold and a card: PLAYER 2")
			return
		if event.keycode == KEY_S:
			start_spider_encounter()
			return
		if event.keycode == KEY_K:
			start_kraken_encounter()
			return
		# P: +1 Puissance, O: +1 Armor, for player 1 (with Shift: player 2)
		if event.keycode == KEY_P or event.keycode == KEY_O:
			var who := 1 if event.shift_pressed else 0
			if event.keycode == KEY_P:
				add_puissance(who, 1.0)
			else:
				add_armor(who, 1.0)
			banner_flash("DEBUG: player %d Puissance %d, Armor %d" % [who + 1, int(puissance[who]), int(armor[who])])
			return
	if event is InputEventKey and event.pressed and not event.echo and match_over and Run.active:
		# in a run the result screen moves the run on; R does not replay a fight
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			continue_run()
			return
		if event.keycode == KEY_R and Run.over:
			continue_run()
			return
		if event.keycode == KEY_R:
			return
	if event is InputEventKey and event.pressed and event.keycode == KEY_R and match_over:
		get_tree().reload_current_scene()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var am := get_global_mouse_position()
		var king: Node = _king_of(0)
		if ability_button_rect(0).has_point(am) or (is_instance_valid(king) and king.position.distance_to(am) < float(TILE) * 1.15):
			use_ability(0)
			return
		if match_over:
			return
		var world: Vector2 = event.position
		if ability_aim >= 0:
			# an armed ability owns the click: a unit under it fires it; anywhere
			# else keeps it armed (right-click or Esc puts it away)
			var who: int = ability_aim
			var hit: Node = ability_target_at(who, world)
			if hit != null:
				use_ability_on(who, hit)
			else:
				banner_flash("No unit there for %s" % commander_name(String(ability[who])))
			return
		for p in 2:
			if hero_prompt_active(p) and hero_prompt_rect(p).has_point(world):
				launch_hero(p)
				return
		if board_rect().has_point(world):
			# a card that is already lifted owns this click: the hand panel drops it on
			# release. Casting here too would fire a two-use card twice per click.
			var lifted := false
			for pn in panels:
				if is_instance_valid(pn) and pn.drag_card != null:
					lifted = true
					break
			if not lifted:
				try_deploy_at(world)
		else:
			clear_selection()


# --------------------------------------------------------------------- render

## Everything the arena paints lives in DDArenaDraw (scripts/arena_draw.gd): the
## board and terrain, the deploy hint, the hover box, the match HUD and the
## result overlay. This file stays about the rules.
func _draw() -> void:
	DDArenaDraw.draw_all(self, self)


func _hovered_entity(at: Vector2) -> Node:
	return DDArenaDraw.hovered(self, at)
