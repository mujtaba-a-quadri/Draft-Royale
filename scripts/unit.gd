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
## Obsidian Whelp: curls (shares `curled`) when an enemy unit is near or it is
## hit; guard_calm counts down from the last hit.
var guard_cfg: Dictionary = {}
var guard_calm := 0.0
## Wu Cheng'en: staff out 0..1 (drawn from behind his ear), which hit of the
## poke / sweep combo is next, banked rage hits, and the rage state.
var staff_cfg: Dictionary = {}
var staff_out := 0.0
var staff_combo := 0
var rage_hits := 0
var rage_t := 0.0
var rage_used := false
var rage_regen := 0.0
## picture of the last staff hit: 0 none, 1 poke, 2 sweep
const STAFF_SHOW := 0.24
var staff_anim := 0
var staff_anim_t := 0.0
var staff_dir := Vector2.RIGHT
var staff_from := 0.0
var staff_to := 0.0
## Nekomancer: a beam instead of a bolt, and a ritual clock that opens two
## pentagrams (scripts/pentagram.gd) every `every` seconds. cloak_t is the
## picture of the wind catching her cloak as they open.
const PENTAGRAM := preload("res://scripts/pentagram.gd")
const BEAM_SHOW := 0.22
const CLOAK_WIND := 1.0
var beam := false
var beam_t := 0.0
var beam_to := Vector2.ZERO
var ritual_cfg: Dictionary = {}
var ritual_cd := 0.0
var cloak_t := 0.0
## raised out of a pentagram: the deploy picture climbs out of the ground
## instead of dropping from the sky
var rises := false
## Gilgamesh: his plain hit is a snake lash; whip_t is its picture.
const WHIP_SHOW := 0.32
var whip := false
var whip_t := 0.0
var whip_to := Vector2.ZERO
## Enkidu: the spear is in hand (spear_away 0) or thrown, and until it comes
## back he fights with the short sword.
var spear_cfg: Dictionary = {}
var spear_away := 0.0
var base_dmg := 0.0
var base_interval := 0.0
## Poison dart frog: moves only in hops (frog_hop_t > 0 in the air, then
## frog_rest on the ground) and leaps on whatever comes within range, bursting
## on landing. The leap is committed once it starts.
var frog_cfg: Dictionary = {}
var frog_hop_t := 0.0
var frog_rest := 0.0
var frog_dir := Vector2.ZERO
var frog_leaping := false
var frog_leap_t := 0.0
var frog_from := Vector2.ZERO
var frog_to := Vector2.ZERO
var frog_victim: Node = null
## Hot Chicken: pecks fireballs, then takes to the air and rams.
var chicken_cfg: Dictionary = {}
var chicken_hits := 0
var chicken_target := 0
var airborne := false
var burn_per_hit := 0.0
## Second phase of a chicken: fly at the target and burst on contact.
var kamikaze_cfg: Dictionary = {}
## Primal Aphid: a cone of pellets instead of a single shot.
var spread_cfg: Dictionary = {}
var targets_weakest := false
var presence_shift := 0
var summon_cfg: Dictionary = {}
var shoots := ""
var shoot_payload: Dictionary = {}
## Some units only ever pick fights with troops (Penny ignores buildings/towers).
var troops_only := false
## The airborne dragon's fire: a patch under and just ahead of it, 25 damage a
## second, ticked four times a second so it reads as burn.
## What counts as a "melee" air attacker for the hedgehog's reaction: a flyer with
## a short reach, i.e. one that has to come to it.
const MELEE_AIR_REACH := 1.2
const DRAGON_FIRE_DPS := 25.0
const DRAGON_FIRE_RADIUS := 2.0
const DRAGON_FIRE_TICK := 0.25
const DRAGON_FIRE_AHEAD := 0.7
const DRAGON_FIRE_BELOW := 1.1
var fire_tick := 0.0
## Penny: three swipes, then an invincible fading step-back and a quarter circle.
var dodge_cfg: Dictionary = {}
var swipes := 0
var dodging := false
var dodge_t := 0.0
var dodge_sign := 1.0
var dodge_picked := false
var dodge_center := Vector2.ZERO
var dodge_radius := 0.0
var dodge_start_r := 0.0
var dodge_angle0 := 0.0
## the leap that ends the dodge: air first, then whatever is closest
var jumping := false
var jump_t := 0.0
var jump_from := Vector2.ZERO
var jump_to := Vector2.ZERO
var jump_victim: Node = null
var jump_dir := Vector2.RIGHT
## after the landing hit she rides the shove for a moment, so the push reads as
## coming from her jump rather than from the target sliding away on its own
## the grab: while carrying, the victim rides in front of her for the whole leap
var carrying := false
var carry_dir := Vector2.RIGHT
var carry_contact := 0.0
var invincible := false
## Laniakea: one greatsword, two swings. A ground target gets a wide cleave with
## a shove; a flyer in the leap window gets a jump and an overhead slam that
## carries on in a line behind it.
var sword_cfg: Dictionary = {}
var leaping := false
var leap_t := 0.0
var leap_from := Vector2.ZERO
var leap_to := Vector2.ZERO
var leap_dir := Vector2.RIGHT
var leap_victim: Node = null
## cosmetic timers for the two swings (the hits themselves land on one tick)
const SWING_SHOW := 0.22
const SLAM_SHOW := 0.28
var swing_t := 0.0
var swing_from := 0.0
var swing_to := 0.0
var slam_t := 0.0
var slam_len := 0.0
## Femme Fatale: a long needle. A far ground target gets a wind-up and a lunge
## that stops at needle range; up close it is a three hit combo (flick, stab,
## stab that recoils her).
var needle_cfg: Dictionary = {}
## 0 = not dashing, 1 = needle raised (wind-up), 2 = lunging
var dash_phase := 0
var dash_t := 0.0
var dash_dir := Vector2.RIGHT
var dash_victim: Node = null
var dash_left := 0.0
var needle_step := 0
var needle_target_id := 0
## cosmetic: the needle drawn in board space for a moment after each hit
const NEEDLE_SHOW := 0.2
var needle_t := 0.0
var needle_from := 0.0
var needle_to := 0.0
## Untargetable: the arena's enemy queries skip these (Penny mid-dodge).
var untargetable := false
var is_b := false
var occupied_tiles: Array = []
var footprint: Array = [1, 1]
var summon_cd := 0.0
enum Status { NONE, SLOW, BURN }
var status: int = Status.NONE
var slow_amount := 0.0
var slow_time := 0.0
const BURN_RATE := 0.4
var burn_stack := 0.0
var burn_ticks := 0
var burn_max_ticks := 4
var burn_timer := 0.0
var burn_pulse := 0.0
## Poison is not a status: it is a counter that only ever goes up and never wears
## off. Every POISON_PERIOD seconds it deals POISON_MULT x the counter.
const POISON_PERIOD := 5.0
const POISON_MULT := 2.0
## buildings and towers take half of every poison tick
const POISON_BUILDING := 0.5
var poison := 0.0
var poison_timer := 0.0
## poison this unit's own melee hit adds (the spiderling's bite)
var poison_hit := 0.0
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
	guard_cfg = d.get("guard", {})
	staff_cfg = d.get("staff", {})
	chicken_cfg = d.get("chicken", {})
	kamikaze_cfg = d.get("kamikaze", {})
	spread_cfg = d.get("spread", {})
	burn_per_hit = float(d.get("burn", 0.0))
	targets_weakest = bool(d.get("targets_weakest", false))
	presence_shift = int(d.get("presence_shift", 0))
	summon_cfg = d.get("summon", {})
	if not summon_cfg.is_empty() and summon_cfg.has("spot"):
		# a hatchery is on the clock, not on alert: the first unit comes "first"
		# seconds after it is played (one interval in if not given). The summon
		# clock only starts once the deploy drop is over, so that is taken off.
		summon_cd = float(summon_cfg.get("interval", 12.0))
		if summon_cfg.has("first"):
			summon_cd = maxf(0.0, float(summon_cfg["first"]) - DEPLOY_DELAY)
	whip = bool(d.get("whip", false))
	spear_cfg = d.get("spear", {})
	frog_cfg = d.get("frog", {})
	base_dmg = dmg
	base_interval = interval
	beam = bool(d.get("beam", false))
	ritual_cfg = d.get("ritual", {})
	if not ritual_cfg.is_empty():
		ritual_cd = float(ritual_cfg["every"])
	shoots = String(d.get("shoots", ""))
	shoot_payload = d.get("payload", {})
	troops_only = bool(d.get("troops_only", false))
	dodge_cfg = d.get("dodge", {})
	sword_cfg = d.get("greatsword", {})
	needle_cfg = d.get("needle", {})
	poison_hit = float(d.get("poison", 0.0))
	footprint = d.get("footprint", [1, 1])
	is_b = String(d.get("type", "troop")) == "building"
	ground_speed = speed
	ground_reach = reach
	deploy_timer = DEPLOY_DELAY
	state = S.IDLE if stationary else S.APPROACH
	z_index = 5


func is_building() -> bool:
	return is_b or stationary


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
	if is_b:
		return
	# buildings are planted: shoves do nothing to them
	if dead or duration <= 0.0 or is_b:
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


## Only one status can be active; the newest one replaces whatever was there.
func clear_status() -> void:
	status = Status.NONE
	slow_amount = 0.0
	slow_time = 0.0
	burn_stack = 0.0
	burn_ticks = 0
	burn_timer = 0.0


func slow(amount: float, seconds: float) -> void:
	if dead or amount <= 0.0:
		return
	if status != Status.SLOW:
		burn_stack = 0.0
		burn_ticks = 0
		burn_timer = 0.0
	status = Status.SLOW
	slow_amount = amount
	slow_time = maxf(slow_time, seconds)


## Burn: a stack that eats 30 % of itself per second. Four seconds without a
## fresh application and the whole thing goes out.
func apply_burn(amount: float, max_ticks: int = 4) -> void:
	if dead or amount <= 0.0:
		return
	if status != Status.BURN:
		slow_amount = 0.0
		slow_time = 0.0
		burn_timer = 1.0
	status = Status.BURN
	burn_stack += amount
	burn_ticks = 0
	burn_max_ticks = maxi(max_ticks, 1)


