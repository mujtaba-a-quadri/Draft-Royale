class_name DDTentacle
extends Node2D

## Hero ability "Tentacle" (and the kraken's burrowing arms): bursts out of the
## ground under the enemy unit with the most HP, coils round it and holds it in
## place for 4 s, squeezing for `dmg` on the grab and every `interval` after. The
## ensnared side has to kill it (20 HP) to free their troop early.
##
## Drawn in the caster's team colour: a coil sized to the victim, front turns on
## this node (over the troop) and back turns on `back_layer` (under it). Every
## squeeze pulls the coil tighter for a moment.

const SQUEEZE_SHOW := 0.35

var kind := "tentacle"
var arena: Node2D = null
var team := 0
var hp := 20.0
var max_hp := 20.0
var dmg := 7.0
var interval := 1.6
var flying := false
var dead := false
var incoming := 0.0
var ensnared: Node = null
var clock := 0.0
var life := 4.0
## hitbox for the troops trying to cut it free (unchanged by the victim's size)
var radius_t := 0.55
## the coil's size: the victim's body (picture only)
var wrap_t := 0.55
## time to the next squeeze; 0 means the first one lands on the grab
var squeeze_cd := 0.0
## 1 right after a squeeze, easing back to 0 (picture only)
var squeeze := 0.0
var back_layer: Node2D = null


func setup(a: Node2D, tm: int, unit: Node) -> void:
	arena = a
	team = tm
	ensnared = unit
	z_index = 6
	if unit != null and is_instance_valid(unit) and unit.has_method("get_radius_t"):
		wrap_t = maxf(0.3, float(unit.get_radius_t()))


func _ready() -> void:
	# the turns behind the troop: one step under the units (z 5)
	back_layer = Node2D.new()
	back_layer.z_index = -2
	back_layer.draw.connect(_draw_back)
	add_child(back_layer)


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
	squeeze = maxf(0.0, squeeze - delta / SQUEEZE_SHOW)
	if clock >= life:
		_release()
		return
	if ensnared == null or not is_instance_valid(ensnared) or ensnared.dead:
		_release()
		return
	position = ensnared.position
	squeeze_cd -= delta
	if squeeze_cd <= 0.0:
		squeeze_cd += interval
		squeeze = 1.0
		ensnared.take_damage(dmg, position)
		if not is_instance_valid(ensnared) or ensnared.dead:
			_release()
			return
	queue_redraw()
	if back_layer != null:
		back_layer.queue_redraw()


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
	# the card is the payoff for the cast, and it arrives when the tentacle is done
	arena.draw_card(team)
	arena.unregister(self)
	queue_free()


# ---------------------------------------------------------------------- picture

## The whole tentacle as samples: [point, width, front?]. It rises out of the
## ground at the victim's back-right, winds up round the body (more turns for a
## bigger body) and the tip curls out over the top.
func _samples() -> Array:
	var rv: float = wrap_t * float(arena.TILE)
	var tight := 1.0 - 0.14 * squeeze
	var cw := rv * 1.08 * tight          # coil half-width
	var turns: float = clampf(wrap_t / 0.25, 2.0, 3.5)
	var low := rv * 0.8                  # lowest turn, round the feet
	var high := -rv * 0.85               # highest turn, round the chest
	var th := rv * (0.28 + 0.06 * squeeze)
	var out: Array = []
	# rise from the ground behind and to the right
	var root := Vector2(rv * 1.5, rv * 1.05)
	var start := Vector2(cos(0.0) * cw, low)
	for i in 6:
		var f := float(i) / 6.0
		var p := root.lerp(start, f) + Vector2(0.0, -sin(f * PI) * rv * 0.25)
		out.append([p, th * (1.25 - 0.2 * f), false])
	# the coil: angle 0 at the right edge; sin > 0 is the near side, over the troop
	var steps := int(turns * 20.0)
	for i in steps + 1:
		var s := float(i) / float(steps)
		var ang := s * turns * TAU
		var y := lerpf(low, high, s) + sin(ang) * cw * 0.32
		var p := Vector2(cos(ang) * cw, y)
		out.append([p, th * (1.0 - 0.25 * s), sin(ang) > -0.05])
	# the free end: out over the top and curling back down, swaying
	var last: Vector2 = out[out.size() - 1][0]
	var sway := sin(clock * 3.2) * 0.25
	for i in range(1, 13):
		var f := float(i) / 12.0
		var a := -PI * 0.5 + f * PI * 1.35 + sway * f
		var arm := rv * (0.9 + 0.5 * f)
		var c := last + Vector2(rv * 0.9, -rv * 0.15)
		var p := c + Vector2(cos(a + PI) * arm * (1.0 - 0.45 * f), sin(a + PI) * arm * 0.8)
		out.append([p, th * 0.75 * (1.0 - f * 0.85), true])
	return out


