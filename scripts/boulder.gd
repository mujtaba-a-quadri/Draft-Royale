class_name DDBoulder
extends Node2D

var dir := Vector2.UP
var area: Node2D = null
var team := 0
var speed_px := 620.0
var radius_t := 0.9
var dmg := 80.0
var hit: Dictionary = {}
var clock := 0.0
var travel := 0.0
var max_travel := 0.0


func setup(a: Node2D, d: Vector2, tm: int) -> void:
	area = a
	dir = d.normalized()
	team = tm
	max_travel = a.TILE * 13.0
	z_index = 14


func _physics_process(delta: float) -> void:
	clock += delta
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


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius_t * area.TILE * 1.15, Color(0.4, 0.36, 0.3, 0.18))
	DDArt.creature(self, "boulder", radius_t * area.TILE, 1.0, clock, 0.0, false)
