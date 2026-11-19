class_name DDCardFace
extends RefCounted

## The card face, trading-card style: cost coin, name and HP along the top, the
## art window (with a coin showing what the card summons, if anything), a
## middle line with the card's type, the attacks (a crossed-swords badge for a
## melee hit, a bow for a ranged one), and the attribute icons along the bottom.
##
## The detail level follows the width: full attack text at 260+, names and
## damage at 170+, icon-and-number chips at 120+, and below that just the
## attack icons. Without the description (the hand), a face 170+ wide names its
## attributes in a list when they fit; otherwise they are the icon bar.
##
## The trim (the border and the frames) and the middle line are colours you can
## change: `trim` and `line` below, the arena's `card_trim` / `card_line`
## exports, or --trim=#hex / --line=#hex on the command line.

const OUT := Color(0.13, 0.12, 0.16)
const TRIM_DEFAULT := Color(0.97, 0.83, 0.36)
const LINE_DEFAULT := Color(0.92, 0.79, 0.34)

## The border, the art frame, the summon coin's rim and the description box edge.
static var trim := TRIM_DEFAULT
## The band under the art (type, speed, sight / footprint, lifetime).
static var line := LINE_DEFAULT

## The whole face's opacity while it is being drawn (1 outside card()).
static var _a := 1.0

## Set to an Array to collect every icon drawn: {"c", "r", "id", "count"}, and
## for the "+N" overflow chip id "more" with "hidden" (the ids it stands for).
## The reward screen uses it for tooltips; null (the default) records nothing.
static var hit_log = null

## What each icon means, for a player: [title, sentence]. %s is the icon's count.
const TIPS := {
	"melee": ["Melee attack", "Hits up close."],
	"ranged": ["Ranged attack", "Hits from a distance."],
	"spell": ["Spell", "Cast where you aim it; there is no unit."],
	"special": ["Special", "An ability rather than a plain hit."],
	"flag": ["Targets buildings", "Walks past troops and only hits towers and buildings."],
	"troops": ["Targets troops only", "Ignores towers and buildings."],
	"weakest": ["Goes for the weakest", "Picks the enemy in range with the least HP."],
	"flies": ["Flies", "Only units that hit air can reach it."],
	"antiair": ["Hits air", "Can attack flying units."],
	"swarm": ["Several bodies", "%s units come from one card."],
	"spawner": ["Spawner", "Makes more units over time."],
	"burn": ["Burn", "Sets what it hits alight: damage over time."],
	"poison": ["Poison", "Leaves poison that keeps hurting and never wears off."],
	"slow": ["Slow", "Makes enemies move and attack slower."],
	"stun": ["Stun", "Briefly stops what it hits."],
	"knock": ["Knockback", "Shoves what it hits away."],
	"splash": ["Area damage", "Hits everything in an area, not just one target."],
	"pierce": ["Pierces", "Hits everything along a line."],
	"leap": ["Leaps", "Jumps or dashes onto its targets."],
	"charge": ["Charges", "Gets faster and hits harder the longer it moves."],
	"shield": ["Armour", "Takes less damage at times."],
	"regen": ["Heals", "Heals itself."],
	"evasive": ["Evasive", "Cannot be targeted at times."],
	"giant": ["Giant", "Too big to be grabbed or carried."],
	"hourglass": ["Lifetime", "Lasts %s, then crumbles."],
	"death": ["On death", "Does something when it dies."],
	"boom": ["Self-destructs", "Blows itself up on its target."],
	"transform": ["Transforms", "Turns into another card during the fight."],
	"casts": ["Several casts", "Can be cast %s times before it leaves your hand."],
	"lockon": ["Locks on", "Must be aimed at a target, and always lands on it."],
	"taunt": ["Taunt", "Draws enemies to it."],
}


## [title, sentence] for an icon hit from hit_log.
static func tip_for(hit: Dictionary) -> Array:
	var id := String(hit.get("id", ""))
	if id == "more":
		var names: Array = []
		for h in hit.get("hidden", []):
			names.append(String((TIPS.get(String(h), [String(h), ""]) as Array)[0]))
		return ["More", ", ".join(names)]
	var tip: Array = TIPS.get(id, [id, ""])
	var body := String(tip[1])
	if body.contains("%s"):
		var count := String(hit.get("count", ""))
		body = body % (count if count != "" else "several")
	return [String(tip[0]), body]

const ATTACK_NAMES := {
	"dragon": "Claw", "chicken": "Burst", "penny": "Swipes", "pen": "Blowgun", "obsidian": "Nip", "wu": "Staff", "neko": "Beam", "gilgamesh": "Serpent Lash", "enkidu": "Spear", "frog": "Poison Leap", "phalanx": "Spear", "wolves": "Bite", "meerkats": "Bite", "ant": "Bite", "anthill": "Ants", "goatrider": "Tomahawk","ratbones": "Bite","magma": "Flame Feathers","aphid": "Spit Spread", "fu": "Boomerang",
	"slate": "Jawbreaker", "hawk": "Dive", "hedgehog": "Quills",
	"hero": "Sword", "alchemist": "Splash Potion", "zombie": "Claw",
	"snowman": "—", "idol": "Taunt", "lizard": "Spear", "warren": "Burrow",
	"ovomachine": "Hatch", "laniakea": "Greatsword", "femme": "Needle",
	"kraken": "Red Orbs", "krakenarm": "Tentacle Slam",
	"spider": "Front Legs","spideregg": "—", "spiderling": "Venom Bite", "troll": "Tree Club",
	"fireball": "Fireball", "firebolt": "Firebolt", "snowball": "Snowball",
}

const ATTACK_ICONS := ["melee", "ranged", "spell", "special"]
## every attribute icon, in the order the bar shows them
const TRAIT_ORDER := ["flag", "troops", "weakest", "flies", "antiair", "swarm", "spawner", "burn", "poison",
	"slow", "stun", "knock", "splash", "pierce", "leap", "charge", "shield", "regen", "evasive",
	"giant", "hourglass", "death", "boom", "transform", "casts", "lockon", "taunt"]
