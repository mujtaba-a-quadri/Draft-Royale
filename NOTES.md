# Deep Draft — working notes (handoff at **0.4.2**)

Godot **4.7.2**, project `C:\Users\Arthur\Documents\Cooler\my games\Deep Draft`.
Read this plus `README.md` before touching anything. The README is the *product*
reference (rules, cards, numbers); this file is the *working* reference (where code
lives, how to verify, what is half-done and why).

State at handoff: 22 cards (21 dealt), 150 s matches with a final-minute surge,
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
| `card_face.gd` | 165 | `DDCardFace.draw()` — the face on a hand card (name/damage map in `ATTACK_NAMES`) |
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
   `boomerang` (Fu), `roll` (Slate), `curl` (hedgehog), `chicken` + `kamikaze` (Hot Chicken,
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

Hand slots are bound **by card kind**, so a deck must not contain duplicates. That
matters when adding cards: `ORDER` is per-player deck size (currently 21, hand 4,
`HAND_MAX` 8, draw every 8 s).

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
5. **Side asymmetry is unexplained**: with the *same* bot, one half of the board plays
   ~3× more cards and ends ~138 HP worse. That is an arena or anchor bug, and it
   pollutes every A/B unless sides are balanced (they are — keep it that way).

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
  plays `oxidvideos-place cardmp3.mp3` from `deploy()`. Audio is silent under
  `--headless` but the nodes still exist, so bot sims are unaffected.
* **Penny's leap is a grab, not a shove.** She always travels the full
  `jump_reach` (2.5 tiles) and carries the target in front of her the whole way
  (`carrying` / `carry_dir` / `carry_contact` in `_tick_jump`), landing the doubled
  hit when she arrives. The victim is moved to `position + carry_dir * contact`
  each frame, so the pair move as one — do not put the leap back on a live chase of
  the victim's position, which is what once walked a dragon off the board.
* **Two cases get no grab**: a `giant` card (the dragon) or a building — she cannot
  carry those, so she stops on their hitbox and hits there (`_is_giant()`). With no
  target left after the strafe she does not jump at all.
* **Card face**: `DDCardFace.rate_text()` and the HP ribbon are type-aware
  (troop / building / spell). New cards only need an `ATTACK_NAMES` entry and
  data; put per-type stats in `rate_text`, never in the ribbon.
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
  the bot's melee role). Scenario: `--scenario=laniakea --log`.
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

---

## 7. Next steps, in order

1. Add cards (fast now — §2); keep `ORDER` free of duplicate kinds.
2. Bot: ability trigger → closing plan → matrix tuning → opponent-gold reading.
3. Extract `unit.gd` (`unit_art`? `abilities`?) the way `board.gd`/`arena_draw.gd` were done.
4. Consider a pixel-probe scenario (`--scenario=pixels`) so rendering checks become
   booleans instead of images in the conversation.
