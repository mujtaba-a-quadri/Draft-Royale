extends RefCounted

## Every relic: what it is called, what it says, and the data its effect reads.
## No class_name (a new one needs an editor rescan before a headless run sees
## it): arena.gd, run_state.gd and the reward screen preload this file.
##
## Effects live where they happen and read these fields:
##   start_puissance / start_armor  arena._apply_relics_start(): +N at the fight's start
##   start_heal                     the commander heals N at the fight's start
##   window {need, secs, gives}     arena: play `need` cards within `secs` s of each
##                                  other -> `gives` ("gold" 1, or "draw" a card); the
##                                  window then empties and starts over
##   idle {secs}                    arena: `secs` s without playing a card -> draw a
##                                  card, and the wait starts over
##   ledger {every}                 arena: every `every`-th whole gold of natural
##                                  income comes as 2
##   lucky {at}                     arena: natural income carrying gold up past `at`
##                                  (from below it) gives 1 more
##   king_mult                      tower.gd: the king tower's shots hit this much harder
##   fuel                           run_state.gd / reward_screen.gd: Fuel for the Fire
## `starter` relics belong to a commander and are never awarded; `placeholder`
## ones do nothing yet.

const RELICS := {
	"whetstone": {
		"name": "Whetstone",
		"text": "Start each fight with 1 Puissance.",
		"start_puissance": 1.0,
	},
	"tortoise_shell": {
		"name": "Tortoise Shell",
		"text": "Start each fight with 1 Armor.",
		"start_armor": 1.0,
	},
	"metronome": {
		"name": "Metronome",
		"text": "Play 3 cards within 9 seconds: gain 1 gold.",
		"window": {"need": 3, "secs": 9.0, "gives": "gold"},
	},
	"sleight": {
		"name": "Sleight of Hand",
		"text": "Play 4 cards within 12 seconds: draw a card.",
		"window": {"need": 4, "secs": 12.0, "gives": "draw"},
	},
	"hourglass": {
		"name": "Hourglass",
		"text": "Go 9 seconds without playing a card: draw a card.",
		"idle": {"secs": 9.0},
	},
	"ledger": {
		"name": "Miser's Ledger",
		"text": "Every 4th gold you earn over time comes as 2.",
		"ledger": {"every": 4},
	},
	"lucky7": {
		"name": "Lucky 7",
		"text": "Whenever your gold climbs from 7 to 8 over time, you get 2 gold instead of 1.",
		"lucky": {"at": 8.0},
	},
	"field_dressing": {
		"name": "Field Dressing",
		"text": "Your commander heals 10 at the start of each fight.",
		"start_heal": 10.0,
	},
	# the commanders' own, one each, from the start of a run
	"fuel": {
		"name": "Fuel for the Fire",
		"text": "Skip a card reward and the next one shows 4 cards, but you cannot take just 1: skip again (and the next stays this way), or take 2 and remove a card from your deck.",
		"fuel": true,
		"starter": "flame",
	},
	"warhorn": {
		"name": "Warlord's Horn",
		"text": "Your king tower deals 1.5x damage.",
		"king_mult": 1.5,
		"starter": "shiesty",
	},
	"abyssal_pearl": {
		"name": "Abyssal Pearl",
		"text": "The Celestial Jelly's relic. (Placeholder: does nothing yet.)",
		"placeholder": true,
		"starter": "tentacle",
	},
	"hive_shard": {
		"name": "Hive Shard",
		"text": "Man-Mantis's relic. (Placeholder: does nothing yet.)",
		"placeholder": true,
		"starter": "drone",
	},
}


static func get_relic(id: String) -> Dictionary:
	return RELICS.get(id, {})


static func relic_name(id: String) -> String:
	return String(get_relic(id).get("name", id))


## The relic a commander starts a run with.
static func starter_for(ability: String) -> String:
	for id in RELICS:
		if String(RELICS[id].get("starter", "")) == ability:
			return String(id)
	return ""


## Every relic a reward can give, in a fixed order (commanders' own excluded).
static func award_pool() -> Array:
	var out: Array = []
	for id in RELICS:
		if not RELICS[id].has("starter"):
			out.append(String(id))
	return out
