class_name DDCardFace
extends RefCounted

## Compact TCG-style card face: cost medallion, name, HP, tall art, stat strip and
## the attack line. No flavour text — this is the in-hand version.

const OUT := Color(0.13, 0.12, 0.16)
const ATTACK_NAMES := {
	"dragon": "Claw", "chicken": "Pecking Fire", "fu": "Boomerang",
	"slate": "Jawbreaker", "hawk": "Dive", "hedgehog": "Quills",
	"hero": "Sword", "alchemist": "Splash Potion", "zombie": "Claw",
	"snowman": "—", "idol": "Taunt", "lizard": "Spear", "warren": "Burrow",
	"fireball": "Fireball", "firebolt": "Firebolt",
}


static func hp_text(d: Dictionary) -> String:
	var hp := int(d["hp"])
	var n := int(d.get("count", 0))
	if d.has("swarm_offsets") and n <= 1:
		n = (d["swarm_offsets"] as Array).size()
	if n > 1:
		return "%d ×%d" % [hp, n]
	if hp <= 0:
		return "—"
	return str(hp)


static func rate_text(d: Dictionary) -> String:
	var parts: Array = []
	var iv := float(d.get("interval", 0.0))
	if iv > 0.0:
		parts.append("%.2fs" % iv)
	var n := int(d.get("count", 1))
	if d.has("swarm_offsets") and n <= 1:
		n = (d["swarm_offsets"] as Array).size()
	if n > 1:
		parts.append("×%d" % n)
	if d.has("burn"):
		parts.append("burn %d" % int(d["burn"]))
	if d.has("knock"):
		parts.append("shove %.1f" % float(d["knock"]))
	var reach := float(d.get("reach", 0.0))
	if reach > 0.0:
		parts.append("r%.1f" % reach)
	return " · ".join(parts)


static func draw(ci: CanvasItem, kind: String, rect: Rect2, alpha: float = 1.0) -> void:
	if kind == "" or rect.size.x < 30.0:
		return
	var d: Dictionary = DDCard.get_card(kind)
	var accent: Color = d["accent"]
	var font := ThemeDB.fallback_font
	var a := clampf(alpha, 0.0, 1.0)
	var sc := rect.size.x / 190.0
	var head_h := rect.size.y * 0.2
	# body
	ci.draw_rect(rect, Color(0.96, 0.93, 0.85, a))
	ci.draw_rect(rect, Color(0.13, 0.12, 0.16, a), false, 2.0 * sc)
	# header band
	ci.draw_rect(Rect2(rect.position, Vector2(rect.size.x, head_h)), Color(accent.darkened(0.4), a))
	# cost medallion
	var cr := head_h * 0.42
	var cc := rect.position + Vector2(cr + 4.0 * sc, head_h * 0.5)
	ci.draw_circle(cc, cr, Color(0.12, 0.1, 0.16, a))
	ci.draw_circle(cc, cr, Color(accent.lightened(0.3), a), false, 1.5 * sc)
	ci.draw_string(font, cc + Vector2(-cr, cr * 0.42), str(int(d["cost"])), HORIZONTAL_ALIGNMENT_CENTER,
		cr * 2.0, int(15.0 * sc), Color(1, 1, 1, a))
	# name + hp
	ci.draw_string(font, rect.position + Vector2(head_h * 0.95, head_h * 0.68), String(d["name"]),
		HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - head_h * 1.9, int(12.0 * sc), Color(1, 1, 1, a))
	ci.draw_string(font, rect.position + Vector2(rect.size.x * 0.45, head_h * 0.68), hp_text(d),
		HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x * 0.53, int(11.0 * sc), Color(1.0, 0.95, 0.8, a))
	# art
	var art := Rect2(rect.position + Vector2(4.0 * sc, head_h + 3.0 * sc),
		Vector2(rect.size.x - 8.0 * sc, rect.size.y * 0.44))
	for i in 8:
		var f := float(i) / 7.0
		ci.draw_rect(Rect2(art.position.x, art.position.y + f * art.size.y, art.size.x, art.size.y / 7.0 + 1.0),
			Color(accent.lightened(0.70 - f * 0.3), a))
	ci.draw_set_transform(art.get_center() + Vector2(0, art.size.y * 0.16), 0.0, Vector2.ONE)
	if kind == "dragon":
		DDArt.dragon(ci, art.size.y * 0.42, 1.0, 0.0, false)
	elif kind == "hawk":
		DDArt.bird(ci, art.size.y * 0.36, 1.0, 0.0, true)
	else:
		DDArt.creature(ci, kind, art.size.y * 0.36, 1.0, 0.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ci.draw_rect(art, Color(0.13, 0.12, 0.16, a), false, 1.5 * sc)
	# stat strip
	var sy := art.end.y + 2.0 * sc
	ci.draw_rect(Rect2(rect.position.x + 2.0 * sc, sy, rect.size.x - 4.0 * sc, rect.size.y * 0.08),
		Color(accent.lightened(0.55), a))
	ci.draw_string(font, Vector2(rect.position.x + 5.0 * sc, sy + rect.size.y * 0.06), String(d["type"]).to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, int(9.0 * sc), Color(0.3, 0.26, 0.22, a))
	var spd := float(d.get("speed", 0.0))
	var rt := "STAT" if bool(d.get("stationary", false)) else ("%.2f t/s" % spd if spd > 0.0 else "")
	ci.draw_string(font, Vector2(rect.position.x, sy + rect.size.y * 0.06), rt, HORIZONTAL_ALIGNMENT_RIGHT,
		rect.size.x - 5.0 * sc, int(9.0 * sc), Color(0.3, 0.26, 0.22, a))
	# attack box
	var atk_y := sy + rect.size.y * 0.08 + 2.0 * sc
	var atk := Rect2(rect.position.x + 3.0 * sc, atk_y, rect.size.x - 6.0 * sc, rect.end.y - atk_y - 3.0 * sc)
	ci.draw_rect(atk, Color(accent.lightened(0.45), a))
	ci.draw_rect(atk, Color(0.13, 0.12, 0.16, a), false, 1.2 * sc)
	var dmg := int(d.get("dmg", 0))
	ci.draw_string(font, atk.position + Vector2(5.0 * sc, atk.size.y * 0.45), String(ATTACK_NAMES.get(kind, "Attack")),
		HORIZONTAL_ALIGNMENT_LEFT, atk.size.x * 0.6, int(10.0 * sc), Color(0.16, 0.12, 0.1, a))
	ci.draw_string(font, atk.position + Vector2(atk.size.x * 0.5, atk.size.y * 0.45), str(dmg) if dmg > 0 else "—",
		HORIZONTAL_ALIGNMENT_RIGHT, atk.size.x * 0.5 - 5.0 * sc, int(14.0 * sc), Color(accent.darkened(0.35), a))
	ci.draw_string(font, atk.position + Vector2(5.0 * sc, atk.size.y * 0.85), rate_text(d),
		HORIZONTAL_ALIGNMENT_LEFT, atk.size.x - 10.0 * sc, int(8.0 * sc), Color(0.32, 0.28, 0.24, a))
