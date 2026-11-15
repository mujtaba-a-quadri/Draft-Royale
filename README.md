# Deep Draft — arena slice

Clash-Royale-shaped arena, RTS troop play, two local hands driven by one mouse.
This slice is the **arena foundation** for the roguelike layer (deck building,
relics, heroes and match types come later).

## Run

```
godot --path . --editor        # open in the editor
godot --path .                 # play
```

## Controls

| Input | Action |
| --- | --- |
| Left click a card in either side panel | Select that card for that player |
| Left click the board | Deploy it (troops: your half only, spells: anywhere) |
| Right click (anywhere) or Esc | Clear the armed card |
| Hover a troop or tower (no card armed) | Name + HP, **pale yellow aggro ring**, **pale red attack-range ring** |
| B | Toggle the bot for player 2 |
| 1 / 2 / 3 (**Tab / debug view only**) | Debug gold: +1 to player 1 / both players / player 2 |
| Tab (dual view) | Shows floating **damage numbers** on troops: white under 20, amber 20+, red on a killing hit |
| A (**Tab / debug view only**) | Toggle the **all-cards shelf**: the bottom hand becomes a 4-column grid of every card, hover for its description, click to arm and place it for free. Placing on the **top half** deploys it for the opponent; on **purple (both-controlled)** tiles the side is random |
| R | Restart after a match ends |

Both hands are live at once: the left panel is Player 1 (blue, bottom half),
the right panel is Player 2 (red, top half). Only one card can be armed at a
time so a single mouse is never ambiguous — and the bot playing its own card
never disarms yours.

## Board

* **30 rows tall.** Rows 1-10 (top) and 19-28 (bottom) are 16 tiles wide; the
  middle band of 8 rows (11-18) bulges out to 18 tiles, so the board reads as a
  plus. River at rows 14-15, bridges at columns 4-5 and 12-13.
* **Hover preview** — armed cards preview on the grid: tile outline plus a tinted ghost (or the
  whole swarm formation) and, for spells, the splash radius.
* **No-man's land** — the middle band of 8 rows. Each player may **always** deploy
  on the 2 band rows nearest their own half (rows 17-18 for the bottom player,
  11-12 for the top), so the free zone always reaches one row from the river.
  Anything deeper needs **presence**: a ground troop projects a **cone** that opens
  back toward its own half — 3 tiles wide on its own row, 5 one row back, 7, then 9.
  Lizard Soldiers project the same cone **one row further forward**. Control is not exclusive — both
  players can hold and deploy on the same tile. Flying units project no control,
  and Shiesty projects none either. The grid is cached and only recomputed when
  a unit changes tile (drawn by `control_layer.gd`, which repaints on that change
  instead of every frame).
  No deployment within 3.5 tiles of an enemy tower.
* **View modes** — solo layout (cards on the left third, arena on the right,
  opponent info strip) and dual hotseat (both hands). Tab toggles; the panel
  button does the same.
* Three towers per side: two princess towers and one king tower, **250 HP each**.
* 12-card deck per player, 4 cards in hand, 1 "next", cycling exactly like
  Clash Royale: play a card and it goes to the back of the queue.
* Gold: starts at 5, caps at 10, regenerates 1 per 2.4 s.

## Cards (base numbers, all tunable in `scripts/card_db.gd`)

