class_name DDCard
extends RefCounted

## Card definitions. Everything the arena needs to build a unit or resolve a spell
## lives here so deck building / relics can later mutate copies of these values.

const CARDS := {
	"hero": {
		"name": "Hero",
		"cost": 3,
		"type": "troop",
		"blurb": "Armoured duelist. Enormous HP for 3 gold. Also rides the dragon down. Playing him draws you a card.",
		# playing it draws this many cards at once; the draw clock is left alone
		"draws": 1,
		"hp": 150.0, "dmg": 15.0, "speed": 1.05, "reach": 0.4, "interval": 1.0,
		"radius": 0.45, "splash": 0.0, "aggro": 5.5, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"accent": Color(0.86, 0.87, 0.93),
	},
	"snowman": {
		"name": "Snowman",
		"cost": 2,
		"type": "building",
		"blurb": "Immobile decoy. Soaks hits, hits nothing. Playing it draws you a card.",
		"draws": 1,
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
		"blurb": "Fired from your king tower: 40 damage, 70 burn, and everything loose is shoved away. The ground keeps burning for 4.2 seconds: 10 more burn a second to anything standing in it.",
		"hp": 0.0, "dmg": 40.0, "speed": 0.0, "reach": 0.0, "interval": 0.0,
		"radius": 2.2, "splash": 2.2, "aggro": 0.0, "stationary": true, "lifetime": 0.0,
		"buildings_only": false,
		"burn": 70.0, "knock": 1.2, "launch": "king",
		# a patch the size of the blast, applying `burn` every `every` seconds
		"ground_fire": {"burn": 10.0, "every": 1.0, "time": 4.2},
		"tower_mult": 0.40,
		"accent": Color(1.0, 0.55, 0.15),
	},
	"firebolt": {
		"name": "Firebolt",
		"cost": 2,
		"type": "spell",
		"blurb": "An arrow of fire from your nearest tower that follows its target all the way in. No damage, but 60 burn on the one thing it hits.",
		# splash 0: one target only. Cast on a troop it homes on that troop and
		# always lands; cast on a tile it hits the single nearest body there.
		"hp": 0.0, "dmg": 0.0, "speed": 0.0, "reach": 0.0, "interval": 0.0,
		"radius": 0.0, "splash": 0.0, "aggro": 0.0, "stationary": true, "lifetime": 0.0,
		"buildings_only": false,
		"burn": 60.0, "launch": "closest",
		"tower_mult": 0.40,
		"unit_lock": true,
		"uses": 2,
		"accent": Color(1.0, 0.78, 0.28),
	},
	# Dominion cards (the power cards): cast anywhere on the board, they raise a
	# per-fight stat for the rest of the fight and are then gone until the next
	# fight ("spent"). They are spells to the deploy rules.
	"dominion_puissance": {
		"name": "Dominion of Puissance",
		"cost": 2,
		"type": "spell",
		"blurb": "For the rest of this fight, every direct hit your side lands deals 1 more damage. Used up when played, until the next fight.",
		"hp": 0.0, "dmg": 0.0, "speed": 0.0, "reach": 0.0, "interval": 0.0,
		"radius": 0.0, "splash": 0.0, "aggro": 0.0, "stationary": true, "lifetime": 0.0,
		"buildings_only": false,
		"dominion": {"stat": "puissance", "amount": 1.0},
		"spent": true,
		"accent": Color(0.9, 0.35, 0.3),
	},
	"dominion_armor": {
		"name": "Dominion of Armor",
		"cost": 2,
		"type": "spell",
		"blurb": "For the rest of this fight, every direct hit your side takes deals 1 less damage (never below 1). Used up when played, until the next fight.",
		"hp": 0.0, "dmg": 0.0, "speed": 0.0, "reach": 0.0, "interval": 0.0,
		"radius": 0.0, "splash": 0.0, "aggro": 0.0, "stationary": true, "lifetime": 0.0,
		"buildings_only": false,
		"dominion": {"stat": "armor", "amount": 1.0},
		"spent": true,
		"accent": Color(0.5, 0.66, 0.92),
	},
	"chicken": {
		"name": "Hot Chicken",
		"cost": 2,
		"type": "troop",
		"blurb": "Pecks fireballs from range. Three hits on one target and it takes to the air: a flying fire spirit that rams in and sets everything nearby alight with 30 burn, taking itself with it. Shoot it down before it lands. Playing it draws you a card.",
		"draws": 1,
		"hp": 45.0, "dmg": 5.0, "speed": 1.35, "reach": 3.5, "interval": 0.75,
		"radius": 0.4, "splash": 0.0, "aggro": 5.5, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"hits_air": true,
		"burn": 5.0,
		# takeoff: seconds it climbs straight up, on the spot, before the dive
		"chicken": {"hits_to_fly": 3, "fire_speed": 620.0, "burst_reach": 0.3, "takeoff": 0.6},
		# the ram does no damage of its own: it sets the splash alight
		"kamikaze": {"radius": 1.4, "burn": 30.0, "speed_mult": 2.0},
		"accent": Color(1.0, 0.55, 0.2),
	},
	"penny": {
		"name": "Penny",
		"cost": 3,
		"type": "troop",
		"blurb": "Calico blur. Goes for anything in the air first: she leaps up to two and a half tiles to snatch it. On the ground, three quick swipes, then she fades out, backs off and circles around them. Playing her brings Pen into your hand (Pen is used up when played).",
		"hp": 90.0, "dmg": 10.0, "speed": 2.5, "reach": 0.45, "interval": 0.7,
		"radius": 0.51, "splash": 0.0, "aggro": 5.5, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		# she reaches flyers only by leaping at them (never a swipe)
		"hits_air": true,
		# air_first: the nearest flyer in sight outranks every ground target; within
		# jump_reach tiles of it she leaps (jump_time s, jump_mult x her hit, carrying
		# it), then waits air_leap_cd s before the next leap
		"dodge": {"after_hits": 2, "time": 0.9, "back": 0.5, "sweep_deg": 90.0,
			"jump_time": 0.35, "jump_reach": 2.5, "jump_mult": 2.0,
			"air_first": true, "air_leap_cd": 1.4},
		# playing her puts a Pen in her hand slot; Penny herself cycles to the back
		# of the deck as usual (Pen is "spent": played once, it is gone)
		"gives": "pen",
		"accent": Color(0.95, 0.62, 0.28),
	},
	"obsidian": {
		"name": "Obsidian Whelp",
		"cost": 1,
		"type": "troop",
		"blurb": "A baby black dragon in a coat of scales. Anything near, or any hit, and it curls up tight: 80 % less damage, but a melee blow still nudges it back. Playing it brings a Magma Whelp into your hand.",
		"hp": 20.0, "dmg": 8.0, "speed": 0.8, "reach": 0.4, "interval": 1.2,
		"radius": 0.6, "splash": 0.0, "aggro": 5.5, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		# curls when an enemy unit is within `sense` tiles (edge to edge) or it is
		# hit; opens again once nothing is in sense AND it has gone `calm` s unhit
		"guard": {"sense": 3.0, "damage_mult": 0.2, "melee_push": 0.25, "push_time": 0.12, "calm": 2.0},
		"becomes": "magma",
		# swapped into the hand by the Magma Whelp, it cannot be played for this long
		"arrive_lock": 3.0,
		"accent": Color(0.42, 0.36, 0.5),
	},
	"wu": {
		"name": "Wu Cheng'en",
		"cost": 4,
		"type": "troop",
		"blurb": "A bonobo who knuckle-walks up to you, then pulls a tiny staff from behind his ear that grows to full size in his hands. Poke, sweep, repeat. Every hit he lands banks rage; at a quarter of his health it all comes out at once.",
		# dmg / reach / interval: each staff hit
		"hp": 140.0, "dmg": 16.0, "speed": 1.0, "reach": 1.0, "interval": 1.4,
		"radius": 0.8, "splash": 0.0, "aggro": 5.5, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"staff": {
			# drawing the staff from behind his ear, before the first swing
			"draw_time": 0.4,
			# a target this many tiles past reach is closed on with the staff still out
			"keep_out": 1.5,
			# poke: through the target and pierce tiles on, pushing everything hit
			"pierce": 2.0, "poke_width": 0.35, "push": 0.5, "push_time": 0.15,
			# sweep: a cone centred on the target, out to sweep_len tiles
			"sweep_deg": 120.0, "sweep_len": 1.8,
			# rage: under rage_hp of his HP, once per life, for rage_time seconds
			"rage_hp": 0.25, "rage_time": 5.0, "rage_speed": 1.25, "rage_attack": 1.25,
			# every enemy struck banks one rage; regen by banked hits
			"rage_levels": [[0, 5.0], [4, 15.0], [8, 25.0], [12, 40.0]],
		},
		"accent": Color(0.42, 0.36, 0.34),
	},
	"neko": {
		"name": "Nekomancer",
		"cost": 5,
		"type": "troop",
		"blurb": "A black cat in a green cloak and a wizard's hat. Her staff fires a beam at anything in range, ground or air, and every four seconds the wind catches her cloak and two pentagrams open in front of her, each raising a rat skeleton a second later.",
		"hp": 100.0, "dmg": 14.0, "speed": 0.85, "reach": 4.0, "interval": 1.2,
		"radius": 0.6, "splash": 0.0, "aggro": 6.0, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"hits_air": true,
		# an instant single-target hit, drawn as a beam in the owner's colour
		"beam": true,
		# every `every` s: two pentagrams `dist` tiles out on the forward diagonals,
		# and `delay` s later a `unit` climbs out of each (even if she has died).
		# The first opens `first` s after she is played. `ahead` pushes both a
		# further that many tiles forward, so the rats climb out in front of her.
		"ritual": {"unit": "ratbones", "every": 4.0, "first": 1.5, "dist": 1.2, "ahead": 1.0, "delay": 1.0},
		"accent": Color(0.55, 0.78, 0.36),
	},
	"ratbones": {
		"name": "Rat Skeleton",
		"cost": 0,
		"type": "troop",
		"blurb": "Raised by the Nekomancer. Quick, brittle, and all teeth.",
		"hp": 20.0, "dmg": 6.0, "speed": 1.4, "reach": 0.35, "interval": 0.8,
		"radius": 0.39, "splash": 0.0, "aggro": 5.0, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		# holds no ground: never counts toward presence (arena._tick_control)
		"no_presence": true,
		"accent": Color(0.9, 0.87, 0.78),
	},
	# one card, two bodies: Gilgamesh is the card's own unit and `partner` lands
	# beside him (arena.spawn_troop)
	"gilgamesh": {
		"name": "Gilgamesh & Enkidu",
		"cost": 6,
		"type": "troop",
		"blurb": "The king and the wild man, side by side. Gilgamesh lashes with a living snake two and a half tiles long; Enkidu throws his spear at the first troop to come within four and a half tiles, then fights with a short sword until it comes back to him.",
		"hp": 200.0, "dmg": 22.0, "speed": 1.3, "reach": 2.5, "interval": 1.3,
		"radius": 1, "splash": 0.0, "aggro": 6.0, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		# the snake whip: an instant hit at reach, drawn as a lash in the owner's colour
		"whip": true,
		"partner": "enkidu",
		# how far apart the two land, across the lane, in tiles
		"partner_gap": 1.0,
		"accent": Color(0.85, 0.66, 0.3),
	},
	"enkidu": {
		"name": "Enkidu",
		"cost": 0,
		"type": "troop",
		"blurb": "Horned, bull-legged, raised by the beasts. Never dealt alone: he comes with Gilgamesh.",
		# dmg / reach / interval: the spear in hand (reaches air)
		"hp": 180.0, "dmg": 24.0, "speed": 1.45, "reach": 1.1, "interval": 1.2,
		"radius": 0.9, "splash": 0.0, "aggro": 6.0, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"hits_air": true,
		"spear": {
			# thrown at a ground troop (never a building, tower or flyer) whose centre is
			# between throw_min and throw_range tiles away; anything closer is fought hand to hand
			"throw_range": 4.5, "throw_min": 3.0, "throw_dmg": 45.0, "throw_speed": 760.0,
			# then the short sword (ground only) until the spear is back
			"away_time": 3.5, "sword_dmg": 16.0, "sword_reach": 0.5, "sword_interval": 0.9,
		},
		"accent": Color(0.7, 0.52, 0.34),
	},
	# a starter basic: cheap, plain, and meant to be replaced by what you draft
	"militia": {
		"name": "Militia",
		"cost": 2,
		"type": "troop",
		"blurb": "A farmhand with a spear and a pot lid for a shield. Cheap, willing, and not very good at this.",
		"hp": 80.0, "dmg": 9.0, "speed": 1.0, "reach": 0.6, "interval": 1.0,
		"radius": 0.42, "splash": 0.0, "aggro": 5.5, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"accent": Color(0.7, 0.58, 0.42),
	},
	"brawler": {
		"name": "Lizard Brawlers",
		"cost": 4,
		"type": "troop",
		"blurb": "Two frilled lizards in belted gis, side by side. No weapons, no plan: they walk up to the nearest thing and claw at it, roaring.",
		"hp": 95.0, "dmg": 14.0, "speed": 1.1, "reach": 0.5, "interval": 1.0,
		"radius": 0.4, "splash": 0.0, "aggro": 5.5, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"swarm_offsets": [[-0.55, 0.0], [0.55, 0.0]],
		"accent": Color(0.5, 0.74, 0.26),
	},
	# the first building that moves: a building in every rule (troops that hunt
	# buildings go for it, shoves do nothing, it takes no tile), but it is not
	# stationary, so it walks like a troop. Its reach outranges a side tower: it
	# stops on the middle of the bridge (9 tiles from the tower's centre) and
	# shoots from there.
	"ballista": {
		"name": "Ballista",
		"cost": 5,
		"type": "building",
		"blurb": "A lizardfolk siege engineer and his ballista. He lifts the back and wheels it forward, sets it down at the river, and shoots at towers from further than they can shoot back. Only ever aims at buildings and towers.",
		"hp": 220.0, "dmg": 25.0, "speed": 0.45, "reach": 7.5, "interval": 3.0,
		"radius": 0.7, "splash": 0.0, "aggro": 9.0, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"hits_air": true,
		"shoots": "ballista",
		"accent": Color(0.72, 0.5, 0.3),
	},
	"elf": {
		"name": "Elf Archer",
		"cost": 4,
		"type": "troop",
		"blurb": "A hooded elf with a longbow. Picks off anything on the ground or in the air from five and a half tiles, and is happy to stay that far away.",
		"hp": 110.0, "dmg": 20.0, "speed": 1.0, "reach": 5.5, "interval": 1.3,
		"radius": 0.45, "splash": 0.0, "aggro": 6.5, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"hits_air": true,
		"shoots": "arrow",
		"accent": Color(0.4, 0.66, 0.36),
	},
	# one card, two bodies: the male is the card's own unit and lands on the
	# deploy tile; his mate lands `partner_behind` tiles behind him (towards
	# his own side) instead of across the lane (arena.spawn_troop)
	"mantis": {
		"name": "Mated Mantises",
		"cost": 5,
		"type": "troop",
		"blurb": "A pair of mantises. He goes in front with his claws; she follows three and a half tiles back, throwing a spinning scythe. When he drops to a quarter of his health she leaps on him and bites his head off, and comes away healed, enraged, and fighting both up close and at range.",
		# dmg / reach / interval: his claws
		"hp": 150.0, "dmg": 14.0, "speed": 1.0, "reach": 0.8, "interval": 1.0,
		"radius": 0.55, "splash": 0.0, "aggro": 5.5, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"partner": "mantisf",
		"partner_behind": 3.5,
		"accent": Color(0.5, 0.78, 0.3),
	},
	"mantisf": {
		"name": "Female Mantis",
		"cost": 0,
		"type": "troop",
		"blurb": "Never dealt alone: she comes with her mate, and outlives him.",
		# dmg / reach / interval: the thrown scythe (reaches air)
		"hp": 120.0, "dmg": 12.0, "speed": 0.9, "reach": 4.0, "interval": 1.6,
		"radius": 0.6, "splash": 0.0, "aggro": 6.0, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"hits_air": true,
		"shoots": "scythe",
		"devour": {
			# her mate under at_hp of his HP: she leaps to him (leap_time s, from any
			# distance) and spends bite_time s eating his head; his body lies there
			# for corpse_time s
			"at_hp": 0.25, "leap_time": 0.55, "bite_time": 0.45, "corpse_time": 3.0,
			# then: +heal of her max HP, up to overheal x her max (the bar runs past
			# its end), and Wu's rage without the regen: faster walk and attacks
			"heal": 0.5, "overheal": 1.25,
			"rage_time": 5.0, "rage_speed": 1.25, "rage_attack": 1.25,
			# and from then on claws as well as the scythe, for anything this close
			"melee_dmg": 18.0, "melee_reach": 0.8, "melee_interval": 1.0,
		},
		"accent": Color(0.42, 0.68, 0.28),
	},
	"frog": {
		"name": "Poison Dart Frog",
		"cost": 1,
		"type": "troop",
		"blurb": "Hops along a tile at a time. It has no bite: the moment anything is within two tiles it leaps on it and bursts, leaving 10 poison on everything within half a tile.",
		# no attack of its own: dmg / reach / interval are unused
		"draws": 1,
		"hp": 25.0, "dmg": 0.0, "speed": 1.0, "reach": 0.0, "interval": 1.0,
		"radius": 0.5, "splash": 0.0, "aggro": 5.5, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"frog": {
			# moves only in hops: hop tiles over hop_time s, then sits for rest s
			"hop": 1.2, "hop_time": 0.22, "rest": 0.45,
			# leaps at the nearest ground enemy (troop, building or tower) whose edge
			# is within leap_range tiles, lands on it and bursts
			"leap_range": 2.0, "leap_time": 0.38,
			"poison": 10.0, "burst": 0.5,
		},
		"accent": Color(0.98, 0.72, 0.15),
	},
	"phalanx": {
		"name": "Phalanx",
		"cost": 8,
		"type": "troop",
		"blurb": "Six spartans, three across and two deep. Anything close, or any hit, and the shields come up: the shield takes the blows, and they keep advancing and poking over each other's shoulders, only slower. Break a shield and that spartan draws a dagger, stabbing between spear pokes at anything within a tile.",
		# dmg / reach / interval: the spear poke (ground only)
		"hp": 70.0, "dmg": 14.0, "speed": 0.85, "reach": 1.7, "interval": 1.3,
		"radius": 0.42, "splash": 0.0, "aggro": 5.5, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		# [forward, across]: two ranks of three
		"swarm_offsets": [[0.5, -1.0], [0.5, 0.0], [0.5, 1.0], [-0.5, -1.0], [-0.5, 0.0], [-0.5, 1.0]],
		# raised by the Obsidian Whelp's rules: an enemy unit within `sense` tiles
		# (edge to edge) or a hit; lowered once nothing is in sense and `calm` s have
		# passed unhit. Raised, every hit lands on the shield's own `hp` (the hit that
		# raises it lands on the spartan), and he moves and pokes slower.
		"shield": {"hp": 60.0, "sense": 3.0, "calm": 2.0, "move_mult": 0.6, "attack_mult": 1.3},
		# shield broken: with the target within `reach` tiles, a stab between every
		# two pokes (poke, stab, poke ... each half an interval apart)
		"dagger": {"reach": 1.0, "dmg": 8.0},
		"accent": Color(0.78, 0.24, 0.2),
	},
	"wolves": {
		"name": "Wolf Pack",
		"cost": 4,
		"type": "troop",
		"blurb": "Four wolves in a diamond that move as one. They pick out the loneliest troop in reach (or head for a tower), ring it two tiles out, and take turns darting in to bite: one bite every 0.4 seconds, however many are left.",
		# dmg: one bite. interval / the pack's size: the pack's steady beat (0.4 s),
		# which does not slow down as wolves die
		"hp": 55.0, "dmg": 10.0, "speed": 1.6, "reach": 0.35, "interval": 1.6,
		"radius": 0.4, "splash": 0.0, "aggro": 6.0, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"swarm_offsets": [[0.8, 0.0], [-0.8, 0.0], [0.0, 0.8], [0.0, -0.8]],
		# hunt: tiles from the pack's centre to look for prey. ring: tiles out from the
		# target's edge they circle at. spin: how fast the ring turns (rad/s, troops
		# only). lunge_mult: dart speed. rethink: s between looks while on a structure.
		"pack": {"hunt": 6.0, "ring": 2.0, "spin": 0.3, "lunge_mult": 2.4, "rethink": 0.5},
		"accent": Color(0.6, 0.62, 0.68),
	},
	"meerkats": {
		"name": "Meerkats",
		"cost": 2,
		"type": "troop",
		"blurb": "Four meerkats. Quick, fragile, and they bite.",
		"hp": 22.0, "dmg": 5.0, "speed": 1.9, "reach": 0.35, "interval": 0.6,
		"radius": 0.3, "splash": 0.0, "aggro": 5.5, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"no_presence": true,
		"swarm_offsets": [[0.6, 0.6], [0.6, -0.6], [-0.6, 0.6], [-0.6, -0.6]],
		"accent": Color(0.86, 0.68, 0.42),
	},
	"anthill": {
		"name": "Ant Hill",
		"cost": 3,
		"type": "building",
		"blurb": "A mound of dirt that never stops emptying: an ant crawls out of the front every 2 seconds for a minute. Each one is slow, tiny and barely bites.",
		"hp": 140.0, "dmg": 0.0, "speed": 0.0, "reach": 0.0, "interval": 0.0,
		"radius": 0.55, "splash": 0.0, "aggro": 0.0, "stationary": true, "lifetime": 60.0,
		"buildings_only": false,
		"footprint": [1, 1],
		# quiet: no screen shake per ant
		"summon": {"unit": "ant", "interval": 2, "first": 1.0, "spot": "front", "quiet": true},
		"accent": Color(0.62, 0.44, 0.28),
	},
	"ant": {
		"name": "Ant",
		"cost": 0,
		"type": "troop",
		"blurb": "Out of the Ant Hill. Slow, tiny, and barely bites, but there is always another. Ants march on buildings and leave troops alone, until a troop kills one: then every ant that can see it swarms it for 10 seconds.",
		"hp": 8.0, "dmg": 2.0, "speed": 0.55, "reach": 0.3, "interval": 1.0,
		"radius": 0.22, "splash": 0.0, "aggro": 4.0, "stationary": false, "lifetime": 0.0,
		# troops are ignored... unless they kill an ant (trail.mark_time below)
		"buildings_only": true,
		"no_presence": true,
		# Whatever kills an ant is marked for mark_time s: ants with a marked
		# killer within aggro tiles go for the closest one instead of buildings.
		"trail": {"mark_time": 10.0},
		"accent": Color(0.35, 0.2, 0.14),
	},
	"goatrider": {
		"name": "Goat Rider",
		"cost": 5,
		"type": "troop",
		"blurb": "A painted warrior on a huge woolly mountain goat, headed for the nearest building. The goat rams it first; after that he chops at it with his tomahawk. Hit the goat up close and its wool puffs up, shoving you a tile back.",
		# dmg / reach / interval: the tomahawk, after the ram
		"hp": 260.0, "dmg": 18.0, "speed": 1.0, "reach": 0.45, "interval": 1.1,
		"radius": 0.7, "splash": 0.0, "aggro": 7.5, "stationary": false, "lifetime": 0.0,
		"buildings_only": true,
		# the first hit on each new target is the goat's ram
		"ram": {"dmg": 60.0},
		# a melee hit on the goat (from an attacker with reach under `melee`) puffs
		# the wool and shoves the attacker `push` tiles away over push_time s
		"wool": {"push": 1.0, "push_time": 0.2, "melee": 2.0},
		"accent": Color(0.9, 0.88, 0.8),
	},
	"magma": {
		"name": "Magma Whelp",
		"cost": 1,
		"type": "troop",
		"blurb": "The Obsidian Whelp's molten twin. Flies, and flicks flaming feathers at anything within two tiles, ground or air: no impact, just 5 burn each. Playing it brings the Obsidian Whelp back into your hand.",
		# the twins swap in the hand every play and never go back into the deck;
		# each one swapped in waits arrive_lock s before it can be played
		"becomes": "obsidian",
		"arrive_lock": 3.0,
		"hp": 30.0, "dmg": 0.0, "speed": 1.3, "reach": 2.0, "interval": 1.4,
		"radius": 0.6, "splash": 0.0, "aggro": 5.5, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"hits_air": true,
		"flying_unit": true,
		"shoots": "feather",
		"payload": {"burn": 5.0},
		"accent": Color(1.0, 0.45, 0.12),
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
		# Penny's gift: played once, it never goes into the deck
		"spent": true,
		"accent": Color(0.86, 0.72, 0.24),
	},
	"lizard": {
		"name": "Lizard Soldiers",
		"cost": 3,
		"type": "troop",
		"blurb": "Three lizardfolk riflemen in a wedge. They ignore the nearest threat and go for whoever is weakest.",
		"hp": 28.0, "dmg": 10.0, "speed": 0.85, "reach": 3.5, "interval": 1.0,
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
		"blurb": "A burrow that empties itself when enemies come close, one soldier at a time, one to hold the line.",
		"hp": 130.0, "dmg": 0.0, "speed": 0.0, "reach": 0.0, "interval": 0.0,
		"radius": 0.75, "splash": 0.0, "aggro": 0.0, "stationary": true, "lifetime": 60.0,
		"buildings_only": false,
		"footprint": [2, 2],
		"summon": {"unit": "lizard", "count": 3, "range": 6.0, "cooldown": 3.5},
		"accent": Color(0.62, 0.8, 0.44),
	},
	"snowball": {
		"name": "Snowball",
		"cost": 3,
		"type": "spell",
		"blurb": "Thrown in an arc out of your nearest tower onto the tile you pick, then rolls eight tiles forward, river and all: one tile of snow, a tile taller for every two it covers, 10 damage per tile of height with a shove to match (once per enemy), then a 30 damage burst and a 3.5 second slow.",
		"hp": 0.0, "dmg": 30.0, "speed": 0.0, "reach": 0.0, "interval": 0.0,
		"radius": 0.6, "splash": 1.0, "aggro": 0.0, "stationary": true, "lifetime": 0.0,
		"buildings_only": false,
		"slow": 0.32, "slow_time": 3.5,
		"launch": "closest",
		# rolls `distance` tiles from where it lands (over the river too) and bursts;
		# the roll hits each enemy once, the burst reaches burst_ahead tiles past
		# the ball's front so it catches what the roll shoved ahead of it
		"roll": {"speed": 4.2, "dmg": 10.0, "push": 1.0, "distance": 8.0, "burst_ahead": 1.5},
		"accent": Color(0.72, 0.86, 1.0),
	},
	"ovomachine": {
		"name": "Ovo Javer Machine",
		"cost": 6,  
		"type": "building",
		"blurb": "An industrial hatchery: a two by two block of steel that cranks out a hot chicken through the front hatch a second after it lands and every twelve seconds after, and one last chicken climbs out of the wreck when it dies.",
		"hp": 240.0, "dmg": 0.0, "speed": 0.0, "reach": 0.0, "interval": 0.0,
		# hatches at 1, 13, 25, 37 and 49 s, plus one whenever it dies (timer or not)
		"radius": 0.95, "splash": 0.0, "aggro": 0.0, "stationary": true, "lifetime": 60.0,
		"buildings_only": false,
		"footprint": [2, 2],
		"summon": {"unit": "chicken", "interval": 12.0, "first": 1.0, "spot": "front", "on_death": true},
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
		"hp": 50.0, "dmg": 15.0, "speed": 0.85, "reach": 0.5, "interval": 1.0,
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
		"draws": 1,
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
	"laniakea": {
		"name": "Laniakea",
		"cost": 4,
		"type": "troop",
		"blurb": "A bug with a sword twice his size. Cleaves everything on the ground in front of him and shoves it back; leaps at flyers and brings the blade down through them and whatever is behind.",
		"hp": 100.0, "dmg": 25.0, "speed": 0.7, "reach": 1.5, "interval": 1.4,
		"radius": 0.45, "splash": 0.0, "aggro": 5.5, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"hits_air": true,
		# every distance here is centre to centre, in tiles
		"greatsword": {
			"swing_range": 1.5, "arc_deg": 140.0, "length": 2.2,
			"push": 0.5, "push_time": 0.2,
			"leap_min": 2.5, "leap_max": 3.5, "leap_time": 0.4,
			"leap_dmg": 50.0, "leap_line": 2.5, "leap_width": 0.6, "stun": 0.5,
		},
		"accent": Color(0.93, 0.93, 0.9),
	},
	"femme": {
		"name": "Femme Fatale",
		"cost": 2,
		"type": "troop",
		"blurb": "Hooded, and carrying a needle longer than she is. From a distance she raises it, the tip glints, and she is suddenly in front of you. Up close: a flick, a stab, and a stab that carries her back out.",
		"hp": 60.0, "dmg": 12.0, "speed": 1.2, "reach": 1.5, "interval": 1.2,
		"radius": 0.38, "splash": 0.0, "aggro": 5.5, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		# every distance here is centre to centre, in tiles
		"needle": {
			"range": 1.5, "tip": 1.6,
			"dash_min": 3.5, "dash_max": 4.5, "windup": 0.45, "dash_speed": 12.0, "dash_dmg": 25.0,
			"swing_deg": 15.0, "recoil": 0.5, "recoil_time": 0.18,
		},
		"accent": Color(0.5, 0.3, 0.3),
	},
	"troll": {
		"name": "Humbaba",
		"cost": 5,
		"type": "troop",
		"blurb": "A mossy old swamp troll dragging a whole tree. Slow, enormous, and only interested in knocking buildings down. He chokes up on the trunk, so the club reaches less far than it looks.",
		"hp": 330.0, "dmg": 40.0, "speed": 0.5, "reach": 1.2, "interval": 1.8,
		"radius": 0.75, "splash": 0.0, "aggro": 4.0, "stationary": false, "lifetime": 0.0,
		"buildings_only": true,
		"giant": true,
		"accent": Color(0.56, 0.62, 0.3),
	},
	# Not in ORDER: entities that never appear in a deck but still need a real
	# identity for the hover inspector and any card lookup.
	# --- the first elite encounter (NOTES §9). The boss is not a DDUnit: it is
	# scripts/spider.gd standing in for all three enemy towers. Its numbers live
	# here anyway so this stays the one balance surface.
	"spider": {
		"name": "Ballista Matriarch",
		"cost": 0,
		"type": "troop",
		"blurb": "Elite. Takes the place of all three towers. Skitters forward, seeps a pool of poison that runs down into the river and spits venom from behind it, lays an egg, then builds a slingshot trap on a bridge before her parting shot at your towers. Stabs with her front legs and webs the ground ahead of your troops.",
		"hp": 900.0, "dmg": 35.0, "speed": 0.0, "reach": 4.0, "interval": 1.6,
		"radius": 1.5, "splash": 0.0, "aggro": 0.0, "stationary": true, "lifetime": 0.0,
		"buildings_only": false,
		"boss": {
			# a cycle: wait back_min..back_max s at the back (random), run
			# skitter_min..max tiles forward in skitter_time s, stay there for
			# cycle - that wait, lay an egg, walk to a bridge with no trap and build
			# one, glint, spit at the nearest tower / building, walk home
			"back_min": 3.0, "back_max": 7.0, "cycle": 10.0,
			# (one tile shorter than it was, to leave room for the wide pool)
			"skitter_min": 2, "skitter_max": 5, "skitter_time": 0.55,
			# forward she seeps poison from her mouth: it runs down the "hill" at
			# seep_speed tiles/s, the first pool_len tiles a pool pool_wide tiles
			# across (each side), then a braided stream into the river, which turns
			# from the inflow downstream at river_speed tiles/s. It dries the same
			# way, mouth first, once she leaves. Enemy ground troops standing in the
			# pool or stream take pool_poison every pool_every s.
			"seep_speed": 2.5, "pool_len": 1.8, "pool_wide": 1.8, "stream_wide": 0.22,
			"river_speed": 6.0, "pool_poison": 5.0, "pool_every": 0.5,
			# spits reach anywhere: one every forward_spit_every s at the closest
			# unit while forward, once the pool has formed; and the parting shot at
			# the nearest tower / building after the trap, her eye glinting for
			# glint_time s first
			"spit_dmg": 6.0, "spit_poison": 10.0, "spit_splash": 0.5, "spit_speed": 700.0,
			"forward_spit_every": 2.0, "glint_time": 0.6,
			# front legs use the card's dmg / reach / interval above
			"web_every": 5.0, "web_ahead": 2.5, "web_slow": 0.5, "web_slow_time": 2.0,
			# the trap: walked to at walk_speed tiles/s, built in build_time s
			"walk_speed": 3.0, "build_time": 3.0, "trap_radius": 0.7,
		},
		"accent": Color(0.8, 0.78, 0.3),
	},
	"spideregg": {
		"name": "Spider Egg",
		"cost": 0,
		"type": "building",
		"blurb": "Laid by the Ballista Matriarch on a patch of web. However it goes, timer or blade, spiderlings climb out: one more for every eighth of its life it lasted, eight if it runs its full course.",
		"hp": 60.0, "dmg": 0.0, "speed": 0.0, "reach": 0.0, "interval": 0.0,
		"radius": 0.55, "splash": 0.0, "aggro": 0.0, "stationary": true, "lifetime": 30.0,
		"buildings_only": false,
		"footprint": [2, 2],
		"hatch": "spiderling",
		# how many hatch: round(hatch_max * age / lifetime), at least 1
		"hatch_max": 8,
		"accent": Color(0.93, 0.92, 0.85),
	},
	"spiderling": {
		"name": "Spiderling",
		"cost": 0,
		"type": "troop",
		"blurb": "Small, fast, and every bite leaves poison that never wears off.",
		"hp": 26.0, "dmg": 6.0, "speed": 1.6, "reach": 0.4, "interval": 0.8,
		"radius": 0.3, "splash": 0.0, "aggro": 5.5, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"poison": 5.0,
		"accent": Color(0.85, 0.5, 0.2),
	},
	# --- the second elite encounter (NOTES §10). scripts/kraken.gd is the body
	# and scripts/kraken_arm.gd one tentacle; neither is a DDUnit.
	"kraken": {
		"name": "South Sea Kraken",
		"cost": 0,
		"type": "troop",
		"blurb": "Elite. Five tentacles first. Sink them all and the Kraken itself surfaces, raises them again at half strength and spews homing orbs.",
		"hp": 500.0, "dmg": 0.0, "speed": 0.0, "reach": 0.0, "interval": 0.0,
		"radius": 1.5, "splash": 0.0, "aggro": 0.0, "stationary": true, "lifetime": 0.0,
		"buildings_only": false,
		"boss": {
			# where the body surfaces, and the tile each tentacle is rooted in
			"center": [9.0, 7.0],
			"arm_tiles": [[8, 3], [2, 6], [15, 6], [5, 11], [13, 11]],
			"emerge_time": 1.0,
			# revived tentacles: this share of their HP, attacks this much slower
			"revive_hp": 0.5, "revive_slow": 2.0,
			# red orbs: orb_count big ones every orb_every s
			"orb_every": 25.0, "orb_count": 3,
			"orb_speed": 1.6, "orb_turn": 1.6, "orb_life": 6.0, "orb_dmg": 30.0, "orb_splash": 1.2,
			"orb_split_min": 3, "orb_split_max": 5,
			"small_speed": 2.6, "small_turn": 3.0, "small_life": 1.5, "small_dmg": 12.0, "small_splash": 0.7,
			# one revived tentacle burrows every burrow_every s
			"burrow_every": 8.0,
		},
		"accent": Color(0.85, 0.2, 0.55),
	},
	"krakenarm": {
		"name": "Kraken Tentacle",
		"cost": 0,
		"type": "building",
		"blurb": "Rooted to one tile, leaning up to a tile any way. Slams, spins when it is nearly dead, and shoots a slow purple arrow when nothing is near.",
		# dmg / reach / interval are the slam
		"hp": 150.0, "dmg": 30.0, "speed": 0.0, "reach": 3.5, "interval": 2.5,
		"radius": 0.7, "splash": 0.0, "aggro": 0.0, "stationary": true, "lifetime": 0.0,
		"buildings_only": false,
		"arm": {
			# the head leans toward the nearest enemy, at most `lean` tiles per axis
			"lean": 1.0, "lean_speed": 0.5, "lean_sight": 7.0,
			# slam: lands up to slam_reach tiles out, then waves run wave_len tiles
			# ahead and to both sides; nothing further back than wave_back
			"slam_windup": 0.65, "slam_reach": 2.5, "wave_len": 1.5, "wave_back": 0.6, "wave_time": 0.4,
			# spin: only at or under spin_hp of its HP, enemy inside spin_radius
			"spin_hp": 0.3, "spin_radius": 2.0, "spin_dmg": 25.0, "spin_windup": 0.5, "spin_time": 0.5,
			# arrow: only if every enemy unit is arrow_min tiles away or more
			"arrow_every": 10.0, "arrow_stagger": 2.0, "arrow_min": 6.0, "arrow_windup": 0.6,
			"arrow_dmg": 40.0, "arrow_speed": 5.0,
			# burrow (revived only): warning, then it bursts where the troop stood
			"burrow_sink": 0.35, "burrow_warn": 0.5, "burrow_catch": 0.8,
			"recover": 0.4, "rise_time": 0.6,
		},
		"accent": Color(0.75, 0.35, 0.9),
	},
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
		"blurb": "The ability's grappler: bursts up under the enemy troop with the most HP, coils round it and holds it for 4 s, squeezing for 7 every 1.6 s.",
		# the live numbers are arena.TENTACLE_*; these mirror them for the inspector
		"hp": 20.0, "dmg": 7.0, "speed": 0.0, "reach": 0.0, "interval": 1.6,
		"radius": 0.6, "splash": 0.0, "aggro": 0.0, "stationary": true, "lifetime": 4.0,
		"buildings_only": false,
		"accent": Color(0.72, 0.45, 0.95),
	},
	# Man-Mantis's drone: what bursts out of an infected troop when it dies, on
	# the caster's side. The more damage the drone did inside it, the bigger it
	# is (arena.PARASITE_TIERS): a worm at first, more like Man-Mantis each step.
	"parasite1": {
		"name": "Drone Larva",
		"cost": 0,
		"type": "troop",
		"blurb": "Burst out of a troop the drone barely had time in. A red worm with a bite.",
		"hp": 30.0, "dmg": 5.0, "speed": 1.3, "reach": 0.35, "interval": 0.8,
		"radius": 0.3, "splash": 0.0, "aggro": 5.0, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"no_presence": true,
		"accent": Color(0.85, 0.25, 0.18),
	},
	"parasite2": {
		"name": "Drone Nymph",
		"cost": 0,
		"type": "troop",
		"blurb": "Burst out after the drone fed for a while: a worm that has grown a head, feelers and two hooked forelegs.",
		"hp": 80.0, "dmg": 10.0, "speed": 1.25, "reach": 0.45, "interval": 0.9,
		"radius": 0.38, "splash": 0.0, "aggro": 5.0, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"no_presence": true,
		"accent": Color(0.85, 0.25, 0.18),
	},
	"parasite3": {
		"name": "Drone Stalker",
		"cost": 0,
		"type": "troop",
		"blurb": "Burst out of a big meal: up on two legs, hunched, scythe-armed, with Man-Mantis's goggling eyes.",
		"hp": 170.0, "dmg": 22.0, "speed": 1.15, "reach": 0.6, "interval": 1.0,
		"radius": 0.45, "splash": 0.0, "aggro": 5.5, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"no_presence": true,
		"accent": Color(0.85, 0.25, 0.18),
	},
	"parasite4": {
		"name": "Drone Monstrosity",
		"cost": 0,
		"type": "troop",
		"blurb": "What comes out of a giant: a second Man-Mantis, tall, ragged-caped and antlered with feelers.",
		"hp": 380.0, "dmg": 40.0, "speed": 1.0, "reach": 0.8, "interval": 1.1,
		"radius": 0.55, "splash": 0.0, "aggro": 6.0, "stationary": false, "lifetime": 0.0,
		"buildings_only": false,
		"accent": Color(0.85, 0.25, 0.18),
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

const ORDER := ["hero", "snowman", "slate", "alchemist", "idol", "fireball", "firebolt", "dragon", "chicken", "fu", "hawk", "zombie", "hedgehog", "lizard", "warren", "penny", "aphid", "ovomachine", "snowball", "laniakea", "femme", "troll", "obsidian", "wu", "neko", "gilgamesh", "frog", "phalanx", "wolves", "meerkats", "anthill", "goatrider", "mantis", "elf", "militia", "ballista", "brawler", "dominion_puissance", "dominion_armor"]


## The pool a run's card reward draws from: ORDER less `exclude` (the run passes
## its starter deck, so every card you do not start with can be drafted).
static func draft_pool(exclude: Array = []) -> Array:
	return ORDER.filter(func(k): return not exclude.has(k))


## Every card in the game. Pen and the Magma Whelp are not in the deck — they
## only arrive when Penny (card key "gives") / the Obsidian Whelp ("becomes") is
## played — but the debug overlay should still be able to show them.
static func all_kinds() -> Array:
	return ORDER + ["pen", "magma"]


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
	"dominion_puissance": "Puissance",
	"dominion_armor": "Armor",
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
	"dominion_puissance": "Might",
	"dominion_armor": "Armor",
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
