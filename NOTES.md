# Deep Draft — working notes (handoff at **0.4.2**)

Godot **4.7.2**, project `C:\Users\Arthur\Documents\Cooler\my games\Deep Draft`.
Read this plus `README.md` before touching anything. The README is the *product*
reference (rules, cards, numbers); this file is the *working* reference (where code
lives, how to verify, what is half-done and why).

State at handoff: 33 cards (31 dealt), 150 s matches with a final-minute surge,
commander-tower wins, threat-driven bot with a measurement harness, arena split
into rules / geometry / painting. Everything below was verified; nothing is
half-finished in the tree.

---

## 1. Where code lives

| file | lines | owns |
| --- | --- | --- |
| `arena.gd` | 1652 | the scene: board state, towers, gold, hands/queues/charges, deploy + staging rules, match clock + win conditions, hero abilities, effects spawners, input |
| `arena_draw.gd` | 282 | **all** arena painting (`DDArenaDraw`): board, deploy hint, hover box, HUD, result overlay |
| `board.gd` | 98 | `DDBoard`: grid constants, tile ⇄ screen maths, footprints. Pure statics |
| `unit.gd` | 1009 | troop AI + every per-card behaviour (see §5) |
| `card_db.gd` | 365 | the single balance surface: all card data + `ORDER` (deck) |
| `projectile.gd` | 246 | bolts/darts/pellets, payloads: `burn`, `stun`, `knock`, `first_hit` |
| `art.gd` | 738 | procedural outlined art; `creature()` for units, `icon()` for previews/cards |
| `card_face.gd` | 660 | `DDCardFace` — the trading-card face (hand, next slot, deck grid, reward screen), its attribute icons, `ATTACK_NAMES`, multi-hit `ATTACKS` |
| `hand_panel.gd` / `hand_card.gd` | 509 / 351 | per-player hand; `DDHandCard` owns a card's rect, hover, drag, fly-back tween |
| `card_grid.gd` | 233 | `DDCardGrid` — reusable filtered, scrolling card grid (debug overlay today; collection/deck view later) |
| `bot.gd` / `bot2.gd` | 295 / 304 | v1 flat utility scorer (baseline) / v2 perception+states |
| `bot_matrix.gd` | 61 | card roles (from card data) + the answers table |
| `bot_sim.gd` | 93 | headless A/B harness |
| `tentacle.gd` / `shiesty.gd` | 104 / 155 | the two hero abilities |
| `control_layer.gd` / `deploy_preview.gd` | 36 / 40 | cached lane-control tint, deploy ghost |
| `dev_capture.gd` | 1152 | dev-only scenarios (**never loaded unless a flag is passed**) |

`*_mock.gd` files are art/layout preview scenes, not game code.

`arena.gd` already delegates: geometry → `board.gd`, painting → `arena_draw.gd`.
Its remaining blocks are: teams/colours (~210-520), clock (~527), control (~734),
targeting API (~862), spawns (~1054), hero abilities (~1190), card play / deploy
(~1390), input, and thin render delegates. **`unit.gd` (1009) is the next
extraction candidate.**

---

## 2. Adding a card — the checklist

1. **`card_db.gd`**: entry in `CARDS` + push the kind onto `ORDER` (the deck) if it
   should be dealt. `all_kinds()` = `ORDER + ["pen"]` feeds the debug overlay.
2. **`art.gd`**: a pen in a new `_thing(ci, r, t, facing)` **and both dispatch tables** —
   `creature()` (board + card art) and `icon()` (deploy preview). Missing `icon` draws a
   magenta circle.
3. **`card_face.gd`**: add the attack name to `ATTACK_NAMES`.
4. **Behaviour** (only if it is not a plain melee/ranged unit): a data block in
   `card_db.gd` read in `unit.setup()` and a branch in `_attack()` or
   `_physics_process()`. Existing hooks:
   `boomerang` (Fu), `roll` (Slate), `curl` (hedgehog), `guard` (Obsidian Whelp: shares `curled`, opens on
   `guard_calm`), `becomes` (the card that takes this one's hand slot when played:
   Penny → Pen, Obsidian → Magma), `staff` (Wu Cheng'en: `_tick_staff`, staff
   draw-out, poke / sweep combo, rage on `take_damage`), `beam` (Nekomancer: the
   plain hit, drawn as a beam), `ritual` (Nekomancer: `_tick_ritual` spawns
   `pentagram.gd` nodes that raise the unit themselves), `partner` (a pair card:
   `arena.spawn_troop` lands the partner `partner_gap` tiles across the lane;
   card face shows both HPs, `DDArt.gil_pair` draws both), `whip` (Gilgamesh: the
   plain hit, drawn as a snake lash), `spear` (Enkidu: `_try_throw` / `_spear_back`
   swap dmg, reach, interval and `hits_air` while the spear is away), `frog` (Poison
   Dart Frog: `_tick_frog` hops instead of `_move`, `_frog_prey` / `_tick_frog_leap` /
   `_frog_burst`; no `_attack` at all), `shield` + `dagger` (Phalanx: the shield's
   own HP and raise/lower in `_physics_process` and `take_damage`, slower `_move`,
   `_attack_spartan` for poke / stab), `pack` (Wolf Pack: `arena.spawn_troop` gives
   every wolf one shared dictionary; the first living wolf runs `_tick_pack` —
   prey, arrival, ring spin, turn clock — and each runs `_tick_wolf`; no
   `_attack`), `summon.quiet` (no screen shake per spawn: the Ant Hill),
   `ram` + `wool` (Goat Rider: `_attack` swaps in the ram's damage on the first
   hit per target, `rammed` keyed by instance id; `take_damage` calls
   `_wool_hit`, which shoves a melee attacker whose blow came from its own body;
   `--scenario=goat`, `--scenario=goatart`),
   `trail` (ants: `_die` records a grave in `arena.ant_graves` stamped with
   `Engine.get_physics_frames()`; `_tick_ant` turns on entering a fresh grave
   tile, `_ant_turn` picks the other lane's side tower and backs `back` tiles
   down the trail, turned ants turn any ant they touch whose `move_dir` points
   the other way, and `_ant_waypoint` crosses by the goal lane's bridge through
   `arena.route_point(from, goal, bridge_col)`; `--scenario=antlane`. Ants are
   `buildings_only`; `_die` also marks the killer (`last_attacker`, never a
   tower) in `arena.ant_marks` until frame + `mark_time` s, and
   `_ant_marked_foe()` picks the closest marked killer within `aggro`, keeping
   one it already chases even out of sight until the mark ends;
   `--scenario=antaggro`),
   `chicken` + `kamikaze` (Hot Chicken,
   two phases), `spread` (Primal Aphid), `dodge` (Penny), `summon` (warren),
   `death_aoe` (snowman), `targets_weakest`, `troops_only`, `flying_unit`, `hits_air`,
   `stationary`, `lifetime`, `shoots` + `payload`, `greatsword` (Laniakea: owns its
   own targeting in `_tick_greatsword`, cleave + leap/slam), `needle` (Femme Fatale:
   `_tick_needle`, wind-up dash + three hit combo).