| Card | Cost | HP | Damage | Notes |
| --- | --- | --- | --- | --- |
| Hero | 3 | 150 | 25 / 1.0 s | Very high HP for the cost. Also rides down an airborne dragon |
| Snowman | 2 | 90 | – | Stationary decoy, 30 s lifetime, draws attention (7.5 tile lure). **On death: 3-tile blast for 30 damage and a 3 s / 30 % slow** (troops only, dark blue tint) |
| Slate | 3 | **200** | 12 / 1.6 s | Slow tank that ignores every moving troop — only structures and towers |
| The Chained Dragon | 9 | **400** | claw 45 / 1.4 s → breath 45 | Chained on the ground; at half HP it flies and burns the ground |
| Alchemist | 4 | 55 | 45 splash (1.4 tiles) / 2.0 s | At ≤50% HP it flips team, charges its caster's tower at high speed and detonates for 100 |
| Fireball | 5 | – | 40 splash + **60 burn**, shoves loose units 1.2 tiles out | Fired from your **king tower**; `tower_mult` cuts tower damage |
| Firebolt | 2 | – | **No damage — 40 burn** | An arrow of fire from your **nearest tower** |
| Golden Idol | 4 | 35 | – | Stationary, taunts. On death it **drags enemies within 3 tiles inward at 1 tile/s** for a 1 s rumble, then breaks loose as a boulder **2.5 tiles behind the idol** and rolls through the spot at its killer, locked to **16 compass directions**: 80 damage, **2 tile knockback and a 2 s stun** to everything it passes |
| Hedgehog | 3 | 60 each | 10 / 1.2 s | Three burrowers. In melee they **curl**: 45 % incoming damage, the quill burst deals 12 and shoves enemies 0.7 tiles (thorns range 2.2 keeps them inside it), and every hit taken inside thorns range returns 8 fixed damage |
| Zombie Horde | 6 | 111 each | 15 / 1.0 s each | Six melee bruisers in a 2x3 block. **Anything a zombie kills rises as a full-HP zombie on the killer's side** |
| Honeycreeper Flock | 4 | 10 each (lead 20) | 6 / 1.0 s each | Flying swarm of 5 in a diamond, lead i'iwi in front. Ground troops can't touch them; they can hit the flying dragon. Alchemist and Boomerang-Fu can hit air too |
| Lizard Soldiers | 3 | 55 ×3 | 10 every 1.0 s **rifle at 3.5 tiles** | Wedge of three. **Always retargets the weakest troop in range**, not the nearest, and its presence cone sits **one row further forward** |
| Lizard Warren | 4 | 130 | – | Stationary burrow. When an enemy comes within **6 tiles** it empties out **3 Lizard Soldiers**, then waits 6 s |
| Hot Chicken | 2 | 45 | 5 fireball (3.5 tiles) + 5 burn, then **10 claws + 5 burn** after 3 hits on one target | Pecks from range; three hits and it takes to the air (becomes a flyer) to claw at close range |
| Boomerang-Fu | 4 | 90 | 30 boomerang / 18 jab + 26 kick (never on air — he throws at flyers even point blank) | Throws a 2 tiles/s boomerang that hurts everything it crosses and turns around at the target; stands still until it is caught. Melee combo (2 jabs) ends in a kick that shoves the enemy 3 tiles and Fu 2.2 tiles back |

Tower fire: 12 damage / 1.0 s, 6 tile range.

## The Chained Dragon vs the Hero

* **Grounded phase** — 400 HP, slow, melee claws only. Chains are drawn across its body.
* **At half HP** — the chains break. It takes off (1.9x speed), ignores bridges and
  river, and only targets buildings and towers. Its breath is an AoE at the target
  that burns *every ground unit, friendly or enemy*, plus enemy towers in the radius.
  While airborne, ground troops cannot target it — towers still can.
* **The answer** — while an enemy dragon is airborne, the defending player gets a
  pulsing **LAUNCH HERO · 3** button beside their king tower. Three gold buys a hero
  leap off the tower: 25 % of the dragon's max HP, grounds it, stuns it for 3 s. The
  hero then dismounts as a normal 150 HP troop of the defending side.
* When the stun expires the dragon takes off again, so the hero walks past it.

## Feel / juice (generic, no per-unit animation)

Every unit shares one squash-and-stretch layer in `unit.gd` so card art can churn
without redoing animation:

* **Deploy** — 0.5 s delay after hitting the board. The unit drops in stretched to
  almost a line (y 2.6x / x 0.32x, lifted 92 px) and squashes on landing
  (y 0.68x / x 1.22x). It cannot move or attack until the timer ends.
* **Attack** — a 0.14 s lunge: +20 % scale along the axis of the target direction,
  −10 % across it.
* **Hurt** — a light pink flash for exactly 2 physics frames.
* **Slowed** — a dark blue tint + ring for as long as the slow lasts.

## Combat primitives (shared by every card)

| Primitive | Where | What it does |
| --- | --- | --- |
| **Unit states** | `unit.gd` `enum S { IDLE, APPROACH, ATTACK, STUNNED, SLIDING }` | one switch drives movement, swings, stuns and knockback; no more ad-hoc flags |
| **Impulse** | `apply_impulse(dir, tiles, seconds)` | slides a unit a fixed distance, cancels its swing and its roll |
| **Projectile lifecycle** | `projectile.gd` | `mode`: bolt / splash / **return**; `pierce`; owner id (releases the overkill reservation); a return leg that flies to the owner's *current* position and calls `catch_projectile()` |
| **Distance-scaled cooldown** | `card_db.gd` `cooldown_per_tile` | `attack interval = interval + cooldown_per_tile × distance` |
| **Roll / charge** | `card_db.gd` `roll` + `unit.gd` | walk uninterrupted to gain levels, spend them on the next hit |

