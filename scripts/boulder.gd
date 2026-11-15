class_name DDBoulder
extends Node2D

var dir := Vector2.UP
var area: Node2D = null
var team := 0
var speed_px := 240.0
var radius_t := 0.9
var dmg := 80.0
var hit: Dictionary = {}
var clock := 0.0
var travel := 0.0
var max_travel := 0.0
var delay := 1.0
var armed := false
var epicenter := Vector2.ZERO
const SUCK_RADIUS := 3.0
const SUCK_SPEED := 1.0


func setup(a: Node2D, d: Vector2, tm: int, delay_s: float = 1.0, epic: Vector2 = Vector2.ZERO) -> void:
	area = a
	dir = d.normalized()
	team = tm
	delay = delay_s
	epicenter = epic
	armed = delay_s <= 0.0
	max_travel = a.TILE * 13.0
	z_index = 14


func _physics_process(delta: float) -> void:
	clock += delta
	if not armed:
		_suck(delta)
		if clock >= delay:
			armed = true
		queue_redraw()
		return
	var step := speed_px * delta
	position += dir * step
	travel += step
	for u in area.enemy_units(team):
		if not is_instance_valid(u) or u.dead:
			continue
		var key: int = u.get_instance_id()
		if hit.has(key):
			continue
		if area.tiles_between(position, u.position) <= radius_t + float(u.get_radius_t()):
			hit[key] = true
			var push: Vector2 = u.position - position
			if push.length() < 0.01:
				push = dir
			u.take_damage(dmg, position)
			if u.has_method("apply_impulse"):
				u.apply_impulse(push.normalized(), 2.0, 0.3)
			if u.get("stunned") != null:
				u.stunned = 2.0
	if travel >= max_travel or not area.rect_for_arena().grow(40.0).has_point(position):
		queue_free()
	queue_redraw()


## The collapsing idol drags enemies inward at 1 tile/s while it rumbles.
func _suck(delta: float) -> void:
	for u in area.units.duplicate():
		if not is_instance_valid(u) or u.dead:
			continue
		if int(u.team) == team:
			continue
		var to: Vector2 = epicenter - u.position
		if to.length() > SUCK_RADIUS * float(area.TILE):
			continue
		if to.length() < 2.0:
			continue
		u.position += to.normalized() * SUCK_SPEED * float(area.TILE) * delta


func _draw() -> void:
	if not armed:
		# the idol's rubble grinds in place before the boulder breaks loose
		var f := clampf(clock / maxf(delay, 0.01), 0.0, 1.0)
		var off: Vector2 = epicenter - position
		var rr: float = radius_t * float(area.TILE) * (1.0 + 0.6 * f)
		draw_arc(off, SUCK_RADIUS * float(area.TILE), 0.0, TAU, 40, Color(0.9, 0.7, 0.3, 0.12 + 0.2 * f), 2.0, true)
		draw_arc(off, rr, 0.0, TAU, 28, Color(0.9, 0.7, 0.3, 0.25 + 0.45 * f), 2.0, true)
		draw_circle(off, radius_t * area.TILE * 0.5, Color(0.6, 0.5, 0.3, 0.35))
		for i in 6:
			var a := TAU * float(i) / 6.0 + clock * 8.0
			var p: Vector2 = off + Vector2(cos(a), sin(a)) * rr * 0.9
			draw_circle(p, 2.0, Color(0.85, 0.75, 0.5, 0.5))
		return
	draw_circle(Vector2.ZERO, radius_t * area.TILE * 1.15, Color(0.4, 0.36, 0.3, 0.18))
	DDArt.creature(self, "boulder", radius_t * area.TILE, 1.0, clock, 0.0, false)