## Poison stacks without limit and is never cleared. The first dose starts the
## five second clock; later doses just raise what the next tick will cost.
func add_poison(amount: float) -> void:
	if dead or amount <= 0.0:
		return
	if poison <= 0.0:
		poison_timer = POISON_PERIOD
	poison += amount


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
	if poison > 0.0:
		poison_timer -= delta
		if poison_timer <= 0.0:
			poison_timer += POISON_PERIOD
			take_damage(poison * POISON_MULT * (POISON_BUILDING if is_building() else 1.0), position)
			if dead:
				return
	swing_t = maxf(0.0, swing_t - delta)
	slam_t = maxf(0.0, slam_t - delta)
	staff_anim_t = maxf(0.0, staff_anim_t - delta)
	beam_t = maxf(0.0, beam_t - delta)
	cloak_t = maxf(0.0, cloak_t - delta)
	whip_t = maxf(0.0, whip_t - delta)
	if spear_away > 0.0:
		# the spear comes back on the clock, whatever he is doing
		spear_away = maxf(0.0, spear_away - delta)
		if spear_away <= 0.0:
			_spear_back()
	if rage_t > 0.0:
		# the rage runs its clock and heals him through stuns and shoves alike
		rage_t = maxf(0.0, rage_t - delta)
		hp = minf(max_hp, hp + rage_regen * delta)
		if rage_t <= 0.0:
			speed = ground_speed
	needle_t = maxf(0.0, needle_t - delta)
	if dash_phase != 0:
		# a stun or a shove knocks her out of it; otherwise the dash runs to its end
		if stunned > 0.0 or knock_time > 0.0 or arena.match_over:
			dash_phase = 0
			dash_victim = null
		else:
			_tick_dash(delta)
			queue_redraw()
			return
	if leaping:
		# committed: once he is off the ground the slam is coming
		_tick_leap(delta)
		queue_redraw()
		return
	if frog_leaping:
		# the frog's leap is committed too: stuns and shoves wait for the landing
		_tick_frog_leap(delta)
		queue_redraw()
		return
	if dodging or jumping:
		if jumping:
			_tick_jump(delta)
		else:
			_tick_dodge(delta)
		queue_redraw()
		return
	if lifetime > 0.0:
		# Clash-Royale style decay: a building bleeds its whole HP bar away over
		# its lifetime, so it always dies on the timer unless something kills it
		# sooner. The rate is max_hp / lifetime per second.
		if is_building():
			hp = maxf(0.0, hp - max_hp / lifetime * delta)
			if hp <= 0.0:
				_die()
				return
		if age >= lifetime:
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
		# a stun breaks Slate's charge: he starts again from a standstill
		if not roll_cfg.is_empty() and (roll_level > 0 or roll_timer > 0.0):
			roll_level = 0
			roll_timer = 0.0
			speed = ground_speed
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

	if burn_pulse > 0.0:
		burn_pulse = maxf(0.0, burn_pulse - delta * 1.7)
	if status == Status.BURN:
		burn_timer -= delta
		if burn_timer <= 0.0:
			burn_timer += 1.0
			var tick_dmg := floorf(burn_stack * BURN_RATE)
			if tick_dmg <= 0.0:
				clear_status()
			else:
				burn_stack = maxf(0.0, burn_stack - tick_dmg)
				burn_ticks += 1
				burn_pulse = 1.0
				take_damage(tick_dmg, position)
				if dead or burn_ticks >= burn_max_ticks or burn_stack <= 0.0:
					clear_status()
	elif status == Status.SLOW:
		slow_time = maxf(0.0, slow_time - delta)
		if slow_time <= 0.0:
			clear_status()

	if not summon_cfg.is_empty():
		_tick_summon(delta)
	if not ritual_cfg.is_empty():
		_tick_ritual(delta)

	# the obsidian whelp: curled while an enemy unit is close or it was hit in the
	# last `calm` seconds; curled, it does nothing but sit there
	if not guard_cfg.is_empty():
		guard_calm = maxf(0.0, guard_calm - delta)
		if _enemy_unit_within(float(guard_cfg["sense"])):
			curled = true
		elif curled and guard_calm <= 0.0:
			curled = false
		if curled:
			state = S.IDLE
			target = null
			queue_redraw()
			return

	# a balled-up hedgehog holds its ground while anything is inside thorn reach;
	# once nothing is, it uncurls and walks again
	if not curl_cfg.is_empty() and curled:
		if _enemy_within(float(curl_cfg["thorn_range"])) == null:
			curled = false
		else:
			state = S.IDLE
			queue_redraw()
			return

	if kind == "dragon" and not flying and hp <= max_hp * 0.5 and hp > 0.0:
		_take_off()

	# a turned alchemist only has eyes for structures; _acquire enforces it, so
	# the nearest tower *or* building is what he charges

	if target == null or not _target_valid(target):
		target = _acquire()
	elif atk_cd <= 0.0 and targets_weakest:
		target = _acquire()

	if kind == "dragon" and flying:
		# airborne it never claws or bites: fire pours straight down while it flies
		# at the tower, then it hovers over it and keeps pouring
		_tick_fire_breath(delta)
		if target != null and is_instance_valid(target) and not target.dead:
			# it flies until its fire is landing on the target, not just until it
			# is close: that is how it burns a tower it is attacking
			var fire_gap: float = arena.tiles_between(dragon_fire_point(), target.position)
			state = S.APPROACH if fire_gap > 1.5 else S.IDLE
			if state == S.APPROACH:
				# fly to the spot where the fire, not the body, lands on the target
				var want: Vector2 = target.position - Vector2(facing * DRAGON_FIRE_AHEAD, DRAGON_FIRE_BELOW) * arena.TILE
				_move(delta, want)
		queue_redraw()
		return
	elif atk_cd <= 0.0:
		var cand: Node = _acquire()
		if cand != null and cand.get_instance_id() != target.get_instance_id():
			var d_new: float = arena.tiles_between(position, cand.position)
			var d_old: float = arena.tiles_between(position, target.position)
			if d_new < d_old - 0.3:
				target = cand

	if target == null and not stationary:
		# nothing worth shooting: advance on the nearest enemy tower rather than
		# standing in the open waiting for someone to walk into range
		target = arena.nearest_enemy_tower(team, position)
	if target == null:
		state = S.IDLE if stationary else S.APPROACH
		queue_redraw()
		return

	var gap: float = arena.gap_between(position, target.position, radius_t, float(target.get_radius_t()))
	if not kamikaze_cfg.is_empty() and airborne:
		# airborne: it flies at whatever it picked and bursts on contact
		if gap <= reach:
			_burst()
			return
		state = S.APPROACH
		speed = ground_speed * float(kamikaze_cfg.get("speed_mult", 1.0))
		_move(delta)
		queue_redraw()
		return
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
	if not sword_cfg.is_empty():
		# Laniakea picks his own target and his own swing every tick
		_tick_greatsword(delta)
		queue_redraw()
		return
	if not needle_cfg.is_empty():
		_tick_needle(delta)
		queue_redraw()
		return
	if not staff_cfg.is_empty():
		_tick_staff(delta, gap)
		queue_redraw()
		return
	if not frog_cfg.is_empty():
		_tick_frog(delta)
		queue_redraw()
		return
	if not spear_cfg.is_empty() and _try_throw():
		queue_redraw()
		return
	if not curl_cfg.is_empty() and not curled and gap <= reach:
		# a hedgehog has no jab: getting into reach is the cue to ball up
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


func _move(delta: float, at: Vector2 = Vector2.INF) -> void:
	var goal: Vector2 = target.position if at == Vector2.INF else at
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
	var spd := speed * (1.0 - (slow_amount if status == Status.SLOW else 0.0))
	position += dir * spd * arena.TILE * delta
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
	# a shooter whose shot is all payload (the Magma Whelp's burn) still fires
	if atk_cd > 0.0 or (dmg <= 0.0 and (shoots == "" or shoot_payload.is_empty())):
		return
	if not boom_cfg.is_empty():
		_attack_fu()
		return
	if not chicken_cfg.is_empty():
		_attack_chicken()
		return
	if not spread_cfg.is_empty():
		_attack_spread()
		return
	if shoots != "":
		_mark_attack()
		atk_cd = interval
		arena.spawn_projectile(position, target.position, team, dmg, 0.0, shoots,
			get_instance_id(), "bolt", false, self, 950.0, target, shoot_payload)
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
	_mark_attack()
	if whip:
		# Gilgamesh's snake: the hit is instant, this is only its picture
		whip_t = WHIP_SHOW
		whip_to = target.position
		if target.get("flying") == true:
			whip_to.y -= 18.0
	if beam:
		# the Nekomancer's beam: the hit is instant, this is only its picture
		beam_t = BEAM_SHOW
		beam_to = target.position
		if target.get("flying") == true:
			beam_to.y -= 18.0
	if splash > 0.0:
		arena.reserve_damage(get_instance_id(), target, hit_dmg)
		arena.spawn_projectile(position, target.position, team, hit_dmg, splash, kind, get_instance_id())
	else:
		if target.has_method("take_damage"):
			arena.reserve_damage(get_instance_id(), target, hit_dmg)
			target.take_damage(hit_dmg, position, self)
			arena.release_reservation(get_instance_id())
			if poison_hit > 0.0 and is_instance_valid(target) and target.has_method("add_poison"):
				target.add_poison(poison_hit)
	if not dodge_cfg.is_empty() and not dodging:
		swipes += 1
		if swipes >= int(dodge_cfg["after_hits"]):
			_begin_dodge()


## Burn tint walks red → orange → yellow across its ticks; the tick that ends
## the burn flashes white.
static func burn_color(ticks: int, max_ticks: int) -> Color:
	if max_ticks <= 1:
		return Color(1, 1, 1)
	if ticks >= max_ticks - 1:
		return Color(1.0, 1.0, 1.0)
	var f := clampf(float(ticks) / float(max_ticks - 1), 0.0, 1.0)
	var red := Color(0.95, 0.18, 0.12)
	var orange := Color(1.0, 0.55, 0.12)
	var yellow := Color(1.0, 0.92, 0.3)
	return red.lerp(orange, f * 2.0) if f < 0.5 else orange.lerp(yellow, (f - 0.5) * 2.0)


## Penny's fade: she vanishes (invincible + untargetable), backs off half a tile
## and steps a quarter circle around whoever she was hitting. The first strafe
## turns toward the outside of the board; after that she keeps turning the same
## way, so the fight drifts rather than doubling back.
func _begin_dodge() -> void:
	if target == null or not is_instance_valid(target):
		return
	swipes = 0
	dodging = true
	untargetable = true
	invincible = true
	dodge_t = 0.0
	atk_cd = 0.0
	dodge_center = target.position
	dodge_start_r = position.distance_to(dodge_center)
	dodge_radius = dodge_start_r + float(dodge_cfg["back"]) * arena.TILE
	dodge_angle0 = (position - dodge_center).angle()
	if not dodge_picked:
		dodge_picked = true
		var sweep := deg_to_rad(float(dodge_cfg["sweep_deg"]))
		var outer: Vector2 = arena.board_rect().get_center()
		var plus: Vector2 = dodge_center + Vector2(cos(dodge_angle0 + sweep), sin(dodge_angle0 + sweep)) * dodge_radius
		var minus: Vector2 = dodge_center + Vector2(cos(dodge_angle0 - sweep), sin(dodge_angle0 - sweep)) * dodge_radius
		dodge_sign = 1.0 if plus.distance_to(outer) > minus.distance_to(outer) else -1.0