## Slate's rolling charge

```
"roll": {"interval": 3.0, "speed_mult": 2.0, "max_level": 2, "damage_bonus": 0.5}
```

* Every **3 s of uninterrupted walking** gains one level, max **2**.
* Speed **doubles per level** (0.62 → 1.24 → 2.48 tiles/s).
* Level 1 draws **speed lines**; level 2 also lays a **broken-ground trail** (`trail.gd`).
* The next attack deals **+50 % per level** (1.5× at level 1, 2× at level 2), then the roll is
  spent and he is back to a standstill. Stopping (attacking, being stunned, being knocked)
  resets the timer, so the charge has to be built on the move.

## Troop AI (deterministic)

1. **Targeting** — nearest enemy entity. Towers are always eligible; troops and
   buildings must be within the aggro radius (5-5.5 tiles, buildings get a
   7.5 tile lure). Targets already doomed by an in-flight attack are skipped.
2. **Retarget** when the target dies or becomes invalid, and also mid-walk: if a
   *strictly closer* target appears (0.3 tile margin) while the unit is not
   mid-attack, it switches. Once its attack is winding down it finishes it.
3. **Movement** — straight line at its own tile speed; if the river is in the
   way it first walks to the nearest bridge lane before crossing.
4. **Attack** — once the edge-to-edge gap is inside its reach, it stops and
   attacks on a fixed cadence until the target dies or it retargets.

Everything runs in `_physics_process` with fixed ticks, no randomness in combat.

## Project layout

```
scenes/arena.tscn      root Node2D + arena.gd
scripts/arena.gd       board, towers, gold, hands, deploy rules, drawing
scripts/card_db.gd     card data (the single balance surface)
scripts/unit.gd        troop AI + phase 2 behaviour
scripts/tower.gd       tower AI, HP, rubble
scripts/art.gd         all procedural outlined art (Adventure Time-ish flat)
scripts/hand_panel.gd  per-player hand UI (cards, gold, next)
scripts/projectile.gd  potion / tower shot
scripts/spell.gd       fireball / firebolt cast + impact
scripts/boulder.gd     golden idol revenge boulder
scripts/burst.gd       splash impact ring
scripts/dev_capture.gd verification helper (see below)
```

### Debug cheats

Only while **both hands are visible** (Tab). They are ignored in solo view so you
cannot cheat the normal layout by accident:

```
1  -> +1 gold to player 1 (bottom)
2  -> +1 gold to both players
3  -> +1 gold to player 2 (top / the bot)
B  -> toggle the bot
```

The keys are listed on a hint line under the mid-control chip in dual view.

## Hero abilities

Each player is assigned **one** of two abilities at random per match. Both cost
**2 gold** and share a **20 s cooldown**. The button sits in the top-right of your
panel and shows the cooldown, or the reason it cannot fire (`2g`, `no target`,
`no tower`).

| Ability | Effect |
| --- | --- |
| **Tentacle** | Bursts from the ground under the enemy troop with the most HP. Deals **20 on reveal** (no more after that) and holds it for **4 s**. The tentacle has **20 HP**; the ensnared side's own units or towers can kill it to free their troop early |
| **Shiesty** | Launches **Shiesty** from your king tower at the enemy tower with the most HP (leftmost on a tie). He hits once for 30 and **steals 1 gold**, then runs home: reaching your tower keeps the loot, being killed on the way hands it back. He is a thief, not a soldier — **towers ignore him entirely** and he **gives you no map presence**; only troops can stop him |

The bot uses its ability too, whenever it is ready and it can spare the gold
(gold >= 5, so it does not starve its card economy).

Force a specific assignment for testing: `--ability=tentacle` or `--ability=shiesty`
(player 1 gets it, player 2 gets the other).

### Buildings

The Snowman and Golden Idol are **1x1 buildings**; the Lizard Warren is a **2x2 building**. Buildings are
stationary and **immune to knockback and shoves**.