5. **Projectile** visuals live in `projectile._draw()` keyed by `kind`; effects that
   hit on impact read the payload dictionary.
6. **Bot roles are automatic** — `DDBotMatrix.roles_of()` derives them from card data.
   Only touch `bot_matrix.ANSWER` if the new card genuinely counters a role.
7. **`README.md`**: a row in the card table, and bump the deck-count line.

**Decks may contain duplicates.** Every copy has an id: `arena.hand_ids` /
`queue_ids` run parallel to `hands` / `queues` (which stay lists of kinds, so
bots and "what card is this" code are untouched). Hand nodes bind by id, the
held card is `arena.selection_id()`, Firebolt charges are keyed by id, a played
card cycles back as the same id, and a `becomes` card (Pen, Magma Whelp) is a new
id. Anything that rewrites a hand or deck wholesale gets fresh ids from
`_sync_ids()`; code that moves single cards must move the id with the kind.
`arena.deck_lists[p]` sets a deck (empty = one of each in `ORDER`, currently 31).
Hand 4, `HAND_MAX` 8. Draws every `DRAW_INTERVAL` 16 s, and every gold spent
takes `DRAW_PER_GOLD` 1 s off the wait (`spend_gold_draw()`; overflow carries).
Debug keys 1-3 (Tab view) give 2 gold and a card. Scenario:
`--scenario=dupes --bots=off`.

---

## 3. Making the bot better

**What exists.** `bot2.gd` reads the board (per-unit threat weight, per-tower
pressure, my own push value, weakest non-crown tower) → picks a state
(DEFEND / COUNTER / ATTACK / HOLD) → scores (card × anchor) with the role matrix →
one softmax pick (no dice when defending) → 0.55 s telegraph → deploy.
`bot.gd` (v1) is kept deliberately as the baseline for A/B runs.

**Measure before changing anything.** The harness is the whole point:

```
godot --headless --path . --fixed-fps 60 -- --botsim=<seed>      # v2 vs v1 (side flips by parity)
godot --headless --path . --fixed-fps 60 -- --botsim=<100+seed>  # control: v1 vs v1
```

One line per match, ~20-30 s wall for 150 s of game, **byte-identical for a given
seed** (verified 3×). Decks are seeded, abilities handed out evenly, sides alternate.
Score by remaining tower HP + who won, not by vibes. Last full measurement was
8 seeds at **5W-3L, +129 HP**; the card set and rules have changed since, so
**re-run the baseline before trusting that number.**

**Levers, in the order I would pull them:**

1. **The hero ability trigger is still dumb** — `DDBot._physics_process` fires it at
   gold ≥ 5 whenever valid. It should fire when the *payload pays*: tentacle when the
   burst finishes the target or the side can kill inside the hold (the logic exists in
   `_wants_tentacle`/`_wants_shiesty` — verify it is actually gating in a live run).
2. **The bot never closes matches** — most seeds hit the timer. It lacks a
   "kill the commander tower" plan and does not convert an HP lead into pressure.
3. **Matrix weights are hand-set**, never tuned. 15 numbers; a small coordinate
   descent over `ANSWER` using the harness is cheap and safe.
4. **No opponent-gold tracking, no card-count reading** — it cannot know when the
   enemy is over-committed.
5. **Side asymmetry — partly explained (2026-11-16).** Until then every `--botsim`
   run had an **extra, uncounted v1 bot on team 1**: the arena's own `_ready`
   builds the default bot (`bot_players` starts `[false, true]`), and the
   harness's second `_setup_bots()` dropped it from `bots` without freeing it.
   So v2-on-team-1 seeds were really v2 + v1, and team 1's `plays` showed only
   one of its two bots (v2 often read 0). `_setup_bots` now frees what it
   replaces, and play counts come out even (~21–27 a side). **Every BOTSIM number
   recorded before this fix — including the 5W-3L above — is contaminated; re-run
   baselines.** First controls after the fix (v1 vs v1, seeds 101–102) both went
   to team 0, so check with more seeds whether a real side bias remains.

