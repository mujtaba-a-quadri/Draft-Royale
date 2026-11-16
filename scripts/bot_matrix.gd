class_name DDBotMatrix

## Card roles, derived from card data, and the small "what answers what" table
## the bot consults. A new card needs role tags, not a row in a 15x15 grid — and
## because decks are shuffled, the bot has to reason about the cards in its hand
## rather than about named matchups.

## my role -> threat role -> how much of an answer it is (0 = no edge)
const ANSWER := {
	"air": {"melee": 2.0, "building": 2.5},
	"melee": {"ranged": 2.0, "tank": 1.6, "building": 1.0},
	"swarm": {"tank": 2.0, "ranged": 1.2, "building": 0.8},
	"splash": {"swarm": 2.6, "building": 2.0, "ranged": 1.0},
	"ranged": {"air": 1.5, "building": 0.6},
	"spell": {"swarm": 2.2, "building": 1.2, "ranged": 1.0},
	"tank": {"ranged": 1.2, "swarm": 0.8},
}


## Every role a card carries. Buildings, swarms, flyers and tanks can overlap.
static func roles_of(kind: String) -> Array:
	var d: Dictionary = DDCard.get_card(kind)
	var out: Array = []
	var stationary := bool(d.get("stationary", false))
	if DDCard.is_spell(kind):
		out.append("spell")
		if float(d.get("splash", 0.0)) > 0.0:
			out.append("splash")
		return out
	if stationary:
		out.append("building")
	if (d.get("swarm_offsets", []) as Array).size() >= 3:
		out.append("swarm")
	if bool(d.get("flying_unit", false)):
		out.append("air")
	if float(d.get("reach", 0.0)) >= 1.8:
		out.append("ranged")
	elif not stationary:
		out.append("melee")
	if float(d.get("hp", 0.0)) >= 150.0 and not stationary:
		out.append("tank")
	if float(d.get("splash", 0.0)) > 0.0 and not out.has("splash"):
		out.append("splash")
	return out


## Best edge any of this card's roles has against any of the threat's roles.
static func answer(kind: String, threat_roles: Array) -> float:
	var best := 0.0
	for r in roles_of(kind):
		var row: Dictionary = ANSWER.get(String(r), {})
		for t in threat_roles:
			best = maxf(best, float(row.get(String(t), 0.0)))
	return best


## Can this card do anything at all to a flying unit?
static func can_hit_air(kind: String) -> bool:
	if DDCard.is_spell(kind):
		return true
	return bool(DDCard.get_card(kind).get("hits_air", false))