func _tick_dodge(delta: float) -> void:
	var total: float = maxf(0.1, float(dodge_cfg["time"]))
	dodge_t += delta
	if target != null and is_instance_valid(target) and not target.dead:
		dodge_center = target.position
	var back_time: float = total * 0.3
	if dodge_t <= back_time:
		var f: float = dodge_t / back_time
		var r: float = lerpf(dodge_start_r, dodge_radius, ease(f, 0.4))
		position = dodge_center + Vector2(cos(dodge_angle0), sin(dodge_angle0)) * r
	else:
		var f: float = clampf((dodge_t - back_time) / (total - back_time), 0.0, 1.0)
		var ang: float = dodge_angle0 + dodge_sign * deg_to_rad(float(dodge_cfg["sweep_deg"])) * ease(f, 0.6)
		position = dodge_center + Vector2(cos(ang), sin(ang)) * dodge_radius
		var dir := position - dodge_center
		if absf(dir.x) > 1.0:
			facing = signf(dir.x)
	if dodge_t >= total:
		_begin_jump()


## Drawn height of Penny during the dodge (picture only): one big startled hop on
## the back-off; the quarter circle is run on the ground (DDArt.penny pose 2).
func _penny_hop() -> float:
	var total: float = maxf(0.1, float(dodge_cfg["time"]))
	var back_time: float = total * 0.3
	if dodge_t <= back_time:
		return sin(dodge_t / back_time * PI) * float(arena.TILE) * 0.5
	return 0.0


## End of the leap: back to ordinary swipes.
func _end_dash() -> void:
	dodging = false
	jumping = false
	carrying = false
	jump_victim = null
	untargetable = false
	invincible = false
	atk_cd = 0.0


## After the spin she grabs whatever she can reach and carries it with her: a full
## 2.5 tile hop for both of them, damage on arrival. A giant or a building cannot
## be carried, so against those she just closes to the hitbox and hits it.
func _begin_jump() -> void:
	var victim: Node = _jump_target()
	if victim == null:
		# nothing left to grab (it died during the strafe): no leap at all
		_end_dash()
		return
	jumping = true
	jump_t = 0.0
	jump_from = position
	jump_victim = victim
	var to: Vector2 = victim.position - position
	var dist: float = to.length()
	var dir: Vector2 = to / dist if dist > 0.01 else Vector2(facing, 0.0)
	jump_dir = dir
	var contact: float = (float(victim.get_radius_t()) + radius_t) * float(arena.TILE)
	var leap: float = float(dodge_cfg.get("jump_reach", 2.5)) * float(arena.TILE)
	var grabbable: bool = not _is_giant(victim) and not victim.is_building()
	if grabbable:
		# the grab: she always covers the full leap and drags the target along,
		# so both of them end up 2.5 tiles from where the jump started
		carrying = true
		carry_dir = dir
		carry_contact = contact
		jump_to = position + dir * leap
	else:
		# a giant or a building will not budge: stop on its hitbox, hit it there
		carrying = false
		jump_to = position + dir * clampf(dist - contact, 0.0, leap)
	target = null
	state = S.IDLE


## Air first, then the nearest ground body. Both inside jump_reach tiles.
func _jump_target() -> Node:
	var reach: float = float(dodge_cfg.get("jump_reach", 2.5))
	var best_air: Node = null
	var best_air_d := INF
	var best_ground: Node = null
	var best_ground_d := INF
	for e in arena.enemy_units(team):
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = arena.tiles_between(position, e.position)
		if d > reach:
			continue
		if e.get("flying") == true:
			if d < best_air_d:
				best_air_d = d
				best_air = e
		elif d < best_ground_d:
			best_ground_d = d
			best_ground = e
	return best_air if best_air != null else best_ground


## The leap itself: still untargetable. A carried target rides in front of her the
## whole way; the doubled hit lands when she arrives.
func _tick_jump(delta: float) -> void:
	var total: float = maxf(0.1, float(dodge_cfg.get("jump_time", 0.35)))
	jump_t += delta
	var f: float = clampf(jump_t / total, 0.0, 1.0)
	position = jump_from.lerp(jump_to, ease(f, 0.35))
	if absf(jump_to.x - jump_from.x) > 1.0:
		facing = signf(jump_to.x - jump_from.x)
	var held: bool = jump_victim != null and is_instance_valid(jump_victim) and not jump_victim.dead
	if carrying and held:
		jump_victim.position = position + carry_dir * carry_contact
	if f >= 1.0:
		if held:
			var power: float = dmg * float(dodge_cfg.get("jump_mult", 2.0))
			jump_victim.take_damage(power, position, self)
			var burst := DDBurst.new()
			burst.setup(arena, 0.7, arena.team_color(int(team)))
			burst.position = position
			arena.add_child(burst)
			arena.shake(1.6)
		_end_dash()


## Nearest enemy on one layer (ground or air), under the same aggro rules as
## _acquire: towers always count, troops inside aggro, buildings a little further.
func _nearest_on_layer(air: bool) -> Node:
	var best: Node = null
	var best_d := INF
	for e in arena.enemy_entities(team):
		if not is_instance_valid(e) or e.dead:
			continue
		if (e.get("flying") == true) != air:
			continue
		if arena.is_doomed(e):
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


## Laniakea's whole decision, once a tick:
##   ground body inside swing range                  -> stand and cleave
##   flyer inside the leap window, nothing on the
##   ground closer than it                           -> stand and leap
##   ground troop inside the leap window, no flyer
##   closer, swing off cooldown                      -> leap
##   otherwise walk: at the flyer if it is the closest thing and still too far to
##   leap at, else at the nearest ground body or tower. A flyer that is already
##   inside the window's near edge cannot be hit at all — that is the card.
func _tick_greatsword(delta: float) -> void:
	var ground: Node = _nearest_on_layer(false)
	var air: Node = _nearest_on_layer(true)
	var gd := INF
	var ad := INF
	if ground != null:
		gd = arena.tiles_between(position, ground.position)
		# a big body (tower, hatchery, dragon) is swung at from its edge
		var swing_at: float = maxf(float(sword_cfg["swing_range"]),
			radius_t + float(ground.get_radius_t()) + 0.2)
		if gd <= swing_at:
			target = ground
			state = S.ATTACK
			if atk_cd <= 0.0:
				_cleave()
			return
		# a ground troop in the leap window with nothing nearer gets the jump too.
		# Only when the swing is ready: otherwise he keeps walking in.
		if atk_cd <= 0.0 and not ground.is_building() and (air == null or gd <= arena.tiles_between(position, air.position)) \
				and gd >= float(sword_cfg["leap_min"]) and gd <= float(sword_cfg["leap_max"]):
			target = ground
			state = S.ATTACK
			_begin_leap()
			return
	if air != null:
		ad = arena.tiles_between(position, air.position)
		if ad < gd and ad >= float(sword_cfg["leap_min"]) and ad <= float(sword_cfg["leap_max"]):
			target = air
			state = S.ATTACK
			if atk_cd <= 0.0:
				_begin_leap()
			return
	if air != null and ad < gd and ad > float(sword_cfg["leap_max"]):
		target = air
	elif ground != null:
		target = ground
	else:
		target = arena.nearest_enemy_tower(team, position)
	if target == null:
		state = S.IDLE
		return
	state = S.APPROACH
	_move(delta)


## The ground swing: a 140 degree arc centred on the target, swept from the side
## nearer the middle of the board to the side nearer its edge. Every ground body
## the blade crosses takes the hit and is shoved straight away from him. Flyers
## are above it.
func _cleave() -> void:
	var to: Vector2 = target.position - position
	var dir: Vector2 = to.normalized() if to.length() > 0.01 else Vector2(facing, 0.0)
	if absf(dir.x) > 0.05:
		facing = signf(dir.x)
	_mark_attack()
	atk_cd = interval
	var half: float = deg_to_rad(float(sword_cfg["arc_deg"])) * 0.5
	var len_t: float = float(sword_cfg["length"])
	var mid: float = dir.angle()
	var centre: Vector2 = arena.board_rect().get_center()
	var len_px: float = len_t * float(arena.TILE)
	var end_plus: Vector2 = position + Vector2.from_angle(mid + half) * len_px
	var end_minus: Vector2 = position + Vector2.from_angle(mid - half) * len_px
	var turn := 1.0 if end_minus.distance_to(centre) <= end_plus.distance_to(centre) else -1.0
	swing_from = mid - half * turn
	swing_to = mid + half * turn
	swing_t = SWING_SHOW
	var primary: Node = target
	var push: float = float(sword_cfg["push"])
	var push_time: float = float(sword_cfg["push_time"])
	for e in arena.enemy_entities(team).duplicate():
		if not is_instance_valid(e) or e.dead or e.get("flying") == true:
			continue
		var off: Vector2 = e.position - position
		var d: float = off.length() / float(arena.TILE)
		if e != primary:
			if d > len_t + float(e.get_radius_t()):
				continue
			if d > 0.01 and absf(angle_difference(mid, off.angle())) > half:
				continue
		e.take_damage(dmg, position, self)
		if is_instance_valid(e) and not e.dead and e.has_method("apply_impulse"):
			e.apply_impulse(off.normalized() if d > 0.01 else dir, push, push_time)
	arena.shake(1.2)


## The air swing, part one: jump at the flyer. The landing spot is fixed when he
## leaves the ground (edge to edge with where the flyer was), never a live chase.
func _begin_leap() -> void:
	var victim: Node = target
	var to: Vector2 = victim.position - position
	var dist: float = to.length()
	leap_dir = to / dist if dist > 0.01 else Vector2(facing, 0.0)
	if absf(leap_dir.x) > 0.05:
		facing = signf(leap_dir.x)
	var contact: float = (radius_t + float(victim.get_radius_t())) * float(arena.TILE)
	var br: Rect2 = arena.board_rect()
	leaping = true
	leap_t = 0.0
	leap_from = position
	leap_to = (position + leap_dir * maxf(dist - contact, 0.0)).clamp(br.position, br.end)
	leap_victim = victim
	atk_cd = interval
	state = S.ATTACK
	_mark_attack()


func _tick_leap(delta: float) -> void:
	var total: float = maxf(0.1, float(sword_cfg["leap_time"]))
	leap_t += delta
	var f: float = clampf(leap_t / total, 0.0, 1.0)
	position = leap_from.lerp(leap_to, f)
	if f >= 1.0:
		leaping = false
		_slam()