**Tuning discipline.** Change one thing, run the same seeds, compare the result
lines. The one time this was skipped the bot got *worse* (a tempo bonus: 2W-2L,
−26 HP) and the revert was only possible because the numbers existed.

---

## 4. Verification protocol

1. **Behaviour → eval assertion.** Numbers, states, timings. Never a screenshot to
   confirm something a number can prove.
2. **Refactor / parity → seeded sim line**, before and after, compared byte for byte.
3. **Rendering only → one picture at full resolution.** Read the viewport, save the
   PNG, crop at coordinates computed from the constants. The 640×400 preview is too
   small to judge anything and cropping it by eye has already cost a whole debugging
   detour.
4. **Art and feel → the user.** Say so instead of faking confidence.

Useful flags: `--bots=both|off`, `--ability=tentacle|shiesty`, `--colors=#hex,#hex`,
`--botsim=<seed>`, `--scenario=checks|click|kit|win|...` (see `dev_capture.gd`),
`--demo --shots=<dir>`.

---

## 5. Gotchas that cost real time

* **`game_eval` bodies must be one line** with `;` separators. Multi-line fails to
  compile. Inline `for` loops silently execute **one** iteration — use `.map()`,
  `.filter()`, `.count()` or separate statements instead.
* Evals that `await` longer than **8 s** abort (**EVAL_HUNG**), and a failed eval can
  park the game in a debugger "break": call `project_manage(op="stop")` and relaunch.
* A **new `class_name` file needs an editor filesystem scan** before a headless run
  can resolve it (`filesystem_manage(op="scan")`), or the run dies with
  "Identifier not declared".
* The editor's **Errors buffer is a ring, not a per-run log** — old entries look
  current. A live run that boots clean is the proof.
* **The user edits files live.** "file changed since it was read" means re-read, not
  corruption. Never rewrite a whole file from memory.
* The **game window can be resized** (1600×1000 ↔ 2112×1320). All screen maths in
  code is in the 1600×1000 canvas; screenshots are the window size.

---

## 6. Design intent — do not "fix" these

* **Hedgehog has no jab.** Walking to melee reach *is* the cue to ball up; the curl
  burst + shove is its only attack besides thorns. The shove is deliberately clamped
  so nothing leaves quill reach.
* **Firebolt keeps its second charge after a right-click**, and only the second cast
  consumes the card.
* **Penny ignores buildings and towers entirely** (`troops_only`) — that is the card.
* **Pen does not turn back into Penny** — no second Pen ever enters the deck.
* **Hot Chicken pecks first**: three fireballs on one target, *then* the kamikaze ram.
* **The ability card draws are payload-gated**: tentacle on death, and Shiesty on
  *either* outcome — he pays a card when he gets home **and** when he is caught. Only
  the coin depends on delivery (death hands it back to the enemy).
* **The Obsidian Whelp curls under tower fire.** Any hit (towers included) keeps
  it shut for `calm` s; the hit that curls it lands in full. Towers then
  deprioritise it (`DDTower._acquire` takes any uncurled unit first and re-picks
  every tick while its target is curled; balled-up hedgehogs too), so alone in
  tower range it sits there soaking shots at 20 % and never bites, and with
  company the tower turns on the company. Scenario: `--scenario=towerpick`.
  The melee push is decided by where the hit came from: `from` equal to the
  attacker's own position (a body blow), never a projectile or a tower.
  The Magma Whelp has `dmg` 0: `_attack` lets a shooter with a payload fire anyway.
  Scenario: `--scenario=whelp --log --bots=off`.
* **Wu Cheng'en's rage is once per life** (`rage_used`), triggers from any
  damage that takes him under `rage_hp`, and its regen is fixed at the level his
  banked hits had reached at that moment (`rage_level()`); hits during the rage
  still bank but change nothing. Rage hits count every enemy struck, so a poke
  through three bodies banks three. Regen and the rage clock tick before the
  stun / shove early-outs, so they run through both. The staff stays out within
  `keep_out` tiles past reach because his own poke pushes the target away.
  Scenarios: `--scenario=wu --log --bots=off`, close-up `--scenario=wuart`.
* **The Nekomancer's ritual outlives her.** Each pentagram is its own node on
  the arena (`scripts/pentagram.gd`, no class_name, preloaded by `unit.gd`), so
  killing her while it glows does not cancel the rats. The diagonals are the
  team's forward direction, not her facing. A spot off the board or under a
  building is pulled back toward her. Rats raised this way climb out of the
  ground (`rises`) instead of the usual drop. The ritual clock stops while
  she is stunned or shoved. Scenarios: `--scenario=neko --log --bots=off`,
  close-up `--scenario=nekoart`.
* **Enkidu's throw is a scan, not his target.** Any ground troop with its
  centre 3 – 4.5 tiles away takes the spear, whoever he is walking at; flyers,
  buildings and towers never do. Anything already inside 3 tiles (that he can
  hit) means no throw: he fights it hand to hand. The spear returns on a 3.5 s
  clock, not by fetching it, and is thrown again at once if a troop is still in
  the band. Gilgamesh's lash is ground only. The pair are two independent units
  after landing. Scenarios: `--scenario=gil --log --bots=off`, close-up
  `--scenario=gilart`.
