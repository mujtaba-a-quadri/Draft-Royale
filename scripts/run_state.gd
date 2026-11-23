extends Node

## The run layer's state, as an autoload ("Run" in project.godot) so it outlives
## the scene reload between fights. No class_name on purpose (a new class_name
## needs an editor rescan before a headless run can see it).
##
## A run is a list of encounters fought in order with one deck. What carries
## from fight to fight: the deck, and your **commander tower's HP** (side towers
## come back full every fight, the enemy's commander too). Win a fight and the
## next one is up; lose one (the commander falls, or the clock runs out against
## you, or a draw) and the run is over.
##
## The arena reads it in _ready (`arena._apply_run()`), reports once when the
## match ends (`report()`), shows the card reward after a win
## (`reward_choices()` / `take_reward()` / `skip_reward()`), and the result
## screen moves it on (`advance()` / `start()`). A real act is a later step; the
## encounter list below is a placeholder to make the loop playable.
##
## Pressing play starts one (`--run=<seed>` for a fixed seed); `--match` plays a
## single plain match instead.

const COMMANDER_MAX := 250.0

## What you start with: ten cards, repeats allowed. Deliberately plain basics
## (Militia, an Elf Archer, Honeycreepers, a Firebolt, the Alchemist), two that
## draw a card (Hot Chicken, Snowman) and one blunt win condition, Humbaba: weak
## enough that every card you draft is a visible step up, but always with a way
## to take a tower. Every card not in it can be drafted (draft_pool).
const STARTER_DECK := ["troll", "alchemist", "chicken", "snowman", "militia", "militia", "militia",
	"elf", "hawk", "firebolt"]

## The elite pool: which boss an "elite" fight can be, and its name. One is
## picked per run and fight from the run seed (encounter_at).
const ELITES := {"spider": "Ballista Matriarch", "kraken": "South Sea Kraken"}

## Placeholder act. type "battle" is a bot with `deck`; "elite" swaps the enemy
## side for a boss (`elites`: drawn from that list, spider or kraken) as Tab+S /
## Tab+K do.
const ACT := [
	# the first fight is on basics too, with the same blunt win condition, so the
	# starter can win it; the decks climb from here
	{"name": "Border Skirmish", "type": "battle",
		"deck": ["militia", "militia", "militia", "elf", "snowman", "firebolt", "hero", "troll"]},
	{"name": "Swamp Patrol", "type": "battle",
		"deck": ["troll", "frog", "frog", "fu", "penny", "aphid", "snowball", "idol"]},
	{"name": "Elite", "type": "elite", "elites": ["spider", "kraken"], "deck": []},
	{"name": "The Chained Keep", "type": "battle",
		"deck": ["dragon", "alchemist", "warren", "ovomachine", "laniakea", "femme", "gilgamesh", "wu", "neko"]},
]

var active := false
var run_seed := 0
var deck: Array = []
var commander_hp := COMMANDER_MAX
## index into ACT of the fight being played (or just played)
var floor_index := 0
## your hero ability for the whole run
var ability := "tentacle"
## Puissance and Armor every fight of the run starts with (relics will raise
## these); the arena copies them in and builds on them for that fight only.
var puissance := 0.0
var armor := 0.0
## Relics held (ids in scripts/relic_db.gd): your commander's own from the
## start, then one after every 2nd regular fight won and every elite won.
const RELIC_DB := preload("res://scripts/relic_db.gd")
var relics: Array = []
var normal_wins := 0
## Fuel for the Fire: a reward was skipped, so the next one is the 4-card kind
## (take 2 and remove 1, or skip again).
var fueled := false
## the match just played: {"won", "winner", "commander_hp", "name"}; empty while playing
var last: Dictionary = {}
## one entry per finished fight
var history: Array = []
var over := false
var won_run := false
## After a won fight (not the last), a card reward: pick 1 of REWARD_CHOICES
## different cards, or skip. `rewarded` is set once it has been taken or skipped.
const REWARD_CHOICES := 3
var rewarded := false
## What the title screen asked for: "match" (a plain match with the whole
## collection), "run" (a fresh run), or "" (launched straight into the arena:
## the old default, a run unless --match / a dev flag says otherwise).
var menu_choice := ""


func start(p_seed: int = -1) -> void:
	var rng := RandomNumberGenerator.new()
	if p_seed >= 0:
		rng.seed = p_seed
	else:
		rng.randomize()
	run_seed = rng.randi() if p_seed < 0 else p_seed
	active = true
	deck = STARTER_DECK.duplicate()
	commander_hp = COMMANDER_MAX
	floor_index = 0
	puissance = 0.0
	armor = 0.0
	normal_wins = 0
	fueled = false
	# your commander for the whole run, out of the whole pool (Arena.ABILITIES);
	# --ability= fixes it (the rng draw is made either way, so seeds stay put)
	ability = String(Arena.ABILITIES[rng.randi() % Arena.ABILITIES.size()])
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ability="):
			var want := String(a.substr(10))
			want = {"goblin": "shiesty", "flammenmeister": "flame", "manmantis": "drone", "mantis": "drone"}.get(want, want)
			if Arena.ABILITIES.has(want):
				ability = want
	# and its own relic
	relics = []
	var own := String(RELIC_DB.starter_for(ability))
	if own != "":
		relics.append(own)
	last = {}
	history = []
	over = false
	won_run = false
	rewarded = false
	print("[run] started: seed %d, %d card deck, ability %s" % [run_seed, deck.size(), ability])


func stop() -> void:
	active = false


func encounter() -> Dictionary:
	return encounter_at(floor_index)


