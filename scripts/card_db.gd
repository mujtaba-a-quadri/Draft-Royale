class_name DDCard
extends RefCounted

## Card definitions. Everything the arena needs to build a unit or resolve a spell
## lives here so deck building / relics can later mutate copies of these values.

const CARDS := {
	"hero": {
		"name": "Hero",
		"cost": 3,
		"type": "troop",
		"blurb": "Armoured duelist. Enormous HP for 3 gold. Also rides the dragon down.",
		"hp": 150.0, "dmg": 15.0, "speed": 1.05, "reach": 0.4, "interval": 1.0,
		"radius": 0.45, "splash": 0.0, "aggro": 5.5, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"accent": Color(0.86, 0.87, 0.93),
	},
	"snowman": {
		"name": "Snowman",
		"cost": 2,
		"type": "building",
		"blurb": "Immobile decoy. Soaks hits, hits nothing.",
		"hp": 90.0, "dmg": 0.0, "speed": 0.0, "reach": 0.0, "interval": 1.0,
		"radius": 0.5, "splash": 0.0, "aggro": 0.0, "stationary": true, "lifetime": 60.0,
		"buildings_only": false,
		"footprint": [1, 1],
		"death_aoe": {"radius": 3.0, "dmg": 30.0, "slow": 0.3, "slow_time": 3.0},
		"accent": Color(0.78, 0.9, 1.0),
	},
	"slate": {
		"name": "Slate",
		"cost": 3,
		"type": "troop",
		"blurb": "200 HP jawbreaker. Ignores troops, walks at structures, and builds up a rolling charge.",
		"hp": 200.0, "dmg": 25.0, "speed": 0.62, "reach": 0.35, "interval": 1.6,
		"radius": 0.5, "splash": 0.0, "aggro": 4.0, "stationary": false, "lifetime": 0.0,
		"buildings_only": true,
		"roll": {"interval": 3.0, "speed_mult": 2.0, "max_level": 2, "damage_bonus": 0.5},
		"accent": Color(0.277, 0.133, 0.023, 1.0),
	},
	"alchemist": {
		"name": "Alchemist",
		"cost": 4,
		"type": "troop",
		"blurb": "Splash potions. Below half HP he turns on his own tower and blows up.",
		"hp": 90.0, "dmg": 45.0, "speed": 1.05, "reach": 3.2, "interval": 2.0,
		"radius": 0.42, "splash": 1.4, "aggro": 7.5, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"hits_air": true,
		"accent": Color(0.5, 0.82, 0.4),
	},
	"idol": {
		"name": "Golden Idol",
		"cost": 4,
		"type": "building",
		"blurb": "Enemies cannot resist it. Break it and a boulder takes revenge.",
		"hp": 35.0, "dmg": 0.0, "speed": 0.0, "reach": 0.0, "interval": 1.0,
		"radius": 0.55, "splash": 0.0, "aggro": 0.0, "stationary": true, "lifetime": 10.0,
		"buildings_only": false,
		"footprint": [1, 1],
		"accent": Color(0.98, 0.8, 0.3),
	},
	"fireball": {
		"name": "Fireball",
		"cost": 5,
		"type": "spell",
		"blurb": "Fired from your king tower: 40 damage, 60 burn, and everything loose is shoved away.",
		"hp": 0.0, "dmg": 40.0, "speed": 0.0, "reach": 0.0, "interval": 0.0,
		"radius": 2.2, "splash": 2.2, "aggro": 0.0, "stationary": true, "lifetime": 0.0,
		"buildings_only": false,
		"burn": 70.0, "knock": 1.2, "launch": "king",
		"tower_mult": 0.40,
		"accent": Color(1.0, 0.55, 0.15),
	},
	"firebolt": {
		"name": "Firebolt",
		"cost": 2,
		"type": "spell",
		"blurb": "An arrow of fire from your nearest tower. No damage, but 60 burn on whatever it lands on.",
		"hp": 0.0, "dmg": 0.0, "speed": 0.0, "reach": 0.0, "interval": 0.0,
		"radius": 0.6, "splash": 0.6, "aggro": 0.0, "stationary": true, "lifetime": 0.0,
		"buildings_only": false,
		"burn": 60.0, "launch": "closest",
		"tower_mult": 0.40,
		"unit_lock": true,
		"uses": 2,
		"accent": Color(1.0, 0.78, 0.28),
	},
	"chicken": {
		"name": "Hot Chicken",
		"cost": 2,
		"type": "troop",
		"blurb": "Pecks fireballs from range. Three hits on one target and it takes to the air: a flying fire spirit that rams for 30 splash and takes itself with it. Shoot it down before it lands.",
		"hp": 45.0, "dmg": 5.0, "speed": 1.35, "reach": 3.5, "interval": 0.75,
		"radius": 0.4, "splash": 0.0, "aggro": 5.5, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"hits_air": true,
		"burn": 5.0,
		"chicken": {"hits_to_fly": 3, "fire_speed": 620.0, "burst_reach": 0.3},
		"kamikaze": {"radius": 1.4, "dmg": 30.0},
		"accent": Color(1.0, 0.55, 0.2),
	},
	"penny": {
		"name": "Penny",
		"cost": 3,
		"type": "troop",
		"blurb": "Calico blur. Only ever goes after troops. Three quick swipes, then she fades out, backs off and circles around them.",
		"hp": 90.0, "dmg": 10.0, "speed": 2.5, "reach": 0.45, "interval": 0.7,
		"radius": 0.34, "splash": 0.0, "aggro": 5.5, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"troops_only": true,
		"dodge": {"after_hits": 2, "time": 0.9, "back": 0.5, "sweep_deg": 90.0,
			"jump_time": 0.35, "jump_reach": 2.5, "jump_mult": 2.0},
		"accent": Color(0.95, 0.62, 0.28),
	},
	"aphid": {
		"name": "Primal Aphid",
		"cost": 3,
		"type": "troop",
		"blurb": "Hovers in at two tiles and spits a five pellet cone. The pellets carry three and a half tiles past that, so it softens a lane without ever closing.",
		"hp": 110.0, "dmg": 40.0, "speed": 1.15, "reach": 2.0, "interval": 2.0,
		"radius": 0.45, "splash": 0.0, "aggro": 6.5, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"hits_air": true,
		"flying_unit": true,
		"spread": {"count": 5, "cone_deg": 45.0, "reach": 3.5, "speed": 780.0, "dmg": 8.0},
		"accent": Color(0.94, 0.86, 0.7),
	},
	"pen": {
		"name": "Pen",
		"cost": 2,
		"type": "troop",
		"blurb": "Penny's other half: slow, unbothered, and carrying a five tile blowgun. Every dart paralyses whatever it hits for half a second.",
		"hp": 100.0, "dmg": 10.0, "speed": 0.7, "reach": 5.0, "interval": 1.8,
		"radius": 0.42, "splash": 0.0, "aggro": 6.0, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"hits_air": true,
		"shoots": "dart",
		"payload": {"stun": 0.5},
		"accent": Color(0.86, 0.72, 0.24),
	},
	"lizard": {
		"name": "Lizard Soldiers",
		"cost": 3,
		"type": "troop",
		"blurb": "Three small spear-carriers in a wedge. They ignore the nearest threat and go for whoever is weakest.",
		"hp": 55.0, "dmg": 10.0, "speed": 0.85, "reach": 3.5, "interval": 1.0,
		"shoots": "rifle",
		"radius": 0.38, "splash": 0.0, "aggro": 5.5, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"hits_air": true,
		"targets_weakest": true,
		"presence_shift": 1,
		"swarm_offsets": [[0.0, 0.8], [-0.75, -0.6], [0.75, -0.6]],
		"accent": Color(0.58, 0.86, 0.46),
	},
	"warren": {
		"name": "Lizard Warren",
		"cost": 4,
		"type": "building",
		"blurb": "A burrow that empties itself when enemies come close: three soldiers, then a pause.",
		"hp": 130.0, "dmg": 0.0, "speed": 0.0, "reach": 0.0, "interval": 0.0,
		"radius": 0.75, "splash": 0.0, "aggro": 0.0, "stationary": true, "lifetime": 60.0,
		"buildings_only": false,
		"footprint": [2, 2],
		"summon": {"unit": "lizard", "count": 3, "range": 6.0, "cooldown": 6.0},
		"accent": Color(0.62, 0.8, 0.44),
	},
	"snowball": {
		"name": "Snowball",
		"cost": 4,
		"type": "spell",
		"blurb": "Thrown in an arc out of your nearest tower onto the tile you pick, then rolls forward from there: one tile of snow, a tile taller for every two it covers, 10 damage per tile of height with a shove to match, then a 30 damage burst and a 3.5 second slow when it reaches the river.",
		"hp": 0.0, "dmg": 30.0, "speed": 0.0, "reach": 0.0, "interval": 0.0,
		"radius": 0.6, "splash": 1.0, "aggro": 0.0, "stationary": true, "lifetime": 0.0,
		"buildings_only": false,
		"slow": 0.32, "slow_time": 3.5,
		"launch": "closest",
		"roll": {"speed": 4.2, "dmg": 10.0, "push": 1.0},
		"accent": Color(0.72, 0.86, 1.0),
	},
	"ovomachine": {
		"name": "In-Ovo Machine",
		"cost": 6,
		"type": "building",
		"blurb": "An industrial hatchery: a two by two block of steel that cranks out a hot chicken through the front hatch every twelve seconds.",
		"hp": 240.0, "dmg": 0.0, "speed": 0.0, "reach": 0.0, "interval": 0.0,
		"radius": 0.95, "splash": 0.0, "aggro": 0.0, "stationary": true, "lifetime": 60.0,
		"buildings_only": false,
		"footprint": [2, 2],
		"summon": {"unit": "chicken", "interval": 12.0, "spot": "front"},
		"accent": Color(0.74, 0.66, 0.58),
	},
	"fu": {
		"name": "Boomerang-Fu",
		"cost": 5,
		"type": "troop",
		"blurb": "Holds still until his boomerang comes home. Kicks out of melee to throw again.",
		"hp": 90.0, "dmg": 30.0, "speed": 1.1, "reach": 3.4, "interval": 1.4,
		"radius": 0.42, "splash": 0.0, "aggro": 6.5, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"hits_air": true,
		"cooldown_per_tile": 0.18,
		"boomerang": {
			"throw_speed_tiles": 10.0,
			"melee_range": 1.2,
			"melee_dmg": 18.0,
			"melee_interval": 0.45,
			"combo_hits": 3,
			"kick_dmg": 26.0,
			"kick_push": 1.5,
			"self_push": 1.1,
		},
		"accent": Color(0.45, 0.68, 0.95),
	},
	"hedgehog": {
		"name": "Hedgehog",
		"cost": 3,
		"type": "troop",
		"blurb": "Walks up slowly and curls into a ball: 45 % damage taken, a quill burst, and a shove that never quite gets you out of reach. Ignores anything in the air — until one dives on it.",
		"hp": 60.0, "dmg": 12.0, "speed": 1.0, "reach": 0.6, "interval": 1.2,
		"radius": 0.4, "splash": 0.0, "aggro": 5.5, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"swarm_offsets": [[0, 0.6], [0, -0.6]],
		"curl": {
			"thorn_range": 1.5, "burst_dmg": 12.0, "thorn_dmg": 8.0,
			"push": 0.5, "push_time": 0.22, "damage_mult": 0.45,
		},
		"accent": Color(0.66, 0.52, 0.38),
	},
	"zombie": {
		"name": "Zombie Horde",
		"cost": 6,
		"type": "troop",
		"blurb": "Six bruisers that refuse to stay dead. Anything they kill gets back up as one of theirs.",
		"hp": 111.0, "dmg": 15.0, "speed": 0.85, "reach": 0.5, "interval": 1.0,
		"radius": 0.42, "splash": 0.0, "aggro": 5.5, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"swarm_offsets": [[-0.8, -0.9], [0.8, -0.9], [-1.2, 0.1], [1.2, 0.1], [-0.8, 1.1], [0.8, 1.1]],
		"accent": Color(0.55, 0.72, 0.42),
	},
	"hawk": {
		"name": "Honeycreeper Flock",
		"cost": 2,
		"type": "troop",
		"blurb": "Four flyers in a diamond. The red i'iwi leads and soaks two tower shots; the rest die to one.",
		"hp": 10.0, "dmg": 6.0, "speed": 1.9, "reach": 0.7, "interval": 1.0,
		"radius": 0.26, "splash": 0.0, "aggro": 6.0, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"hits_air": true,
		"flying_unit": true,
		"lead_hp": 20.0,
		"swarm_offsets": [[0.8, 0.0], [-0.8, -0], [0, -0.8], [0, 0.8]],
		"accent": Color(0.99, 0.8, 0.22),
	},
	"dragon": {
		"name": "The Chained Dragon",
		"cost": 9,
		"type": "troop",
		"blurb": "Chained by the wings, so it can only claw. At half HP the chains burst and it takes the sky, pouring fire straight down onto the ground it crosses.",
		"hp": 420.0, "dmg": 45.0, "speed": 0.55, "reach": 1.6, "interval": 1.4,
		"radius": 1.15, "splash": 0.0, "aggro": 7.5, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"hits_air": true,
		"giant": true,
		"accent": Color(0.9, 0.45, 0.3),
	},
	# Not in ORDER: entities that never appear in a deck but still need a real
	# identity for the hover inspector and any card lookup.
	"shiesty": {
		"name": "Shiesty",
		"cost": 2,
		"type": "troop",
		"blurb": "The ability's thief. Lands on the enemy's healthiest tower, steals 1 gold and runs home. Towers ignore him; troops do not.",
		"hp": 32.0, "dmg": 30.0, "speed": 2.2, "reach": 1.0, "interval": 1.0,
		"radius": 0.4, "splash": 0.0, "aggro": 0.0, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"accent": Color(0.55, 0.8, 0.4),
	},
	"tentacle": {
		"name": "Tentacle",
		"cost": 2,
		"type": "troop",
		"blurb": "The ability's grappler: burst-rises under the enemy's healthiest tower and beats on it.",
		"hp": 25.0, "dmg": 20.0, "speed": 0.0, "reach": 1.2, "interval": 0.8,
		"radius": 0.6, "splash": 0.0, "aggro": 0.0, "stationary": true, "lifetime": 4.0,
		"buildings_only": false,
		"accent": Color(0.72, 0.45, 0.95),
	},
	"boulder": {
		"name": "Boulder",
		"cost": 0,
		"type": "troop",
		"blurb": "Rolled by a destroyed Golden Idol. 80 damage, 2 tile knockback and a 2 s stun to whatever it crosses.",
		"hp": 9999.0, "dmg": 80.0, "speed": 0.0, "reach": 0.0, "interval": 0.0,
		"radius": 0.7, "splash": 0.0, "aggro": 0.0, "stationary": true, "lifetime": 0.0,
		"buildings_only": false,
		"accent": Color(0.55, 0.5, 0.42),
	},
}