* **The dart frog's burst reaches any body the 0.5 tile circle touches**, not
  centres within 0.5: bodies never overlap, so a centre rule would only ever
  poison the one it landed on. It leaps at the nearest ground enemy of any kind
  (troop, building or tower) whose edge is within 2 tiles, follows it in the air,
  and the leap is committed (stuns and shoves wait for the landing). A hop, once
  started, finishes; slow shortens hops. The bot reads it as a 0-damage card.
  Scenarios: `--scenario=frog --bots=off`, close-up `--scenario=frogart`.
* **Shiesty commits to one bridge.** `DDShiesty._pick_bridge()` runs once, on
  landing: it counts enemy `DDUnit`s that could target him (dmg > 0, not
  `buildings_only`, not a kamikaze Alchemist, not an airborne dragon) on each
  half of the board, split between the bridges, and takes the bridge with fewer
  (nearer on a tie). `_route_home` is `arena.route_point` pinned to that
  `bridge_col`. Troops played afterwards do not change it.
  Scenario: `--scenario=shiestylane --log --bots=off`.
* **Shiesty is immune to nothing but tower fire.** He is not a `DDUnit`, so he
  carries his own copies of the troop hooks (`apply_burn`, `slow`, `add_poison`,
  `apply_impulse`, `stunned`) with DDUnit's numbers and tick order: poison and
  shoves run through stuns, burn and slow pause during them. In the air
  (`untargetable`) nothing lands on him. The kraken's burrow grab accepts
  `DDShiesty` as well as `DDUnit`. Anything new that touches troops through a
  `has_method` check reaches him for free; anything that filters on `is DDUnit`
  has to name him too. Scenario: `--scenario=shiestyfx --bots=off`.
* **Towers are only decorative HP sinks** — the commander tower is the only win
  condition besides the clock.
* **The hedgehog never targets air** (`hits_air` stays off) and its curl burst skips
  flyers; it only balls up when a *melee* flyer hits it, and that first hit is not
  reflected. Air is answered with thorns, not with chasing.
* **The dragon is chained by the wings only** and, airborne, does not attack at all:
  it pours a **2 tile, team-coloured** patch of 25-damage-per-second fire on the
  ground beneath it (`_tick_fire_breath` + `_draw_fire_breath` in `unit.gd`). It
  **burns friendly troops too** — that is deliberate — and it flies until the fire
  lands on its target so the tower it is attacking burns. Do not give it back a
  breath burst.
* **Sound**: `SFX/` holds the Pixabay card sounds (credit in the filename). `DDSfx`
  (`scripts/sfx.gd`) is a child of the arena created in `_build_sfx()`; the opening
  deal slices the eight draws in `opening hand` down to a random four, placement
  plays `oxidvideos-place cardmp3.mp3` from `deploy()`. Every later draw, either
  player's (the timer, ability payoffs), goes through `arena.draw_card()`, which
  calls `DDSfx.take_card()`: one of the three `taking-playing-card` takes at
  random, and draws within 3 physics frames of each other play once. The opening
  hand is sliced straight from the deck in `_build_decks`, never through
  `draw_card()`, so it keeps its own deal sound. Audio is silent under
  `--headless` but the nodes still exist, so bot sims are unaffected. Match music
  (`DDSfx.start_music`, songs in `musictoreplace/`) starts 4 deal slices + 0.3 s
  after `_build_sfx()`; it is skipped entirely when headless, so its random song
  pick never touches a bot sim's global RNG. The volume slider (`arena._build_volume`)
  has `FOCUS_NONE` so it never eats arrow keys or hotkeys; it drives the Master
  bus through `DDSfx.set_volume`, which also writes `user://settings.cfg`.
  Hand cards poll the viewport mouse, so a scenario hovers them with
  `viewport.warp_mouse`, not pushed motion events (`--scenario=hovervol`).
* **Burning ground** (`scripts/ground_fire.gd`, no `class_name`, preloaded by
  `arena.gd`): a spell with a `ground_fire` block in `card_db.gd` (the Fireball)
  leaves a patch the size of its splash that adds `burn` to every enemy inside it
  each `every` seconds for `time` seconds. The impact's own burn is not repeated
  at t = 0, so the Fireball's 4.2 s patch gives four extra doses of 10.
* **Penny's leap is a grab, not a shove.** She always travels the full
  `jump_reach` (2.5 tiles) and carries the target in front of her the whole way
  (`carrying` / `carry_dir` / `carry_contact` in `_tick_jump`), landing the doubled
  hit when she arrives. The victim is moved to `position + carry_dir * contact`
  each frame, so the pair move as one — do not put the leap back on a live chase of
  the victim's position, which is what once walked a dragon off the board.
* **Two cases get no grab**: a `giant` card (the dragon) or a building — she cannot
  carry those, so she stops on their hitbox and hits there (`_is_giant()`). With no
  target left after the strafe she does not jump at all.
* **Card face** (`DDCardFace.card()`, trading-card style): everything on it is
  read from card data. Attributes come from `traits_of()`; the attack rows come
  from `attacks_of()`, which derives one row from `dmg` / `reach` / `interval`, a
  summon row from `summon`, and Ram + Tomahawk from `ram`. A card with more than
  one hit needs a hand-written entry in `ATTACKS`, and those numbers do not follow
  balance changes. The summon coin comes from `summon.unit` / `ritual.unit`. The
  trim and the middle line are the static vars `trim` / `line`, set from the
  arena's `card_trim` / `card_line` exports (or `--trim=` / `--line=`). Opacity
  goes through `_c()`; any new colour in the face must go through it too, or it
  will not fade with the card.
