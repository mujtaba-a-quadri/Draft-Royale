class_name DDBot
extends Node

## Utility AI v1.
##
## Every decision tick it enumerates (card x placement) candidates, scores them
## with a handful of weighted features, then picks from the top scoring few with
## a seeded softmax — so it is varied between matches but reproducible for a
## given seed. It telegraphs its choice by "hovering" the card it is about to
## play (the panel only renders that when both hands are visible).

const DECISION_INTERVAL := 0.45
const TELEGRAPH_TIME := 0.55
const MIN_SCORE := 0.4

var arena = null
var player := 1
var rng := RandomNumberGenerator.new()
var enabled := true

var think_cd := 0.4
var hover_index := -1
var pending_kind := ""
var pending_pos := Vector2.ZERO
var armed := false
var arm_t := 0.0

var plays := 0
var gold_spent := 0.0
var last_scores: Array = []


func setup(a, p: int, seed_value: int) -> void:
	arena = a
	player = p
	rng.seed = seed_value
	think_cd = 0.3 + rng.randf() * 0.35


func _physics_process(delta: float) -> void:
	if arena == null or not enabled or arena.match_over:
		return
	if armed:
		arm_t -= delta
		if arm_t <= 0.0:
			_commit()
		return
	think_cd -= delta
	if think_cd > 0.0:
		return
	think_cd = DECISION_INTERVAL + rng.randf() * 0.25
	# hero ability: fire it when it will not starve the card economy
	if float(arena.gold[player]) >= 5.0 and arena.ability_valid(player):
		arena.use_ability(player)
		return
	_decide()


func _decide() -> void:
	var hand: Array = arena.hands[player]
	if hand.is_empty():
		return
	var scored: Array = []
	for i in hand.size():
		var kind := String(hand[i])
		if float(arena.gold[player]) < float(DDCard.cost(kind)):
			continue
		for pos in _anchors(kind):
			if not arena.can_deploy(player, kind, pos):
				continue
			var s := _score(kind, pos)
			scored.append({"score": s, "kind": kind, "pos": pos, "index": i})
	last_scores = scored
	if scored.is_empty():
		return
	scored.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))
	if float(scored[0]["score"]) < MIN_SCORE:
		return  # nothing worth spending gold on right now
	var k := mini(3, scored.size())
	var weights: Array = []
	var total := 0.0
	for j in k:
		var w: float = exp(float(scored[j]["score"]) / 1.6)
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	var chosen: Dictionary = scored[0]
	for j in k:
		roll -= float(weights[j])
		if roll <= 0.0:
			chosen = scored[j]
			break
	pending_kind = String(chosen["kind"])
	pending_pos = chosen["pos"]
	hover_index = int(chosen["index"])
	armed = true
	arm_t = TELEGRAPH_TIME + rng.randf() * 0.2


func _commit() -> void:
	armed = false
	var idx: int = arena.hands[player].find(pending_kind)
	var ok := false
	if idx >= 0:
		if arena.can_deploy(player, pending_kind, pending_pos):
			if float(arena.gold[player]) >= float(DDCard.cost(pending_kind)):
				var before: float = float(arena.gold[player])
				arena.deploy(player, idx, pending_pos)
				gold_spent += before - float(arena.gold[player])
				plays += 1
				ok = true
	hover_index = -1
	if not ok and int(arena.hands[player].size()) > 0:
		think_cd = maxf(think_cd, 0.2)


# --------------------------------------------------------------- candidates

func _anchors(kind: String) -> Array:
	var out: Array = []
	var spell := DDCard.is_spell(kind)
	var hold := 1.1 if spell else 1.4
	for e in arena.enemy_entities(player):
		if not is_instance_valid(e) or e.dead:
			continue
		out.append(_jitter(e.position, hold))
		if not spell:
			out.append(_jitter(e.position, hold + 1.3))
		if out.size() >= 12:
			break
	if not spell:
		for tw in arena.towers:
			if not is_instance_valid(tw) or tw.dead or int(tw.team) == player:
				continue
			out.append(_jitter(tw.position, 2.4))
		# lane openings on our own side so the bot can start a push
		var lane_row := 20.0 if player == 0 else 9.0
		out.append(_jitter(arena.tile_center(5.0, lane_row), 1.6))
		out.append(_jitter(arena.tile_center(13.0, lane_row), 1.6))
		out.append(_jitter(arena.tile_center(9.5, 24.5 if player == 0 else 5.5), 2.2))
	return out


func _jitter(pos: Vector2, radius_tiles: float) -> Vector2:
	var r: float = radius_tiles * float(arena.TILE)
	var a := rng.randf() * TAU
	var d := sqrt(rng.randf()) * r
	return pos + Vector2(cos(a), sin(a)) * d


# ------------------------------------------------------------------ scoring

func _score(kind: String, pos: Vector2) -> float:
	var data: Dictionary = DDCard.get_card(kind)
	var cost := float(data["cost"])
	var pressure := clampf((float(arena.gold[player]) - 4.0) / 6.0, 0.0, 1.0)
	var s := pressure * 2.3
	if DDCard.is_spell(kind):
		var radius := float(data["splash"])
		var dmg := float(data["dmg"])
		for e in arena.enemy_entities(player):
			if not is_instance_valid(e) or e.dead:
				continue
			var d: float = arena.tiles_between(pos, e.position)
			if d > radius + 0.7:
				continue
			var hp := float(e.get("hp"))
			var fraction := clampf(dmg / maxf(hp, 1.0), 0.0, 1.0)
			var worth := 5.5 if e.is_tower() else (2.5 + _threat_of(e))
			s += fraction * worth
	else:
		for e in arena.enemy_units(player):
			if not is_instance_valid(e) or e.dead:
				continue
			var d2: float = arena.tiles_between(pos, e.position)
			if d2 > 4.0:
				continue
			s += _threat_of(e) * clampf(1.0 - d2 / 4.0, 0.0, 1.0) * 1.5
		var tw: Node = arena.nearest_enemy_tower(player, pos)
		if tw != null:
			var dt: float = arena.tiles_between(pos, tw.position)
			var push := clampf(1.0 - dt / 13.0, 0.0, 1.0)
			s += push * push * 4.5
	var t: Vector2i = arena.tile_of(pos)
	if arena.row_is_band(t.y) and arena.tile_claim(player, t) <= 0.0 and not arena.tile_contested(t):
		s += 1.3
	if data.has("swarm_offsets"):
		s *= 1.55
	s -= cost * 0.5 * (1.0 - 0.65 * pressure)
	return s


func _threat_of(e: Node) -> float:
	var dmg: float = float(e.get("dmg"))
	var interval: float = float(e.get("interval"))
	if interval <= 0.01:
		interval = 1.0
	var dps := dmg / interval
	var hp: float = float(e.get("hp"))
	var t := dps * 0.22 + hp / 130.0
	if e.is_building():
		t *= 0.65
	return clampf(t, 0.0, 6.0)
