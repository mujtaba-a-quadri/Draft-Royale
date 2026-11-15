class_name DDShiesty
extends Node2D

## Hero ability "Shiesty": leaps from your king tower onto the enemy tower with
## the most HP (leftmost on ties), hits it once and steals 1 gold. Then it runs
## home — reaching your tower keeps the gold, dying hands it back.
##
## Shiesty is a thief, not a soldier: it gives its owner no map presence and
## towers ignore it entirely. Only troops can stop it.

enum P { LAND, RETURN }

var kind := "shiesty"
var arena: Node2D = null
var team := 0
var hp := 40.0
var max_hp := 40.0
var dmg := 30.0
var interval := 1.0
var flying := false
var gives_presence := false
var tower_ignore := true
var dead := false
var incoming := 0.0
var phase: int = P.LAND
var clock := 0.0
var land_time := 0.7
var from := Vector2.ZERO
var target_tower: Node = null
var home_tower: Node = null
var stolen := 0.0
var speed_px := 60.0
var radius_t := 0.4
var run_clock := 0.0


func setup(a: Node2D, tm: int, tower: Node, home: Node) -> void:
	arena = a
	team = tm
	target_tower = tower
	home_tower = home
	from = home.position if home != null else Vector2.ZERO
	position = from
	speed_px = 1.8    * float(a.TILE)
	z_index = 9


func is_building() -> bool:
	return false


func is_tower() -> bool:
	return false


func get_radius_t() -> float:
	return radius_t


func _physics_process(delta: float) -> void:
	if dead:
		return
	clock += delta
	if phase == P.LAND:
		var to: Vector2 = from
		if is_instance_valid(target_tower):
			to = target_tower.position
		var f := clampf(clock / land_time, 0.0, 1.0)
		position = from.lerp(to, f) - Vector2(0, sin(f * PI) * 80.0)
		queue_redraw()
		if f >= 1.0:
			_land()
		return
	run_clock += delta
	var home: Vector2 = from
	if is_instance_valid(home_tower):
		home = home_tower.position
	var wp: Vector2 = arena.route_point(position, home)
	var dir: Vector2 = wp - position
	if dir.length() < 2.0:
		dir = home - position
	if position.distance_to(home) < float(arena.TILE) * 1.2:
		_escape()
		return
	if dir.length() > 0.001:
		position += dir.normalized() * speed_px * delta
	queue_redraw()


func _land() -> void:
	if is_instance_valid(target_tower) and not target_tower.dead:
		target_tower.take_damage(dmg, position)
	var enemy_team := 1 - team
	var steal: float = minf(1.0, float(arena.gold[enemy_team]))
	if steal > 0.0:
		arena.gold[enemy_team] = float(arena.gold[enemy_team]) - steal
	stolen = steal
	arena.banner_flash("Shiesty picks a pocket! %d gold taken" % int(steal))
	phase = P.RETURN
	clock = 0.0
	queue_redraw()


func _escape() -> void:
	arena.stat_shiesty_escaped += 1
	arena.gold[team] = minf(float(arena.gold_max), float(arena.gold[team]) + stolen)
	arena.banner_flash("Shiesty gets away with %d gold" % int(stolen))
	_finish()


func take_damage(amount: float, _from: Vector2, _attacker: Node = null) -> void:
	if dead or amount <= 0.0:
		return
	hp -= amount
	if hp <= 0.0:
		var enemy_team := 1 - team
		arena.stat_shiesty_caught += 1
		if stolen > 0.0:
			arena.gold[enemy_team] = minf(float(arena.gold_max), float(arena.gold[enemy_team]) + stolen)
			arena.banner_flash("Shiesty is caught — %d gold recovered" % int(stolen))
		_finish()
	queue_redraw()


func _finish() -> void:
	if dead:
		return
	dead = true
	arena.unregister(self)
	queue_free()


func _draw() -> void:
	var r: float = radius_t * float(arena.TILE)
	var bob := sin(run_clock * 12.0) * r * 0.18
	if phase == P.LAND:
		draw_arc(Vector2.ZERO, r * 1.2, 0.0, TAU, 20, Color(1.0, 0.9, 0.4, 0.35), 2.0, true)
	var skin := Color(0.45, 0.78, 0.36)
	draw_circle(Vector2(0, bob), r * 0.75, skin)
	draw_arc(Vector2(0, bob), r * 0.75, 0.0, TAU, 20, DDArt.OUTLINE, 2.0, true)
	draw_circle(Vector2(-r * 0.25, -r * 0.2 + bob), r * 0.12, Color(0.1, 0.09, 0.12))
	draw_circle(Vector2(r * 0.25, -r * 0.2 + bob), r * 0.12, Color(0.1, 0.09, 0.12))
	draw_circle(Vector2(r * 0.9, r * 0.3 + bob), r * 0.45, Color(0.82, 0.7, 0.4))
	draw_arc(Vector2(r * 0.9, r * 0.3 + bob), r * 0.45, 0.0, TAU, 16, DDArt.OUTLINE, 1.6, true)
	if hp < max_hp:
		var w := r * 2.0
		draw_rect(Rect2(-w * 0.5, -r * 1.6, w, 3.0), Color(0.1, 0.08, 0.12, 0.8), true)
		draw_rect(Rect2(-w * 0.5, -r * 1.6, w * clampf(hp / max_hp, 0.0, 1.0), 3.0), Color(0.5, 0.9, 0.5), true)