func _paint(ci: CanvasItem, front: bool) -> void:
	var col: Color = arena.team_color(team)
	var flesh := col.darkened(0.15)
	var shade := col.darkened(0.45)
	var ink: Color = arena.team_ink(team).darkened(0.25)
	var belly := col.lightened(0.5)
	var pts := _samples()
	# outline pass, then fill, so overlapping joints stay clean
	for pass_i in 2:
		for i in pts.size() - 1:
			if bool(pts[i][2]) != front:
				continue
			var a: Vector2 = pts[i][0]
			var b: Vector2 = pts[i + 1][0]
			var w: float = float(pts[i][1])
			if pass_i == 0:
				ci.draw_line(a, b, ink, w + 4.0, true)
				ci.draw_circle(b, (w + 4.0) * 0.5, ink)
			else:
				var c := flesh if front else shade
				ci.draw_line(a, b, c, w, true)
				ci.draw_circle(b, w * 0.5, c)
	if not front:
		return
	# a glossy ridge along the top and pale suckers along the underside
	for i in range(0, pts.size() - 1):
		if not bool(pts[i][2]):
			continue
		var a: Vector2 = pts[i][0]
		var b: Vector2 = pts[i + 1][0]
		var w: float = float(pts[i][1])
		var d := (b - a)
		if d.length() < 0.01:
			continue
		var n := Vector2(-d.y, d.x).normalized()
		if n.y > 0.0:
			n = -n
		ci.draw_line(a + n * w * 0.25, b + n * w * 0.25, col.lightened(0.25), maxf(1.0, w * 0.18), true)
		if i % 3 == 0:
			ci.draw_circle(a - n * w * 0.32, maxf(1.2, w * 0.17), belly)
			ci.draw_arc(a - n * w * 0.32, maxf(1.2, w * 0.17), 0.0, TAU, 10, shade, 1.0, true)


func _draw_back() -> void:
	if arena == null or dead:
		return
	var rv: float = wrap_t * float(arena.TILE)
	# ground rupture where it came up
	back_layer.draw_set_transform(Vector2(rv * 0.4, rv * 1.0), 0.0, Vector2(1.0, 0.4))
	back_layer.draw_circle(Vector2.ZERO, rv * 1.6, Color(0.12, 0.08, 0.1, 0.45))
	back_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_paint(back_layer, false)


func _draw() -> void:
	if arena == null:
		return
	var rv: float = wrap_t * float(arena.TILE)
	_paint(self, true)
	# hp pips above the victim
	var w := maxf(rv * 1.6, 24.0)
	var y := -rv * 2.2
	draw_rect(Rect2(-w * 0.5, y, w, 4.0), Color(0.1, 0.08, 0.12, 0.8), true)
	draw_rect(Rect2(-w * 0.5, y, w * clampf(hp / max_hp, 0.0, 1.0), 4.0), arena.team_color(team).lightened(0.3), true)
