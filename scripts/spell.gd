class_name DDSpell
extends Node2D

## Spells are fired out of one of the caster's towers, not dropped from the sky.
##   launch "closest"  the friendly tower nearest the target point
##   launch "king"     the king tower
## The node exists for one frame: it picks the tower, spawns the bolt and dies.

var kind := "fireball"
var team := 0
var area: Node2D = null
var dmg := 0.0
var radius_t := 1.0
var tower_mult := 1.0
var burn := 0.0
var knock := 0.0
var launch := "closest"
var fired := false


func setup(a: Node2D, k: String, tm: int) -> void:
	area = a
	kind = k
	team = tm
	var d: Dictionary = DDCard.get_card(k)
	dmg = float(d.get("dmg", 0.0))
	radius_t = float(d.get("splash", 0.0))
	tower_mult = float(d.get("tower_mult", 1.0))
	burn = float(d.get("burn", 0.0))
	knock = float(d.get("knock", 0.0))
	launch = String(d.get("launch", "closest"))
	z_index = 20


func _physics_process(_delta: float) -> void:
	if fired:
		return
	fired = true
	var origin: Vector2 = position
	var tw: Node = null
	if launch == "king":
		tw = area.crown_tower(team)
	if tw == null:
		tw = area.nearest_own_tower(team, position)
	if tw != null:
		origin = tw.position + Vector2(0.0, -float(area.TILE) * 0.9)
	area.spawn_projectile(origin, position, team, dmg, radius_t, kind,
		0, "bolt", false, null, 0.0, null,
		{"burn": burn, "knock": knock, "tower_mult": tower_mult, "spell": true})
	queue_free()