* **Animation stills/GIFs**: `--scenario=pennygif` (dev_capture) renders a pair into a
  transparent SubViewport at 20 fps and dumps raw RGBA frames to
  `.godot/penny_frames`; `node docs/make_gif.mjs <frames> docs/penny.gif` encodes them.
  The scenario is `--scenario=pairgif --gif-a=<kind> --gif-b=<kind>` — the frame
  dump and the encoder are generic, only the staging code is specific.
  The encoder is hand-written because there is no ffmpeg/ImageMagick/Pillow on this
  machine — do not assume those exist.
* **Laniakea cannot hit a flyer inside 2.5 tiles.** His leap window is 2.5 – 3.5
  tiles (centre to centre) and only opens when no ground body is closer than the
  flyer; a melee flyer that has already reached him is safe from him. The cleave
  never touches air and the slam's strip hits ground and air alike. All his ranges
  live in the `greatsword` block and are centre distances, not the edge-to-edge
  `reach` the other units use (`reach` 1.5 is only there for the card face and
  the bot's melee role). He also leaps at a ground *troop* (never a building or
  tower) in the same window when no flyer is closer and `atk_cd` is 0; with the
  swing on cooldown he walks in instead of standing and waiting.
  Scenario: `--scenario=laniakea --log`.
* **The snowball's size is continuous, its damage is not.** `height_t` grows
  smoothly (drawn size and lane width); roll damage and shove use
  `whole_height()`, so the numbers on the card are still whole tiles.
* **The goblin commander's animations are picture only.** His tower shot is the
  same aimed bolt as every tower's, drawn as his standard (projectile kind
  `spear`); `throw_t` / `toss_t` on `DDTower` are cosmetic clocks. When Shiesty is
  sent, the commander scoops and throws him, but Shiesty's real position stays on
  the old tower-to-tower arc and only his *drawn* position rides the hand
  (`DDShiesty._launch_offset`), so timings and bot sims are unchanged. Eyes stay
  dark until the ability is ready, then light in the team colour, and the
  standard is waved. Scenario: `--scenario=toss --log --shots=<abs dir>`.
* **The opening deal is picture only.** Both hands are dealt instantly; each
  `HandPanel` just holds its cards back (`deal_hidden`) and releases one per beat,
  where a beat is one draw in the deal sound (`DDSfx.slice_seconds`, 0.576 s).
  Own hand right to left out of the NEXT box, opponent top to bottom from above
  the column, both on the same clock. The match clock, gold and bots do not wait
  for it. Scenario: `--scenario=deal --log --shots=<abs dir>`.
* **Femme Fatale never dashes across the river.** The dash only starts when
  `route_point` says the walk to the target is a straight line, so she cannot
  stop in the water. The dash ignores her attack cooldown (the wind-up is the
  cost), a stun or shove cancels it, and her third combo hit pushes *her* back,
  not the target. Ranges are centre distances in the `needle` block, like
  Laniakea's. Scenario: `--scenario=femme --log`.
* **Penny's dash ends in a leap**: after the spin she jumps at the nearest *air*
  unit within 2.5 tiles (else the closest body), lands 2× damage and stays
  untargetable through the whole thing. Both the swipes and the leaping blow do not
  touch buildings.
* **Penny's dodge animation is picture only.** `DDArt.penny(pose, pf)`: 0 trot,
  1 the startled hop back, 2 the arched, stiff-legged sideways run through the
  quarter circle (walked on the ground, tail swapping between a puffed brush held
  up and a hook hanging down), 3 the leap with both forepaws out. Her foreleg band
  is the team colour. The hop height comes from `unit._penny_hop()`, and during the dodge she is *drawn* facing the target
  (so the circle is run sideways) while the real `facing` is untouched. Stills:
  `docs/penny.gif` via `--scenario=pennygif`.

---

## 7. Next steps, in order

1. Add cards (fast now — §2). `ORDER` stays one of each; duplicates go in `deck_lists`.
2. Bot: ability trigger → closing plan → matrix tuning → opponent-gold reading.
3. Extract `unit.gd` (`unit_art`? `abilities`?) the way `board.gd`/`arena_draw.gd` were done.
4. Consider a pixel-probe scenario (`--scenario=pixels`) so rendering checks become
   booleans instead of images in the conversation.
5. Run layer: §8 is the design. Nothing of it is built except the sample map
   printer.

6. Elite encounters: §9 and §10 are built and startable from the debug view.

---

## 9. Elite encounter: the Momma Ballista Spider (built)

Start it with **Tab, then S** (`arena.start_spider_encounter()`), or
`--scenario=spider --log --bots=off --shots=<abs dir>` for the scripted check.

* **`scripts/spider.gd` is a tower by duck typing, not a `DDUnit`.** It sits in
  `arena.towers` with `crown = true`, so every existing rule applies unchanged:
  troops target and hit it as a tower, spells use `tower_mult`, killing it ends
  the match, and the clock compares its HP with the player's tower HP. It has
  **no `class_name`** and is loaded with `preload()` in `arena.gd`, so a headless
  run never depends on the editor rescanning global classes (§5).