const ICON_INFO := {
	"melee": ["Melee attack", "reach under ~2.6 tiles, no projectile"],
	"ranged": ["Ranged attack", "a projectile, a beam, or reach 2.6+"],
	"spell": ["Spell effect", "cast, not attacked with"],
	"special": ["Special", "an ability that is not a hit (a ritual, a hatch, a ram)"],
	"flag": ["Targets buildings", "buildings_only: walks at towers and buildings, ignores troops"],
	"troops": ["Targets troops only", "troops_only (Penny)"],
	"weakest": ["Goes for the weakest", "targets_weakest (Lizard Soldiers)"],
	"flies": ["Flies", "flying_unit, or a flying phase (Hot Chicken, the Dragon)"],
	"antiair": ["Hits air", "hits_air"],
	"swarm": ["Several bodies", "swarm_offsets / partner: the count goes in the corner"],
	"spawner": ["Spawner", "summon, ritual, hatch: makes more units"],
	"burn": ["Burn", "burn, payload burn, kamikaze, ground_fire"],
	"poison": ["Poison", "poison counters (spit, bites, the frog)"],
	"slow": ["Slow", "slow / slow_time, death_aoe slow"],
	"stun": ["Stun / paralyse", "payload stun, greatsword stun"],
	"knock": ["Knockback", "knock, push, kick_push: shoves what it hits"],
	"splash": ["Area damage", "splash, spread, cleave or sweep arcs"],
	"pierce": ["Pierces", "hits everything along a line (boomerang, staff poke)"],
	"leap": ["Leaps / dashes", "needle dash, greatsword leap, frog leap, Penny's jump"],
	"charge": ["Builds speed", "roll: faster and harder the longer it moves"],
	"shield": ["Damage reduction", "guard, curl, shield"],
	"regen": ["Heals", "staff rage regen"],
	"evasive": ["Untargetable at times", "dodge (Penny's fade)"],
	"giant": ["Giant", "giant: cannot be grabbed or carried"],
	"hourglass": ["Lifetime", "lifetime: how long it lasts, in the corner"],
	"death": ["On death", "death_aoe, on_death summon, hatch"],
	"boom": ["Self-destructs", "kamikaze, the frog's burst"],
	"transform": ["Becomes another card", "becomes (Penny -> Pen, Obsidian -> Magma)"],
	"casts": ["Several casts", "uses > 1: the count goes in the corner"],
	"lockon": ["Locks on", "unit_lock: homes on its target"],
	"taunt": ["Taunts", "draws enemies to it (Golden Idol)"],
}
const BADGE_COL := {
	"melee": Color(0.62, 0.62, 0.66), "ranged": Color(0.55, 0.42, 0.26), "spell": Color(0.5, 0.36, 0.78),
	"special": Color(0.85, 0.65, 0.2),
	"flag": Color(0.78, 0.25, 0.22), "troops": Color(0.36, 0.5, 0.72), "weakest": Color(0.75, 0.3, 0.45),
	"flies": Color(0.45, 0.68, 0.9), "antiair": Color(0.3, 0.55, 0.8), "swarm": Color(0.5, 0.56, 0.6),
	"spawner": Color(0.86, 0.78, 0.55), "burn": Color(0.95, 0.45, 0.15), "poison": Color(0.5, 0.75, 0.25),
	"slow": Color(0.45, 0.72, 0.95), "stun": Color(0.95, 0.8, 0.2), "knock": Color(0.6, 0.5, 0.42),
	"splash": Color(0.9, 0.55, 0.3), "pierce": Color(0.55, 0.6, 0.7), "leap": Color(0.4, 0.7, 0.55),
	"charge": Color(0.75, 0.5, 0.3), "shield": Color(0.55, 0.6, 0.68), "regen": Color(0.85, 0.35, 0.45),
	"evasive": Color(0.7, 0.68, 0.85), "giant": Color(0.42, 0.4, 0.44), "hourglass": Color(0.78, 0.68, 0.48),
	"death": Color(0.35, 0.33, 0.38), "boom": Color(0.32, 0.3, 0.34), "transform": Color(0.6, 0.45, 0.75),
	"casts": Color(0.8, 0.62, 0.3), "lockon": Color(0.85, 0.3, 0.3), "taunt": Color(0.95, 0.75, 0.3),
}
## Cards whose attacks are more than "its one hit": [kind, name, damage, note].
## Summoner buildings are not here: their row is read from the summon data.
const ATTACKS := {
	"fu": [["ranged", "Boomerang", 30, "comes back, hits all it crosses"], ["melee", "Jab, Jab, Kick", 18, "kick 26, shoves 1.5"]],
	"gilgamesh": [["melee", "Serpent Lash", 22, "2.5 tiles"], ["ranged", "Spear Throw", 45, "Enkidu, 3 - 4.5 tiles"],
		["melee", "Spear", 24, "Enkidu, hits air"]],
	"chicken": [["ranged", "Fire Peck", 5, "+5 burn, 3.5 tiles"], ["special", "Ram", 0, "after 3 hits: 30 burn splash"]],
	"laniakea": [["melee", "Cleave", 25, "140 deg arc, shoves 0.5"], ["melee", "Leap Slam", 50, "at flyers, stuns 0.5 s"]],
	"femme": [["melee", "Needle Dash", 25, "from 3.5 - 4.5 tiles"], ["melee", "Combo", 12, "flick, stab, stab"]],
	"neko": [["ranged", "Beam", 14, "4 tiles, ground or air"], ["special", "Ritual", 0, "2 Rat Skeletons every 4 s"]],
	"phalanx": [["melee", "Spear", 14, "1.7 tiles, over the front rank"], ["melee", "Dagger", 8, "shield broken, within 1"]],
	"wu": [["melee", "Staff Poke", 16, "pierces 2 tiles, shoves"], ["melee", "Staff Sweep", 16, "120 deg cone"]],
	"enkidu": [["ranged", "Spear Throw", 45, "3 - 4.5 tiles"], ["melee", "Spear", 24, "hits air"]],
	"frog": [["special", "Poison Leap", 10, "poison, once, 2 tiles"]],
	"hedgehog": [["melee", "Quills", 12, "curl burst + 8 thorns"]],
	"snowman": [["special", "Meltdown", 30, "on death: 3 tiles, slows"]],
	"idol": [["special", "Taunt", 0, "lures enemies, a boulder on death"]],
}
const SHORT_LABEL := {
	"flag": "Buildings", "troops": "Troops only", "weakest": "Weakest", "flies": "Flies", "antiair": "Hits air",
	"swarm": "%s bodies", "spawner": "Spawner", "burn": "Burn", "poison": "Poison", "slow": "Slow",
	"stun": "Stun", "knock": "Knockback", "splash": "Area", "pierce": "Pierces", "leap": "Leaps",
	"charge": "Charges", "shield": "Armour", "regen": "Heals", "evasive": "Evasive", "giant": "Giant",
	"hourglass": "%s life", "death": "On death", "boom": "Self-destruct", "transform": "Transforms",
	"casts": "%s casts", "lockon": "Lock-on", "taunt": "Taunt",
}


## Set the trim and the middle line in one go (either may be left as is by
## passing a colour with alpha 0).
static func set_colors(trim_col: Color, line_col: Color) -> void:
	if trim_col.a > 0.0:
		trim = trim_col
	if line_col.a > 0.0:
		line = line_col


static func trim_dark() -> Color:
	return trim.darkened(0.28)


## `col` at the face's current opacity.
static func _c(col: Color) -> Color:
	return Color(col.r, col.g, col.b, col.a * _a)


# ------------------------------------------------------------------ entry points

## The in-hand face (no description). cost_col overrides the cost digit's colour
## (the hand flags a card you cannot pay for yet); hide_art blanks the art
## window (a swarm being dragged over the board, where the preview shows it).
static func draw(ci: CanvasItem, kind: String, rect: Rect2, alpha: float = 1.0,
		cost_col: Color = Color(0, 0, 0, 0), hide_art: bool = false) -> void:
	card(ci, kind, rect, false, alpha, cost_col, hide_art)


## The full face with the description (`blurb`): the reward screen.
static func draw_full(ci: CanvasItem, kind: String, rect: Rect2, alpha: float = 1.0) -> void:
	card(ci, kind, rect, true, alpha)


static func card(ci: CanvasItem, kind: String, r: Rect2, with_desc: bool, alpha: float = 1.0,
		cost_col: Color = Color(0, 0, 0, 0), hide_art: bool = false) -> void:
	if kind == "" or r.size.x < 26.0:
		return
	_a = clampf(alpha, 0.0, 1.0)
	_card(ci, kind, r, with_desc, cost_col, hide_art)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_a = 1.0


