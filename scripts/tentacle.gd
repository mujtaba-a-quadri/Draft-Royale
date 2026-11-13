class_name DDTentacle
extends Node2D

## Hero ability "Tentacle": bursts out of the ground, deals 20 on reveal, then
## holds the enemy unit with the most HP in place for 4 s. The ensnared side has
## to kill it (20 HP) to free their troop early.

var kind := "tentacle"
var arena: Node2D = null
var team := 0
var hp := 20.0
var max_hp := 20.0
var dmg := 0.0
var interval := 1.0
var flying := false
var dead := false
var incoming := 0.0
var ensnared: Node = null
var clock := 0.0
var life := 4.0
var radius_t := 0.55


func setup(a: Node2D, tm: int, unit: Node) -> void:
	arena = a
	team = tm
	ensnared = unit
	z_index = 6


func is_building() -> bool:
	return true


func is_tower() -> bool:
	return false


func get_radius_t() -> float:
	return radius_t


func _physics_process(delta: float) -> void:
	if dead:
		return
	clock += delta
	if clock >= life:
		_release()
		return
	if ensnared == null or not is_instance_valid(ensnared) or ensnared.dead:
		_release()
		return
	position = ensnared.position
	queue_redraw()


func take_damage(amount: float, _from: Vector2, _attacker: Node = null) -> void:
	if dead or amount <= 0.0:
		return
	hp -= amount
	if hp <= 0.0:
		arena.banner_flash("The tentacle is cut apart!")
		_release()
	queue_redraw()


func _release() -> void:
	if dead:
		return
	dead = true
	if is_instance_valid(ensnared) and ensnared.get("stunned") != null:
		ensnared.stunned = 0.0
	arena.unregister(self)
	queue_free()


func _draw() -> void:
	var r: float = radius_t * float(arena.TILE)
	var t := clock
	# ground rupture
	draw_set_transform(Vector2(0, r * 0.5), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, r * 1.25, Color(0.16, 0.1, 0.16, 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the tentacle itself, swaying
	var pts := PackedVector2Array()
	for i in 9:
		var f := float(i) / 8.0
		var y := r * 1.5 - f * r * 3.2
		var x := sin(t * 3.0 + f * 3.2) * r * 0.35 * f
		pts.append(Vector2(x, y))
	draw_polyline(pts, Color(0.42, 0.16, 0.45), r * 0.62, true)
	draw_polyline(pts, Color(0.6, 0.26, 0.62), r * 0.34, true)
	for i in 6:
		var f := float(i) / 5.0
		var p := pts[i]
		draw_circle(p, r * 0.11, Color(0.85, 0.55, 0.85))
	# grip ring on the victim
	draw_arc(Vector2.ZERO, r * 1.15, 0.0, TAU, 28, Color(0.75, 0.4, 0.8, 0.55), 2.0, true)
	# hp pips
	var w := r * 1.4
	draw_rect(Rect2(-w * 0.5, -r * 2.1, w, 4.0), Color(0.1, 0.08, 0.12, 0.8), true)
	draw_rect(Rect2(-w * 0.5, -r * 2.1, w * clampf(hp / max_hp, 0.0, 1.0), 4.0), Color(0.85, 0.45, 0.85), true)
