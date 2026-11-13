class_name DDUnit
extends Node2D

## Troop primitive: a small state machine plus the shared combat systems.
##
##   states    IDLE / APPROACH / ATTACK / STUNNED / SLIDING
##   impulse   apply_impulse(dir, tiles, seconds) slides the unit and cancels its swing
##   cooldown  interval + cooldown_per_tile * distance (per card)
##   roll      per-card charge: walk uninterrupted, gain levels, spend on the next hit
##   projectile lifecycle hooks live in DDProjectile; units expose catch_projectile()

enum S { IDLE, APPROACH, ATTACK, STUNNED, SLIDING }

const DEPLOY_DELAY := 0.5
const FALL_TIME := 0.26
const SQUASH_TIME := 0.16
const ATTACK_STRETCH := 0.14

var kind: String = "slate"
var team: int = 0
var arena: Node2D = null

var max_hp := 1.0
var hp := 1.0
var radius_t := 0.5
var speed := 1.0
var reach := 0.35
var interval := 1.0
var dmg := 0.0
var splash := 0.0
var aggro := 5.0
var stationary := false
var lifetime := 0.0
var buildings_only := false
var cooldown_per_tile := 0.0
var hits_air := false
var bird_lead := false

var age := 0.0
var atk_cd := 0.0
var target: Node = null
var facing := 1.0
var flash := 0.0
var clock := 0.0
var dead := false
var phase2 := false
var last_from := Vector2.INF
var last_attacker: Node = null
var incoming := 0.0

var state: int = S.IDLE
var ground_speed := 0.0
var ground_reach := 0.0

var flying := false
var stunned := 0.0

var knock_vel := Vector2.ZERO
var knock_time := 0.0

var curl_cfg: Dictionary = {}
var curled := false
var boom_cfg: Dictionary = {}
var throw_cd := 0.0
var throw_dist := 0.0
var combo_hits := 0

var roll_cfg: Dictionary = {}
var roll_level := 0
var roll_timer := 0.0
var trail_t := 0.0
var moved_this_frame := false
var has_projectile := false
var deploy_timer := 0.0
var hurt_frames := 0
var attack_stretch := 0.0
var attack_dir := Vector2.RIGHT


func setup(k: String, tm: int, ar: Node2D) -> void:
	kind = k
	team = tm
	arena = ar
	var d: Dictionary = DDCard.get_card(k)
	max_hp = float(d["hp"])
	hp = max_hp
	radius_t = float(d["radius"])
	speed = float(d["speed"])
	reach = float(d["reach"])
	interval = float(d["interval"])
	dmg = float(d["dmg"])
	splash = float(d["splash"])
	aggro = float(d["aggro"])
	stationary = bool(d["stationary"])
	lifetime = float(d["lifetime"])
	buildings_only = bool(d.get("buildings_only", false))
	cooldown_per_tile = float(d.get("cooldown_per_tile", 0.0))
	hits_air = bool(d.get("hits_air", false))
	if bool(d.get("flying_unit", false)):
		flying = true
	roll_cfg = d.get("roll", {})
	boom_cfg = d.get("boomerang", {})
	curl_cfg = d.get("curl", {})
	ground_speed = speed
	ground_reach = reach
	deploy_timer = DEPLOY_DELAY
	state = S.IDLE if stationary else S.APPROACH
	z_index = 5


func is_building() -> bool:
	return stationary


func is_tower() -> bool:
	return false


func is_airborne() -> bool:
	return flying


func is_alive_unit() -> bool:
	return not dead and hp > 0.0


func get_radius_t() -> float:
	return radius_t


# ------------------------------------------------------------------- primitives

func apply_impulse(dir: Vector2, tiles: float, duration: float) -> void:
	if dead or duration <= 0.0:
		return
	knock_vel = dir.normalized() * (tiles * arena.TILE / duration)
	knock_time = duration
	state = S.SLIDING
	stunned = 0.0
	atk_cd = maxf(atk_cd, duration)
	if not roll_cfg.is_empty():
		roll_level = 0
		roll_timer = 0.0
		speed = ground_speed