## Where `_card` puts the art window for a card drawn in `r` (the hand asks, to
## drop the art when troops stand behind it). Same budget as `_card`.
static func art_rect(kind: String, r: Rect2, with_desc: bool = false) -> Rect2:
	var s: float = r.size.x / 300.0
	var w := r.size.x
	var level := 3 if w >= 260.0 else (2 if w >= 170.0 else (1 if w >= 120.0 else 0))
	var n_attacks := attacks_of(kind).size()
	var panel := r.grow(-maxf(2.0, 9.0 * s))
	var header_h := 38.0 * s
	var strip_room := 24.0 * s if level >= 2 else 6.0 * s
	var bar_room := 44.0 * s if panel.size.y > 110.0 else 0.0
	var atk_min := clampf(11.0 * s, 7.0, 14.0) * 2.0 + 4.0
	if level == 3:
		atk_min = 36.0 * s * float(n_attacks) + (70.0 * s if with_desc else 0.0)
	elif level == 2:
		atk_min = 22.0 * s * float(maxi(1, n_attacks))
	var art_h := clampf(panel.size.y - header_h - strip_room - bar_room - atk_min - 4.0 * s, 40.0 * s, 150.0 * s)
	return Rect2(panel.position.x + 8.0 * s, panel.position.y + header_h, panel.size.x - 16.0 * s, art_h)


static func _card(ci: CanvasItem, kind: String, r: Rect2, with_desc: bool, cost_col: Color, hide_art: bool) -> void:
	var d: Dictionary = DDCard.get_card(kind)
	var font: Font = ThemeDB.fallback_font
	var s: float = r.size.x / 300.0
	var w := r.size.x
	var accent: Color = d["accent"]
	var level := 3 if w >= 260.0 else (2 if w >= 170.0 else (1 if w >= 120.0 else 0))
	var attacks := attacks_of(kind)
	# the border and the panel
	var sb := StyleBoxFlat.new()
	sb.bg_color = _c(trim)
	sb.set_corner_radius_all(int(14.0 * s))
	sb.border_color = _c(trim_dark())
	sb.set_border_width_all(maxi(1, int(2.0 * s)))
	sb.draw(ci.get_canvas_item(), r)
	var pad := maxf(2.0, 9.0 * s)
	var panel := r.grow(-pad)
	var top_col: Color = accent.lightened(0.5)
	var bot_col: Color = accent.lightened(0.15)
	for i in 12:
		var f := float(i) / 12.0
		ci.draw_rect(Rect2(panel.position.x, panel.position.y + panel.size.y * f, panel.size.x, panel.size.y / 12.0 + 1.0),
			_c(top_col.lerp(bot_col, f)))
	ci.draw_rect(panel, _c(Color(0, 0, 0, 0.25)), false, maxf(1.0, 1.2 * s))
	var x0 := panel.position.x
	var y0 := panel.position.y
	var pw := panel.size.x
	# the vertical budget: the art window takes what the header, the middle line,
	# the attacks and the icon bar leave, up to its full height
	var header_h := 38.0 * s
	var show_bar := panel.size.y > 110.0
	var chip_r := clampf(11.0 * s, 7.0, 14.0)
	var strip_room := 24.0 * s if level >= 2 else 6.0 * s
	var art := art_rect(kind, r, with_desc)
	# type tag, cost, name, HP
	if level >= 2:
		var tag := String(d.get("type", "troop")).to_upper()
		ci.draw_string(font, Vector2(x0 + 38.0 * s, y0 + 10.0 * s), tag, HORIZONTAL_ALIGNMENT_LEFT, -1,
			maxi(6, int(9.0 * s)), _c(Color(0.25, 0.2, 0.15, 0.8)))
	var cost_r := maxf(7.0, 15.0 * s)
	var cost_c := Vector2(x0 + cost_r + 1.0 * s, y0 + 18.0 * s)
	ci.draw_circle(cost_c, cost_r + maxf(1.0, 1.5 * s), _c(OUT))
	ci.draw_circle(cost_c, cost_r, _c(Color(0.86, 0.68, 0.18)))
	ci.draw_circle(cost_c + Vector2(-cost_r * 0.3, -cost_r * 0.3), cost_r * 0.38, _c(Color(1.0, 0.94, 0.62, 0.9)))
	var cost_ink := OUT if cost_col.a <= 0.0 else Color(cost_col.r, cost_col.g, cost_col.b)
	ci.draw_string(font, cost_c + Vector2(-cost_r, cost_r * 0.42), str(int(d["cost"])), HORIZONTAL_ALIGNMENT_CENTER,
		cost_r * 2.0, maxi(8, int(cost_r * 1.3)), _c(cost_ink))
	var hp_txt := _hp_text(d)
	var hp_sz := maxi(8, int(20.0 * s))
	var hp_w: float = font.get_string_size(hp_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, hp_sz).x
	var name_y := y0 + 28.0 * s
	if hp_txt != "":
		ci.draw_string(font, Vector2(x0 + pw - hp_w - 6.0 * s, name_y), hp_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, hp_sz,
			_c(Color(0.7, 0.12, 0.1)))
		if level >= 1:
			ci.draw_string(font, Vector2(x0 + pw - hp_w - 6.0 * s - 18.0 * s, name_y), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1,
				maxi(6, int(9.0 * s)), _c(Color(0.7, 0.12, 0.1)))
	var name_left := cost_c.x + cost_r + 4.0 * s
	var name_avail: float = x0 + pw - name_left - hp_w - (30.0 * s if level >= 1 else 8.0 * s)
	var nm := String(d["name"]) if level >= 2 else DDCard.short_name(kind)
	var n_sz := fitted(font, nm, name_avail, 20.0 * s, 7.0)
	if font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, n_sz).x > name_avail:
		nm = DDCard.tiny_name(kind)
		n_sz = fitted(font, nm, name_avail, 20.0 * s, 6.0)
	ci.draw_string(font, Vector2(name_left, name_y), nm, HORIZONTAL_ALIGNMENT_LEFT, name_avail, n_sz, _c(OUT))
	# the art window
	ci.draw_rect(art.grow(3.0 * s), _c(trim_dark()))
	ci.draw_rect(art.grow(1.5 * s), _c(trim))
	# hide_art leaves the window empty (backdrop too), so the board shows through
	for i in (0 if hide_art else 8):
		var f2 := float(i) / 8.0
		ci.draw_rect(Rect2(art.position.x, art.position.y + art.size.y * f2, art.size.x, art.size.y / 8.0 + 1.0),
			_c(accent.lightened(0.75 - f2 * 0.35)))
	if not hide_art:
		_draw_art(ci, kind, art)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ci.draw_rect(art, _c(Color(0, 0, 0, 0.35)), false, 1.0)
	# what it summons, in a coin at the art's top right, under the HP
	var minion := _minion_of(d)
	if minion != "":
		var mr: float = clampf(19.0 * s, 6.0, art.size.y * 0.3)
		var mc := Vector2(art.end.x - mr - 4.0 * s, art.position.y + mr + 4.0 * s)
		ci.draw_circle(mc, mr + maxf(1.0, 2.0 * s), _c(trim_dark()))
		ci.draw_circle(mc, mr, _c(trim))
		ci.draw_circle(mc, mr * 0.86, _c(accent.lightened(0.8)))
		DDArt.icon(ci, minion, mc + Vector2(0, mr * 0.08), mr * 0.62)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		ci.draw_arc(mc, mr * 0.86, 0.0, TAU, 32, _c(Color(0, 0, 0, 0.25)), maxf(1.0, 1.0 * s), true)
	# the middle line under the art
	var strip := Rect2(x0 + 14.0 * s, art.end.y + 5.0 * s, pw - 28.0 * s, 13.0 * s)
	var atk_top := art.end.y + strip_room
	if level >= 2:
		ci.draw_rect(strip, _c(line))
		ci.draw_rect(strip, _c(line.darkened(0.3)), false, 1.0)
		var strip_ink := Color(0.3, 0.22, 0.1) if line.get_luminance() > 0.5 else Color(0.97, 0.95, 0.9)
		ci.draw_string(font, Vector2(strip.position.x + 4.0 * s, strip.end.y - 3.0 * s), _info_text(d),
			HORIZONTAL_ALIGNMENT_CENTER, strip.size.x - 8.0 * s, maxi(6, int(9.0 * s)), _c(strip_ink))
	# without the description there is room to name the attributes: icon and a
	# word each, two to a row, under the attacks. Otherwise the bar of icons.
	var listed := false
	if not with_desc and level >= 2:
		var row_h_a: float = (36.0 if level == 3 else 26.0) * s
		var list_top: float = atk_top + row_h_a * float(attacks.size()) + 6.0 * s
		listed = _trait_list(ci, kind, Rect2(x0 + 6.0 * s, list_top, pw - 12.0 * s, panel.end.y - list_top - 6.0 * s), s)
	var bar_h := 34.0 * s
	var bar := Rect2(x0 + 6.0 * s, panel.end.y - bar_h - 4.0 * s, pw - 12.0 * s, bar_h)
	var atk_bottom := bar.position.y - 6.0 * s
	if listed or not show_bar:
		atk_bottom = panel.end.y - 6.0 * s
	else:
		ci.draw_line(Vector2(bar.position.x, bar.position.y - 3.0 * s), Vector2(bar.end.x, bar.position.y - 3.0 * s),
			_c(Color(0, 0, 0, 0.3)), 1.0)
		_trait_bar(ci, kind, bar, s)
	if level == 3:
		var row_h := 36.0 * s
		var y := atk_top
		for a in attacks:
			_attack_row_full(ci, a, Rect2(x0 + 6.0 * s, y, pw - 12.0 * s, row_h), s)
			y += row_h
		if with_desc:
			var box := Rect2(x0 + 8.0 * s, y + 4.0 * s, pw - 16.0 * s, atk_bottom - y - 4.0 * s)
			if box.size.y > 14.0 * s:
				ci.draw_rect(box, _c(Color(1.0, 0.98, 0.9, 0.6)))
				ci.draw_rect(box, _c(trim_dark()), false, 1.0)
				var text := String(d.get("blurb", ""))
				var sz := int(13.0 * s)
				var tw: float = box.size.x - 8.0 * s
				while sz > 6 and font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, tw, sz).y > box.size.y - 6.0 * s:
					sz -= 1
				ci.draw_multiline_string(font, box.position + Vector2(4.0 * s, 3.0 * s + float(sz)), text,
					HORIZONTAL_ALIGNMENT_LEFT, tw, sz, -1, _c(Color(0.25, 0.2, 0.15)))
	elif level == 2:
		var row_h2 := minf(26.0 * s, (atk_bottom - atk_top) / maxf(1.0, float(attacks.size())))
		var y2 := atk_top
		for a in attacks:
			_attack_row_mid(ci, a, Rect2(x0 + 6.0 * s, y2, pw - 12.0 * s, row_h2), s)
			y2 += row_h2
	else:
		# chips: icon + damage side by side
		var cx := x0 + 6.0 * s + chip_r
		var cy := (atk_top + atk_bottom) * 0.5
		for a in attacks:
			badge(ci, String(a[0]), Vector2(cx, cy), chip_r)
			cx += chip_r + 2.0
			if level == 1 and int(a[2]) > 0:
				var dt := str(int(a[2]))
				var dsz := maxi(8, int(chip_r * 1.2))
				ci.draw_string(font, Vector2(cx, cy + dsz * 0.35), dt, HORIZONTAL_ALIGNMENT_LEFT, -1, dsz, _c(OUT))
				cx += font.get_string_size(dt, HORIZONTAL_ALIGNMENT_LEFT, -1, dsz).x + 6.0
			cx += chip_r + 2.0


