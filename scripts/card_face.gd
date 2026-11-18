class_name DDCardFace
extends RefCounted

## Compact TCG-style card face: cost medallion, name, HP, tall art, stat strip and
## the attack line. No flavour text — this is the in-hand version.

const OUT := Color(0.13, 0.12, 0.16)
const ATTACK_NAMES := {
	"dragon": "Claw", "chicken": "Burst", "penny": "Swipes", "pen": "Blowgun", "obsidian": "Nip", "wu": "Staff", "neko": "Beam", "gilgamesh": "Serpent Lash", "enkidu": "Spear", "frog": "Poison Leap", "phalanx": "Spear", "wolves": "Bite", "meerkats": "Bite", "ant": "Bite", "anthill": "Ants","ratbones": "Bite","magma": "Flame Feathers","aphid": "Spit Spread", "fu": "Boomerang",
	"slate": "Jawbreaker", "hawk": "Dive", "hedgehog": "Quills",
	"hero": "Sword", "alchemist": "Splash Potion", "zombie": "Claw",
	"snowman": "—", "idol": "Taunt", "lizard": "Spear", "warren": "Burrow",
	"ovomachine": "Hatch", "laniakea": "Greatsword", "femme": "Needle",
	"kraken": "Red Orbs", "krakenarm": "Tentacle Slam",
	"spider": "Front Legs","spideregg": "—", "spiderling": "Venom Bite", "troll": "Tree Club",
	"fireball": "Fireball", "firebolt": "Firebolt", "snowball": "Snowball",
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


## The effect line under the attack name. Troops show their cadence and reach;
## buildings show what they do on their clock; spells show what they leave behind.
static func rate_text(d: Dictionary) -> String:
	var parts: Array = []
	if d.has("frog"):
		# no cadence to show: it goes off once
		var fc: Dictionary = d["frog"]
		return "poison · once · leap r%.1f" % float(fc["leap_range"])
	if d.has("pack"):
		# the pack bites in turn: one bite every interval / wolves
		var n_pack := (d["swarm_offsets"] as Array).size()
		return "a bite every %.1fs · ×%d · ring r%.0f" % [float(d["interval"]) / float(n_pack), n_pack,
			float((d["pack"] as Dictionary)["ring"])]
	var sum_cfg: Dictionary = d.get("summon", {})
	if not sum_cfg.is_empty():
		var spawn_iv := float(sum_cfg.get("interval", sum_cfg.get("cooldown", 0.0)))
		if spawn_iv <= 0.0:
			parts.append("spawn")
		elif is_equal_approx(spawn_iv, roundf(spawn_iv)):
			parts.append("spawn %.0fs" % spawn_iv)
		else:
			parts.append("spawn %.1fs" % spawn_iv)
	if d.has("lifetime") and float(d["lifetime"]) > 0.0:
		parts.append("%.0fs life" % float(d["lifetime"]))
	if d.has("roll"):
		parts.append("grows 1 tile / 2")
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
	if d.has("slow_time"):
		parts.append("slow %.1fs" % float(d["slow_time"]))
	if int(d.get("uses", 0)) > 1:
		parts.append("×%d casts" % int(d["uses"]))
	return " · ".join(parts)


## The art pane: one big creature for a single body, or — for a swarm — the
## whole formation, scaled to fit, so the card reads like the deploy preview.
static func _draw_art(ci: CanvasItem, kind: String, art: Rect2) -> void:
	var offsets: Array = DDCard.get_card(kind).get("swarm_offsets", [])
	if offsets.is_empty():
		ci.draw_set_transform(art.get_center() + Vector2(0, art.size.y * 0.14), 0.0, Vector2.ONE)
		if kind == "gilgamesh":
			DDArt.gil_pair(ci, art.get_center() + Vector2(0, art.size.y * 0.14), art.size.y * 0.3)
		elif kind == "dragon":
			DDArt.dragon(ci, art.size.y * 0.30, 1.0, 0.0, false)
		elif kind == "hawk":
			DDArt.bird(ci, art.size.y * 0.34, 1.0, 0.0, true)
		else:
			DDArt.creature(ci, kind, art.size.y * 0.34, 1.0, 0.0)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var half_x := 0.0
	var half_y := 0.0
	for off in offsets:
		half_x = maxf(half_x, absf(float((off as Array)[0])))
		half_y = maxf(half_y, absf(float((off as Array)[1])))
	# each body is one tile wide with a 0.44 tile radius, in the preview's units
	var unit_scale: float = minf(art.size.x / (half_x * 2.0 + 0.9), art.size.y / (half_y * 2.0 + 0.9))
	var centre := art.get_center()
	for i in offsets.size():
		var off: Array = offsets[i]
		# the preview mirrors a formation's y offsets for team 0 (ydir = -1); the
		# card art uses the same orientation so the two line up
		var at: Vector2 = centre + Vector2(float(off[0]), -float(off[1])) * unit_scale
		# the lead bird is the red i'iwi: the card shows it too
		DDArt.icon(ci, kind, at, unit_scale * 0.44, 0.0, i == 0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Largest integer size no bigger than start that fits the space, never below floor_size.
static func fitted(font: Font, text: String, avail: float, start: float, floor_size: float) -> int:
	var s := start
	while s > floor_size and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(s)).x > avail:
		s -= 1.0
	return int(maxf(s, floor_size))


## The full card: the in-hand face on top and the card's description (`blurb`)
## in a panel underneath, inside one frame. Used where there is room to read it
## (the reward screen). The text size steps down until the whole blurb fits.
static func draw_full(ci: CanvasItem, kind: String, rect: Rect2, alpha: float = 1.0) -> void:
	if kind == "" or rect.size.x < 60.0:
		return
	var d: Dictionary = DDCard.get_card(kind)
	var accent: Color = d["accent"]
	var font := ThemeDB.fallback_font
	var a := clampf(alpha, 0.0, 1.0)
	ci.draw_rect(rect, Color(0.93, 0.89, 0.8, a))
	var top := Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.66))
	draw(ci, kind, top, alpha)
	var box := Rect2(rect.position.x + 6.0, top.end.y + 6.0, rect.size.x - 12.0, rect.end.y - top.end.y - 12.0)
	ci.draw_rect(box, Color(0.97, 0.95, 0.89, a))
	ci.draw_rect(box, Color(accent.darkened(0.2).r, accent.darkened(0.2).g, accent.darkened(0.2).b, a), false, 1.5)
	var text := String(d.get("blurb", ""))
	var pad := 8.0
	var size := 17
	while size > 8 and font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - pad * 2.0, size).y > box.size.y - pad * 2.0:
		size -= 1
	ci.draw_multiline_string(font, box.position + Vector2(pad, pad + float(size) * 0.9), text,
		HORIZONTAL_ALIGNMENT_LEFT, box.size.x - pad * 2.0, size, -1, Color(0.2, 0.17, 0.14, a))
	ci.draw_rect(rect, Color(0.13, 0.12, 0.16, a), false, 3.0)