## The air swing, part two: the blade comes down on the flyer and keeps going
## for leap_line tiles behind it. Everything in that strip, ground or air, takes
## the hit; units are stunned as well.
func _slam() -> void:
	var victim: Node = leap_victim
	leap_victim = null
	var held: bool = victim != null and is_instance_valid(victim) and not victim.dead
	var line_t: float = float(sword_cfg["leap_line"])
	if held:
		line_t += maxf(0.0, (victim.position - position).dot(leap_dir) / float(arena.TILE))
	var width: float = float(sword_cfg["leap_width"])
	var power: float = float(sword_cfg["leap_dmg"])
	var stun_s: float = float(sword_cfg["stun"])
	slam_t = SLAM_SHOW
	slam_len = line_t
	for e in arena.enemy_entities(team).duplicate():
		if not is_instance_valid(e) or e.dead:
			continue
		if not (held and e == victim):
			var off: Vector2 = (e.position - position) / float(arena.TILE)
			var r: float = float(e.get_radius_t())
			var along: float = off.dot(leap_dir)
			if along < -r or along > line_t + r or absf(off.cross(leap_dir)) > width + r:
				continue
		e.take_damage(power, position, self)
		if is_instance_valid(e) and not e.dead and e.get("stunned") != null:
			e.stunned = maxf(float(e.stunned), stun_s)
	arena.shake(2.4)


## Wu Cheng'en, once a tick. In reach: stand, draw the staff (no swing until it
## is all the way out), then poke and sweep in turn. Out of reach: put it away
## and knuckle-walk on.
func _tick_staff(delta: float, gap: float) -> void:
	var draw_time: float = maxf(0.05, float(staff_cfg["draw_time"]))
	if gap > reach:
		# a step or two to close back in (his own poke pushes the target off)
		# keeps the staff in hand; further than that, it goes back behind his ear
		if gap > reach + float(staff_cfg["keep_out"]):
			staff_out = maxf(0.0, staff_out - delta / draw_time)
		state = S.APPROACH
		_move(delta)
		return
	state = S.ATTACK
	var to: Vector2 = target.position - position
	if absf(to.x) > 1.0:
		facing = signf(to.x)
	if staff_out < 1.0:
		staff_out = minf(1.0, staff_out + delta / draw_time)
		return
	if atk_cd > 0.0:
		return
	var faster: float = float(staff_cfg["rage_attack"]) if rage_t > 0.0 else 1.0
	atk_cd = interval / faster
	_mark_attack()
	staff_dir = to.normalized() if to.length() > 0.01 else Vector2(facing, 0.0)
	if staff_combo == 0:
		_staff_poke()
	else:
		_staff_sweep()
	staff_combo = 1 - staff_combo


## Through the target and `pierce` tiles beyond it: everything on the ground in
## that strip is hit and pushed straight along the staff.
func _staff_poke() -> void:
	var tile: float = float(arena.TILE)
	var length: float = arena.tiles_between(position, target.position) + float(staff_cfg["pierce"])
	var width: float = float(staff_cfg["poke_width"])
	var primary: Node = target
	var struck := 0
	for e in arena.enemy_entities(team).duplicate():
		if not is_instance_valid(e) or e.dead or e.get("flying") == true:
			continue
		if e != primary:
			var off: Vector2 = (e.position - position) / tile
			var r: float = float(e.get_radius_t())
			var along: float = off.dot(staff_dir)
			if along < 0.0 or along > length + r or absf(off.cross(staff_dir)) > width + r:
				continue
		e.take_damage(dmg, position, self)
		struck += 1
		if is_instance_valid(e) and not e.dead and e.has_method("apply_impulse"):
			e.apply_impulse(staff_dir, float(staff_cfg["push"]), float(staff_cfg["push_time"]))
	rage_hits += struck
	staff_anim = 1
	staff_anim_t = STAFF_SHOW
	arena.shake(1.0)


## A 120 degree cone centred on the target, swept across from one side.
func _staff_sweep() -> void:
	var tile: float = float(arena.TILE)
	var half: float = deg_to_rad(float(staff_cfg["sweep_deg"])) * 0.5
	var len_t: float = float(staff_cfg["sweep_len"])
	var mid: float = staff_dir.angle()
	var primary: Node = target
	var struck := 0
	for e in arena.enemy_entities(team).duplicate():
		if not is_instance_valid(e) or e.dead or e.get("flying") == true:
			continue
		if e != primary:
			var off: Vector2 = e.position - position
			var d: float = off.length() / tile
			if d > len_t + float(e.get_radius_t()):
				continue
			if d > 0.01 and absf(angle_difference(mid, off.angle())) > half:
				continue
		e.take_damage(dmg, position, self)
		struck += 1
	rage_hits += struck
	staff_anim = 2
	staff_anim_t = STAFF_SHOW
	staff_from = mid - half * facing
	staff_to = mid + half * facing
	arena.shake(0.8)


## Banked hits -> the regen of the highest rage level reached.
func rage_level() -> int:
	var lv := 0
	var levels: Array = staff_cfg.get("rage_levels", [])
	for i in levels.size():
		if rage_hits >= int(levels[i][0]):
			lv = i
	return lv


func _enter_rage() -> void:
	rage_used = true
	rage_t = float(staff_cfg["rage_time"])
	rage_regen = float(staff_cfg["rage_levels"][rage_level()][1])
	speed = ground_speed * float(staff_cfg["rage_speed"])
	arena.banner_flash("Wu Cheng'en flies into a rage!")


## How close Femme Fatale stands to a body: needle range, or its edge if it is big.
func _needle_stop(body: Node) -> float:
	return maxf(float(needle_cfg["range"]), radius_t + float(body.get_radius_t()) + 0.2)


## Femme Fatale's decision, once a tick. She only ever looks at the ground:
##   nearest ground body inside needle range          -> stand and run the combo
##   nearest ground body 3.5 - 4.5 tiles off, with a
##   straight walk to it (no river in between)        -> raise the needle and dash
##   otherwise                                        -> walk at it
func _tick_needle(delta: float) -> void:
	var near: Node = _nearest_on_layer(false)
	if near == null:
		near = arena.nearest_enemy_tower(team, position)
	if near == null:
		state = S.IDLE
		return
	target = near
	var d: float = arena.tiles_between(position, near.position)
	if d <= _needle_stop(near):
		state = S.ATTACK
		if atk_cd <= 0.0:
			_needle_combo()
		return
	if d >= float(needle_cfg["dash_min"]) and d <= float(needle_cfg["dash_max"]) \
			and arena.route_point(position, near.position).is_equal_approx(near.position):
		dash_phase = 1
		dash_t = float(needle_cfg["windup"])
		dash_victim = near
		dash_dir = (near.position - position).normalized()
		if absf(dash_dir.x) > 0.05:
			facing = signf(dash_dir.x)
		state = S.ATTACK
		return
	state = S.APPROACH
	_move(delta)


## The dash. Wind-up: she stands with the needle straight up and keeps turning to
## face the target. Lunge: a straight line at dash_speed, ended when she is at
## needle range from the target or the distance she set out to cover runs out.
func _tick_dash(delta: float) -> void:
	var held: bool = dash_victim != null and is_instance_valid(dash_victim) and not dash_victim.dead
	if not held:
		dash_phase = 0
		dash_victim = null
		return
	var tile: float = float(arena.TILE)
	var to: Vector2 = dash_victim.position - position
	var stop_px: float = _needle_stop(dash_victim) * tile
	if dash_phase == 1:
		if to.length() > 0.01:
			dash_dir = to.normalized()
		if absf(dash_dir.x) > 0.05:
			facing = signf(dash_dir.x)
		dash_t -= delta
		if dash_t <= 0.0:
			dash_phase = 2
			# half a tile of slack for a target that is walking away
			dash_left = maxf(to.length() - stop_px, 0.0) + 0.5 * tile
		return
	var need: float = to.length() - stop_px
	var step: float = float(needle_cfg["dash_speed"]) * tile * delta
	if need <= step or dash_left <= step:
		position += dash_dir * maxf(minf(need, dash_left), 0.0)
		moved_this_frame = true
		dash_phase = 0
		_dash_hit()
		return
	position += dash_dir * step
	dash_left -= step
	moved_this_frame = true


## End of the lunge: the tip lands if the target is inside tip range of where she
## stopped. Either way the swing is spent and the combo starts from the flick.
func _dash_hit() -> void:
	var victim: Node = dash_victim
	dash_victim = null
	atk_cd = interval
	needle_step = 0
	if victim == null or not is_instance_valid(victim) or victim.dead:
		return
	target = victim
	_mark_attack()
	var ang: float = dash_dir.angle()
	needle_from = ang
	needle_to = ang
	needle_t = NEEDLE_SHOW
	var d: float = arena.tiles_between(position, victim.position)
	if d <= maxf(float(needle_cfg["tip"]), _needle_stop(victim) + 0.1):
		victim.take_damage(float(needle_cfg["dash_dmg"]), position, self)
		arena.shake(1.4)


## The close combo, one hit per swing: a flick in from the side nearer the middle
## of the board (the arc is only drawn, the hit is single target), a stab, and a
## stab whose recoil carries her half a tile back out.
func _needle_combo() -> void:
	var id: int = target.get_instance_id()
	if id != needle_target_id:
		needle_target_id = id
		needle_step = 0
	var to: Vector2 = target.position - position
	var dir: Vector2 = to.normalized() if to.length() > 0.01 else Vector2(facing, 0.0)
	if absf(dir.x) > 0.05:
		facing = signf(dir.x)
	_mark_attack()
	atk_cd = interval
	var step := needle_step
	needle_step = (needle_step + 1) % 3
	var mid: float = dir.angle()
	needle_from = mid
	needle_to = mid
	needle_t = NEEDLE_SHOW
	if step == 0:
		var off: float = deg_to_rad(float(needle_cfg["swing_deg"]))
		var centre: Vector2 = arena.board_rect().get_center()
		var plus: Vector2 = position + Vector2.from_angle(mid + off) * 100.0
		var minus: Vector2 = position + Vector2.from_angle(mid - off) * 100.0
		needle_from = mid + off if plus.distance_to(centre) <= minus.distance_to(centre) else mid - off
	if target.has_method("take_damage"):
		arena.reserve_damage(get_instance_id(), target, dmg)
		target.take_damage(dmg, position, self)
		arena.release_reservation(get_instance_id())
	if step == 2:
		apply_impulse(-dir, float(needle_cfg["recoil"]), float(needle_cfg["recoil_time"]))