# ------------------------------------------------------------------ what it says

static func _hp_text(d: Dictionary) -> String:
	if String(d.get("type", "troop")) == "spell":
		return ""
	var hp := int(d["hp"])
	if d.has("partner"):
		return "%d+%d" % [hp, int(DDCard.get_card(String(d["partner"]))["hp"])]
	# a swarm: HP of one body, then how many land
	var n := int(d.get("count", 0))
	if d.has("swarm_offsets") and n <= 1:
		n = (d["swarm_offsets"] as Array).size()
	if n > 1:
		return "%d ×%d" % [hp, n]
	return str(hp)


## The unit a card makes over time (a summoner building's spawn, the
## Nekomancer's ritual), or "" if it makes none.
static func _minion_of(d: Dictionary) -> String:
	for key in ["summon", "ritual"]:
		var cfg: Dictionary = d.get(key, {})
		if cfg.has("unit"):
			return String(cfg["unit"])
	return ""


static func _info_text(d: Dictionary) -> String:
	match String(d.get("type", "troop")):
		"spell":
			return "Spell  -  from your %s tower" % ("king" if String(d.get("launch", "")) == "king" else "nearest")
		"building":
			var fp: Array = d.get("footprint", [1, 1])
			return "Building  -  %dx%d  -  lasts %ds" % [int(fp[0]), int(fp[1]), int(d.get("lifetime", 0))]
	return "Troop  -  speed %.2f  -  sight %.1f tiles" % [float(d.get("speed", 0.0)), float(d.get("aggro", 0.0))]


static func traits_of(kind: String) -> Array:
	var d: Dictionary = DDCard.get_card(kind)
	var out: Array = []
	var payload: Dictionary = d.get("payload", {})
	if bool(d.get("buildings_only", false)):
		out.append(["flag", ""])
	if bool(d.get("troops_only", false)):
		out.append(["troops", ""])
	if bool(d.get("targets_weakest", false)):
		out.append(["weakest", ""])
	if bool(d.get("flying_unit", false)) or d.has("chicken") or kind == "dragon":
		out.append(["flies", ""])
	if bool(d.get("hits_air", false)):
		out.append(["antiair", ""])
	var n: int = (d.get("swarm_offsets", []) as Array).size()
	if d.has("partner"):
		n = 2
	if n > 1:
		out.append(["swarm", "%d" % n])
	if d.has("summon") or d.has("ritual") or d.has("hatch"):
		out.append(["spawner", ""])
	if float(d.get("burn", 0.0)) > 0.0 or float(payload.get("burn", 0.0)) > 0.0 or d.has("kamikaze") \
			or d.has("ground_fire") or kind == "dragon":
		out.append(["burn", ""])
	if float(d.get("poison", 0.0)) > 0.0 or d.has("frog") or float(payload.get("poison", 0.0)) > 0.0:
		out.append(["poison", ""])
	if d.has("slow") or d.has("slow_time") or d.has("death_aoe"):
		out.append(["slow", ""])
	if float(payload.get("stun", 0.0)) > 0.0 or d.has("greatsword"):
		out.append(["stun", ""])
	if d.has("knock") or d.has("curl") or d.has("staff") or d.has("boomerang") or d.has("greatsword") \
			or d.has("wool") or (d.has("roll") and kind == "snowball"):
		out.append(["knock", ""])
	if float(d.get("splash", 0.0)) > 0.0 or d.has("spread") or d.has("greatsword") or d.has("staff"):
		out.append(["splash", ""])
	if d.has("boomerang") or d.has("staff"):
		out.append(["pierce", ""])
	if d.has("needle") or d.has("greatsword") or d.has("frog") or d.has("dodge"):
		out.append(["leap", ""])
	if d.has("roll") and kind != "snowball":
		out.append(["charge", ""])
	if d.has("guard") or d.has("curl") or d.has("shield"):
		out.append(["shield", ""])
	if d.has("staff"):
		out.append(["regen", ""])
	if d.has("dodge"):
		out.append(["evasive", ""])
	if bool(d.get("giant", false)):
		out.append(["giant", ""])
	if float(d.get("lifetime", 0.0)) > 0.0:
		out.append(["hourglass", "%ds" % int(d["lifetime"])])
	if d.has("death_aoe") or bool((d.get("summon", {}) as Dictionary).get("on_death", false)) or d.has("hatch") \
			or kind == "idol":
		out.append(["death", ""])
	if d.has("kamikaze") or d.has("frog"):
		out.append(["boom", ""])
	if d.has("becomes"):
		out.append(["transform", ""])
	if int(d.get("uses", 1)) > 1:
		out.append(["casts", "%d" % int(d["uses"])])
	if bool(d.get("unit_lock", false)):
		out.append(["lockon", ""])
	if kind == "idol":
		out.append(["taunt", ""])
	return out


