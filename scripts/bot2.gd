class_name DDBot2
extends DDBot

## Bot v2 — perception, then a state, then a scored play.
##
## v1 scored every (card x jittered anchor) pair with one flat formula, so a card
## heading for an enemy tower and a card answering an attacker on its own tower
## competed on the same number. This one reads the board first:
##
##   DEFEND   something is closing on a tower of mine: spend on the answer to it
##   COUNTER  my troops are alive on their half: support the survivors
##   ATTACK   nothing threatening and gold in hand: stage a push on the weakest
##            enemy tower
##   HOLD     nothing worth the gold — wait instead of feeding
##
## What "the answer" is comes from DDBotMatrix: roles derived from card data and a
## small answers table, never hand-written per-card matchups (the decks shuffle).

enum St { HOLD, DEFEND, COUNTER, ATTACK }

const DEFEND_AT := 1.5      ## threat pressure that makes defence take priority
const PUSH_AT := 2.5        ## worth of my own troops on their half for COUNTER
const ATTACK_GOLD := 6.0
const DEFEND_RADIUS := 3.4  ## how far from the danger a defensive play may land
const TOWER_FIRE := 6.0     ## an enemy tower's reach

var state := St.HOLD
var threats: Array = []
var pressure := 0.0
var danger_at := Vector2.INF
var push_at := Vector2.INF
var push_value := 0.0
var target_tower: Node = null


func _decide() -> void:
	var hand: Array = arena.hands[player]
	if hand.is_empty():
		return
	_perceive()
	_choose_state()
	var scored: Array = []
	for i in hand.size():
		var kind := String(hand[i])
		if float(arena.gold[player]) < float(DDCard.cost(kind)):
			continue
		if arena.card_locked(player, i):
			continue
		# Dominion cards have no target: DDBot._play_dominion casts them
		if DDCard.get_card(kind).has("dominion"):
			continue
		for pos in _anchors(kind):
			if not arena.can_deploy(player, kind, pos):
				continue
			var s := _score(kind, pos)
			if s <= 0.0:
				continue
			scored.append({"score": s, "kind": kind, "pos": pos, "index": i})
	last_scores = scored
	if scored.is_empty():
		return
	scored.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))
	if float(scored[0]["score"]) < MIN_SCORE:
		return
	# defending, take the best answer straight away: a tower is at stake
	var k := 1 if state == St.DEFEND else mini(3, scored.size())
	var chosen: Dictionary = scored[0]
	if k > 1:
		var weights: Array = []
		var total := 0.0
		for j in k:
			var w: float = exp(float(scored[j]["score"]) / 1.6)
			weights.append(w)
			total += w
		var roll := rng.randf() * total
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


# ------------------------------------------------------------------ perception

func _perceive() -> void:
	threats.clear()
	pressure = 0.0
	danger_at = Vector2.INF
	push_at = Vector2.INF
	push_value = 0.0
	var mines := _my_towers()
	var worst := 0.0
	for e in arena.enemy_units(player):
		if not is_instance_valid(e) or e.dead:
			continue
		var w := _threat_value(e)
		threats.append({
			"node": e, "pos": e.position, "w": w,
			"roles": DDBotMatrix.roles_of(String(e.get("kind"))),
			"flying": bool(e.get("flying")),
		})
		# how badly this one threatens me: its weight, discounted by how far it is
		# from the nearest tower of mine, and always real once it is on my half
		var term := 0.0
		for tw in mines:
			var d: float = arena.tiles_between(e.position, tw.position)
			term = maxf(term, w * clampf(1.0 - d / 12.0, 0.0, 1.0))
		if _on_my_half(e.position):
			term = maxf(term, w * 0.9)
		pressure += term
		if term > worst:
			worst = term
			danger_at = e.position
	# my own attack: what of mine is alive on their half, and how close to a tower
	var closest := -1.0
	for u in arena.units:
		if not is_instance_valid(u) or bool(u.get("dead")) or int(u.team) != player:
			continue
		if _on_my_half(u.position):
			continue
		push_value += _threat_value(u)
		var tw: Node = arena.nearest_enemy_tower(player, u.position)
		if tw != null:
			var d2: float = arena.tiles_between(u.position, tw.position)
			if closest < 0.0 or d2 < closest:
				closest = d2
				push_at = u.position
	target_tower = _weakest_enemy_tower()


func _choose_state() -> void:
	if pressure >= DEFEND_AT:
		state = St.DEFEND
	elif push_value >= PUSH_AT:
		state = St.COUNTER
	elif float(arena.gold[player]) >= ATTACK_GOLD:
		state = St.ATTACK
	else:
		state = St.HOLD


func _my_towers() -> Array:
	var out: Array = []
	for tw in arena.towers:
		if is_instance_valid(tw) and not tw.dead and int(tw.team) == player:
			out.append(tw)
	return out


## The tower worth attacking: weakest non-crown first, crown only once a side is down.
func _weakest_enemy_tower() -> Node:
	var best: Node = null
	var best_hp := 1.0e9
	for tw in arena.towers:
		if not is_instance_valid(tw) or tw.dead or int(tw.team) == player:
			continue
		if bool(tw.get("crown")):
			continue
		if float(tw.hp) < best_hp:
			best_hp = float(tw.hp)
			best = tw
	if best == null:
		for tw in arena.towers:
			if is_instance_valid(tw) and not tw.dead and int(tw.team) != player:
				best = tw
				break
	return best