## Giants (the dragon) shrug off the shove: they take the hit and stay planted.
func _is_giant(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var k = node.get("kind")
	if k == null:
		return false
	return bool(DDCard.get_card(String(k)).get("giant", false))


## Primal Aphid: a shotgun cone, five pellets spread across cone_deg, each flying
## its own full length whether or not anything is in front of it. The pellets
## carry further than the aphid's own 2 tile stance, so they reach into a lane it
## never has to enter.
func _attack_spread() -> void:
	if target == null:
		return
	_mark_attack()
	atk_cd = interval
	var dir: Vector2 = target.position - position
	if dir.length() < 1.0:
		dir = Vector2(facing, 0.0)
	var base_angle := dir.angle()
	var n: int = maxi(1, int(spread_cfg["count"]))
	var half := deg_to_rad(float(spread_cfg["cone_deg"])) * 0.5
	var reach_px: float = float(spread_cfg["reach"]) * arena.TILE
	for i in n:
		var f := 0.0
		if n > 1:
			f = (float(i) / float(n - 1)) * 2.0 - 1.0
		var ang: float = base_angle + half * f
		var to: Vector2 = position + Vector2(cos(ang), sin(ang)) * reach_px
		arena.spawn_projectile(position, to, team, float(spread_cfg["dmg"]), 0.0, "aphid",
			get_instance_id(), "bolt", false, self, float(spread_cfg["speed"]), null,
			{"first_hit": true})


## Hot Chicken's ground phase: peck fireballs. Three hits on one target and it
## takes off — the ram below does the rest.
func _attack_chicken() -> void:
	if target == null or atk_cd > 0.0:
		return
	_mark_attack()
	atk_cd = interval
	var id: int = target.get_instance_id()
	if id == chicken_target:
		chicken_hits += 1
	else:
		chicken_target = id
		chicken_hits = 1
	arena.spawn_projectile(position, target.position, team, dmg, 0.0, "chicken",
		get_instance_id(), "bolt", false, self, float(chicken_cfg["fire_speed"]), target,
		{"burn": burn_per_hit})
	if chicken_hits >= int(chicken_cfg["hits_to_fly"]):
		airborne = true
		flying = true
		reach = float(chicken_cfg["burst_reach"])
		atk_cd = 0.0


## Hot Chicken's air phase: fly into the target and burst, killing itself.
func _burst() -> void:
	if dead:
		return
	# no damage of its own: everything in the splash (towers included) catches fire
	var rad := float(kamikaze_cfg["radius"])
	arena.spawn_splash_burst(position, rad, float(kamikaze_cfg.get("dmg", 0.0)),
		team, Color(1.0, 0.62, 0.25))
	arena.apply_burn_at(position, rad, float(kamikaze_cfg.get("burn", 0.0)), team)
	_die()


func _attack_fu() -> void:
	var gap: float = arena.gap_between(position, target.position, radius_t, float(target.get_radius_t()))
	var dist: float = arena.tiles_between(position, target.position)
	if absf(target.position.x - position.x) > 0.6:
		facing = signf(target.position.x - position.x)
	var target_airborne: bool = target.get("flying") == true
	if gap <= float(boom_cfg["melee_range"]) and not target_airborne:
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
		get_instance_id(), "return", false, self, speed_px, target)


## Nearest enemy whose gap to this unit's *edge* is inside range_t. Edge to edge
## on purpose: a ranged attacker the hedgehog has walked up on still counts.
func _enemy_within(range_t: float) -> Node:
	var best: Node = null
	var best_d := INF
	for e in arena.enemy_entities(team):
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = arena.gap_between(position, e.position, radius_t, float(e.get_radius_t()))
		if d <= range_t and d < best_d:
			best = e
			best_d = d
	return best


## Any enemy unit (ground or air, not towers) within range_t tiles, edge to edge.
func _enemy_unit_within(range_t: float) -> bool:
	for e in arena.enemy_units(team):
		if not is_instance_valid(e) or e.dead:
			continue
		if arena.gap_between(position, e.position, radius_t, float(e.get_radius_t())) <= range_t:
			return true
	return false


## The obsidian whelp being hit: it curls (the hit that wakes it lands in full),
## restarts its calm clock, and a melee blow nudges it straight back. A blow is
## melee when it comes from the attacker's own body, not a projectile.
func _guard_hit(from: Vector2, attacker: Node) -> void:
	curled = true
	guard_calm = float(guard_cfg["calm"])
	if attacker == null or not is_instance_valid(attacker) or not attacker.has_method("get_radius_t"):
		return
	if attacker.is_tower() or from.distance_to(attacker.position) > 1.0:
		return
	var d: Vector2 = position - attacker.position
	if d.length() < 0.01:
		d = Vector2(facing, 0.0)
	apply_impulse(d.normalized(), float(guard_cfg["melee_push"]), float(guard_cfg["push_time"]))


## The hedgehog's reach attack: ball up, quills out at everything inside thorn
## reach, and a short shove — short enough that nothing leaves the thorns, which
## is where the reflection happens. It never opens up again on its own; that is
## the uncurl above, and it only happens when the thorns can reach nothing.
func _curl() -> void:
	curled = true
	state = S.IDLE
	target = null
	atk_cd = 0.0
	var burst := float(curl_cfg["burst_dmg"])
	var tr := float(curl_cfg["thorn_range"])
	var push := float(curl_cfg["push"])
	for e in arena.enemy_entities(team).duplicate():
		if not is_instance_valid(e) or e.dead:
			continue
		# the hedgehog never picks a fight in the air: the burst is a ground shove
		if e.get("flying") == true:
			continue
		var gap: float = arena.gap_between(position, e.position, radius_t, float(e.get_radius_t()))
		if gap > tr:
			continue
		if e.has_method("take_damage"):
			e.take_damage(burst, position, self)
		if e.has_method("apply_impulse"):
			# never shove a unit out of thorn reach
			var shove: float = minf(push, maxf(tr - gap - 0.1, 0.0))
			if shove > 0.02:
				var d: Vector2 = e.position - position
				if d.length() < 0.01:
					d = Vector2(facing, 1.0)
				e.apply_impulse(d.normalized(), shove, float(curl_cfg["push_time"]))


## Balled up without attacking: a flyer that dives on it cannot be chased, so the
## hedgehog simply closes up and lets the quills answer the next hit.
func _curl_up() -> void:
	curled = true
	state = S.IDLE
	target = null
	atk_cd = 0.0


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


## Where the dragon's fire lands in world space: under it, a little ahead.
func dragon_fire_point() -> Vector2:
	return position + Vector2(facing * DRAGON_FIRE_AHEAD, DRAGON_FIRE_BELOW) * arena.TILE


## Fire rains from the airborne dragon onto the ground below: 25 damage a second
## to whatever is standing in the one tile patch. Flying units are above it.
func _tick_fire_breath(delta: float) -> void:
	fire_tick -= delta
	if fire_tick > 0.0:
		return
	fire_tick = DRAGON_FIRE_TICK
	var at := dragon_fire_point()
	var hit: float = DRAGON_FIRE_DPS * DRAGON_FIRE_TICK
	# the fire does not care whose colours you wear: every ground body under it burns
	for e in arena.units.duplicate():
		if not is_instance_valid(e) or e.dead or e == self or e.get("flying") == true:
			continue
		if arena.tiles_between(at, e.position) <= DRAGON_FIRE_RADIUS + float(e.get_radius_t()):
			e.take_damage(hit, at, self)
	for tw in arena.towers:
		if not is_instance_valid(tw) or tw.dead or int(tw.team) == team:
			continue
		if arena.tiles_between(at, tw.position) <= DRAGON_FIRE_RADIUS + 0.7:
			tw.take_damage(hit, at, self)


