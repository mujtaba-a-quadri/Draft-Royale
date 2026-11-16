class_name DDProjectile
extends Node2D

## Projectile lifecycle primitive.
##   mode "bolt"    fire and forget at a point (towers)
##   mode "splash"  same, but detonates a splash radius on arrival (alchemist)
##   mode "return"  flies out, hits once, then comes back to its owner and can be
##                  caught (calls owner.catch_boomerang())
##   pierce         damage every enemy crossed instead of stopping at the target
##
## owner_id is the attacking unit's instance id so the overkill reservation is
## released on impact.

enum Phase { OUT, BACK }

var from := Vector2.ZERO
var to := Vector2.ZERO
var team := 0
var dmg := 0.0
var splash := 0.0
var kind := "tower"
var mode := "bolt"
var pierce := false
var owner_id := 0
var owner_node: Node = null
var area: Node2D = null
var speed_px := 900.0
var clock := 0.0
var done := false
var radius_px := 6.0
var phase := Phase.OUT
var travel := 0.0
var leg := 1.0
var hit: Dictionary = {}
var spin := 0.0
var home_point := Vector2.ZERO
var target_node: Node = null
var burn := 0.0
var burn_ticks := 4
## Seconds of paralysis applied to whatever this hits (Pen's blowgun).
var stun := 0.0
## Shotgun pellet: the first body it crosses takes it, and then it is spent. No
## pierce, and it does not need a locked target.
var first_hit := false
var knock_tiles := 0.0
var tower_mult := 1.0
var spell_blast := false


func setup(a: Node2D, f: Vector2, t: Vector2, tm: int, dm: float, sp: float, k: String,
		owner: int = 0, mode_s: String = "bolt", pierce_s: bool = false, owner_n: Node = null,
		speed_override: float = 0.0, target_n: Node = null, payload: Dictionary = {}) -> void:
	target_node = target_n
	burn = float(payload.get("burn", 0.0))
	burn_ticks = int(payload.get("burn_ticks", 4))
	stun = float(payload.get("stun", 0.0))
	first_hit = bool(payload.get("first_hit", false))
	knock_tiles = float(payload.get("knock", 0.0))
	tower_mult = float(payload.get("tower_mult", 1.0))
	spell_blast = bool(payload.get("spell", false))
	area = a
	from = f
	to = t
	team = tm
	dmg = dm
	splash = sp
	kind = k
	owner_id = owner
	owner_node = owner_n
	if mode_s == "bolt" and sp > 0.0:
		mode = "splash"
	else:
		mode = mode_s
	pierce = pierce_s
	leg = maxf(f.distance_to(t), 1.0)
	home_point = f
	if owner_n != null and is_instance_valid(owner_n):
		home_point = owner_n.position
	if speed_override > 0.0:
		speed_px = speed_override
	z_index = 12
	if kind == "alchemist":
		radius_px = 9.0
	elif kind == "tower":
		radius_px = 5.0
	position = from


func _physics_process(delta: float) -> void:
	if done:
		return
	clock += delta
	spin += delta * 9.0
	if clock > 5.0:
		queue_free()
		return
	if phase == Phase.OUT:
		_travel_out(delta)
	else:
		_travel_back(delta)
	queue_redraw()


func _travel_out(delta: float) -> void:
	travel += speed_px * delta
	var f := clampf(travel / leg, 0.0, 1.0)
	position = from.lerp(to, f)
	# a shotgun pellet: whichever body it reaches first eats it, then it is done
	if first_hit:
		for u in area.enemy_units(team):
			if not is_instance_valid(u) or u.dead:
				continue
			var uid: int = u.get_instance_id()
			if hit.has(uid):
				continue
			if area.tiles_between(position, u.position) <= 0.3 + float(u.get_radius_t()):
				hit[uid] = true
				if dmg > 0.0:
					var src: Node = owner_node if is_instance_valid(owner_node) else null
					u.take_damage(dmg, position, src)
				_finish_out()
				return
	# a boomerang only strikes the thing it was aimed at on the way out
	if target_node != null and is_instance_valid(target_node):
		var id: int = target_node.get_instance_id()
		if not hit.has(id):
			var tr := 0.55 + float(target_node.get_radius_t())
			if area.tiles_between(position, target_node.position) <= tr:
				hit[id] = true
				if dmg > 0.0:
					# credit the shooter, not the bolt: a hedgehog's quills need to
					# know who to poke back at
					var src: Node = owner_node if is_instance_valid(owner_node) else null
					target_node.take_damage(dmg, position, src)
				if stun > 0.0 and target_node.get("stunned") != null:
					target_node.stunned = maxf(float(target_node.stunned), stun)
				if burn > 0.0 and target_node.has_method("apply_burn"):
					target_node.apply_burn(burn, burn_ticks)
				_finish_out()
				return
	elif pierce:
		_pierce_hits()
	if f >= 1.0:
		if target_node == null and not pierce:
			_impact()
		_finish_out()