func _on_my_half(pos: Vector2) -> bool:
	var row: int = arena.tile_of(pos).y
	if player == 0:
		return row >= arena.BAND_BOTTOM - 1
	return row <= arena.BAND_TOP + 1


func _threat_value(e: Node) -> float:
	var t: float = _threat_of(e)
	if bool(e.get("flying")):
		t *= 1.25          # ground troops may not be able to touch it
	var sp = e.get("splash")
	if sp != null and float(sp) > 0.0:
		t *= 1.15
	if e.is_tower():
		t *= 1.4
	return t


# -------------------------------------------------------------------- anchors

func _anchors(kind: String) -> Array:
	var out: Array = []
	var spell := DDCard.is_spell(kind)
	var intent: Array = []
	match state:
		St.DEFEND:
			if danger_at != Vector2.INF:
				intent.append(danger_at)                      # spells: the cluster
				if not spell:
					intent.append(_toward_home(danger_at, 2.0))   # bodies: behind it
					intent.append(danger_at)
		St.COUNTER:
			if push_at != Vector2.INF:
				intent.append(_toward_home(push_at, 2.6))       # support from behind
				intent.append(push_at)
		St.ATTACK:
			var lane: float = 9.5
			if target_tower != null:
				lane = float(arena.tile_of(target_tower.position).x)
			var back_row := 22.5 if player == 0 else 7.5
			intent.append(arena.tile_center(lane, back_row))
			intent.append(arena.tile_center(lane + 1.5, back_row + (1.2 if player == 0 else -1.2)))
		_:
			return out
	for p in intent:
		var at: Vector2 = p
		if spell:
			out.append(_jitter(at, 1.0))
			continue
		var legal := _legal_near(kind, at)
		if legal != Vector2.INF:
			out.append(legal)
	return out


func _toward_home(at: Vector2, tiles: float) -> Vector2:
	var dir := Vector2(0.0, 1.0) if player == 0 else Vector2(0.0, -1.0)
	return at + dir * (tiles * float(arena.TILE))


## Nearest deployable spot to what we wanted, so an illegal intent still plays.
func _legal_near(kind: String, at: Vector2, tries: int = 12) -> Vector2:
	if arena.can_deploy(player, kind, at):
		return at
	for i in tries:
		var p := _jitter(at, 1.2 + 0.8 * float(i))
		if arena.can_deploy(player, kind, p):
			return p
	return Vector2.INF


# -------------------------------------------------------------------- scoring

func _score(kind: String, pos: Vector2) -> float:
	var data: Dictionary = DDCard.get_card(kind)
	var cost := float(data["cost"])
	var pressed := state == St.DEFEND
	if DDCard.is_spell(kind):
		return _score_spell(kind, pos, data)
	var s := 0.0
	for t in threats:
		var d: float = arena.tiles_between(pos, t["pos"])
		if d > 4.5:
			continue
		if bool(t["flying"]) and not DDBotMatrix.can_hit_air(kind):
			continue
		var fit: float = clampf(1.0 - d / 4.5, 0.0, 1.0)
		var edge: float = DDBotMatrix.answer(kind, t["roles"])
		s += float(t["w"]) * (0.3 + edge) * (0.4 + fit) * 1.5
	if pressed:
		# a defensive play that lands away from the danger is a donation
		var near := 1.0e9
		for t in threats:
			near = minf(near, arena.tiles_between(pos, t["pos"]))
		if near > DEFEND_RADIUS:
			return 0.0
	if state == St.ATTACK or state == St.COUNTER:
		var tw: Node = target_tower if target_tower != null else arena.nearest_enemy_tower(player, pos)
		if tw != null:
			var dt: float = arena.tiles_between(pos, tw.position)
			s += clampf(1.0 - dt / 14.0, 0.0, 1.0) * 2.4
		# NOTE: an extra "tempo" bonus for spending on a quiet board was tried and
		# measured — it made v2 push into nothing and drop from +360 to −96 HP
		# average, so the push term above is deliberately the only one.
	# do not walk something squishy into tower fire for nothing
	if not pressed and not DDCard.is_spell(kind):
		var tank: bool = (DDBotMatrix.roles_of(kind) as Array).has("tank")
		if not tank:
			for tw in arena.towers:
				if is_instance_valid(tw) and not tw.dead and int(tw.team) != player:
					if arena.tiles_between(pos, tw.position) < TOWER_FIRE:
						s *= 0.55
						break
	s -= cost * (0.35 if pressed else 0.6)
	return s


func _score_spell(kind: String, pos: Vector2, data: Dictionary) -> float:
	var radius := float(data.get("splash", 0.0))
	var dmg := float(data["dmg"])
	var cost := float(data["cost"])
	var s := 0.0
	for t in threats:
		var e: Node = t["node"]
		var span: float = maxf(radius + float(e.get_radius_t()), 0.9)
		if radius <= 0.0:
			span = maxf(float(e.get_radius_t()) + 0.4, 0.8)
		if arena.tiles_between(pos, t["pos"]) > span:
			continue
		var frac := clampf(dmg / maxf(float(e.get("hp")), 1.0), 0.0, 1.0)
		s += frac * (1.6 + float(t["w"]) * 1.7) * (1.0 + DDBotMatrix.answer(kind, t["roles"]) * 0.25)
	if s <= 0.0:
		return 0.0
	return s - cost * 0.6