* You cannot deploy onto a **1x1** building tile at all (a swarm's outer bodies can still spill onto it).
* The **2x2** Warren sits **centred on the corner between four tiles** (its preview outlines all four),
  and it shoves any body that lands on it off to the nearest free tile, diagonals included.
* **Gold is drawn on the board**: one coin per tile, ten in a row along the bottom edge starting one
  tile in from the bottom-left corner for blue, and the mirrored top edge for red. Full coins are
  solid, spent ones grey, and the one filling is drawn larger with a near-white timer arc that only
  turns solid gold when it completes. There are no numeric gold totals anywhere.
* Troops no longer share a tile: overlapping bodies separate every physics tick, heavier bodies giving
  less ground, and flying never collides with ground.

### Statuses

Only **one** status can be on a unit; the newest application replaces whatever was there.

* **Burn** — pulses on every tick and its colour walks **red → orange → yellow** across the burn,
  flashing **white** on the tick that ends it. Each second it deals `floor(rate × stack)` and removes
  that much from the stack: **40 % for troops, 20 % for towers**. Ticks without a fresh application
  and the whole thing goes out — the duration is per card (`burn_ticks`, default 4). Towers can burn.
  A 40 burn on a 90 hp troop ticks 16 / 10 / 6 / 4; on a tower 8 / 6 / 5 / 4.
* **Slow** — dark blue tint; movement only, for a fixed duration.

### Orientation

The board is drawn **landscape**: your half on the LEFT, the enemy on the RIGHT, hand along the
bottom. Flip `LANDSCAPE` in `arena.gd` to get the original portrait board back — every drawing
primitive goes through `tile_rect()` / `tile_center()` / `tile_of()`, so nothing else has to change
(only the HUD layout would need to follow).

### The hand

Cards are **compact TCG faces** — cost medallion, name, HP (`60 ×3` for swarms), tall art, stat
strip and the attack line with its timing. No flavour text.

* **Hover** enlarges a card in place (1.3×) without moving it out of the strip.
* **Press and drag** pulls it out at normal size and it follows the cursor.
* Over the board the card fades out (22 %) and the **board preview takes over**: tile outline,
  tinted swarm ghost, spell radius.
* **Release over the board** deploys; release anywhere else leaves the card armed.

### Hover previews

While a card is armed, the tile under the cursor is outlined on the grid and a ghost of the
placement is drawn on the **tile centre**: swarms show the whole formation, the ghost is
half-transparent and tinted the placing team's colour, and spells draw their damage radius.
Legal tiles highlight green, illegal red.

### Towers

Towers fire an **aimed single-target bolt** — no splash, so a stacked pair only loses one body per shot.

### Boomerang rules

* Outbound it strikes **only the unit (or tower) it was aimed at** — one hit per throw, even against a
  fast target, and towers are fair game.
* On the way home it can still clip **anything closer than that target**, once each.
* It travels at 2 tiles/s, so a long throw is a slow, readable commitment.

## The bot (utility AI v1)

`scripts/bot.gd`. Player 2 is bot-controlled by default; **B** toggles it, and its
"thinking" (the card it is about to play, plus a target ring on the board) is only
drawn while **both hands are visible** (Tab).

Decision loop, ~2 Hz plus a 0.55 s telegraph before committing:

1. **Candidates** — every affordable card x a jittered set of anchor tiles (near
   enemies, near enemy towers, our lane openings, our towers, the band).
2. **Score** — gold pressure + defence value (summed enemy threat within 4 tiles,
   falling off with distance) + push value (progress toward the nearest enemy
   tower) + spell value (damage fraction x worth, towers worth more) + band control
   bonus − a cost penalty that shrinks when gold is near the cap.
3. **Pick** — sort, keep the top 3, softmax-weighted random choice with a per-bot
   seeded RNG. Same seed = same match; new seed = new match.
4. **Telegraph** — hold ~0.55 s with the card highlighted, then deploy.

Self-play harness (headless, fast-forward):

```
godot --headless --fixed-fps 60 --quit-after 20000 --path . -- --bots=both --scenario=bot --log
```

Known gaps, in rough priority: no counter-knowledge (it reacts to threat, not to
*which* card is coming), no tracking of the opponent's gold, spells valued only for
immediate damage, no retreating, and band control is a flat bonus rather than a
plan.

## Verification hooks

`dev_capture.gd` is only attached when a matching user argument is passed, so it
never ships in normal play:

```
godot --path . -- --demo --shots=<abs dir>          # bot plays both hands, dumps frames
godot --headless --path . -- --scenario=checks --log  # idol boulder + phase 2 numbers
godot --path . -- --scenario=click --log              # simulated mouse: card -> board -> spell
godot --path . -- --scenario=kit --shots=<abs dir>    # scripted visual kit
godot --path . -- --scenario=win --shots=<abs dir>    # match-over screen
```
