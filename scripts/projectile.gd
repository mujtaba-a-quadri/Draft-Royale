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


func setup(a: Node2D, f: Vector2, t: Vector2, tm: int, dm: float, sp: float, k: String,
		owner: int = 0, mode_s: String = "bolt", pierce_s: bool = false, owner_n: Node = null,
		speed_override: float = 0.0) -> void:
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
	if pierce:
		_pierce_hits()
	if f >= 1.0:
		if not pierce:
			_impact()
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
	if pierce:
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
			u.take_damage(dmg, position)


func _impact() -> void:
	area.release_reservation(owner_id)
	if splash > 0.0:
		var col := Color(0.5, 0.9, 0.45) if kind == "alchemist" else Color(1.0, 0.6, 0.2)
		area.spawn_splash_burst(to, splash, dmg, team, col)
	else:
		area.damage_at_point(to, 0.0, dmg, team)


func _draw() -> void:
	var back := phase == Phase.BACK
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