## cost_col overrides the cost medallion's digit — the hand uses it to flag a
## card the player cannot pay for yet.
static func draw(ci: CanvasItem, kind: String, rect: Rect2, alpha: float = 1.0,
		cost_col: Color = Color(0, 0, 0, 0), hide_art: bool = false) -> void:
	if kind == "" or rect.size.x < 26.0:
		return
	var d: Dictionary = DDCard.get_card(kind)
	var accent: Color = d["accent"]
	var font := ThemeDB.fallback_font
	var a := clampf(alpha, 0.0, 1.0)
	var w := rect.size.x
	var h := rect.size.y
	var head_h := h * 0.185
	ci.draw_rect(rect, Color(0.96, 0.93, 0.85, a))
	ci.draw_rect(rect, Color(0.13, 0.12, 0.16, a), false, 2.0)
	ci.draw_rect(Rect2(rect.position, Vector2(w, head_h)), Color(accent.darkened(0.4), a))
	var cr := head_h * 0.40
	var cc := rect.position + Vector2(cr + 3.0, head_h * 0.5)
	ci.draw_circle(cc, cr, Color(0.86, 0.68, 0.18, a))
	ci.draw_circle(cc + Vector2(-cr * 0.28, -cr * 0.28), cr * 0.38, Color(1.0, 0.94, 0.62, a * 0.9))
	ci.draw_arc(cc, cr, 0.0, TAU, 16, Color(0.45, 0.32, 0.05, a), 1.2, true)
	var cost_ink := Color(0.2, 0.18, 0.16, a)
	if cost_col.a > 0.0:
		cost_ink = Color(cost_col.r, cost_col.g, cost_col.b, a)
	ci.draw_string(font, cc + Vector2(-cr, cr * 0.44), str(int(d["cost"])), HORIZONTAL_ALIGNMENT_CENTER,
		cr * 2.0, int(clampf(cr * 1.5, 8.0, 18.0)), cost_ink)
	var name_avail := w - cr * 2.0 - 10.0
	var name_start: float = clampf(w * 0.155, 8.0, 19.0)
	var nm := DDCard.short_name(kind)
	var nsize := fitted(font, nm, name_avail, name_start, 9.0)
	if font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x > name_avail:
		nm = DDCard.tiny_name(kind)
		nsize = fitted(font, nm, name_avail, name_start, 7.0)
	ci.draw_string(font, rect.position + Vector2(cr * 2.0 + 6.0, head_h * 0.74), nm,
		HORIZONTAL_ALIGNMENT_CENTER, name_avail, nsize, Color(1, 1, 1, a))
	var art := Rect2(rect.position + Vector2(4.0, head_h + 2.0), Vector2(w - 8.0, h * 0.42))
	if not hide_art:
		for i in 8:
			var f := float(i) / 7.0
			ci.draw_rect(Rect2(art.position.x, art.position.y + f * art.size.y, art.size.x, art.size.y / 7.0 + 1.0),
				Color(accent.lightened(0.70 - f * 0.3), a))
		_draw_art(ci, kind, art)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ci.draw_rect(art, Color(0.13, 0.12, 0.16, a), false, 1.4)
	# HP ribbon under the art
	var bh := h * 0.105
	var bw := w * 0.86
	var br := Rect2(rect.position.x + (w - bw) * 0.5, art.end.y - bh * 0.55, bw, bh)
	ci.draw_rect(br, Color(accent.darkened(0.25), a))
	ci.draw_rect(br, Color(0.13, 0.12, 0.16, a), false, 1.4)
	var hp_txt := ""
	match String(d.get("type", "troop")):
		"spell":
			# no body to show: name the cast instead of an HP line
			hp_txt = "Spell · %s" % ("from your tower" if String(d.get("launch", "")) == "closest" else "cast")
		"building":
			hp_txt = "%d HP · %.0fs" % [int(d["hp"]), float(d.get("lifetime", 0.0))]
			var bfp: Array = d.get("footprint", [1, 1])
			if int(bfp[0]) > 1 or int(bfp[1]) > 1:
				hp_txt += " · %d×%d" % [int(bfp[0]), int(bfp[1])]
		_:
			hp_txt = "%d HP" % int(d["hp"])
			if d.has("partner"):
				hp_txt = "%d + %d HP" % [int(d["hp"]), int(DDCard.get_card(String(d["partner"]))["hp"])]
			var n := int(d.get("count", 0))
			if d.has("swarm_offsets") and n <= 1:
				n = (d["swarm_offsets"] as Array).size()
			if n > 1:
				hp_txt += " ×%d" % n
			hp_txt += " · %s" % String(d["type"]).capitalize()
	ci.draw_string(font, Vector2(br.position.x, br.position.y + bh * 0.74), hp_txt, HORIZONTAL_ALIGNMENT_CENTER,
		bw - 4.0, fitted(font, hp_txt, bw - 8.0, clampf(bh * 0.72, 7.0, 14.0), 6.0), Color(1.0, 0.97, 0.86, a))
	# attack box
	var atk_y := br.end.y + 3.0
	var atk := Rect2(rect.position.x + 3.0, atk_y, w - 6.0, rect.end.y - atk_y - 3.0)
	ci.draw_rect(atk, Color(accent.lightened(0.45), a))
	ci.draw_rect(atk, Color(0.13, 0.12, 0.16, a), false, 1.2)
	var dmg := int(d.get("dmg", 0))
	if d.has("frog"):
		dmg = int((d["frog"] as Dictionary)["poison"])
	var atk_name := String(ATTACK_NAMES.get(kind, "Attack"))
	var atk_avail := atk.size.x * 0.58 - 6.0
	ci.draw_string(font, atk.position + Vector2(5.0, atk.size.y * 0.42), atk_name,
		HORIZONTAL_ALIGNMENT_LEFT, atk_avail, fitted(font, atk_name, atk_avail, clampf(w * 0.10, 7.0, 14.0), 6.0),
		Color(0.16, 0.12, 0.1, a))
	var dmg_txt := str(dmg) if dmg > 0 else "—"
	var dmg_avail := atk.size.x * 0.58 - 4.0
	ci.draw_string(font, atk.position + Vector2(atk.size.x * 0.42, atk.size.y * 0.48), dmg_txt,
		HORIZONTAL_ALIGNMENT_RIGHT, dmg_avail, fitted(font, dmg_txt, dmg_avail, clampf(w * 0.16, 9.0, 24.0), 8.0),
		Color(accent.darkened(0.35), a))
	var rate := rate_text(d)
	ci.draw_string(font, atk.position + Vector2(5.0, atk.size.y * 0.82), rate,
		HORIZONTAL_ALIGNMENT_LEFT, atk.size.x - 8.0, fitted(font, rate, atk.size.x - 10.0, clampf(w * 0.066, 6.0, 11.0), 6.0),
		Color(0.32, 0.28, 0.24, a))
