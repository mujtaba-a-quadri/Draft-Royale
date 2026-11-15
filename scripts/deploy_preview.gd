class_name DDDeployPreview
extends Node2D

## Ghost preview for the armed card: swarm units are drawn as the whole
## formation, tinted the colour of the side that is placing them.

var arena = null
var kind := ""
var team := 0


func show_for(k: String, tm: int, at: Vector2) -> void:
	kind = k
	team = tm
	position = at
	visible = true
	modulate = Color(0.72, 0.88, 1.0, 0.62) if tm == 0 else Color(1.0, 0.78, 0.78, 0.62)
	queue_redraw()


func hide_preview() -> void:
	visible = false


func _draw() -> void:
	if arena == null or kind == "":
		return
	var tile: float = arena.TILE
	var data: Dictionary = DDCard.get_card(kind)
	if String(data["type"]) == "spell":
		DDArt.icon(self, kind, Vector2.ZERO, tile * 0.44, arena.clock)
		return
	var offs: Array = data.get("swarm_offsets", [])
	if offs.is_empty():
		DDArt.icon(self, kind, Vector2.ZERO, tile * 0.44, arena.clock)
		return
	var ydir := -1.0 if team == 0 else 1.0
	for off in offs:
		DDArt.icon(self, kind, Vector2(float(off[0]), float(off[1]) * ydir) * tile, tile * 0.44, arena.clock)