func catch_projectile() -> void:
	has_projectile = false
	atk_cd = 0.0
	if not boom_cfg.is_empty():
		throw_cd = cooldown_per_tile * throw_dist


func _physics_process(delta: float) -> void:
	if dead:
		return
	moved_this_frame = false
	clock += delta
	age += delta
	if hurt_frames > 0:
		hurt_frames -= 1
	if attack_stretch > 0.0:
		attack_stretch = maxf(0.0, attack_stretch - delta)
	flash = maxf(0.0, flash - delta * 5.0)
	if lifetime > 0.0 and age >= lifetime:
		_die()
		return
	if arena.match_over:
		queue_redraw()
		return
	if deploy_timer > 0.0:
		deploy_timer = maxf(0.0, deploy_timer - delta)
		queue_redraw()
		return

	if stunned > 0.0:
		stunned = maxf(0.0, stunned - delta)
		# a stunned unit can still be carried by an impulse (boulder knockback)
		if knock_time > 0.0:
			knock_time = maxf(0.0, knock_time - delta)
			position += knock_vel * delta
			if knock_time <= 0.0:
				knock_vel = Vector2.ZERO
		if stunned <= 0.0:
			if kind == "dragon" and hp <= max_hp * 0.5 and hp > 0.0:
				_take_off()
			state = S.IDLE if stationary else S.APPROACH
		queue_redraw()
		return

	if knock_time > 0.0:
		knock_time = maxf(0.0, knock_time - delta)
		position += knock_vel * delta
		if knock_time <= 0.0:
			knock_vel = Vector2.ZERO
			state = S.IDLE if stationary else S.APPROACH
		queue_redraw()
		return

	atk_cd = maxf(0.0, atk_cd - delta)
	throw_cd = maxf(0.0, throw_cd - delta)

	# curled hedgehog: hold position while anything is inside thorn range
	if not curl_cfg.is_empty() and curled:
		if _enemy_within(float(curl_cfg["thorn_range"])) == null:
			curled = false
		else:
			state = S.IDLE
			queue_redraw()
			return

	if kind == "dragon" and not flying and hp <= max_hp * 0.5 and hp > 0.0:
		_take_off()

	if phase2:
		var tw: Node = arena.nearest_enemy_tower(team, position)
		if tw != null:
			target = tw

	if target == null or not _target_valid(target):
		target = _acquire()
	elif atk_cd <= 0.0:
		var cand: Node = _acquire()
		if cand != null and cand.get_instance_id() != target.get_instance_id():
			var d_new: float = arena.tiles_between(position, cand.position)
			var d_old: float = arena.tiles_between(position, target.position)
			if d_new < d_old - 0.3:
				target = cand

	if target == null:
		state = S.IDLE if stationary else S.APPROACH
		queue_redraw()
		return

	var gap: float = arena.gap_between(position, target.position, radius_t, float(target.get_radius_t()))
	if phase2:
		if gap <= 0.35:
			_explode()
			return
		_move(delta)
		queue_redraw()
		return
	if stationary:
		state = S.IDLE
		queue_redraw()
		return
	if not curl_cfg.is_empty() and not curled and gap <= float(curl_cfg["range"]):
		_curl()
		queue_redraw()
		return
	if gap <= reach:
		state = S.ATTACK
		_attack()
	elif not boom_cfg.is_empty() and has_projectile:
		state = S.IDLE
	else:
		state = S.APPROACH
		_move(delta)
		_tick_roll(delta)
	queue_redraw()


func _move(delta: float) -> void:
	var goal: Vector2 = target.position
	var wp := goal
	if not flying:
		wp = arena.route_point(position, goal)
	var dir := wp - position
	if dir.length() < 1.0:
		dir = goal - position
	if dir.length() < 0.001:
		return
	dir = dir.normalized()
	if absf(dir.x) > 0.05:
		facing = signf(dir.x)
	position += dir * speed * arena.TILE * delta
	moved_this_frame = true