* **The swap** removes the enemy's towers and troops, empties their hand and
  queue, disables their bot and parks their ability cooldown. Nothing puts them
  back; restart the match to leave the encounter.
* **Numbers live in `card_db.gd`** (`spider` with its `boss` block, `spideregg`,
  `spiderling`), none of them in `ORDER`.
* **Her dice are a seeded `RandomNumberGenerator`** (skitter distance only), so
  the encounter is reproducible like the rest of combat.
* **Eggs and spiderlings are ordinary `DDUnit`s.** The egg is a 2×2 building
  with a card key `hatch`; `DDUnit._die` spawns the hatchlings on any death.
  The spiderling's card key `poison` adds counters on each melee hit.
* **Poison is a counter, not a status** (`DDUnit.poison`, `DDTower.poison`):
  never cleared, never replaced by burn or slow, ticks 2× the counter every 5 s.
  Projectiles carry it as payload key `poison`.
* **Webs and traps are state on the spider** (`webs`, `traps`), drawn by two
  child canvas items (`floor_layer` under the board's units, `sky_layer` above).
  A web tile slows through the normal `slow()`, so it replaces a burn like any
  slow does. A trap **removes** a `DDUnit` without calling `_die`, on purpose.
* **Her cycle** is the state machine in `_tick_skitter`: HOME (a random 3 – 7 s,
  `back_min` / `back_max`, seeded RNG) → ADVANCE (`skitter_time`, 2 – 5 tiles:
  one shorter than it was, so the wide pool, `pool_wide` 1.8 a side and
  `pool_len` 1.8, fits before the river) → FORWARD
  (`cycle` minus that wait; `back_wait` / `stay_time` hold the current values)
  → egg → TO_BRIDGE → BUILD (`build_time`) → GLINT (`glint_time`) → RETREAT,
  walking at `walk_speed`.
* **The poison** (`_start_ooze` / `_tick_ooze` / `in_ooze`): a straight path from
  her mouth (`ooze_from`) to the river's near bank on her lane (`ooze_len`
  tiles); `ooze_dry .. ooze_wet` is the wet stretch, each end moving at
  `seep_speed`. The first `pool_len` tiles are the pool (`_pool_half`), the rest
  two branches (`_branch_off`). Once the wet end reaches the bank the river fills
  from `river_in` (her lane's column) downstream to `_river_end()` at
  `river_speed`; once the path is dry it clears from the top. Only the path
  poisons (`pool_poison` every `pool_every` s); the river tint is a picture.
  Her lane meets the river at the board's middle, so it is the lower half that
  turns.
* **The venom waits for the pool**: while FORWARD, one glob every
  `forward_spit_every` (2 s) at the closest enemy unit once `ooze_wet >=
  pool_len`; the parting glob at the nearest tower or building after GLINT. No
  spit on setting off any more.
* **Traps are built, not timed**: `_head_for_bridge` picks a bridge with no trap
  (none free: straight to GLINT), adds the trap with `build` 0 and walks to a
  spot `build_back` (2.4) + 1 tiles short of the bridge's middle. Traps with
  `build` < 1 never spring. `lay_trap()` (armed at once) is kept for
  `--scenario=spider` only. `DDArt.slingshot_trap` draws all build stages.
* **Eggs hatch by age**: `DDUnit.hatch_count()` = round(`hatch_max` × age /
  lifetime), at least 1. `--scenario=eggs` checks 1 / 4 / 8,
  `--scenario=spidercycle` (add `--shots=` for pictures) logs one full cycle.
* **Poison ticks are halved on buildings and towers** (`DDUnit.POISON_BUILDING`). The projectile carries payload key `seek`
  (its landing point follows that node) and bursts through the normal splash
  path, which now also applies `poison` in the splash.
* **Splash rings** (`arena.spawn_splash_ring`): any projectile splash flashes a
  light circle in the attacker's colour for 12 physics frames. Picture only.
* **She is stretched 1.5× both ways** (`WIDE`, `TALL` in `spider.gd`); the hitbox
  (`radius` on the card) did not change.
* **Design choices that were mine, not specified:** all the numbers; eggs
  hatching on the timer as well as on damage; traps taking giants too (a dragon
  on foot is launched).

---

## 10. Elite encounter: the South Sea Kraken (built)

Start it with **Tab, then K** (`arena.start_kraken_encounter()`), or
`--scenario=kraken --log --bots=off --shots=<abs dir>` for the scripted check.

* **Two scripts, neither with a `class_name`.** `scripts/kraken.gd` (body, phase
  change, every projectile of the fight) preloads `scripts/kraken_arm.gd` (one
  tentacle). Both duck-type towers like the spider (§9).
* **Phase 1 has no crown tower on the enemy side.** The five arms are in
  `arena.towers` (`crown = false`); the body is not, so nothing can target it.
  `crown_tower(1)` / `_king_of(1)` return null until phase 2; every caller
  already handles that. On the clock only the arms' HP counts in phase 1.
* **Phase 2** starts inside the killing blow on the last arm
  (`kraken.on_arm_down` → `_surface`): the body appends itself to `towers` as
  the crown, and each arm is `revive()`d (half `max_hp`, `slow` = 2 on the slam
  interval and the arrow timer). Arms killed again in phase 2 stay down; the
  win is the body.
* **`dead` vs `down` on an arm.** `dead` only means "not targetable now" (sunk,
  or away burrowing); `down` means killed. The phase check reads `down`.
* **An arm's `position` is its body, not its root.** `base` is the fixed tile;
  `offset` leans toward the nearest enemy unit, clamped to `lean` tiles per axis
  (so the body stays in the 3×3 around the root). Ranges are measured from the
  body.
* **Attack priority when idle and off cooldown**: spin (own HP ≤ `spin_hp`, enemy
  inside `spin_radius`) → slam (enemy within `reach`) → arrow (own timer, and
  every enemy *unit* at least `arrow_min` away). The slam hits a rectangle
  around the impact in the aim's frame: `wave_len` ahead and to each side,
  `wave_back` behind.
* **Arrows and orbs are plain dictionaries on the kraken**, not `DDProjectile`s,
  because both need to strike towers as well as units on contact. Arrows never
  turn; the first enemy body within 0.3 tiles of its edge takes it.
* **Burrow reuses `DDTentacle`** (the hero ability) on team 1 with the arena's
  `TENTACLE_*` constants. Its `draw_card(1)` is a no-op on the empty queue. The
  mark is fixed where the troop stood when the arm went under.
* **Seeded RNG** only for the orb split count and the split's starting angle.
* **Design choices that were mine, not specified:** all the numbers and the
  five root tiles; "low health" for the spin is the tentacle's own HP; the slam
  hits air; revived tentacles need not be killed again; the burrow's mark stays
  on the ground instead of following the troop; the art.

---

## 11. Run layer: the first slice (built)

`scripts/run_state.gd` is the autoload **`Run`** (project.godot), no
class_name. It holds `deck`, `commander_hp`, `floor_index` into `ACT`, the run's
`ability`, `history`, and `last` (the fight just played). Being an autoload it
survives `reload_current_scene()`, which is how a run moves between fights.

* **Start:** pressing play starts a run (`arena._apply_run()` calls
  `Run.start()` if none is active). `--match` plays one plain match instead; the
  bot sim and dev scenarios (`--botsim=`, `--scenario=`, `--shots=`, `--demo`)
  never start one unless `--run` / `--run=<seed>` is also passed, so they are
  untouched (`--botsim=3` is byte-identical before and after).
* **Card reward** (`scripts/reward_screen.gd`, no class_name, preloaded): after a
  won fight that is not the last, `_match_ended()` puts it on its own CanvasLayer
  (50) and hides the hand panels. Three different cards from `DDCard.ORDER`,
  seeded by run seed and fight (`Run.reward_choices()`), drawn with
  `DDCardFace.draw_full` (the trading-card face with the description, text size
  stepping down to fit). Click / 1-3 picks (`Run.take_reward`), Skip / S skips; both then call
  `arena.continue_run()`. It eats the keyboard while up, and `continue_run()`
  refuses while `Run.reward_pending()`, so Enter cannot skip by accident.
  Input waits for the 0.9 s appear delay. The control must be sized with
  `set_anchors_and_offsets_preset`: with anchors alone it was 0 x 0 and got no
  mouse input at all (only the keys worked). Hover grows a card by 6 % and the
  Skip button by 10 %, eased by `lift` / `skip_lift`. Icon tooltips:
  `DDCardFace.hit_log` collects every badge drawn that frame (`TIPS` holds the
  player-facing text, `tip_for()` reads it). `--scenario=rewardui --run=7` drives
  the mouse through hover, tooltip, Skip and a click (`push_input`).
* **Lane pocket** (`arena.POCKET`, `pocket_tiles`, `in_pocket()`): rebuilt by
  `_tick_pockets()` only when the set of fallen DDTower side towers changes; the
  taker can deploy there regardless of presence (still subject to the 3.5-tile
  live-tower buffer). `is_water()` (river rows minus bridge decks) is excluded from
  presence, the pocket and all troop/building deploys. `--scenario=pocket` checks
  both lanes, both teams and the river.
* **Setup** (`_apply_run`, in `arena._ready`): `deck_lists = [Run.deck,
  encounter deck]`, a bot on side 1 only, abilities from the run, decks shuffled
  from `Run.deck_seed()` (run seed × fight). After the board is built your
  commander's `hp` is set to `Run.commander_hp`; side towers and the enemy are
  fresh. An `elite` encounter calls `start_spider_encounter` /
  `start_kraken_encounter` deferred.
* **End:** both ways a match ends (`on_tower_destroyed` for a commander,
  `_finish_on_towers` for the clock) call `_match_ended()` once, which reports
  `winner` and your commander's HP (0 if it fell) to `Run.report()`.
* **Result screen** (`arena_draw._result`): VICTORY / RUN OVER / RUN COMPLETE.
  Enter (or Space) calls `arena.continue_run()`: next fight after a win, a new
  run once over. R does nothing mid-run (no replaying a fight) and starts a new
  run once it is over.
* **Placeholder rules, mine:** any lost fight (including a time loss or a draw)
  ends the run. That is not §8's design, where losing activates a relic and you
  are out only when all of them are; when relics exist, `Run.report()` is where a
  loss becomes "lose a relic" instead of "run over". The four `ACT` fights and the
  `STARTER_DECK` are placeholders for steps 3 and 4.
* The opening deal's sound stopper is a child `Timer` of `DDSfx`, not a
  SceneTree timer: the latter outlived the scene on a quick reload and fired into
  freed nodes.
* **Time-up rule** (`_finish_on_towers`, all matches, not only runs): more
  towers destroyed loses; level, more standing tower HP wins; level, draw. A
  kraken tentacle counts once `down`. Scenario: `--scenario=timeout --bots=off`.
* Scenario: `--scenario=run --run=7 --bots=off` plays a run by script: win with
  the commander cut to 180, the reward screen is up and Enter does not skip it,
  pick a card (deck 10 -> 11); fight 2 opens with the commander still at 180 and
  the side towers full, win, skip the reward; the spider fight starts as the
  elite and is lost, and Enter starts a fresh run.

---

## 8. Run layer design (agreed on paper, not built)

Discussed 2026-11-16. This is design, not code: only `scripts/map_sample.gd`
exists. Numbers are starting points.

### The constraint that shapes it

The game is real time, so decisions outside a match must stay short. A full
Slay the Spire act (7 × 15, every node typed and visible) invites minutes of
route planning at the start; that is the thing to avoid, without falling back to
"only the next few tiles are visible".

### Lobby

* A run is a **lobby**, not floor-by-floor matchmaking. A lobby needs enough
  humans once and bots fill the rest; floor matchmaking needs another human on
  your floor every time you queue, which a small playerbase cannot supply.
* **8 players** (bot fill), so there are seven possible opponents rather than
  three.
* The lobby runs on a **shared clock**: fight, then a 20 – 30 s map phase.
  Players may **plot a route** ahead of time (queue, result screen); when the
  map timer runs out the plotted node is taken.
* **Pairing by map choice**: players who pick the same kind of node fight each
  other, so pathing decides who you meet. Bot fights and fights against a saved
  deck piloted by the bot are mixed in between live ones.
* Fight formats: 1v1, 2v2, fights with a modifier (double gold, extra card
  draw). **Bosses are 1v4 or 1v8** against other players, bot-filled. A player
  joins the many-side through a map tile; the idea is a live tile with a
  countdown that appears when someone is approaching their boss.

### Relics are lives

* Everyone starts with **3 relics**: one unique to their hero, one for passive
  card draw, one for passive gold.
* **Lose a fight** and the winner picks one of your relics. They get a copy
  (if they already hold it, theirs gets stronger). You keep yours and it becomes
  **activated**: stronger, and it can no longer be taken.
* **All of your relics activated = you are out.** So losing makes you stronger,
  three times, and then it kills you.
* Relic state only goes one way: dormant → activated. Nothing ever makes a
  relic weaker.
* **Relics picked up during the run are extra lives**, since each new dormant
  relic is one more that can be taken.
* **The winner chooses one**: steal a relic, or take a **ward**. A ward is a
  token, not tied to a relic, at most one held. When a warded player loses, the
  ward breaks, no relic activates and nothing is stolen. It is the only "heal",
  and it has to be won.
* Card rewards: the winner picks 1 of 3, the loser 1 of 2 (rather than none, so
  the loser's deck still grows).
* **Bonuses add, they do not multiply.** The first sketch was ×1.5 on activation
  and ×1.2 per stolen copy; gold rate is the strongest stat in the arena, so
  stacked multipliers on the gold relic would decide matches before cards do.
  Keep the base draw/gold bonuses small and step them additively.

### Open questions

* **Last one standing, or reach the boss?** PvP is zero-sum: every match
  produces one loss, so an 8-player lobby with 3 lives each loses 4 lives a
  round. If the goal is to reach the boss, lives must come in faster (relic
  pickups, bot-fight nodes) than that drains; if elimination is the point, 3 is
  fine. Not decided.
* How the boss's many-side is rewarded, and what the boss player gets.
* Whether bot-piloted saved decks are good enough to stand in for live
  opponents (the bot's weak spots are in §3).

### The map

* **5 lanes × 9 columns, left to right like the arena, boss after the last
  column.** Small enough to read in seconds: a handful of routes, not dozens.
* Generation is Slay the Spire's, shrunk: **4 path passes**; each pass starts in
  a random lane of column 1 (the first two in different lanes) and steps to the
  same lane or a neighbour in the next column; paths merge but **never cross**;
  unused slots are empty.
* Tile types are rolled from weights and re-rolled until the rules hold:
  column 1 is all 1v1; the last column is all shops; no elite before column 4;
  no elite or shop straight after an elite or shop; no shop in the column before
  the last; **two exits from one node lead to different types**.
* Reveal: the whole shape plus the landmarks (boss, elites, shops) from the
  start; an ordinary fight's format and modifier only one column ahead.
* Sample printer (dev-only, deterministic per seed, tile types shown as die
  faces):

  ```
  godot --headless --path . -s res://scripts/map_sample.gd -- --seeds=1,2,3 --out=<abs file>
  ```

  It writes a file because the console mangles the die glyphs. Types and
  weights (`WEIGHTS` in the script) are placeholders: ⚀ 1v1 35, ⚁ 2v2 20,
  ⚂ modifier fight 15, ⚃ elite 10, ⚄ shop 8, ⚅ event 12. Seed 4:

  ```
          ⚅───⚀───⚂       ⚀───⚃───⚄ ┤
        ╱           ╲   ╱   ╱   ╲   │
      ⚁       ⚄       ⚃───⚁       ⚄ ┤
    ╱       ╱   ╲   ╱           ╱   │─ BOSS
  ⚀       ⚀───⚁───⚁───⚄───⚅───⚁     │
        ╱   ╱   ╲       ╱   ╲       │
  ⚀───⚂───⚂       ⚂───⚁       ⚀───⚄ ┤
    ╱
  ⚀
  ```