static func attacks_of(kind: String) -> Array:
	if ATTACKS.has(kind):
		return ATTACKS[kind]
	var d: Dictionary = DDCard.get_card(kind)
	var dmg := int(d.get("dmg", 0))
	var nm := String(ATTACK_NAMES.get(kind, "Attack"))
	if DDCard.is_spell(kind):
		var note := ""
		if float(d.get("burn", 0.0)) > 0.0:
			note = "+%d burn" % int(d["burn"])
		if float(d.get("splash", 0.0)) > 0.0:
			note += "%sradius %.1f" % [", " if note != "" else "", float(d["splash"])]
		return [["spell", nm, dmg, note]]
	var sum_cfg: Dictionary = d.get("summon", {})
	if sum_cfg.has("unit") and dmg <= 0:
		return [["special", nm, 0, _summon_note(sum_cfg)]]
	if dmg <= 0:
		return []
	var reach := float(d.get("reach", 0.0))
	var ranged: bool = d.has("shoots") or d.has("spread") or bool(d.get("beam", false)) or reach >= 2.6
	if d.has("pack"):
		var n_pack := (d["swarm_offsets"] as Array).size()
		return [["melee", nm, dmg, "in turns: one every %.1f s" % (float(d["interval"]) / float(n_pack))]]
	var note2 := "every %.1f s, %.1f tiles" % [float(d.get("interval", 1.0)), reach]
	if d.has("ram"):
		return [["special", "Ram", int((d["ram"] as Dictionary)["dmg"]), "first hit on each building"],
			["melee", nm, dmg, "every %.1f s after the ram" % float(d.get("interval", 1.0))]]
	return [["ranged" if ranged else "melee", nm, dmg, note2]]


## "an Ant every 2 s", "3 Lizard Soldiers when enemies near", read from the
## summon block so a balance change shows on the card.
static func _summon_note(cfg: Dictionary) -> String:
	var unit_name := String(DDCard.get_card(String(cfg["unit"])).get("name", String(cfg["unit"])))
	var count := int(cfg.get("count", 1))
	var who := ("a %s" % unit_name) if count <= 1 else ("%d %s" % [count, unit_name])
	if cfg.has("interval"):
		var iv := float(cfg["interval"])
		var iv_txt := ("%.0f" % iv) if is_equal_approx(iv, roundf(iv)) else ("%.1f" % iv)
		return "%s every %s s" % [who, iv_txt]
	return "%s when enemies near" % who


# ------------------------------------------------------------------ the rows

static func _attack_row_full(ci: CanvasItem, a: Array, r: Rect2, s: float) -> void:
	var font: Font = ThemeDB.fallback_font
	badge(ci, String(a[0]), Vector2(r.position.x + 12.0 * s, r.position.y + 13.0 * s), 11.0 * s)
	ci.draw_string(font, Vector2(r.position.x + 30.0 * s, r.position.y + 17.0 * s), String(a[1]),
		HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 80.0 * s, int(15.0 * s), _c(OUT))
	if int(a[2]) > 0:
		ci.draw_string(font, Vector2(r.position.x, r.position.y + 19.0 * s), str(int(a[2])),
			HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 4.0 * s, int(20.0 * s), _c(OUT))
	ci.draw_string(font, Vector2(r.position.x + 30.0 * s, r.position.y + 30.0 * s), String(a[3]),
		HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 34.0 * s, int(9.5 * s), _c(Color(0.3, 0.25, 0.2)))
	ci.draw_line(Vector2(r.position.x + 4.0 * s, r.end.y - 1.0), Vector2(r.end.x - 4.0 * s, r.end.y - 1.0),
		_c(Color(0, 0, 0, 0.18)), 1.0)


static func _attack_row_mid(ci: CanvasItem, a: Array, r: Rect2, s: float) -> void:
	var font: Font = ThemeDB.fallback_font
	var ir: float = minf(10.0 * s, r.size.y * 0.42)
	badge(ci, String(a[0]), Vector2(r.position.x + ir + 2.0, r.get_center().y), ir)
	var dsz := int(clampf(17.0 * s, 9.0, 20.0))
	var dt := str(int(a[2])) if int(a[2]) > 0 else ""
	var dw: float = font.get_string_size(dt, HORIZONTAL_ALIGNMENT_LEFT, -1, dsz).x
	var avail: float = r.size.x - ir * 2.0 - 10.0 - dw - 6.0
	var nm := String(a[1])
	ci.draw_string(font, Vector2(r.position.x + ir * 2.0 + 7.0, r.get_center().y + 5.0 * s), nm,
		HORIZONTAL_ALIGNMENT_LEFT, avail, fitted(font, nm, avail, 13.0 * s, 7.0), _c(OUT))
	if dt != "":
		ci.draw_string(font, Vector2(r.end.x - dw - 2.0, r.get_center().y + dsz * 0.36), dt, HORIZONTAL_ALIGNMENT_LEFT, -1,
			dsz, _c(OUT))