const ORDER := ["hero", "snowman", "slate", "alchemist", "idol", "fireball", "firebolt", "dragon", "chicken", "fu", "hawk", "zombie", "hedgehog", "lizard", "warren", "penny", "aphid", "ovomachine", "snowball"]


## Every card in the game. Pen is not in the deck — he only arrives when Penny is
## played — but the debug overlay should still be able to show him.
static func all_kinds() -> Array:
	return ORDER + ["pen"]


## Placeholder for any kind that was never registered. Shaped exactly like a real
## card so every caller keeps working; the blurb names the kind that went missing.
const MISSING := {
	"name": "MissingNo.",
	"cost": 0,
	"type": "troop",
	"blurb": "Unregistered card kind.",
	"hp": 0.0, "dmg": 0.0, "speed": 0.0, "reach": 0.0, "interval": 0.0,
	"radius": 0.4, "splash": 0.0, "aggro": 0.0, "stationary": true, "lifetime": 0.0,
	"buildings_only": false,
	"accent": Color(0.62, 0.5, 0.72),
}


static func get_card(kind: String) -> Dictionary:
	if CARDS.has(kind):
		return CARDS[kind]
	var d: Dictionary = MISSING.duplicate(true)
	d["blurb"] = "Unregistered card kind \"%s\". It should not exist." % kind
	return d