## The airborne dragon's fire: a burning patch on the ground with a column of
## green flame pouring into it from the maw.
func _draw_fire_breath(px: float) -> void:
	var f := facing if absf(facing) > 0.01 else 1.0
	var patch: Vector2 = Vector2(f * DRAGON_FIRE_AHEAD, DRAGON_FIRE_BELOW) * arena.TILE
	var rad: float = DRAGON_FIRE_RADIUS * arena.TILE
	var team_col: Color = arena.team_color(int(team))
	var deep: Color = team_col.darkened(0.45)
	var hot: Color = team_col.lerp(Color(1.0, 0.98, 0.95), 0.6)
	var flick := 0.5 + 0.5 * sin(clock * 17.0)
	var flick2 := 0.5 + 0.5 * sin(clock * 23.0 + 1.7)
	draw_set_transform(patch, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, rad * (0.98 + 0.03 * flick), Color(deep.r, deep.g, deep.b, 0.62))
	draw_circle(Vector2.ZERO, rad * (0.72 + 0.07 * flick2), Color(team_col.r, team_col.g, team_col.b, 0.62))
	draw_circle(Vector2.ZERO, rad * 0.44, Color(hot.r, hot.g, hot.b, 0.75))
	draw_arc(Vector2.ZERO, rad * (0.98 + 0.03 * flick), 0.0, TAU, 40, Color(hot.r, hot.g, hot.b, 0.55), 3.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# a few tongues licking up out of the patch
	for i in 4:
		var ang := float(i) * 1.7 + flick * 0.6
		var base_at: Vector2 = patch + Vector2(cos(ang), sin(ang) * 0.42) * rad * 0.62
		var tall: float = rad * (0.28 + 0.18 * (0.5 + 0.5 * sin(clock * 21.0 + float(i) * 2.1)))
		draw_line(base_at, base_at + Vector2(0.0, -tall), Color(team_col.r, team_col.g, team_col.b, 0.5), rad * 0.14, true)
		draw_line(base_at, base_at + Vector2(0.0, -tall * 0.7), Color(hot.r, hot.g, hot.b, 0.5), rad * 0.06, true)
	var maw := Vector2(f * px * 0.5, -px * 0.5)
	for i in 3:
		var q := float(i) - 1.0
		var wob := sin(clock * 13.0 + float(i) * 1.3) * rad * 0.1
		draw_line(maw + Vector2(wob, 0.0), patch + Vector2(q * rad * 0.3, -rad * 0.1),
			Color(team_col.r, team_col.g, team_col.b, 0.28), rad * 0.34, true)
		draw_line(maw + Vector2(wob, 0.0), patch + Vector2(q * rad * 0.3, -rad * 0.1),
			Color(hot.r, hot.g, hot.b, 0.34), rad * 0.14, true)


## The flame leaving the dragon's mouth: short, flickering, aimed straight down.
func _draw_maw_flame(px: float) -> void:
	var f := facing if absf(facing) > 0.01 else 1.0
	var maw := Vector2(f * px * 0.52, -px * 0.5)
	for i in 3:
		var q := float(i) - 1.0
		var len_px: float = px * (0.32 + 0.14 * (0.5 + 0.5 * sin(clock * 19.0 + float(i))))
		var tip := maw + Vector2(q * px * 0.14 + sin(clock * 15.0 + float(i)) * px * 0.06, len_px)
		var team_col: Color = arena.team_color(int(team))
		var hot: Color = team_col.lerp(Color(1.0, 0.98, 0.95), 0.6)
		draw_line(maw, tip, Color(team_col.r, team_col.g, team_col.b, 0.5), px * 0.16, true)
		draw_line(maw, tip, Color(hot.r, hot.g, hot.b, 0.6), px * 0.07, true)


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


## Where a hatchery's units come out: front and centre of the building.
func _hatch_spot() -> Vector2:
	var fwd := 1.0 if team == 0 else -1.0
	var fp: Array = DDCard.get_card(kind).get("footprint", [1, 1])
	var depth: float = float(fp[1]) * 0.5 + 0.45
	return position + Vector2(fwd * depth * float(arena.TILE), 0.0)


func _tick_summon(delta: float) -> void:
	summon_cd = maxf(0.0, summon_cd - delta)
	if summon_cd > 0.0:
		return
	if summon_cfg.has("spot"):
		# the hatchery: one body out of the front hatch, centred on the building,
		# on a fixed cadence rather than waiting for company
		summon_cd = float(summon_cfg.get("interval", 12.0))
		arena.spawn_troop(String(summon_cfg["unit"]), team, _hatch_spot(), true)
		arena.shake(1.2)
		return
	var rng_t := float(summon_cfg["range"])
	var near := false
	for e in arena.enemy_entities(team):
		if not is_instance_valid(e) or e.dead:
			continue
		if arena.tiles_between(position, e.position) <= rng_t:
			near = true
			break
	if not near:
		return
	summon_cd = float(summon_cfg["cooldown"])
	var kind_s := String(summon_cfg["unit"])
	var closest: Node = null
	var best := INF
	for e in arena.enemy_entities(team):
		if not is_instance_valid(e) or e.dead:
			continue
		var d2: float = arena.tiles_between(position, e.position)
		if d2 <= rng_t and d2 < best:
			best = d2
			closest = e
	var dir := Vector2(-1.0 if team == 0 else 1.0, 0.0)
	if closest != null:
		var raw: Vector2 = closest.position - position
		if raw.length() > 0.001:
			var step := TAU / 16.0
			var snapped := roundf(raw.angle() / step) * step
			dir = Vector2(cos(snapped), sin(snapped))
	var at: Vector2 = position + dir * 1.3 * float(arena.TILE)
	arena.spawn_troop(kind_s, team, at, true)
	arena.shake(2.0)


## Enkidu's throw: spear in hand and off cooldown, nothing already inside
## throw_min (that is hand-to-hand), and a ground troop whose centre is in the
## throw_min .. throw_range band — the nearest such one takes the spear. Flyers,
## buildings and towers are never thrown at. Returns true if he threw.
func _try_throw() -> bool:
	if spear_away > 0.0 or atk_cd > 0.0:
		return false
	var lo: float = float(spear_cfg["throw_min"])
	var hi: float = float(spear_cfg["throw_range"])
	var pick: Node = null
	var best := INF
	for e in arena.enemy_entities(team):
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = arena.tiles_between(position, e.position)
		if d < lo and _target_valid(e):
			# something is already in close: he fights it with the spear in hand
			return false
		if e.get("flying") == true or e.is_building() or e.is_tower():
			continue
		if d >= lo and d <= hi and d < best and _target_valid(e):
			best = d
			pick = e
	if pick == null:
		return false
	target = pick
	if absf(pick.position.x - position.x) > 1.0:
		facing = signf(pick.position.x - position.x)
	_mark_attack()
	atk_cd = base_interval
	arena.spawn_projectile(position + Vector2(0.0, -radius_t * float(arena.TILE) * 0.6), pick.position, team,
		float(spear_cfg["throw_dmg"]), 0.0, "javelin", get_instance_id(), "bolt", false, self,
		float(spear_cfg["throw_speed"]), pick, {"seek": pick})
	# the short sword until the spear is back: shorter, quicker, ground only
	spear_away = float(spear_cfg["away_time"])
	dmg = float(spear_cfg["sword_dmg"])
	reach = float(spear_cfg["sword_reach"])
	interval = float(spear_cfg["sword_interval"])
	hits_air = false
	state = S.ATTACK
	return true


## The frog on the ground: leap if anything is in range, otherwise hop toward
## its target (a hop, once started, finishes; the rest between hops is where it
## can turn).
func _tick_frog(delta: float) -> void:
	if frog_hop_t > 0.0:
		var hop_time: float = float(frog_cfg["hop_time"])
		var step: float = float(frog_cfg["hop"]) / hop_time
		var spd: float = step * (1.0 - (slow_amount if status == Status.SLOW else 0.0))
		position += frog_dir * spd * float(arena.TILE) * minf(delta, frog_hop_t)
		frog_hop_t = maxf(0.0, frog_hop_t - delta)
		moved_this_frame = true
		return
	var prey := _frog_prey()
	if prey != null:
		frog_leaping = true
		frog_leap_t = 0.0
		frog_from = position
		frog_victim = prey
		frog_to = prey.position
		if absf(prey.position.x - position.x) > 1.0:
			facing = signf(prey.position.x - position.x)
		return
	frog_rest = maxf(0.0, frog_rest - delta)
	if frog_rest > 0.0 or target == null or not is_instance_valid(target):
		state = S.IDLE
		return
	state = S.APPROACH
	var wp: Vector2 = arena.route_point(position, target.position)
	var dir := wp - position
	if dir.length() < 1.0:
		dir = target.position - position
	if dir.length() < 0.001:
		return
	frog_dir = dir.normalized()
	if absf(frog_dir.x) > 0.05:
		facing = signf(frog_dir.x)
	frog_hop_t = float(frog_cfg["hop_time"])
	frog_rest = float(frog_cfg["rest"])


## The nearest ground enemy (troop, building or tower) whose edge is within
## leap_range tiles of the frog's centre. Flyers are out of reach.
func _frog_prey() -> Node:
	var best: Node = null
	var best_d := INF
	var rng: float = float(frog_cfg["leap_range"])
	for e in arena.enemy_entities(team):
		if not is_instance_valid(e) or e.dead:
			continue
		if e.get("flying") == true:
			continue
		var d: float = arena.tiles_between(position, e.position) - float(e.get_radius_t())
		if d <= rng and d < best_d:
			best_d = d
			best = e
	return best


func _tick_frog_leap(delta: float) -> void:
	frog_leap_t += delta
	if frog_victim != null and is_instance_valid(frog_victim) and not frog_victim.dead:
		# it follows its prey through the air: the landing is on it, not where it was
		frog_to = frog_victim.position
	var f: float = clampf(frog_leap_t / float(frog_cfg["leap_time"]), 0.0, 1.0)
	position = frog_from.lerp(frog_to, f)
	if f >= 1.0:
		_frog_burst()


## Landing: 10 poison on every ground enemy the `burst` circle touches (any part
## of its body; bodies cannot overlap, so measured to the centre it would only
## ever reach the one it landed on), and the frog is spent.
func _frog_burst() -> void:
	frog_leaping = false
	# for --scenario=frog: where the last burst went off
	arena.set_meta("frog_burst", position)
	var r: float = float(frog_cfg["burst"])
	for e in arena.enemy_entities(team):
		if not is_instance_valid(e) or e.dead or e.get("flying") == true:
			continue
		if not e.has_method("add_poison"):
			continue
		if arena.tiles_between(position, e.position) <= r + float(e.get_radius_t()):
			e.add_poison(float(frog_cfg["poison"]))
	arena.spawn_splash_ring(position, r, team)
	hp = 0.0
	# it spent itself: nothing killed it, so nothing (a zombie) gets to raise it
	last_attacker = null
	_die()


func _spear_back() -> void:
	dmg = base_dmg
	reach = ground_reach
	interval = base_interval
	hits_air = true


## The Nekomancer's ritual: on its clock the wind catches her cloak and two
## pentagrams open on the forward diagonals, `dist` tiles out. Each one raises
## its unit itself, `delay` seconds later.
func _tick_ritual(delta: float) -> void:
	ritual_cd -= delta
	if ritual_cd > 0.0:
		return
	ritual_cd += float(ritual_cfg["every"])
	cloak_t = CLOAK_WIND
	var fwd := 1.0 if team == 0 else -1.0
	var dist_px: float = float(ritual_cfg["dist"]) * float(arena.TILE)
	for side in [-1.0, 1.0]:
		var spot: Vector2 = position + Vector2(fwd, side).normalized() * dist_px
		# off the board or under a building: pulled back toward her until it fits
		for i in 6:
			var tl: Vector2i = arena.tile_of(spot)
			if arena.valid_tile(tl) and arena.building_at(tl) == null:
				break
			spot = spot.lerp(position, 0.35)
		var p: Node2D = PENTAGRAM.new()
		p.setup(arena, team, String(ritual_cfg["unit"]), spot, float(ritual_cfg["delay"]))
		arena.add_child(p)


func _acquire() -> Node:
	if targets_weakest:
		var weakest: Node = null
		var worst_hp := INF
		for e in arena.enemy_entities(team):
			if not is_instance_valid(e) or e.dead:
				continue
			if e.get("flying") == true and not hits_air:
				continue
			if arena.is_doomed(e):
				continue
			if buildings_only and not e.is_building():
				continue
			if troops_only and (e.is_building() or e.is_tower()):
				continue
			if phase2 and not (e.is_building() or e.is_tower()):
				continue
			var dw: float = arena.tiles_between(position, e.position)
			if dw > aggro:
				continue
			var ehp := float(e.get("hp"))
			if ehp < worst_hp:
				worst_hp = ehp
				weakest = e
		return weakest
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
		if troops_only and (e.is_building() or e.is_tower()):
			continue
		if phase2 and not (e.is_building() or e.is_tower()):
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
	if dead or amount <= 0.0 or invincible:
		return
	var taken := amount
	if curled and not curl_cfg.is_empty():
		taken *= float(curl_cfg["damage_mult"])
	if curled and not guard_cfg.is_empty():
		taken *= float(guard_cfg["damage_mult"])
	last_from = from
	if attacker != null:
		last_attacker = attacker
	hp -= taken
	flash = 0.5
	hurt_frames = 2
	if arena.show_damage():
		var tint := Color(1.0, 0.45, 0.45) if hp <= 0.0 else (Color(1.0, 0.85, 0.5) if taken >= 20.0 else Color(0.95, 0.95, 1.0))
		arena.spawn_damage_text(position + Vector2(0.0, -radius_t * arena.TILE - 8.0), taken, tint)
	# quills: anything that hits the ball from inside thorn reach gets poked, so
	# a ranged attacker that has been closed on is punished exactly like a melee
	# one. The guard stops two hedgehogs poking each other forever.
	if curled and not curl_cfg.is_empty() and arena.damage_guard == 0:
		var src_node: Node = attacker
		var src_pos := from
		if src_node != null and is_instance_valid(src_node):
			src_pos = src_node.position
		var src_r := 0.0
		if src_node != null and src_node.has_method("get_radius_t"):
			src_r = float(src_node.get_radius_t())
		if arena.gap_between(position, src_pos, radius_t, src_r) <= float(curl_cfg["thorn_range"]):
			if src_node != null and is_instance_valid(src_node) and src_node.has_method("take_damage"):
				arena.damage_guard += 1
				src_node.take_damage(float(curl_cfg["thorn_dmg"]), position, self)
				arena.damage_guard = maxi(0, arena.damage_guard - 1)
	# it will not chase a flyer, but a melee one that dives on it gets the ball: the
	# hit that started it is not repaid, the next one is
	if not curled and not curl_cfg.is_empty() and hp > 0.0:
		if attacker != null and is_instance_valid(attacker) and attacker.get("flying") == true:
			var air_reach = attacker.get("reach")
			if air_reach != null and float(air_reach) <= MELEE_AIR_REACH:
				_curl_up()
	if not guard_cfg.is_empty() and hp > 0.0:
		_guard_hit(from, attacker)
	if not staff_cfg.is_empty() and not rage_used and hp > 0.0 and hp < max_hp * float(staff_cfg["rage_hp"]):
		_enter_rage()
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
	# death blast (snowman): damage + slow around the corpse
	var da: Dictionary = DDCard.get_card(kind).get("death_aoe", {})
	if not da.is_empty():
		arena.death_aoe(position, float(da["radius"]), float(da["dmg"]),
			float(da["slow"]), float(da["slow_time"]), team)
	# an egg hatches where it stood, however it went (timer or damage)
	var hatch_kind := String(DDCard.get_card(kind).get("hatch", ""))
	if hatch_kind != "":
		var born = arena.spawn_troop(hatch_kind, team, position, true)
		if born != null and is_instance_valid(born):
			born.position = position
			born.deploy_timer = 0.0
	# a hatchery gives up one last unit as it goes, however it went
	if bool(summon_cfg.get("on_death", false)):
		arena.spawn_troop(String(summon_cfg["unit"]), team, _hatch_spot(), true)
	# zombies raise whatever they kill, on their own side — buildings are not
	# people, they do not get back up
	if kind != "zombie" and not is_building() and last_attacker != null and is_instance_valid(last_attacker):
		var killer_kind = last_attacker.get("kind")
		# attackers that carry no kind at all (a rolling snowball) raise nothing
		if killer_kind != null and String(killer_kind) == "zombie":
			var risen = arena.spawn_troop("zombie", int(last_attacker.team), position, true)
			if risen != null and is_instance_valid(risen):
				risen.deploy_timer = 0.0
			arena.banner_flash("Another one rises...")
	if kind == "idol":
		var src := last_from
		if last_attacker != null and is_instance_valid(last_attacker):
			src = last_attacker.position
		var dir := Vector2(0, -1)
		if src != Vector2.INF:
			dir = src - position
			if dir.length() < 0.01:
				dir = Vector2(0, -1)
			dir = dir.normalized()
		arena.spawn_boulder(position, dir, team)
	# mini confetti in the card's accent and the owner's colour
	arena.spawn_unit_confetti(position, kind, team, radius_t)
	arena.unregister(self)
	queue_free()


func _draw() -> void:
	var px: float = radius_t * arena.TILE
	if kind == "dragon" and flying:
		_draw_fire_breath(px)
	var lift := 0.0
	if flying:
		lift = 18.0 + sin(clock * 2.2) * 3.0
		draw_set_transform(Vector2(0, px * 0.55), 0.0, Vector2(1.0, 0.42))
		draw_circle(Vector2.ZERO, px * 0.95, Color(0.05, 0.06, 0.1, 0.32))
	elif jumping:
		# the leap that ends Penny's spin: a hop and a drop, shadow left on the ground
		var jf: float = clampf(jump_t / maxf(0.1, float(dodge_cfg.get("jump_time", 0.35))), 0.0, 1.0)
		lift = sin(jf * PI) * float(arena.TILE) * 1.1
		draw_set_transform(Vector2(0, px * 0.6), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, px * (0.9 - 0.4 * sin(jf * PI)), Color(0.05, 0.06, 0.1, 0.3))
	elif dodging:
		# Penny's spooked hop back, then the stiff-legged bounces of the crab run
		lift = _penny_hop()
		var hf: float = lift / float(arena.TILE)
		draw_set_transform(Vector2(0, px * 0.6), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, px * (0.9 - 0.5 * hf), Color(0.05, 0.06, 0.1, 0.3))
	elif frog_leaping or frog_hop_t > 0.0:
		# the frog's hops are small arcs; the leap a big one
		var ff: float
		var height: float
		if frog_leaping:
			ff = clampf(frog_leap_t / float(frog_cfg["leap_time"]), 0.0, 1.0)
			height = float(arena.TILE) * 0.9
		else:
			ff = 1.0 - frog_hop_t / float(frog_cfg["hop_time"])
			height = float(arena.TILE) * 0.3
		lift = sin(ff * PI) * height
		draw_set_transform(Vector2(0, px * 0.6), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, px * (0.9 - 0.3 * sin(ff * PI)), Color(0.05, 0.06, 0.1, 0.3))
	elif leaping:
		# Laniakea going up to meet a flyer: an arc that ends at flying height
		var lf: float = clampf(leap_t / maxf(0.1, float(sword_cfg["leap_time"])), 0.0, 1.0)
		lift = sin(lf * PI) * float(arena.TILE) * 0.9 + lf * 18.0
		draw_set_transform(Vector2(0, px * 0.6), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, px * (0.9 - 0.4 * sin(lf * PI)), Color(0.05, 0.06, 0.1, 0.3))
	# squash & stretch: drop-in, landing squash, attack lunge
	var sx := 1.0
	var sy := 1.0
	var drop := 0.0
	if deploy_timer > 0.0 and rises:
		# climbing up out of the pentagram: starts flat and sunk, ends standing
		var rf: float = clampf((DEPLOY_DELAY - deploy_timer) / DEPLOY_DELAY, 0.0, 1.0)
		sy = lerpf(0.15, 1.0, ease(rf, 0.5))
		sx = lerpf(1.3, 1.0, rf)
		drop = px * 0.8 * (1.0 - rf)
	elif deploy_timer > 0.0:
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
	# every unit is outlined in a darker shade of its own team's colour
	var ink: Color = arena.team_ink(int(team))
	if kind == "hedgehog":
		DDArt.hedgehog(self, px, facing, clock, curled, ink)
	elif kind == "obsidian":
		DDArt.whelp(self, px, facing, clock, curled, false, ink)
	elif kind == "wu":
		if rage_t > 0.0:
			var rp: float = 0.5 + 0.5 * sin(clock * 14.0)
			draw_circle(Vector2.ZERO, px * (1.25 + 0.1 * rp), Color(1.0, 0.15, 0.1, 0.18 + 0.14 * rp))
		DDArt.bonobo(self, px, facing, clock, {"staff": staff_out, "walk": state == S.APPROACH,
			"swing": staff_anim_t > 0.0, "rage": rage_t > 0.0}, ink)
	elif kind == "gilgamesh":
		DDArt.gilgamesh(self, px, facing, clock, {"lashing": whip_t > 0.0, "walk": state == S.APPROACH},
			ink, arena.team_color(int(team)))
	elif kind == "frog":
		var air := 0.0
		if frog_leaping:
			air = 1.0
		elif frog_hop_t > 0.0:
			air = 0.7
		DDArt.dart_frog(self, px, facing, clock, air, ink, DDArt.frog_stripe(arena.team_color(int(team))))
	elif kind == "enkidu":
		DDArt.enkidu(self, px, facing, clock, {"spear": spear_away <= 0.0, "walk": state == S.APPROACH,
			"strike": attack_stretch / ATTACK_STRETCH}, ink)
	elif kind == "neko":
		DDArt.nekomancer(self, px, facing, clock, {"wind": cloak_t / CLOAK_WIND,
			"cast": beam_t / BEAM_SHOW, "walk": state == S.APPROACH}, ink, arena.team_color(int(team)))
	elif kind == "hawk":
		DDArt.bird(self, px, facing, clock, bird_lead, ink)
	elif kind == "dragon":
		DDArt.dragon(self, px, facing, clock, flying, 0.0, ink)
		if flying:
			_draw_maw_flame(px)
	elif kind == "laniakea":
		# sword on his back, overhead in the leap, or out of his hands mid-swing
		# (the swing itself is drawn below, in board space)
		var pose := 0
		if leaping:
			pose = 1
		elif swing_t > 0.0 or slam_t > 0.0:
			pose = 2
		DDArt.laniakea(self, px, facing, clock, pose, ink)
	elif kind == "femme":
		# needle at her side, straight up for the wind-up, or out of her hands
		# while the lunge / combo hit is drawn below in board space
		var fpose := 0
		if dash_phase == 1:
			fpose = 1
		elif dash_phase == 2 or needle_t > 0.0:
			fpose = 2
		DDArt.femme(self, px, facing, clock, fpose, ink)
	elif kind == "troll":
		# picture only: the tree climbs over his head as the next swing comes due,
		# and is down in front of him the moment it lands
		var club := 0.45
		if state == S.ATTACK and interval > 0.0:
			club = clampf(1.0 - atk_cd / interval, 0.0, 1.0)
		DDArt.troll(self, px, facing, clock, club, ink)
	elif kind == "penny":
		var ppose := 0
		var ppf := 0.0
		var look := facing
		if jumping:
			ppose = 3
			ppf = clampf(jump_t / maxf(0.1, float(dodge_cfg.get("jump_time", 0.35))), 0.0, 1.0)
		elif dodging:
			var ptotal: float = maxf(0.1, float(dodge_cfg["time"]))
			var pback: float = ptotal * 0.3
			if dodge_t <= pback:
				ppose = 1
				ppf = dodge_t / pback
			else:
				ppose = 2
				ppf = clampf((dodge_t - pback) / (ptotal - pback), 0.0, 1.0)
			# eyes stay on whoever she just hit, so the circle is run sideways
			# (picture only: the real facing is left alone)
			if absf(dodge_center.x - position.x) > 1.0:
				look = signf(dodge_center.x - position.x)
		DDArt.penny(self, px, look, clock, ppose, ppf, ink, arena.team_color(int(team)))
	else:
		DDArt.creature(self, kind, px, facing, clock, 0.0, phase2, ink, flying)
	if status == Status.SLOW:
		draw_circle(Vector2.ZERO, px * 1.15, Color(0.18, 0.32, 0.85, 0.45))
		draw_arc(Vector2.ZERO, px * 1.15, 0.0, TAU, 20, Color(0.35, 0.55, 1.0, 0.6), 2.0, true)
	elif status == Status.BURN:
		var c := burn_color(burn_ticks, burn_max_ticks)
		var pulse := 0.2 + 0.5 * burn_pulse
		draw_circle(Vector2.ZERO, px * (1.08 + 0.18 * burn_pulse), Color(c.r, c.g, c.b, pulse))
		draw_arc(Vector2.ZERO, px * (1.08 + 0.18 * burn_pulse), 0.0, TAU, 20,
			Color(c.r, c.g, c.b, 0.5 + 0.4 * burn_pulse), 2.0, true)
	if hurt_frames > 0:
		draw_circle(Vector2.ZERO, px * 1.0, Color(1.0, 0.55, 0.72, 0.62))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if poison > 0.0:
		DDArt.poison_badge(self, Vector2(-px - 4.0, -px - 4.0 - lift), poison, poison_timer / POISON_PERIOD)
	if swing_t > 0.0:
		# the cleave: the blade sweeps the arc and leaves a fading wake behind it
		var sf: float = 1.0 - swing_t / SWING_SHOW
		var ang: float = lerpf(swing_from, swing_to, ease(sf, 0.5))
		var blade_px: float = float(sword_cfg["length"]) * float(arena.TILE)
		draw_arc(Vector2.ZERO, blade_px * 0.78, swing_from, ang, 24,
			Color(1.0, 1.0, 1.0, 0.34 * (1.0 - sf * 0.6)), blade_px * 0.4, true)
		var along := Vector2.from_angle(ang)
		DDArt.greatsword(self, along * px * 0.7, along * blade_px, px * 0.5, ink)
	elif slam_t > 0.0:
		# the overhead: blade buried along the line, a shock running on behind it
		var kf: float = slam_t / SLAM_SHOW
		var blade_px2: float = float(sword_cfg["length"]) * float(arena.TILE)
		var line_px: float = slam_len * float(arena.TILE)
		var wide: float = float(sword_cfg["leap_width"]) * 2.0 * float(arena.TILE)
		draw_line(Vector2.ZERO, leap_dir * line_px, Color(1.0, 1.0, 1.0, 0.4 * kf), wide * (0.4 + 0.6 * kf), true)
		DDArt.greatsword(self, leap_dir * px * 0.7, leap_dir * blade_px2, px * 0.5, ink)
	if whip_t > 0.0:
		# Gilgamesh's lash: the snake shoots out from his hand to the target in a
		# travelling wave, holds a beat with its jaws on it, and snaps back
		var wp: float = 1.0 - whip_t / WHIP_SHOW
		var ext: float = clampf(wp / 0.35, 0.0, 1.0)
		if wp > 0.7:
			ext = 1.0 - clampf((wp - 0.7) / 0.3, 0.0, 1.0)
		DDArt.snake_lash(self, DDArt.gilgamesh_hand(px, facing), whip_to - position, ext,
			clock, px * 0.2, arena.team_color(int(team)), ink)
	if beam_t > 0.0:
		# the Nekomancer's beam, staff tip to target, in her team's colour
		var bf: float = beam_t / BEAM_SHOW
		var from: Vector2 = DDArt.neko_staff_tip(px, facing)
		var to: Vector2 = beam_to - position
		var bc: Color = arena.team_color(int(team))
		draw_line(from, to, Color(bc.r, bc.g, bc.b, 0.35 * bf), px * 0.55 * bf + 2.0, true)
		draw_line(from, to, Color(bc.lightened(0.3).r, bc.lightened(0.3).g, bc.lightened(0.3).b, 0.9 * bf), px * 0.22 * bf + 1.0, true)
		draw_line(from, to, Color(1.0, 1.0, 1.0, 0.85 * bf), 1.2, true)
		draw_circle(to, px * (0.25 + 0.3 * (1.0 - bf)), Color(bc.r, bc.g, bc.b, 0.5 * bf))
		draw_circle(from, px * 0.22 * bf + 1.0, Color(1.0, 1.0, 1.0, 0.8 * bf))
	if staff_anim_t > 0.0:
		var tile_px: float = float(arena.TILE)
		var sp: float = 1.0 - staff_anim_t / STAFF_SHOW
		var held := Vector2(0.0, -px * 0.35)
		if staff_anim == 1:
			# the poke: the staff shoots out along the line and a streak runs on
			# through the pierce
			var reach_px: float = tile_px * (reach + radius_t) * sin(minf(sp * 1.6, 1.0) * PI * 0.5)
			var tip: Vector2 = held + staff_dir * (px * 0.6 + reach_px)
			var streak: float = tile_px * float(staff_cfg["pierce"]) * sp
			draw_line(tip, tip + staff_dir * streak, Color(1.0, 0.95, 0.75, 0.45 * (1.0 - sp)), px * 0.5, true)
			DDArt.gold_staff(self, tip - staff_dir * px * 2.6, tip, px * 0.13)
		else:
			# the sweep: the staff rakes across the cone, a pale wake behind it
			var sang: float = lerpf(staff_from, staff_to, ease(sp, 0.5))
			var slen: float = float(staff_cfg["sweep_len"]) * tile_px
			draw_arc(held, slen * 0.75, minf(staff_from, sang), maxf(staff_from, sang), 20,
				Color(1.0, 0.95, 0.75, 0.32 * (1.0 - sp * 0.6)), slen * 0.4, true)
			var sd := Vector2.from_angle(sang)
			DDArt.gold_staff(self, held - sd * px * 0.6, held + sd * slen, px * 0.13)
	if not needle_cfg.is_empty():
		var tip_px: float = float(needle_cfg["tip"]) * float(arena.TILE)
		if dash_phase == 1:
			# the glint on the raised tip: a four point star that swells as she is
			# about to go (the tip position matches DDArt.femme pose 1)
			var wf: float = 1.0 - clampf(dash_t / maxf(0.05, float(needle_cfg["windup"])), 0.0, 1.0)
			var at := Vector2(px * 0.42 * facing, -px * 4.2)
			var arm: float = px * (0.25 + 0.75 * sin(wf * PI))
			var spark := Color(1.0, 1.0, 1.0, 0.95)
			draw_line(at - Vector2(arm, 0.0), at + Vector2(arm, 0.0), spark, 2.0, true)
			draw_line(at - Vector2(0.0, arm), at + Vector2(0.0, arm), spark, 2.0, true)
			draw_line(at - Vector2(arm, arm) * 0.45, at + Vector2(arm, arm) * 0.45, spark, 1.4, true)
			draw_line(at - Vector2(arm, -arm) * 0.45, at + Vector2(arm, -arm) * 0.45, spark, 1.4, true)
		elif dash_phase == 2:
			# the lunge: needle levelled, a few streaks trailing behind her
			for i in 3:
				var back: Vector2 = -dash_dir * px * (1.0 + 0.9 * float(i))
				var side: Vector2 = dash_dir.orthogonal() * px * 0.45 * (float(i) - 1.0)
				draw_line(back + side, back + side - dash_dir * px * 1.4, Color(1.0, 1.0, 1.0, 0.4), 2.0, true)
			DDArt.needle(self, dash_dir * px * 0.5, dash_dir * tip_px, px * 0.2, ink)
		elif needle_t > 0.0:
			# a combo hit (or the dash landing): the flick sweeps in, a stab thrusts out
			var nf: float = 1.0 - needle_t / NEEDLE_SHOW
			var nang: float = lerp_angle(needle_from, needle_to, ease(nf, 0.4))
			var out_f: float = 1.0 if needle_from != needle_to else lerpf(0.72, 1.0, ease(nf, 0.3))
			var nd := Vector2.from_angle(nang)
			if needle_from != needle_to:
				draw_arc(Vector2.ZERO, tip_px * 0.85, needle_from, nang, 8, Color(1.0, 1.0, 1.0, 0.35), tip_px * 0.12, true)
			DDArt.needle(self, nd * px * 0.5, nd * tip_px * out_f, px * 0.2, ink)
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
	if hp < max_hp or not staff_cfg.is_empty():
		var w: float = px * 2.2
		var y2: float = -px - 10.0 - lift
		if not staff_cfg.is_empty():
			# his bars sit above the staff
			y2 -= px * 0.5
		draw_rect(Rect2(-w * 0.5, y2, w, 5.0), Color(0.08, 0.07, 0.1, 0.85), true)
		var frac := clampf(hp / max_hp, 0.0, 1.0)
		var col2 := Color(0.45, 0.9, 0.55) if team == 0 else Color(0.95, 0.45, 0.45)
		draw_rect(Rect2(-w * 0.5 + 1.0, y2 + 1.0, (w - 2.0) * frac, 3.0), col2, true)
		if not staff_cfg.is_empty():
			_draw_rage_bars(w, y2)


## Wu Cheng'en's bars: the rage threshold as a tick on the HP bar in the
## opponent's colour, and under it the rage bar. It fills once per rage level,
## each pass redder, laid over the colour of the level before it.
const RAGE_COLORS := [Color(1.0, 0.8, 0.55), Color(1.0, 0.52, 0.32), Color(0.95, 0.24, 0.16), Color(0.75, 0.04, 0.06)]
func _draw_rage_bars(w: float, y2: float) -> void:
	if not rage_used:
		var mark_x: float = -w * 0.5 + 1.0 + (w - 2.0) * float(staff_cfg["rage_hp"])
		draw_line(Vector2(mark_x, y2 - 2.0), Vector2(mark_x, y2 + 7.0), arena.team_color(1 - int(team)), 2.0)
	var levels: Array = staff_cfg["rage_levels"]
	var lv := rage_level()
	var y3: float = y2 + 6.0
	var under: Color = Color(0.08, 0.07, 0.1, 0.85) if lv == 0 else Color(RAGE_COLORS[lv - 1])
	draw_rect(Rect2(-w * 0.5, y3, w, 4.0), Color(0.08, 0.07, 0.1, 0.85), true)
	draw_rect(Rect2(-w * 0.5 + 1.0, y3 + 1.0, w - 2.0, 2.0), under, true)
	var fill := 1.0
	if lv < levels.size() - 1:
		var lo: float = float(levels[lv][0])
		var hi: float = float(levels[lv + 1][0])
		fill = clampf((float(rage_hits) - lo) / maxf(1.0, hi - lo), 0.0, 1.0)
	var top: Color = RAGE_COLORS[mini(lv, RAGE_COLORS.size() - 1)]
	draw_rect(Rect2(-w * 0.5 + 1.0, y3 + 1.0, (w - 2.0) * fill, 2.0), top, true)
	if rage_t > 0.0:
		# raging: the bar drains with the time left
		draw_rect(Rect2(-w * 0.5, y3 + 4.0, w * rage_t / float(staff_cfg["rage_time"]), 1.5), Color(1.0, 0.2, 0.15), true)