## How many regular (non-elite) fights come before fight i: each one adds
## arena.SINGLE_STEP seconds to the next regular fight's single-gold period.
func battles_before(i: int) -> int:
	var n := 0
	for k in mini(i, ACT.size()):
		if String((ACT[k] as Dictionary).get("type", "battle")) == "battle":
			n += 1
	return n


## Fight i of the act. An elite fight draws its boss from its `elites` pool,
## seeded by the run seed and the fight, so it is the same boss every time it
## is asked for (the "next:" line, the fight itself, the summary).
func encounter_at(i: int) -> Dictionary:
	if i < 0 or i >= ACT.size():
		return {}
	var e: Dictionary = ACT[i]
	if not e.has("elites"):
		return e
	var pool: Array = e["elites"]
	if pool.is_empty():
		return e
	var rng := RandomNumberGenerator.new()
	# hashed, so neighbouring run seeds do not draw in lockstep
	rng.seed = hash("elite:%d:%d" % [run_seed, i])
	var pick := String(pool[rng.randi_range(0, pool.size() - 1)])
	e = e.duplicate()
	e["elite"] = pick
	e["name"] = String(ELITES.get(pick, pick))
	return e


## The enemy's commander for this fight: one of the others in the pool, seeded
## by the run and the fight (the same one every time it is asked for).
func enemy_ability() -> String:
	var rest: Array = Arena.ABILITIES.duplicate()
	rest.erase(ability)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("enemy:%d:%d" % [run_seed, floor_index])
	return String(rest[rng.randi_range(0, rest.size() - 1)])


## The seed this fight's decks are shuffled from (same run seed, same fight,
## same opening hands).
func deck_seed() -> int:
	return int(run_seed % 1000000) * 16 + floor_index


## Called by the arena exactly once, when the match ends.
func report(winner: int, commander_left: float) -> void:
	if not active or not last.is_empty():
		return
	commander_hp = clampf(commander_left, 0.0, COMMANDER_MAX)
	var won := winner == 0 and commander_hp > 0.0
	last = {"won": won, "winner": winner, "commander_hp": commander_hp,
		"name": String(encounter().get("name", ""))}
	history.append({"floor": floor_index, "name": last["name"], "won": won, "commander_hp": commander_hp})
	if not won:
		over = true
	elif floor_index >= ACT.size() - 1:
		over = true
		won_run = true
	else:
		# a relic after every elite, and after every 2nd regular fight won
		var due := false
		if String(encounter().get("type", "battle")) == "elite":
			due = true
		else:
			normal_wins += 1
			due = normal_wins % 2 == 0
		if due:
			_award_relic()


## One relic you do not have yet, out of the award pool, the same one every
## time for this run and fight. Noted in `last` for the reward screen.
func _award_relic() -> void:
	var pool: Array = RELIC_DB.award_pool()
	for id in relics:
		pool.erase(id)
	if pool.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("relic:%d:%d" % [run_seed, floor_index])
	var id := String(pool[rng.randi_range(0, pool.size() - 1)])
	relics.append(id)
	last["relic"] = id
	if not history.is_empty():
		history[-1]["relic"] = id


## A won fight is behind us and the run goes on.
func can_continue() -> bool:
	return active and not over and bool(last.get("won", false))


func advance() -> void:
	if not can_continue():
		return
	floor_index += 1
	last = {}
	rewarded = false


## A won fight with the run still going, and the card not yet taken or skipped.
func reward_pending() -> bool:
	return can_continue() and not rewarded


## Every card a reward can offer: the whole deck order less the starter deck.
func draft_pool() -> Array:
	return DDCard.draft_pool(STARTER_DECK)


## The cards offered for the fight just won: REWARD_CHOICES different cards from
## the draft pool (draft_pool(): every card not in the starter deck), the same
## ones every time for this run and fight. A card already in the deck can be
## offered again (duplicates are allowed).
func reward_choices() -> Array:
	var n := REWARD_CHOICES + (1 if fueled_now() else 0)
	var pool: Array = draft_pool()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(run_seed % 1000000) * 31 + floor_index * 7 + 3
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, mini(n, pool.size()))


## Fuel for the Fire is lit: this reward is the 4-card kind.
func fueled_now() -> bool:
	return fueled and relics.has("fuel")


func take_reward(kind: String) -> void:
	# a fueled reward cannot be taken one card at a time (take_two)
	if not reward_pending() or fueled_now() or not reward_choices().has(kind):
		return
	deck.append(kind)
	rewarded = true
	if not history.is_empty():
		history[-1]["reward"] = kind


## The fueled reward: two different cards offered go in, `removed` (a card in
## the deck as it was) comes out, and the next reward is a normal one again.
func take_two(a: String, b: String, removed: String) -> bool:
	var offered := reward_choices()
	if not reward_pending() or not fueled_now() or a == b or not offered.has(a) or not offered.has(b):
		return false
	var at := deck.find(removed)
	if at < 0:
		return false
	deck.remove_at(at)
	deck.append(a)
	deck.append(b)
	rewarded = true
	fueled = false
	if not history.is_empty():
		history[-1]["reward"] = "%s+%s -%s" % [a, b, removed]
	return true


func skip_reward() -> void:
	if not reward_pending():
		return
	rewarded = true
	# with Fuel for the Fire, skipping lights it: the next reward is the 4-card
	# kind (and skipping that keeps it lit)
	if relics.has("fuel"):
		fueled = true
	if not history.is_empty():
		history[-1]["reward"] = ""


## A few short lines for the HUD: where you are and what your commander has left.
func status_lines() -> Array:
	return [
		"RUN  fight %d / %d" % [floor_index + 1, ACT.size()],
		String(encounter().get("name", "")),
		"commander %d / %d" % [int(ceilf(commander_hp)), int(COMMANDER_MAX)],
		"deck %d cards" % deck.size(),
	]