func _tick_roll(delta: float) -> void:
	if roll_cfg.is_empty():
		return
	if not moved_this_frame:
		roll_timer = 0.0
		return
	roll_timer += delta
	var max_level := int(roll_cfg["max_level"])
	if roll_level < max_level and roll_timer >= float(roll_cfg["interval"]):
		roll_timer = 0.0
		roll_level += 1
		speed = ground_speed * pow(float(roll_cfg["speed_mult"]), float(roll_level))
	if roll_level >= max_level:
		trail_t -= delta
		if trail_t <= 0.0:
			trail_t = 0.11
			arena.spawn_trail(position, facing, team)


func _attack() -> void:
	if atk_cd > 0.0 or dmg <= 0.0:
		return
	if not boom_cfg.is_empty():
		_attack_fu()
		return
	var dist: float = arena.tiles_between(position, target.position)
	atk_cd = interval + cooldown_per_tile * dist
	if absf(target.position.x - position.x) > 1.0:
		facing = signf(target.position.x - position.x)
	var hit_dmg := dmg
	if not roll_cfg.is_empty() and roll_level > 0:
		hit_dmg = dmg * (1.0 + float(roll_cfg["damage_bonus"]) * float(roll_level))
		roll_level = 0
		roll_timer = 0.0
		speed = ground_speed
	if kind == "dragon" and flying:
		arena.dragon_breath(target.position, 1.8, hit_dmg, team)
		return
	_mark_attack()
	if splash > 0.0:
		arena.reserve_damage(get_instance_id(), target, hit_dmg)
		arena.spawn_projectile(position, target.position, team, hit_dmg, splash, kind, get_instance_id())
	else:
		if target.has_method("take_damage"):
			arena.reserve_damage(get_instance_id(), target, hit_dmg)
			target.take_damage(hit_dmg, position, self)
			arena.release_reservation(get_instance_id())


func _attack_fu() -> void:
	var gap: float = arena.gap_between(position, target.position, radius_t, float(target.get_radius_t()))
	var dist: float = arena.tiles_between(position, target.position)
	if absf(target.position.x - position.x) > 0.6:
		facing = signf(target.position.x - position.x)
	if gap <= float(boom_cfg["melee_range"]):
		# melee combo: quick jabs ending in a kick that re-opens throwing range
		_mark_attack()
		atk_cd = float(boom_cfg["melee_interval"])
		if target.has_method("take_damage"):
			target.take_damage(float(boom_cfg["melee_dmg"]), position)
		combo_hits += 1
		if combo_hits >= int(boom_cfg["combo_hits"]):
			combo_hits = 0
			_kick()
		return
	if has_projectile or throw_cd > 0.0:
		return
	has_projectile = true
	throw_dist = dist
	_mark_attack()
	atk_cd = 999.0
	var speed_px: float = float(boom_cfg["throw_speed_tiles"]) * arena.TILE
	arena.spawn_projectile(position, target.position, team, dmg, 0.0, "boomerang",
		get_instance_id(), "return", true, self, speed_px)


func _enemy_within(range_t: float) -> Node:
	var best: Node = null
	var best_d := INF
	for e in arena.enemy_entities(team):
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = arena.tiles_between(position, e.position)
		if d <= range_t + float(e.get_radius_t()) and d < best_d:
			best = e
			best_d = d
	return best


func _curl() -> void:
	curled = true
	state = S.IDLE
	target = null
	atk_cd = 0.0
	var burst := float(curl_cfg["burst_dmg"])
	var push := float(curl_cfg["push"])
	var tr := float(curl_cfg["thorn_range"])
	for e in arena.enemy_entities(team).duplicate():
		if not is_instance_valid(e) or e.dead:
			continue
		if arena.tiles_between(position, e.position) > tr + float(e.get_radius_t()):
			continue
		if e.has_method("take_damage"):
			e.take_damage(burst, position, self)
		if e.has_method("apply_impulse"):
			var d: Vector2 = e.position - position
			if d.length() < 0.01:
				d = Vector2(facing, 1.0)
			e.apply_impulse(d.normalized(), push, float(curl_cfg["push_time"]))


func _mark_attack() -> void:
	if target == null or not is_instance_valid(target):
		return
	attack_dir = (target.position - position)
	if attack_dir.length() > 0.01:
		attack_dir = attack_dir.normalized()
	else:
		attack_dir = Vector2.RIGHT
	attack_stretch = ATTACK_STRETCH