static func cost(kind: String) -> int:
	return int(get_card(kind)["cost"])


static func is_spell(kind: String) -> bool:
	return String(get_card(kind)["type"]) == "spell"


## Names for the narrow in-hand cards. The full faces keep the long names.
const SHORT := {
	"hawk": "Honeycreepers",
	"dragon": "Dragon",
	"chicken": "Hot Chicken",
	"alchemist": "Alchemist",
	"lizard": "Lizard Squad",
	"hedgehog": "Hedgehog",
	"warren": "Warren",
	"slate": "Slate",
	"hero": "Hero",
	"zombie": "Zombies",
	"fu": "Boomerang",
	"idol": "Idol",
	"snowman": "Snowman",
	"fireball": "Fireball",
	"firebolt": "Firebolt",
}


## Second tier, used when even the short name cannot fit the header.
const TINY := {
	"hawk": "Creepers",
	"lizard": "Lizards",
	"chicken": "Chicken",
	"fu": "Boomer",
	"alchemist": "Alchy",
	"zombie": "Zombs",
	"hedgehog": "Hogs",
	"firebolt": "Bolt",
}


static func short_name(kind: String) -> String:
	return String(SHORT.get(kind, get_card(kind)["name"]))


static func tiny_name(kind: String) -> String:
	return String(TINY.get(kind, short_name(kind)))


## Card size for a hand of this many cards spanning a given width.
## Fewer cards means every card gets wider and taller.
static func hand_size(span: float, count: int) -> Vector2:
	var n := maxi(count, 1)
	var gap := 5.0
	var w := clampf((span - float(n - 1) * gap) / float(n), 118.0, 216.0)
	return Vector2(w, w * 1.22)


static func pretty(kind: String) -> String:
	return String(get_card(kind)["name"])