## Icon + word for each attribute, two columns, top down. False (and nothing
## drawn) if they do not all fit.
static func _trait_list(ci: CanvasItem, kind: String, area: Rect2, s: float) -> bool:
	var traits := traits_of(kind)
	if traits.is_empty():
		return true
	var r: float = clampf(10.0 * s, 7.0, 12.0)
	var row_h: float = r * 2.0 + 5.0 * s
	var rows := int(ceilf(float(traits.size()) / 2.0))
	if float(rows) * row_h > area.size.y:
		return false
	var font: Font = ThemeDB.fallback_font
	var col_w: float = area.size.x * 0.5
	var fs := maxi(7, int(11.0 * s))
	ci.draw_line(Vector2(area.position.x, area.position.y - 3.0 * s), Vector2(area.end.x, area.position.y - 3.0 * s),
		_c(Color(0, 0, 0, 0.18)), 1.0)
	for i in traits.size():
		var t: Array = traits[i]
		var cx: float = area.position.x + col_w * float(i % 2) + r + 2.0
		var cy: float = area.position.y + row_h * float(i / 2) + r + 2.0
		badge(ci, String(t[0]), Vector2(cx, cy), r)
		var label := String(SHORT_LABEL.get(String(t[0]), String(t[0])))
		if label.contains("%s"):
			label = label % String(t[1])
		ci.draw_string(font, Vector2(cx + r + 4.0, cy + fs * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT,
			col_w - r * 2.0 - 8.0, fs, _c(OUT))
	return true


## The icons along the bottom, as many as fit; the rest become "+N".
static func _trait_bar(ci: CanvasItem, kind: String, bar: Rect2, s: float) -> void:
	var traits := traits_of(kind)
	if traits.is_empty():
		return
	var r: float = clampf(bar.size.y * 0.42, 6.0, 15.0)
	var step: float = r * 2.0 + maxf(2.0, 4.0 * s)
	var fit: int = int(floorf((bar.size.x + 4.0 * s) / step))
	var show := traits.size()
	if show > fit:
		show = fit - 1
	var total_w: float = float(show) * step - (step - r * 2.0)
	var x: float = bar.position.x + (bar.size.x - total_w) * 0.5 + r
	if traits.size() > show:
		x = bar.position.x + r
	for i in show:
		var t: Array = traits[i]
		badge(ci, String(t[0]), Vector2(x, bar.get_center().y), r, String(t[1]))
		x += step
	if traits.size() > show:
		var font: Font = ThemeDB.fallback_font
		if hit_log != null:
			var hidden: Array = []
			for k in range(show, traits.size()):
				hidden.append(String((traits[k] as Array)[0]))
			hit_log.append({"c": Vector2(x, bar.get_center().y), "r": r, "id": "more", "hidden": hidden})
		ci.draw_circle(Vector2(x, bar.get_center().y), r, _c(Color(0.2, 0.18, 0.22)))
		ci.draw_string(font, Vector2(x - r, bar.get_center().y + r * 0.42), "+%d" % (traits.size() - show),
			HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, maxi(7, int(r * 1.05)), _c(Color(1, 1, 1)))


# ------------------------------------------------------------------ the art

## The art pane: one big creature for a single body, or — for a swarm — the
## whole formation, scaled to fit, so the card reads like the deploy preview.
static func _draw_art(ci: CanvasItem, kind: String, art: Rect2) -> void:
	var offsets: Array = DDCard.get_card(kind).get("swarm_offsets", [])
	if offsets.is_empty():
		ci.draw_set_transform(art.get_center() + Vector2(0, art.size.y * 0.14), 0.0, Vector2.ONE)
		if kind == "gilgamesh":
			DDArt.gil_pair(ci, art.get_center() + Vector2(0, art.size.y * 0.14), art.size.y * 0.3)
		elif kind == "dragon":
			DDArt.dragon(ci, art.size.y * 0.30, 1.0, 0.0, false)
		elif kind == "hawk":
			DDArt.bird(ci, art.size.y * 0.34, 1.0, 0.0, true)
		else:
			DDArt.creature(ci, kind, art.size.y * 0.34, 1.0, 0.0)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var half_x := 0.0
	var half_y := 0.0
	for off in offsets:
		half_x = maxf(half_x, absf(float((off as Array)[0])))
		half_y = maxf(half_y, absf(float((off as Array)[1])))
	# each body is one tile wide with a 0.44 tile radius, in the preview's units
	var unit_scale: float = minf(art.size.x / (half_x * 2.0 + 0.9), art.size.y / (half_y * 2.0 + 0.9))
	var centre := art.get_center()
	for i in offsets.size():
		var off: Array = offsets[i]
		# the preview mirrors a formation's y offsets for team 0 (ydir = -1); the
		# card art uses the same orientation so the two line up
		var at: Vector2 = centre + Vector2(float(off[0]), -float(off[1])) * unit_scale
		# the lead bird is the red i'iwi: the card shows it too
		DDArt.icon(ci, kind, at, unit_scale * 0.44, 0.0, i == 0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Largest integer size no bigger than start that fits the space, never below floor_size.
static func fitted(font: Font, text: String, avail: float, start: float, floor_size: float) -> int:
	var s := start
	while s > floor_size and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(s)).x > avail:
		s -= 1.0
	return int(maxf(s, floor_size))


# ------------------------------------------------------------------ the icons

## A round badge in the icon's colour with its glyph, and an optional count
## tucked into the lower right.
static func badge(ci: CanvasItem, id: String, c: Vector2, r: float, count: String = "") -> void:
	var col: Color = BADGE_COL.get(id, Color(0.5, 0.5, 0.5))
	if hit_log != null:
		hit_log.append({"c": c, "r": r, "id": id, "count": count})
	ci.draw_circle(c, r + maxf(1.0, r * 0.12), _c(OUT))
	ci.draw_circle(c, r, _c(col))
	ci.draw_circle(c + Vector2(-r * 0.3, -r * 0.35), r * 0.45, _c(Color(1, 1, 1, 0.14)))
	glyph(ci, id, c, r * 0.62)
	if count != "":
		var font: Font = ThemeDB.fallback_font
		var fs := maxi(6, int(r * 0.85))
		var tw: float = font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := c + Vector2(r * 0.55, r * 0.55)
		var pill := Rect2(at.x - tw * 0.5 - 2.0, at.y - fs * 0.55, tw + 4.0, fs * 1.1)
		ci.draw_rect(pill, _c(OUT))
		ci.draw_string(font, Vector2(pill.position.x + 2.0, pill.end.y - fs * 0.22), count, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			_c(Color(1, 1, 1)))


## The glyph, white with a dark edge, inside a radius-r circle centred on c.
static func glyph(ci: CanvasItem, id: String, c: Vector2, r: float) -> void:
	var W := _c(Color(1, 1, 1))
	var K := _c(Color(0.1, 0.09, 0.12))
	var lw: float = maxf(1.2, r * 0.22)
	var L := func(a: Vector2, b: Vector2, wd: float = -1.0) -> void:
		var ww: float = lw if wd < 0.0 else wd
		ci.draw_line(c + a * r, c + b * r, K, ww + 1.6, true)
		ci.draw_line(c + a * r, c + b * r, W, ww, true)
	var P := func(pts: Array, col: Color = Color(1, 1, 1)) -> void:
		var pv := PackedVector2Array()
		for p in pts:
			pv.append(c + (p as Vector2) * r)
		ci.draw_colored_polygon(pv, DDCardFace._c(col))
		var loop := pv.duplicate()
		loop.append(pv[0])
		ci.draw_polyline(loop, K, maxf(1.0, r * 0.1), true)
	match id:
		"melee":
			# two swords crossed, blades up
			for sgn in [-1.0, 1.0]:
				L.call(Vector2(-0.75 * sgn, 0.75), Vector2(0.7 * sgn, -0.7))
				L.call(Vector2(-0.55 * sgn, 0.25), Vector2(-0.25 * sgn, 0.55), lw * 0.9)
		"ranged":
			# a bow drawn, an arrow on the string
			var arc := PackedVector2Array()
			for i in 9:
				var a: float = lerpf(-PI * 0.42, PI * 0.42, float(i) / 8.0)
				arc.append(c + Vector2(cos(a) * 0.55 - 0.2, sin(a) * 0.95) * r)
			ci.draw_polyline(arc, K, lw + 1.6, true)
			ci.draw_polyline(arc, W, lw, true)
			ci.draw_line(arc[0], arc[8], W, maxf(1.0, lw * 0.4), true)
			L.call(Vector2(-0.5, 0.0), Vector2(0.75, 0.0), lw * 0.7)
			P.call([Vector2(0.95, 0.0), Vector2(0.6, -0.22), Vector2(0.6, 0.22)])
		"spell":
			P.call([Vector2(0, -0.95), Vector2(0.2, -0.2), Vector2(0.95, 0), Vector2(0.2, 0.2), Vector2(0, 0.95),
				Vector2(-0.2, 0.2), Vector2(-0.95, 0), Vector2(-0.2, -0.2)])
		"special":
			var star: Array = []
			for i in 10:
				var a2: float = -PI * 0.5 + TAU * float(i) / 10.0
				var rr: float = 0.95 if i % 2 == 0 else 0.42
				star.append(Vector2(cos(a2), sin(a2)) * rr)
			P.call(star)
		"flag":
			L.call(Vector2(-0.55, 0.9), Vector2(-0.55, -0.9))
			P.call([Vector2(-0.5, -0.85), Vector2(0.75, -0.5), Vector2(-0.5, -0.1)], Color(1.0, 0.85, 0.8))
		"troops":
			# a helmeted head and shoulders
			P.call([Vector2(-0.7, 0.9), Vector2(-0.6, 0.35), Vector2(0.6, 0.35), Vector2(0.7, 0.9)])
			P.call([Vector2(-0.45, 0.1), Vector2(-0.45, -0.35), Vector2(0, -0.75), Vector2(0.45, -0.35), Vector2(0.45, 0.1)])
		"weakest":
			# a heart with a crack down it
			P.call([Vector2(0, 0.85), Vector2(-0.85, -0.05), Vector2(-0.55, -0.7), Vector2(0, -0.35), Vector2(0.55, -0.7),
				Vector2(0.85, -0.05)], Color(1.0, 0.75, 0.8))
			ci.draw_polyline(PackedVector2Array([c + Vector2(0, -0.35) * r, c + Vector2(-0.15, 0.05) * r,
				c + Vector2(0.12, 0.3) * r, c + Vector2(0, 0.8) * r]), K, maxf(1.0, r * 0.14), true)
		"flies":
			# one wing, feathers fanned
			P.call([Vector2(-0.9, 0.2), Vector2(-0.2, -0.75), Vector2(0.9, -0.6), Vector2(0.5, -0.2), Vector2(0.8, 0.05),
				Vector2(0.35, 0.25), Vector2(0.55, 0.5), Vector2(-0.3, 0.45)])
		"antiair":
			# an arrow pointing up at a small wing
			L.call(Vector2(0, 0.9), Vector2(0, -0.35))
			P.call([Vector2(0, -0.95), Vector2(-0.35, -0.4), Vector2(0.35, -0.4)])
			P.call([Vector2(0.25, -0.2), Vector2(0.9, -0.55), Vector2(0.75, 0.0)], Color(0.85, 0.95, 1.0))
		"swarm":
			for p in [Vector2(-0.5, 0.15), Vector2(0.5, 0.15), Vector2(0, -0.35)]:
				ci.draw_circle(c + (p + Vector2(0, -0.3)) * r, r * 0.24 + 1.0, K)
				ci.draw_circle(c + (p + Vector2(0, -0.3)) * r, r * 0.24, W)
				P.call([p + Vector2(-0.3, 0.55), p + Vector2(0, 0.0), p + Vector2(0.3, 0.55)])
		"spawner":
			# an egg with a crack
			var egg: Array = []
			for i in 14:
				var a3: float = TAU * float(i) / 14.0
				egg.append(Vector2(cos(a3) * 0.62, sin(a3) * 0.85 + (0.12 if sin(a3) > 0.0 else 0.0)))
			P.call(egg, Color(1.0, 0.97, 0.88))
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.6, 0.0) * r, c + Vector2(-0.3, -0.2) * r, c + Vector2(-0.05, 0.05) * r,
				c + Vector2(0.25, -0.2) * r, c + Vector2(0.6, 0.0) * r]), K, maxf(1.0, r * 0.13), true)
		"burn":
			P.call([Vector2(0, -0.95), Vector2(0.45, -0.3), Vector2(0.6, 0.25), Vector2(0.35, 0.8), Vector2(-0.35, 0.8),
				Vector2(-0.6, 0.25), Vector2(-0.3, -0.25), Vector2(-0.1, 0.05)], Color(1.0, 0.92, 0.6))
			P.call([Vector2(0, 0.0), Vector2(0.25, 0.4), Vector2(0.15, 0.75), Vector2(-0.15, 0.75), Vector2(-0.25, 0.4)], Color(1.0, 0.6, 0.2))
		"poison":
			P.call([Vector2(0, -0.95), Vector2(0.55, 0.15), Vector2(0.4, 0.65), Vector2(0, 0.85), Vector2(-0.4, 0.65),
				Vector2(-0.55, 0.15)], Color(0.85, 1.0, 0.6))
			ci.draw_circle(c + Vector2(-0.18, 0.3) * r, r * 0.11, K)
			ci.draw_circle(c + Vector2(0.18, 0.3) * r, r * 0.11, K)
		"slow":
			for k in 3:
				var a4: float = PI * float(k) / 3.0
				var dv := Vector2(cos(a4), sin(a4))
				L.call(-dv * 0.9, dv * 0.9, lw * 0.8)
				for sgn2 in [-1.0, 1.0]:
					var tip: Vector2 = dv * 0.6 * sgn2
					L.call(tip, tip + (dv * 0.25 * sgn2).rotated(0.9), lw * 0.6)
					L.call(tip, tip + (dv * 0.25 * sgn2).rotated(-0.9), lw * 0.6)
		"stun":
			P.call([Vector2(0.15, -0.95), Vector2(-0.55, 0.1), Vector2(-0.05, 0.1), Vector2(-0.25, 0.95), Vector2(0.6, -0.15),
				Vector2(0.1, -0.15)], Color(1.0, 1.0, 0.8))
		"knock":
			P.call([Vector2(-0.2, -0.45), Vector2(0.3, -0.45), Vector2(0.3, -0.75), Vector2(0.95, 0.0), Vector2(0.3, 0.75),
				Vector2(0.3, 0.45), Vector2(-0.2, 0.45)])
			for yy in [-0.4, 0.0, 0.4]:
				L.call(Vector2(-0.9, yy), Vector2(-0.45, yy), lw * 0.6)
		"splash":
			ci.draw_circle(c, r * 0.32 + 1.0, K)
			ci.draw_circle(c, r * 0.32, W)
			for k in 8:
				var a5: float = TAU * float(k) / 8.0
				var dv2 := Vector2(cos(a5), sin(a5))
				L.call(dv2 * 0.5, dv2 * (0.95 if k % 2 == 0 else 0.75), lw * 0.7)
		"pierce":
			ci.draw_arc(c + Vector2(0.1, 0) * r, r * 0.45, 0.0, TAU, 16, K, lw + 1.6, true)
			ci.draw_arc(c + Vector2(0.1, 0) * r, r * 0.45, 0.0, TAU, 16, W, lw * 0.7, true)
			L.call(Vector2(-0.95, 0), Vector2(0.7, 0), lw * 0.75)
			P.call([Vector2(0.98, 0), Vector2(0.62, -0.25), Vector2(0.62, 0.25)])
		"leap":
			var arc2 := PackedVector2Array()
			for i in 9:
				var f3 := float(i) / 8.0
				arc2.append(c + Vector2(lerpf(-0.85, 0.55, f3), 0.6 - sin(f3 * PI) * 1.2) * r)
			ci.draw_polyline(arc2, K, lw + 1.6, true)
			ci.draw_polyline(arc2, W, lw, true)
			P.call([Vector2(0.9, 0.75), Vector2(0.35, 0.65), Vector2(0.7, 0.25)])
		"charge":
			for k in 2:
				var ox: float = -0.45 + 0.6 * float(k)
				P.call([Vector2(ox - 0.25, -0.7), Vector2(ox + 0.4, 0.0), Vector2(ox - 0.25, 0.7), Vector2(ox - 0.05, 0.0)])
		"shield":
			P.call([Vector2(-0.7, -0.75), Vector2(0.7, -0.75), Vector2(0.65, 0.15), Vector2(0, 0.95), Vector2(-0.65, 0.15)])
			L.call(Vector2(0, -0.6), Vector2(0, 0.7), lw * 0.5)
		"regen":
			P.call([Vector2(0, 0.85), Vector2(-0.85, -0.05), Vector2(-0.55, -0.7), Vector2(0, -0.35), Vector2(0.55, -0.7),
				Vector2(0.85, -0.05)], Color(1.0, 0.8, 0.85))
			var red := _c(Color(0.8, 0.15, 0.25))
			ci.draw_line(c + Vector2(-0.3, -0.05) * r, c + Vector2(0.3, -0.05) * r, red, maxf(1.2, r * 0.18), true)
			ci.draw_line(c + Vector2(0, -0.35) * r, c + Vector2(0, 0.25) * r, red, maxf(1.2, r * 0.18), true)
		"evasive":
			# a little ghost
			var gh: Array = [Vector2(-0.6, 0.85), Vector2(-0.6, -0.2)]
			for i in 7:
				var a6: float = PI + PI * float(i) / 6.0
				gh.append(Vector2(cos(a6) * 0.6, -0.2 + sin(a6) * 0.7))
			gh.append_array([Vector2(0.6, 0.85), Vector2(0.3, 0.6), Vector2(0.0, 0.85), Vector2(-0.3, 0.6)])
			P.call(gh, Color(1, 1, 1, 0.92))
			ci.draw_circle(c + Vector2(-0.2, -0.2) * r, r * 0.11, K)
			ci.draw_circle(c + Vector2(0.2, -0.2) * r, r * 0.11, K)
		"giant":
			# a heavy weight with a handle
			ci.draw_arc(c + Vector2(0, -0.35) * r, r * 0.35, PI, TAU, 10, K, lw + 1.6, true)
			ci.draw_arc(c + Vector2(0, -0.35) * r, r * 0.35, PI, TAU, 10, W, lw, true)
			P.call([Vector2(-0.6, -0.35), Vector2(0.6, -0.35), Vector2(0.85, 0.85), Vector2(-0.85, 0.85)])
		"hourglass":
			P.call([Vector2(-0.6, -0.9), Vector2(0.6, -0.9), Vector2(0.1, 0), Vector2(0.6, 0.9), Vector2(-0.6, 0.9), Vector2(-0.1, 0)],
				Color(1.0, 0.95, 0.8))
			P.call([Vector2(-0.35, 0.75), Vector2(0.35, 0.75), Vector2(0, 0.35)], Color(0.85, 0.65, 0.3))
		"death":
			# a skull
			ci.draw_circle(c + Vector2(0, -0.15) * r, r * 0.68 + 1.2, K)
			ci.draw_circle(c + Vector2(0, -0.15) * r, r * 0.68, W)
			P.call([Vector2(-0.4, 0.3), Vector2(0.4, 0.3), Vector2(0.3, 0.85), Vector2(-0.3, 0.85)])
			ci.draw_circle(c + Vector2(-0.27, -0.15) * r, r * 0.18, K)
			ci.draw_circle(c + Vector2(0.27, -0.15) * r, r * 0.18, K)
		"boom":
			ci.draw_circle(c + Vector2(-0.1, 0.15) * r, r * 0.68 + 1.2, K)
			ci.draw_circle(c + Vector2(-0.1, 0.15) * r, r * 0.68, _c(Color(0.35, 0.35, 0.4)))
			ci.draw_circle(c + Vector2(-0.3, -0.05) * r, r * 0.16, _c(Color(1, 1, 1, 0.5)))
			L.call(Vector2(0.3, -0.35), Vector2(0.6, -0.75), lw * 0.6)
			ci.draw_circle(c + Vector2(0.65, -0.82) * r, r * 0.16, _c(Color(1.0, 0.8, 0.3)))
		"transform":
			for sgn3 in [1.0, -1.0]:
				var arc3 := PackedVector2Array()
				for i in 8:
					var a7: float = lerpf(0.3, PI - 0.5, float(i) / 7.0) + (0.0 if sgn3 > 0.0 else PI)
					arc3.append(c + Vector2(cos(a7), sin(a7)) * r * 0.7)
				ci.draw_polyline(arc3, K, lw + 1.6, true)
				ci.draw_polyline(arc3, W, lw, true)
				var tip2: Vector2 = (arc3[7] - c) / r
				var dirv: Vector2 = (arc3[7] - arc3[6]).normalized()
				P.call([tip2 + dirv * 0.3, tip2 + dirv.orthogonal() * 0.25, tip2 - dirv.orthogonal() * 0.25])
		"casts":
			# two cards fanned
			P.call([Vector2(-0.75, -0.6), Vector2(0.1, -0.85), Vector2(0.35, 0.55), Vector2(-0.5, 0.8)], Color(0.92, 0.9, 0.85))
			P.call([Vector2(-0.2, -0.75), Vector2(0.65, -0.6), Vector2(0.75, 0.85), Vector2(-0.1, 0.85)])
		"lockon":
			ci.draw_arc(c, r * 0.6, 0.0, TAU, 20, K, lw + 1.6, true)
			ci.draw_arc(c, r * 0.6, 0.0, TAU, 20, W, lw, true)
			for k in 4:
				var dv3 := Vector2.from_angle(PI * 0.5 * float(k))
				L.call(dv3 * 0.35, dv3 * 0.98, lw * 0.75)
			ci.draw_circle(c, r * 0.12, W)
		"taunt":
			# a magnet
			var mag_col := _c(Color(0.95, 0.3, 0.3))
			var mag := PackedVector2Array()
			for i in 9:
				var a8: float = lerpf(0.0, PI, float(i) / 8.0)
				mag.append(c + Vector2(cos(a8) * 0.5, -0.05 - sin(a8) * 0.6) * r)
			ci.draw_polyline(mag, K, r * 0.42 + 1.6, true)
			ci.draw_polyline(mag, mag_col, r * 0.42, true)
			for sx in [-0.5, 0.5]:
				ci.draw_line(c + Vector2(sx, -0.05) * r, c + Vector2(sx, 0.55) * r, K, r * 0.42 + 1.6, true)
				ci.draw_line(c + Vector2(sx, -0.05) * r, c + Vector2(sx, 0.55) * r, mag_col, r * 0.42, true)
				ci.draw_line(c + Vector2(sx, 0.45) * r, c + Vector2(sx, 0.75) * r, W, r * 0.42, true)
		_:
			ci.draw_circle(c, r * 0.4, W)