func _kick() -> void:
	if target == null or not is_instance_valid(target):
		return
	var dir: Vector2 = target.position - position
	if dir.length() < 0.01:
		dir = Vector2(facing, 0.0)
	dir = dir.normalized()
	if target.has_method("take_damage"):
		target.take_damage(float(boom_cfg["kick_dmg"]), position)
	if target.has_method("apply_impulse"):
		target.apply_impulse(dir, float(boom_cfg["kick_push"]), 0.25)
	apply_impulse(-dir, float(boom_cfg["self_push"]), 0.28)


func _take_off() -> void:
	flying = true
	speed = ground_speed * 1.9
	reach = 2.6
	target = null
	atk_cd = 0.6
	arena.banner_flash("The chains break — the dragon takes to the skies!")


func _target_valid(t: Node) -> bool:
	if t == null or not is_instance_valid(t):
		return false
	if t.get("dead") == true:
		return false
	if int(t.get("team")) == team:
		return false
	if t.get("flying") == true and not hits_air:
		return false
	return true


func _acquire() -> Node:
	var best: Node = null
	var best_d := INF
	for e in arena.enemy_entities(team):
		if not is_instance_valid(e) or e.dead:
			continue
		if e.get("flying") == true and not hits_air:
			continue
		if arena.is_doomed(e):
			continue
		if buildings_only and not e.is_building():
			continue
		if kind == "dragon" and flying and not e.is_building():
			continue
		var d: float = arena.tiles_between(position, e.position)
		if not e.is_tower():
			var limit: float = aggro
			if e.is_building():
				limit = maxf(aggro, 7.5)
			if d > limit:
				continue
		if d < best_d - 0.0001:
			best = e
			best_d = d
		elif absf(d - best_d) <= 0.0001 and best != null and e.get_instance_id() < best.get_instance_id():
			best = e
	return best


func take_damage(amount: float, from: Vector2, attacker: Node = null) -> void:
	if dead or amount <= 0.0:
		return
	var taken := amount
	if curled and not curl_cfg.is_empty():
		taken *= float(curl_cfg["damage_mult"])
	last_from = from
	if attacker != null:
		last_attacker = attacker
	hp -= taken
	flash = 0.5
	hurt_frames = 2
	# quills: fixed damage back at anything hitting us from within thorn range
	if curled and not curl_cfg.is_empty() and arena.damage_guard == 0:
		var src_node: Node = attacker
		var src_pos := from
		if src_node != null and is_instance_valid(src_node):
			src_pos = src_node.position
		if arena.tiles_between(position, src_pos) <= float(curl_cfg["thorn_range"]):
			if src_node != null and is_instance_valid(src_node) and src_node.has_method("take_damage"):
				arena.damage_guard += 1
				src_node.take_damage(float(curl_cfg["thorn_dmg"]), position, self)
				arena.damage_guard = maxi(0, arena.damage_guard - 1)
	if kind == "alchemist" and not phase2 and hp > 0.0 and hp <= max_hp * 0.5:
		_enter_phase2()
	if hp <= 0.0:
		_die()


func hit_by_hero(amount: float, stun_seconds: float) -> void:
	if dead:
		return
	hp -= amount
	flash = 0.8
	hurt_frames = 6
	if kind == "dragon":
		flying = false
		speed = ground_speed
		reach = ground_reach
		stunned = stun_seconds
		target = null
		state = S.STUNNED
		atk_cd = 1.0
	if hp <= 0.0:
		_die()


func _enter_phase2() -> void:
	phase2 = true
	team = 1 - team
	speed *= 2.4
	aggro = 99.0
	atk_cd = 0.0
	target = null
	arena.banner_flash("%s turns on its caster!" % DDCard.pretty("alchemist"))


func _explode() -> void:
	arena.spawn_splash_burst(position, 2.0, 100.0, team, Color(0.55, 0.95, 0.4))
	_die()