func _finish_out() -> void:
	if mode == "return":
		phase = Phase.BACK
		from = position
		travel = 0.0
	else:
		done = true
		queue_free()


func _travel_back(delta: float) -> void:
	# Homing, not a lerp: the owner can be displaced (kicked, etc.) while the
	# boomerang is out, so the return leg has to chase his live position. If he
	# died, home_point keeps the last place he held and it flies back there.
	if owner_node != null and is_instance_valid(owner_node):
		home_point = owner_node.position
	var step := speed_px * delta
	var dir := home_point - position
	if dir.length() <= maxf(step, 4.0):
		position = home_point
		if owner_node != null and is_instance_valid(owner_node) and owner_node.has_method("catch_projectile"):
			owner_node.catch_projectile()
		done = true
		queue_free()
		return
	position += dir.normalized() * step
	# coming home it can still clip anything closer than the target, once each
	if mode == "return" or pierce:
		_pierce_hits()


func _pierce_hits() -> void:
	for u in area.enemy_units(team):
		if not is_instance_valid(u) or u.dead:
			continue
		var key: int = u.get_instance_id()
		if hit.has(key):
			continue
		if area.tiles_between(position, u.position) <= 0.6 + float(u.get_radius_t()):
			hit[key] = true
			u.take_damage(dmg, position, owner_node if is_instance_valid(owner_node) else null)
			if burn > 0.0 and u.has_method("apply_burn"):
				u.apply_burn(burn, burn_ticks)


func _impact() -> void:
	area.release_reservation(owner_id)
	if spell_blast:
		area.spell_blast(to, splash, dmg, team, tower_mult, burn, knock_tiles, kind, burn_ticks)
		return
	if splash > 0.0:
		area.damage_at_point(to, splash, dmg, team, tower_mult)
		if burn > 0.0:
			area.apply_burn_at(to, splash, burn, team)
	else:
		area.damage_at_point(to, 0.0, dmg, team, tower_mult)
		if burn > 0.0:
			area.apply_burn_at(to, 0.0, burn, team)


func _draw() -> void:
	var back := phase == Phase.BACK
	if kind == "firebolt" or kind == "fireball":
		var fl: float = 1.0 + 0.18 * sin(clock * 22.0)
		draw_circle(Vector2.ZERO, 7.0 * fl, Color(1.0, 0.45, 0.12, 0.55))
		draw_circle(Vector2.ZERO, 4.0 * fl, Color(1.0, 0.75, 0.3))
		draw_arc(Vector2.ZERO, 7.0 * fl, 0.0, TAU, 16, Color(1.0, 0.9, 0.55, 0.8), 1.5, true)
		return
	if kind == "aphid":
		draw_circle(Vector2.ZERO, 3.6, Color(0.96, 0.86, 0.52))
		draw_circle(Vector2.ZERO, 1.9, Color(0.76, 0.46, 0.16))
		return
	if kind == "dart":
		draw_line(Vector2(-7, 0), Vector2(7, 0), Color(0.55, 0.42, 0.2), 2.0, true)
		draw_circle(Vector2(7, 0), 2.2, Color(0.9, 0.85, 0.6))
		draw_line(Vector2(-7, 0), Vector2(-11, 0), Color(0.8, 0.3, 0.35), 2.5, true)
		return
	if kind == "chicken":
		draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.55, 0.15, 0.85))
		draw_circle(Vector2.ZERO, 2.6, Color(1.0, 0.85, 0.4))
		return
	if kind == "rifle":
		draw_line(Vector2(-9, 0), Vector2(3, 0), Color(1.0, 0.86, 0.5, 0.9), 2.0, true)
		draw_circle(Vector2(4, 0), 2.2, Color(1.0, 0.95, 0.7))
		return
	if kind == "alchemist":
		draw_circle(Vector2.ZERO, radius_px, Color(0.55, 0.92, 0.5))
		draw_arc(Vector2.ZERO, radius_px, 0.0, TAU, 20, DDArt.OUTLINE, 2.0, true)
		draw_circle(Vector2(-2, -2), radius_px * 0.35, Color(1, 1, 1, 0.8))
	elif kind == "boomerang":
		draw_set_transform(Vector2.ZERO, spin, Vector2.ONE)
		draw_rect(Rect2(-radius_px * 1.6, -radius_px * 0.28, radius_px * 3.2, radius_px * 0.56), Color(0.86, 0.7, 0.32), true)
		draw_rect(Rect2(-radius_px * 1.6, -radius_px * 0.28, radius_px * 3.2, radius_px * 0.56), DDArt.OUTLINE, false, 1.8)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		var c := Color(1.0, 0.92, 0.6) if not back else Color(0.75, 0.9, 1.0)
		draw_circle(Vector2.ZERO, radius_px, c)
		draw_circle(Vector2.ZERO, radius_px * 0.5, Color(1, 1, 1))
