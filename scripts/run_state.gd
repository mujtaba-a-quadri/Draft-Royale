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

## What you start with: eight cards, repeats allowed.
const STARTER_DECK := ["troll", "hero", "neko", "anthill", "meerkats", "chicken",
	"fireball", "firebolt"]

## Placeholder act. type "battle" is a bot with `deck`; "elite" swaps the enemy
## side for a boss (`elite`: spider or kraken) as Tab+S / Tab+K do.
const ACT := [
	{"name": "Border Skirmish", "type": "battle",
		"deck": ["hero", "hero", "lizard", "snowman", "fireball", "hedgehog", "zombie", "firebolt"]},
	{"name": "Swamp Patrol", "type": "battle",
		"deck": ["troll", "frog", "frog", "fu", "penny", "aphid", "snowball", "idol"]},
	{"name": "Momma Ballista Spider", "type": "elite", "elite": "spider", "deck": []},
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
	ability = "tentacle" if rng.randf() < 0.5 else "shiesty"
	last = {}
	history = []
	over = false
	won_run = false
	rewarded = false
	print("[run] started: seed %d, %d card deck, ability %s" % [run_seed, deck.size(), ability])


func stop() -> void:
	active = false


func encounter() -> Dictionary:
	if floor_index < 0 or floor_index >= ACT.size():
		return {}
	return ACT[floor_index]


## The enemy's ability for this fight: whichever one you do not have.
func enemy_ability() -> String:
	return "shiesty" if ability == "tentacle" else "tentacle"


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


## The cards offered for the fight just won: REWARD_CHOICES different cards from
## the deck pool (DDCard.ORDER), the same ones every time for this run and fight.
## A card already in the deck can be offered again (duplicates are allowed).
func reward_choices() -> Array:
	var pool: Array = DDCard.ORDER.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(run_seed % 1000000) * 31 + floor_index * 7 + 3
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, mini(REWARD_CHOICES, pool.size()))


func take_reward(kind: String) -> void:
	if not reward_pending() or not reward_choices().has(kind):
		return
	deck.append(kind)
	rewarded = true
	if not history.is_empty():
		history[-1]["reward"] = kind


func skip_reward() -> void:
	if not reward_pending():
		return
	rewarded = true
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