func _die() -> void:
	if dead:
		return
	dead = true
	# zombies raise whatever they kill, on their own side
	if kind != "zombie" and last_attacker != null and is_instance_valid(last_attacker):
		if String(last_attacker.get("kind")) == "zombie":
			var risen = arena.spawn_troop("zombie", int(last_attacker.team), position, true)
			if risen != null and is_instance_valid(risen):
				risen.deploy_timer = 0.0
			arena.banner_flash("Another one rises...")
	if kind == "idol":
		var dir := Vector2(0, -1)
		if last_from != Vector2.INF:
			dir = (last_from - position)
			if dir.length() < 0.01:
				dir = Vector2(0, -1)
			dir = dir.normalized()
		arena.spawn_boulder(position, dir, team)
	arena.unregister(self)
	queue_free()


func _draw() -> void:
	var px: float = radius_t * arena.TILE
	var lift := 0.0
	if flying:
		lift = 18.0 + sin(clock * 2.2) * 3.0
		draw_set_transform(Vector2(0, px * 0.55), 0.0, Vector2(1.0, 0.42))
		draw_circle(Vector2.ZERO, px * 0.95, Color(0.05, 0.06, 0.1, 0.32))
	# squash & stretch: drop-in, landing squash, attack lunge
	var sx := 1.0
	var sy := 1.0
	var drop := 0.0
	if deploy_timer > 0.0:
		var e := DEPLOY_DELAY - deploy_timer
		if e < FALL_TIME:
			var ff := e / FALL_TIME
			sy = lerpf(2.6, 1.0, ff)
			sx = lerpf(0.32, 1.0, ff)
			drop = -92.0 * (1.0 - ff * ff)
		else:
			var f2 := clampf((e - FALL_TIME) / SQUASH_TIME, 0.0, 1.0)
			var b := sin(f2 * PI) * 0.32
			sy = 1.0 - b
			sx = 1.0 + b * 0.7
	elif attack_stretch > 0.0:
		var a := attack_stretch / ATTACK_STRETCH
		if absf(attack_dir.x) >= absf(attack_dir.y):
			sx = 1.0 + 0.2 * a
			sy = 1.0 - 0.1 * a
		else:
			sy = 1.0 + 0.2 * a
			sx = 1.0 - 0.1 * a
	draw_set_transform(Vector2(0, -lift + drop), 0.0, Vector2(sx, sy))
	if kind == "hedgehog":
		DDArt.hedgehog(self, px, facing, clock, curled)
	elif kind == "hawk":
		DDArt.bird(self, px, facing, clock, bird_lead)
	elif kind == "dragon":
		DDArt.dragon(self, px, facing, clock, flying, 0.0)
	else:
		DDArt.creature(self, kind, px, facing, clock, 0.0, phase2)
	if hurt_frames > 0:
		draw_circle(Vector2.ZERO, px * 1.0, Color(1.0, 0.55, 0.72, 0.62))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not roll_cfg.is_empty() and roll_level > 0:
		var lines := roll_level + 1
		for i in lines:
			var y := -px * 0.55 + float(i) * px * 0.55
			var length := px * (1.2 + 0.45 * float(i))
			var col := Color(1, 1, 1, 0.45) if roll_level == 1 else Color(1, 0.85, 0.55, 0.6)
			draw_line(Vector2(-facing * px * 0.9, y), Vector2(-facing * (px * 0.9 + length), y), col, 2.0, true)
		if roll_level >= 2:
			draw_arc(Vector2.ZERO, px * 1.25, 0.0, TAU, 24, Color(1.0, 0.8, 0.45, 0.35), 2.0, true)
	if stunned > 0.0:
		for i in 3:
			var a := clock * 4.0 + float(i) * TAU / 3.0
			draw_circle(Vector2(cos(a), sin(a)) * px * 0.9 + Vector2(0, -px - 16.0 - lift), 3.0, Color(1.0, 0.9, 0.35))
	if hp < max_hp:
		var w: float = px * 2.2
		var y2: float = -px - 10.0 - lift
		draw_rect(Rect2(-w * 0.5, y2, w, 5.0), Color(0.08, 0.07, 0.1, 0.85), true)
		var frac := clampf(hp / max_hp, 0.0, 1.0)
		var col2 := Color(0.45, 0.9, 0.55) if team == 0 else Color(0.95, 0.45, 0.45)
		draw_rect(Rect2(-w * 0.5 + 1.0, y2 + 1.0, (w - 2.0) * frac, 3.0), col2, true)
