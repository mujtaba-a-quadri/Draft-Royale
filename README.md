# Draft Quadrint — arena slice

(Formerly Deep Draft; the folder and the code prefixes keep the old name.)

**0.4.2** · Godot 4.7.2

Clash-Royale-shaped arena, RTS troop play, two local hands driven by one mouse.
This slice is the **arena foundation** for the roguelike layer (deck building,
relics, heroes and match types come later).

> Working notes — where each system lives, how to add a card, how to measure the
> bot, and the traps that cost time — are in [`NOTES.md`](NOTES.md). Read that
> first if you are picking this up cold.

## Run

```
godot --path . --editor        # open in the editor
godot --path .                 # play: the title screen
godot --path . -- --run=<seed> # a run with a fixed seed
godot --path . -- --match      # one plain match, skipping the title
```

### Title screen

The game opens on a **coordinate plane drawn on graph paper** (`scenes/title.tscn`,
`title_screen.gd`): two axes running off every edge of the screen with a tick across them every square (a
longer one every five), and quadrants big enough that their outer edges run off screen too, so the
plane trails off in every direction (`MARGIN` / `ARROWS` in `title_screen.gd` bring back the bounded version), and the name, **Draft Quadrint**, in a circle on the origin. Each quadrant, in its colour from a
maths-textbook plane, is an option; hovering one (or picking it with the arrow keys) **lifts it away from
the axes and grows it**, and a click or Enter takes it:

| Quadrant | Option |
| --- | --- |
| 2nd, top left (peach) | **Play a match**: one plain match, both decks the whole collection |
| 1st, top right (lavender) | **Start a run** |
| 3rd, bottom left (mint) | **Collection**: every card, large (click one to see it with its description; Esc or Back returns) |
| 4th, bottom right (blue) | **Exit** to the desktop |

The pause menu (Esc) has a **Title screen** button, which abandons the match or run. Launching with
`--match`, `--run`, `--botsim=`, `--scenario=`, `--shots=` or `--demo` skips the title.

### A run (first slice)

A run is a string of fights with **one deck** against bots, one after another:
Border Skirmish, Swamp Patrol, an elite (the **Ballista Matriarch** or the **South Sea Kraken**, drawn from the run seed), The Chained
Keep. You start with a deliberately plain **10 card deck**: three Militia, two Elf Archers, a
Firebolt, the Alchemist, two cards that draw (Hot Chicken, Snowman) and **Humbaba** as the one win
condition, so every card you draft is a visible step up. Border Skirmish's bot plays the same kind of
basics.

* **Your commander tower's HP carries over** from fight to fight. Your side
  towers, and everything on the enemy side, come back full every time.
* **Win** and, after a moment, **Choose a Card** comes up: three different full
  cards (face and description) and **Skip**. Hovering a card grows it a little;
  hovering an icon on it shows what the icon means; hovering Skip grows and lights
  it. Click a card or press **1 – 3** to add it to your deck, or Skip (**S**);
  either way the next fight starts. Enter does
  not skip it. The three offered are fixed for that run and fight, and can be
  cards you already have. No reward after the last fight.
* **Lose** (your commander falls, or the clock runs out without you having taken more towers than
  you lost: in a run, level towers is a loss and tower HP never decides it) and
  the run is over; **Enter** (or R) starts a new one.
* Your hero ability is fixed for the whole run; the enemy gets the other one.
* The run's position, commander HP and deck size are shown left of the board.

A real act and its map are the next steps; the four fights above are
placeholders.

## Controls

| Input | Action |
| --- | --- |
| Left click a card in either side panel | Select that card for that player |
| **1 – 8** (solo view only) | Pull that card out of your hand — press it again to put it back |
| **9** (solo view only) | Fire your hero ability |
| Left click the board | Deploy it (troops: your half only, spells: anywhere) |
| Right click (anywhere) or Esc | Clear the armed card |
| Esc (nothing armed) | Pause: the match stops under a Resume / volume screen; Esc again resumes |
| Hover a troop or tower (no card armed) | Name + HP, **pale yellow aggro ring**, **pale red attack-range ring**, and for a summoner (Lizard Warren) a **pale green summoning radius** |
| B | Toggle the bot for player 2 |
| 1 / 2 / 3 (**Tab / debug view only**) | Debug gold: +1 to player 1 / both players / player 2 |
| Tab (dual view) | Shows floating **damage numbers** on troops: white under 20, amber 20+, red on a killing hit |
| A (**Tab / debug view only**) | Toggle the **all-cards overlay**: a scrolling grid of every card, 8 per row, with **BUILDINGS / TROOPS / SPELLS** filter buttons above it (click to filter, click again to clear, several at once allowed — the header says what is showing). Click a card to arm and place it for free. Placing on the **top half** deploys it for the opponent; on **purple (both-controlled)** tiles the side is random |
| S (**Tab / debug view only**) | Start the **elite encounter**: the opponent and all three of their towers are replaced by the **Ballista Matriarch** (see below). In a run, the elite fight draws her or the Kraken |
| R | Restart after a match ends |

Both hands are live at once: the left panel is Player 1 (blue, bottom half),
the right panel is Player 2 (red, top half). Only one card can be armed at a
time so a single mouse is never ambiguous — and the bot playing its own card
never disarms yours.

The opponent's hand runs down the right edge as **one column of up to four
cards**. The fifth makes that column shrink to half width and starts a second
column beside it, so a full hand reads as four plus one. Everything in a column
is the same size, shrunk so the whole column fits the panel.

## Board

* **30 rows tall.** Rows 1-10 (top) and 19-28 (bottom) are 16 tiles wide; the
  middle band of 8 rows (11-18) bulges out to 18 tiles, so the board reads as a
  plus. River at rows 14-15, bridges at columns 4-5 and 12-13, each deck **3 tiles wide**: those two columns plus half a tile of the water on either side. The half tiles can be walked on but **nothing can be played there**, and a troop shoved sideways on the bridge stays on it and keeps crossing instead of turning back to its bank.
* **Hover preview** — armed cards preview on the grid: tile outline plus a tinted ghost (or the
  whole swarm formation) and, for spells, the splash radius.
* **No-man's land** — the middle band of 8 rows. Each player may **always** deploy
  on the 2 band rows nearest their own half (rows 17-18 for the bottom player,
  11-12 for the top), so the free zone always reaches one row from the river.
  Anything deeper needs **presence**: a ground troop projects a **cone** that opens
  back toward its own half — 3 tiles wide on its own row, 5 one row back, 7, then 9 —
  but **never the tile the unit is standing on** (so its own row gives only the two beside it).
  Presence **never reaches the river water**; the bridge decks can be held.
  **Summoned fodder gives no presence**: the Nekomancer's Rat Skeletons, Meerkats and ants hold no ground (card key `no_presence`).
  Lizard Soldiers project the same cone **one row further forward**. Control is not exclusive — both
  players can hold and deploy on the same tile. Flying units project no control,
  and Shiesty projects none either. The grid is cached and only recomputed when
  a unit changes tile (drawn by `control_layer.gd`, which repaints on that change
  instead of every frame).
  No deployment within 3.5 tiles of an enemy tower, and **never on river water**
  (a building may not hang over it either).
* **Lane pocket** — take an enemy side tower and that lane opens to you, with or
  without presence. It covers the 6 columns from that edge to the bridge on both
  sides of the river: your near-river band row, and the 3 band rows past the river.
  It also reaches 3 rows further past the ruin along the edge (columns 1-2). The
  river water itself stays closed. It is drawn in your colour like held ground
  (`arena.POCKET`, mirrored for the other lane and the other player).
* **View modes** — solo layout (cards on the left third, arena on the right,
  opponent info strip) and dual hotseat (both hands). Tab toggles; the panel
  button does the same.
* Three towers per side: two princess towers and one **commander (king) tower**, **250 HP each**. Princess towers shoot **7 tiles**, the commander tower **8**.
  The princess towers stand in line with the bridges (centred on columns 5 and 13,
  rows 6 and 24); the commanders sit at rows 3 and 27. Their hitbox is a circle of
  0.9 tiles. `--towers=diamond` draws the princess towers as diamond keeps (looks
  only; `res://scenes/tower_mock.tscn` compares the shapes against the hitbox).
  **Taking the commander tower wins the match outright** — princess towers alone never end it.
* **The clock runs in three phases**, each announced in big letters across the middle of the board
  (over the troops, under buildings and towers) and named in the clock chip at the top:
  1. **Single gold**: 1:30 in a plain match and the run's first fight, **+15 s for every regular fight
     after that** (1:45, then 2:00), and 2:00 in an elite fight.
  2. **Double gold**, half as long (0:45 after 1:30). When it ends, **a tower lead wins**.
  3. Level on towers (and always in an elite fight): **sudden death**, half as long again but **at
     least 0:30**, with **quadruple gold**. **The next tower to fall loses** the match for its owner. In an
     elite fight your side towers do not count: only your commander or the boss ends it.
  From double gold on, ability cooldowns are halved and card draws come **two seconds faster**.
  If sudden death runs out: in a **run** that is a loss (an elite has to be killed); in a plain match
  it goes to **more tower HP left** (all standing towers summed), and level on that is a draw.
* **38 cards in the game, 36 in each deck** — Pen and the Magma Whelp are not dealt out; they only
  arrive when Penny / the Obsidian Whelp is played. (The Nekomancer's Rat Skeletons and the Ant Hill's ants are summons, not cards.) **3 cards dealt** at the start (`OPENING_HAND`), **at most 6 in hand** (`HAND_MAX`), 1 "next", cycling exactly like
  Clash Royale: play a card and it goes to the back of the queue. Both decks are
  **shuffled fresh every match**, independently of each other. **A deck may hold several copies
  of a card**; each copy is its own card (its own slot, its own Firebolt charges).
* **Card draws: one every 12 s, and every gold you spend brings the next draw 1 s closer** (play a
  5-cost card and it arrives 5 s sooner). A big spend can roll past a draw; the extra time carries
  into the next one. Cards, each Firebolt cast, the hero ability and the hero launch all count.
* Gold: starts at 5, caps at 10, regenerates 1 per 2.4 s — **double rate in double gold, quadruple in sudden death**.

## Cards (base numbers, all tunable in `scripts/card_db.gd`)

The card face is trading-card style (`scripts/card_face.gd`):

* **Top**: the cost coin, the name, and the HP at the right (`70 ×6` for a
  formation, `200+180` for a pair, nothing for a spell).
* **Art window**: a card that summons (Nekomancer, Ant Hill, Lizard Warren, Ovo
  Javer Machine) shows what it makes in a coin at the art's top right. A card that brings
  another card into the hand (Penny's Pen, each whelp's twin) shows it in the same spot as a
  little upright card instead of a coin.
* **Middle line** under the art: the type, then speed and sight for a troop,
  footprint and lifetime for a building, or where a spell is cast from.
* **Attacks**: one row each, with a crossed-swords badge for melee, a bow for
  ranged, a star for something that is not a hit, and a burst for a spell.
* **Attributes**: icons along the bottom (targets buildings, flies, spawner,
  burn, and so on). The hand names them in a list when they fit.
* **Description**: shown on the reward screen only.

The detail steps down with the card's width, and in the hand the face never
shows the description. The trim (border, frames) and the middle line are
colours: set `card_trim` / `card_line` on the arena in the inspector, or pass
`--trim=#hex` / `--line=#hex`. `res://scenes/tcg_mock.tscn` renders the face at
every size into `mockups/tcg/`, with an icon legend.

| Card | Cost | HP | Damage | Notes |
| --- | --- | --- | --- | --- |
| Hero | 3 | 150 | 25 / 1.0 s | Very high HP for the cost. Also rides down an airborne dragon. **Playing him draws one card** at once, and that is all: his gold does not pull the next draw closer, and the draw clock is left where it was |
| Snowman | 2 | 90 | – | Stationary decoy, **60 s lifetime**, draws attention (7.5 tile lure). **On death: 3-tile blast for 30 damage and a 3 s / 30 % slow** (troops only, dark blue tint). **Playing it draws one card** at once, and that is all: its gold does not pull the next draw closer, and the draw clock is left where it was |
| Slate | 3 | **200** | 12 / 1.6 s | Slow tank that ignores every moving troop — only structures and towers |
| Humbaba (troll) | 5 | **330** | 40 / 1.8 s, **1.2 tile tree club** | The tank: a mossy swamp troll who walks slowly at **buildings and towers only** and ignores troops. He swings a whole tree, held **by the middle of the trunk** (as much tree behind his hands as in front), so its reach is **1.2 tiles**. **Giant**: Penny cannot carry him off in her leap |
| The Chained Dragon | 9 | **420** | claw 45 / 1.4 s → **25 fire per second** | A green brute with his **wings** chained (the hands are free — it can still claw). At half HP the chains burst, he takes the sky and **breathes straight down** in **your team's colour**: a **2 tile burning patch** under and just ahead of him doing **25 damage a second**. It **burns friend and foe alike** — anything on the ground under him, your own troops included — but flyers are above it. He flies until the fire is landing on his target, so **the tower he is attacking burns too**, and he hovers there pouring it on |
| Alchemist | 4 | 55 | 45 splash (1.4 tiles) / 2.0 s | At ≤50% HP it flips team, charges the nearest **tower or building** at high speed and detonates for 100. After turning it ignores troops entirely |
| Fireball | 5 | – | 40 splash + **70 burn**, shoves loose units 1.2 tiles out, then **10 burn a second** from the ground | Fired from your **king tower**; `tower_mult` cuts tower damage. The blast leaves the ground **burning for 4.2 s** across its whole 2.2 tile radius: every second (4 doses) it adds **10 burn** to each enemy troop, building or tower standing in it |
| Firebolt | 2 | – | **No damage — 60 burn**, one target | An arrow of fire from your **nearest tower**. The only card that **locks on**: while you hold it, hovering any enemy body — **troop, building, tower or boss** — rings it and pins the cast to it. **It can only be played locked on**: over bare ground there is no preview and a click does nothing (no gold spent). It has **no radius**: the arrow **follows its target all the way in and always lands on it**, burning that one body and nothing beside it (if the target dies first, it lands where it was)  **Two casts**: after the first throw the card stays in your hand and stays armed, so clicking again throws again — right click (or picking another card) puts it back with one charge left, shaded over the spent half (the triangle below the bottom-left → top-right diagonal). Only the **second** cast consumes it |
| Snowball | 4 | – | **10 × height** while rolling, **30** on the burst | You pick a tile; it is **thrown in an arc** from your **nearest tower** onto it, lands as **one tile of snow**, then rolls forward in a straight line along that row, growing **smoothly, a tile of height for every two tiles it covers** (its size and the lane it flattens grow continuously; damage and shove count whole tiles of height). That means it can be cast **on their side** — it simply starts rolling where it lands. Rolling strikes deal **10 per tile of current height** and shove things back that many tiles, **once per enemy** (the roll never hits the same thing twice). It rolls **8 tiles** from where it lands, **straight over the river**, then bursts (sooner at the back of the board) for **30** and a **3.5 s slow** on everything in its lane from its own size behind to **1.5 tiles past its front**, so the burst catches what the roll shoved ahead of it. Troops only |
| Golden Idol | 4 | 35 | – | Stationary, taunts, **10 s lifetime**. On death it **drags enemies within 3 tiles inward at 1 tile/s** for a 1 s rumble, then breaks loose as a boulder **2.5 tiles behind the idol** and rolls through the spot at its killer, locked to **16 compass directions**: 80 damage, **2 tile knockback and a 2 s stun** to everything it passes |
| Hedgehog | 3 | 60 each | 12 curl / 8 thorns | Two burrowers with **no jab at all**. They walk to their melee reach and **ball up**: 12 damage plus a shove of about half a tile, always short enough that nothing leaves quill reach. Balled up they take **45 % damage**, and anything striking the ball from within **1.5 tiles gets 8 back — melee or ranged**, since projectiles are credited to their shooter. They hold while the quills can reach something and **walk again once nothing is in reach**  **Air is invisible to them**: they never pick a flying target and their burst skips flyers. But a **melee flyer that dives on one** makes it ball up on the spot — the dive itself is not repaid, and **every hit after it takes 8 thorns**. They stay rolled up until nothing is in quill reach, then walk again |
| Zombie Horde | 6 | 111 each | 15 / 1.0 s each | Six melee bruisers in a 2x3 block. **Anything a zombie kills rises as a full-HP zombie on the killer's side — troops only, buildings stay dead** |
| Honeycreeper Flock | 4 | 10 each (lead 20) | 6 / 1.0 s each | Flying swarm of 5 in a diamond, lead i'iwi in front. Ground troops can't touch them; they can hit the flying dragon. Alchemist and Boomerang-Fu can hit air too |
| Lizard Soldiers | 3 | 55 ×3 | 10 every 1.0 s **rifle at 3.5 tiles** | Wedge of three. **Always retargets the weakest thing in range — troops, buildings and towers alike** — not the nearest, and its presence cone sits **one row further forward**. With nothing in range it **advances on the nearest enemy tower** instead of standing still |
| Lizard Warren | 4 | 130 | – | Stationary burrow with a **60 s lifetime**. When an enemy comes within **6 tiles** it empties out **3 Lizard Soldiers**, then waits 6 s |
| In-Ovo Machine | 6 | 240 | – | A **2 × 2** industrial hatchery with a **60 s lifetime** that pushes a **Hot Chicken** out of its front hatch **1 second after it is deployed and every 12 seconds after that** (five on the clock), plus **one more when it dies** — whether the timer takes it or it is destroyed early — front and centre, facing whichever way your push is going. It runs on its own clock: unlike the Warren it does not need company |
| Hot Chicken | 2 | 45 | 5 fireball (3.5 tiles) + 5 burn; **then 30 burn splash** on contact | Two phases. It **pecks fireballs from range**, and after **three hits on one target** it takes to the air: a **fire spirit that flies **twice as fast** at that target and rams it, setting everything in a 1.4 tile radius alight with **30 burn** (no direct damage), dying in its own blast**. It becomes a flyer for the ram, so ground troops without anti-air cannot stop it — but it is **killable in flight** by anything that hits air, and shooting it down means no burst at all. **Playing it draws one card** at once, and that is all: its gold does not pull the next draw closer, and the draw clock is left where it was |
| Penny | 3 | 90 | 10 / 0.7 s, melee; **20 leap** | Calico blur. She fights **anything, buildings and towers included**, but **a flyer in sight always comes first**, ahead of any nearer ground target. She **never swipes a flyer**: she runs in under it and, within **2.5 tiles**, **leaps at it**, grabbing it and carrying it the full 2.5 tiles for a **double hit** (20) while untargetable, then waits **1.4 s** before her next leap. On the ground, after **2 swipes** she goes **invincible and untargetable**: she steps **half a tile back** and **strafes a quarter circle** around her target (first strafe turns toward the outside of the board, later ones keep turning the same way), then leaps at the nearest air unit within 2.5 tiles, otherwise the closest body, the same grab. **Giants and buildings cannot be carried** (she stops on their hitbox instead), and with nothing to grab she simply does not jump. **Playing Penny gives you Pen on the spot**: his card flies from where she landed into the hand slot she left, and Penny goes to the back of the deck like any card |
| Pen | 2 | 100 | 10 / 1.8 s, **5 tile blowgun** | Penny's other half: slow, calm, wrapped in a yellow toga. Every **dart paralyses** whatever it hits for **0.5 s** (units only — towers have nothing to paralyse). **Used up when played**: Pen never goes into the deck, so each Penny play gives exactly one Pen  **Hits air** — a dart to a honeycreeper paralyses it mid-dive |
| Primal Aphid | 3 | 110 | **5 × 8** in a 45° cone, every 2 s | A flyer that **hovers in to 2 tiles and stops** — it never closes. From there it spits a **five pellet shotgun** across a 45° cone aimed at its target. Each pellet flies **3.5 tiles**, so it reaches a full tile and a half past the aphid's own stance, and it can hit **ground or air**. Pellets **do not pierce**: the first body a pellet crosses eats it and the pellet is spent |
| Boomerang-Fu | 4 | 90 | 30 boomerang / 18 jab + 26 kick (never on air — he throws at flyers even point blank) | Throws a 2 tiles/s boomerang that hurts everything it crosses and turns around at the target; stands still until it is caught. Melee combo (2 jabs) ends in a kick that shoves the enemy 3 tiles and Fu 2.2 tiles back |
| Laniakea | 4 | 100 | **25 cleave** / **50 leaping slam**, one swing every 2.0 s | A slow bug with a sword bigger than he is, and the only **melee unit that hits air**. He goes for whatever is closest, and the swing depends on what that is (all distances centre to centre). **Ground, within 1.5 tiles: the cleave** — a **140° arc** centred on the target, swept from the inside of the arena to the outside with a **2.2 tile** blade; every ground body in it takes 25 and is **shoved 0.5 tiles** away from him. **Air, 2.5 – 3.5 tiles away with nothing on the ground closer: the leap** — he jumps to the flyer and brings the sword down for **50** on it and on everything, ground or air, in a strip **2.5 tiles behind it**, **stunning units for 0.5 s**. **He leaps at ground troops too**: a ground troop (not a building or tower) in the same 2.5 – 3.5 window with no flyer closer gets the jump, as long as his swing is off cooldown — otherwise he keeps walking in to cleave. A ground body closer than the flyer keeps him from leaping at the flyer, and a flyer that gets **inside 2.5 tiles is out of his reach entirely** |
| Femme Fatale | 2 | 60 | **12** per combo hit / 1.2 s, **25 dash** | Hooded, with a needle longer than she is. Ground only, and she always goes for the nearest ground body (all distances centre to centre). **Dash:** when that body is **3.5 – 4.5 tiles** away with a straight walk to it (never across the river), she raises the needle, the tip glints for **0.45 s**, and she lunges until she is **1.5 tiles** away, landing **25** with the tip (1.6 reach). A stun or a shove during the wind-up or the lunge cancels it. **Combo, within 1.5 tiles:** a 15° flick in from the inside of the arena (drawn only — single target), a stab, then a stab whose recoil **carries her 0.5 tiles back**; then it repeats. A new target restarts the combo |
| Obsidian Whelp | 1 | 60 | 8 / 1.2 s nip, melee | A baby black dragon armoured in bone-coloured scales. **It curls up** — head tucked, eye shut — whenever an **enemy unit is within 3 tiles** (edge to edge, ground or air) **or it is hit**. Curled it does nothing at all, takes **80 % less damage** (no thorns), and **any melee blow pushes it 0.25 tiles**. The hit that wakes it lands in full. It opens again once **no enemy unit is within 3 tiles and it has gone 2 s without being hit** — so under tower fire it stays shut. **Playing it puts a Magma Whelp in its hand slot**, and playing that puts the Obsidian Whelp back: the twins swap every play and **never go back into the deck**. A whelp that swaps in **cannot be played for 3 s** (the card shows a draining clock and the seconds left) |
| Wu Cheng'en | 4 | 140 | **16** per staff hit / 1.4 s, melee (1 tile) | A bonobo who **knuckle-walks on all fours**. In reach he stands and **pulls a tiny staff from behind his ear that grows to full size in both hands** (0.4 s, no swing until it is out; it stays out while he closes a step or two, and goes back once the fight is more than 1.5 tiles past his reach). Then he alternates: a **poke** that goes through the target and **2 tiles on**, hitting and **pushing 0.5 tiles** everything on the ground in that line, and a **sweep** across a **120° cone** (1.8 tiles) centred on the target. Ground only. **Every enemy struck banks one rage.** Under **25 % HP** (a tick in the opponent's colour on his HP bar) he **rages once for 5 s**: **+25 % move and attack speed** and regen by banked rage: **5 HP/s**, **15** from 4 hits, **25** from 8, **40** from 12. A second bar under his HP fills once per rage level, each pass redder |
| Nekomancer | 5 | 100 | **14 beam** / 1.2 s, **4 tiles** | A black cat in a ragged green cloak and a pointed wizard's hat, with a crescent-headed staff. The staff fires an **instant single-target beam** in **your team's colour** at **ground or air**. **1.5 s after she is played, then every 4 s**, the wind catches her cloak and **two pentagrams** open on the ground **on her forward diagonals, a tile further ahead** (1.85 tiles in front, 0.85 to each side), so the rats climb out in front of her; **1 s later a Rat Skeleton climbs out of each**. The pentagrams belong to the board, so **a ritual already glowing still finishes if she dies** |
| Gilgamesh & Enkidu | 6 | **320 + 280** | lash **22** / 1.3 s (**2.5 tiles**); spear **24** / 1.2 s, **45 thrown** | One card, **two bodies** landing a tile apart, both tanky and quick (1.3 and 1.45). **Gilgamesh**, in teal plate with a lion's head on his shoulder, lashes with **a snake in your colour**: an instant hit out to **2.5 tiles**, ground only. **Enkidu**, the horned bull-man, **throws his spear** (45) at the nearest **ground troop** whose centre is **3 – 4.5 tiles** away — never a flyer, building or tower, and not at all if anything is already **inside 3 tiles**, which he fights with the spear in hand instead (24, **reaches air**). After a throw he fights with a **short sword** (16 / 0.9 s, 0.5 reach, ground only) for **3.5 s**, then the spear is back and can be thrown again |
| Militia | 2 | 80 | **9** / 1.0 s, 0.6 tile spear | A farmhand with a spear and a pot-lid shield: the plain melee basic of the starter deck. Never offered as a card reward (every card not in the starter deck can be) |
| Ballista | 5 | 220 | **34** siege bolt / 3.0 s, **7.5 tiles**, buildings and towers only | **The first moving building.** A lizardfolk engineer lifts the back of the stock and **wheels it forward** (0.45 tiles/s); once something is in reach he sets it down and winds the string back for each shot. It is a building by every rule (building-hunters go for it, shoves do nothing, it holds no tile) but it walks, and it has **no lifetime**. Up a lane it **sets down on the middle of the bridge, 9 tiles from the enemy side tower's centre: out of that tower's 7-tile reach**, so only troops can stop it. Uncontested it takes about 22 s to bring a side tower down |
| Elf Archer | 4 | 110 | **20** / 1.3 s, **5.5 tiles**, hits air | A hooded elf with a longbow: a plain ranged troop with the longest reach of any troop, shooting **ground or air**. The string comes back as the next shot comes due. In the run's starter deck, never offered as a card reward |
| Mated Mantises | 5 | **150 + 120** | claws **14** / 1.0 s (0.8 tiles); scythe **12** / 1.6 s (**4 tiles**, hits air) | One card, **two bodies**: the male lands on the tile, the **female 3.5 tiles behind him** (towards your side, pulled forward off water). He claws; she throws a **spinning scythe**. When he drops to **25 %** she **leaps on him from wherever she is** (0.55 s; he is frozen and unkillable while she is in the air) and **bites his head off**: he is out of the fight at once and his headless body lies there for 3 s. She heals **+50 % of her max HP, up to 125 %** (the extra shows as a brighter run of bar past its end), gets **Wu's rage without the regen** (5 s of 1.25x speed and attack speed, a red line under her bar) and from then on **claws (18 / 1.0 s, 0.8 tiles) as well as throwing**. Shot down in mid-leap, she lets him go and he fights on. Numbers: `devour` in `card_db.gd` |
| Poison Dart Frog | 1 | 25 | **10 poison**, once | A glossy black frog striped in a brighter version of **your colour**, on blue spotted legs. It never walks: it **hops 0.7 tiles** at a time (0.22 s in the air, 0.45 s sitting, about a tile a second). It has **no attack**. The moment any ground enemy — troop, building or tower — has its edge within **2 tiles**, it **leaps** on the nearest one (following it through the air), lands, and **bursts**: **10 poison** on every ground enemy the **0.5 tile** circle touches, and the frog is gone. Flyers are out of its reach. Poison never wears off (see the spider) |
| Phalanx | 8 | 70 ×6, **shield 60** each | spear **14** / 1.3 s, **1.7 tiles**; dagger **8** | Six spartans, **three across and two deep**, so the back rank pokes over the front. Each **raises its shield by the Obsidian Whelp's rules**: an enemy unit within **3 tiles** (edge to edge) or a hit; lowered once nothing is in 3 tiles and **2 s** have passed unhit. The hit that raises it lands on the spartan; while raised, **every hit lands on the shield's own 60 HP** (burn and poison go past it), and he **keeps walking and poking, slower** (60 % move, 1.3× the poke interval). A **broken shield** means a **dagger**: with the target within **1 tile** he stabs between pokes (poke, stab, poke… each 0.65 s apart). Ground only |
| Wolf Pack | 4 | 55 ×4 | **10** a bite | Four wolves in a diamond that **move as one** (each keeps its place around the pack's middle; single file over a bridge). Within **6 tiles** of the pack they hunt the **loneliest ground troop** — the one whose nearest friend (troop, building or tower) is furthest — and with none, the nearest building or tower. Arrived, they **ring it 2 tiles out from its edge** (turning slowly round a troop, an arc on the near side of a structure) and **take turns darting in to bite** like clockwork: the pack bites **every 0.4 s, however many wolves are left** (a lone wolf goes again as soon as it is back) |
| Goat Rider | 5 | 260 | **60 ram**, then **18** tomahawk / 1.1 s, melee | A painted warrior on a huge woolly mountain goat that walks at **buildings and towers only**. The **first hit on each new target is the goat's ram** (60); after that he chops at it with his tomahawk (18). **The wool:** a melee blow on the goat (struck up close by anything with less than 2 tiles of reach) puffs it up and **shoves the attacker 1 tile away**; the blow still lands. Projectiles and long reaches do not set it off |
| Meerkats | 2 | 22 ×4 | 5 / 0.6 s, melee | Four fast (1.9), fragile biters in a square |
| Ant Hill | 4 | 140 | – | A 1 × 1 mound with a **60 s lifetime**. An **ant** crawls out of the front **1 s after it lands and every 1.2 s after** (about fifty in all) |
| Ant | – | 8 | 2 / 1.0 s, melee | From the Ant Hill, never dealt. Slow (0.55), tiny, ground only. Ants walk the shortest way to a tower. **Ants ignore troops and go for buildings** (a building within reach of their sight is bitten first), **until a troop kills an ant**: that troop is **marked for 10 s**, and every ant that sees it within 4 tiles swarms it for as long as the mark lasts. With several killers marked, each ant takes the **closest**, not the latest |
| Rat Skeleton | – | 20 | 6 / 0.8 s, melee | The Nekomancer's summon, never dealt. Quick (1.4), brittle, ground only |
| Magma Whelp | 1 | 30 | **5 burn** per feather / 1.4 s, **2 tiles** | The Obsidian Whelp's molten twin, never dealt. **Flies**, and flicks flaming feathers at **ground and air** within 2 tiles: no impact damage, just 5 burn each. Playing it brings the **Obsidian Whelp back into the hand slot**; neither twin ever returns to the deck |

Tower fire: 12 damage / 1.0 s, 6 tile range. Towers shoot the nearest enemy unit
in range, but a **curled** unit (an Obsidian Whelp or a balled-up hedgehog) is
only shot when there is nothing else in range; a tower on a curled target
switches as soon as something else walks in.

## Elite encounter: the Ballista Matriarch

Press **S in the debug view** (Tab). The opponent's towers, troops, hand and bot
are removed and one giant spider, drawn from above, sits where their commander
was. She counts as a tower: troops walk at her and hit her like one, and
**killing her wins the match**. On the clock it is her HP against the sum of
your towers. All numbers are in the `spider`, `spideregg` and `spiderling` cards.

| What | Numbers | How it works |
| --- | --- | --- |
| Body | **900 HP** | Always faces your board; never turns around |
| Skitter | waits **3 – 7 s** at the back (random), **2 – 5 tiles** forward, stays **10 s minus that wait** | Runs toward you and stays. The longer she sat at the back, the shorter she stays forward. Then she lays an egg, builds a trap, takes her parting shot and **walks** home (3 tiles/s). She keeps stabbing and webbing the whole time |
| Poison pool | seeps at **2.5 tiles/s**; **5 poison every 0.5 s** to your ground troops in it (pool and stream alike) | The moment she is forward, poison in the green of her abdomen seeps from her mouth: a wide **pool** in front of her face (about **3.6 tiles across** and 1.8 deep), then a **braided stream** running down to the river. Where it flows in, the **river turns poison downstream**, to the bottom of the board (the bridges stay clear). When she leaves it **dries from her mouth down**, then the river **clears from the top down**. The river itself does nothing to troops (they cross on the bridges) |
| Egg | **60 HP** building, **30 s** lifetime | Laid centred on a **2 × 2 patch of web**. When it dies — timer or damage — **Spiderlings** climb out: **one per eighth of its life it lasted** (rounded, at least 1): 4 at 15 s, **8** if it runs out. Dark specks inside the egg show how many are in there now |
| Spiderling | 40 HP, **6 + 5 poison** per bite / 0.8 s, fast | An ordinary enemy troop: walks at your troops and towers |
| Venom spit | **6 + 10 poison**, **0.5 tile splash**, any distance | **Not until the pool has formed.** Then one every **2 s** at your closest unit while she is forward. **Parting shot:** after the trap, her **eye glints for 0.6 s** and she spits at your nearest tower or building, then walks home. The glob follows its target and bursts on arrival, hitting everything of yours in the splash |
| Front legs | **35** / 1.6 s, **4 tiles** | A stab at the nearest of your units in reach |
| Webbing | a **2 × 2 patch** every **5 s** | Laid 2.5 tiles ahead of your nearest ground troop, along the way it is walking, **never on water** (the bridge decks' outer half tiles included). Stepping on a web tile **slows 50 % for 2 s** and **destroys that one tile** |
| Slingshot trap | one per cycle, on a bridge that has none | After the egg she walks to a bridge with no trap (the nearer; alternating when level) and **builds it with her front legs over 3 s**, modelled on the real slingshot spider's: anchor threads on the deck, a silk cone pulled up into a point, a taut thread from the point. Until it is finished it does nothing. Then the first of your ground troops to step on it is **launched out of the arena**: removed, not killed, so nothing that happens on death fires. Flyers pass over it. Both bridges armed: no trap that cycle |

She is drawn stretched **1.5 × both ways** (along the lane and across it); her
hitbox is unchanged.

**Splash attacks show their reach**: every splash that lands from a projectile
(the venom, the Alchemist's potion) flashes a **light circle in the attacker's
colour for 12 frames** at the size of the splash. Spells keep their own blast.

**Poison** is new and is not a status like burn or slow: it is a counter that
**only goes up and never wears off**. Every **5 s** it deals **2 × the counter**
(**half that to buildings and towers**).
A purple badge on the unit (or tower) shows the counter and a ring that fills
toward the next tick.

## Elite encounter: the South Sea Kraken

Press **K in the debug view** (Tab). The same swap as the spider, but what takes
the opponent's place is **five tentacles**. Each is rooted in one tile; its body
and head (the part your troops hit) lean slowly toward your nearest unit, never
more than a tile from the root either way. They count as towers. The Kraken
itself is under water and cannot be hit until all five are down. All numbers are
in the `kraken` and `krakenarm` cards.

| What | Numbers | How it works |
| --- | --- | --- |
| Tentacle | **150 HP** each | Killed, it pulls back into the ground and only the horn shows |
| Slam | **30**, enemy within **3.5 tiles**, every 2.5 s | Sways for 0.65 s, smashes down up to 2.5 tiles out, and purple waves run **1.5 tiles ahead and to both sides** of the impact. Hits ground and air. **Behind the tentacle is safe** |
| Spin | **25**, **2 tile** radius | Only at **30 % HP or less** with an enemy inside 2 tiles: coils back for 0.5 s, then one full turn with a pink trail |
| Purple arrow | **40**, every **10 s** | Only when **every one of your units is 6+ tiles from that tentacle**. Flattens and points for 0.6 s, then shoots a slow (5 tiles/s) straight arrow at your nearest unit, building or tower. It never turns, and **the first of your bodies in its path takes it**. Timers start 2 s apart, the furthest tentacle first |
| Phase 2 | body **500 HP** | When all five are down the Kraken surfaces in the middle of its side. **Killing it wins.** Every tentacle comes back with **half HP and half attack speed** |
| Red orbs | 3 big orbs every **25 s**: **30** in 1.2 tiles | Slow, with a limited turn rate, chasing your nearest body. On touch or after 6 s each bursts and **splits into 3 – 5 small orbs** (12 in 0.7 tiles) that chase for 1.5 s and burst too |
| Burrow | every **8 s**, one revived tentacle | It sinks through its root, a **red circle marks the spot** where one of your ground troops is standing, and 0.5 s later it bursts out there: whoever is still within 0.8 tiles takes **20** and is **held for 4 s by a 20 HP tentacle** (the hero ability) unless it is cut down. The tentacle is untargetable while away |

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
- A **stun wipes the charge**: levels, timer and speed all go back to the start.

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
Only the cosmetics roll dice: a dying unit **pops into mini confetti** — its card accent and its
owner's team colour, each with a lighter and a darker variation — thrown further, faster and in
greater number the bigger the body was (the randomiser lives in `confetti.gd`).

## Project layout

```
scenes/arena.tscn      root Node2D + arena.gd
scripts/arena.gd       towers, gold, hands, deploy rules, drawing (the scene)
scripts/board.gd       DDBoard — grid constants, tile <-> screen maths, footprints
scripts/arena_draw.gd  DDArenaDraw — board, deploy hint, hover box, HUD, result overlay
scripts/card_db.gd     card data (the single balance surface)
scripts/unit.gd        troop AI + phase 2 behaviour
scripts/tower.gd       tower AI, HP, rubble
scripts/art.gd         all procedural outlined art (Adventure Time-ish flat)
scripts/hand_panel.gd  per-player hand (slot layout, NEXT, input routing, fly-in)
scripts/hand_card.gd   DDHandCard — one hand card node (rect, hover/drag/fly-back, tween)
scripts/card_grid.gd   DDCardGrid — filtered, scrolling card grid (debug overlay today)
scripts/card_face.gd   DDCardFace — the printed face of a card
scripts/bot.gd         DDBot  — v1 flat utility scorer (A/B baseline)
scripts/bot2.gd        DDBot2 — perception, states, role-matrix scoring
scripts/bot_matrix.gd  card roles derived from data + the answers table
scripts/bot_sim.gd     headless A/B harness (--botsim=<seed>)
scripts/projectile.gd  potion / tower shot
scripts/spell.gd       fireball / firebolt cast + impact
scripts/boulder.gd     golden idol revenge boulder
scripts/burst.gd       splash impact ring
scripts/confetti.gd    DDConfetti — the mini confetti a dying unit leaves behind
scripts/dev_capture.gd verification helper (see below)
```

### Debug cheats

Only while **both hands are visible** (Tab). They are ignored in solo view so you
cannot cheat the normal layout by accident:

```
1  -> +2 gold and a card to player 1 (bottom)
2  -> +2 gold and a card to both players
3  -> +2 gold and a card to player 2 (top / the bot)
B  -> toggle the bot
```

The keys are listed on a hint line under the match clock in dual view.

## Hero abilities

Each player is assigned **one** of two abilities at random per match. Both cost
**2 gold** and share a **15 s cooldown** (**7.5 s from double gold on**). The button sits in the
top-right of your panel and shows the cooldown, or the reason it cannot fire (`2g`, `no target`,
`no tower`). Both also pay out **one card draw**, but only when the payload actually lands —
the tentacle's draw arrives when it dies, Shiesty's **either way** — caught or home.

| Ability | Effect |
| --- | --- |
| **Tentacle** | Bursts from the ground under the enemy troop with the most HP, **coils round it** (more turns for a bigger body, drawn in the caster's team colour) and holds it for **4 s**, **squeezing for 7 on the grab and every 1.6 s after** (21 over a full hold; the coil visibly tightens on each squeeze). The kraken elite's burrowing arms use the same tentacle. The tentacle has **20 HP**; the ensnared side's own units or towers can kill it to free their troop early. **Its card draw comes when it dies** |
| **Shiesty** | Launches **Shiesty** from your king tower at the enemy tower with the most HP (leftmost on a tie). The flight out is **invincible and untargetable** — nothing can see or touch him until he lands. He hits once for 30 and **steals 1 gold**, then runs home: reaching your tower keeps the loot (**and pays the card draw**), being killed on the way hands it back and pays nothing. He is a thief, not a soldier — **towers ignore him entirely** and he **gives you no map presence**; only troops can stop him, and only on the way home. **He picks his way home as he lands**: the bridge whose half of the board holds fewer enemy troops that could attack him (the nearer bridge on a tie), and he **never turns back** once he has chosen, whatever gets played after  **Either outcome pays one card draw** — getting home or being cut down on the way; only the **coin** has to reach your tower, so a dead Shiesty hands the gold back and still brings a card |

The bot holds the ability until it will pay off (it still needs gold ≥ 5 first):

* **Tentacle** — fires if its squeezes alone (21 over the hold) kill the target, or if its own units and nearby
  towers can finish the held troop inside the 4 s hold, or if its hand is down to 3 cards (then the
  draw is the point). It **will not** fire into a target that a crowd of enemy units and towers are
  standing over — that tentacle dies on reveal for nothing.
* **Shiesty** — never fires while enemy units and towers near the target will meet him, and never
  fires when the enemy has no gold to steal (nothing to deliver means no card either).

Force a specific assignment for testing: `--ability=tentacle` or `--ability=shiesty`
(player 1 gets it, player 2 gets the other).

### Buildings

The Snowman and Golden Idol are **1x1 buildings**; the Lizard Warren is a **2x2 building**. Buildings are
stationary and **immune to knockback and shoves**, and every one of them but the Ballista has a **lifetime**: it bleeds
its whole HP bar away at `max_hp / lifetime` per second, so it dies on the timer unless something
kills it sooner. The Snowman and the Warren last **60 s**, the Golden Idol **10 s**.

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

### Team colours

Both sides are **data, not literals**. `arena.team_colors = [colour, colour]` recolours everything a
side owns — towers, the panel accent, the control tint, the deploy ghost and the NEXT trace — and
every unit's outline is a darker shade of its own colour instead of black. Nothing else hard-codes
blue or red. To see it without a menu:

```
godot --path . -- --colors=#ff8800,#22ccaa
```

### The hand

Cards are **compact TCG faces** — cost medallion, name, HP (`60 ×3` for swarms), tall art, stat
strip and the attack line with its timing. No flavour text. A **swarm card's art shows the whole
formation**, not one body, oriented exactly like the deploy preview — and that art is **blanked out
while you drag the card over the arena**, so the placement preview is the only copy on screen.

* **Unplayable** — a card you cannot pay for is washed dark grey and see-through, with a light grey
  fill climbing it for every part of its cost you already hold and its cost written in **red**. It
  only shows its true colours once it is affordable, but it can still be picked up and carried onto
  the board and its ghost keeps the grey, the fill and the red cost.
* **Clicking to place something you cannot pay for** spends nothing: two or more gold short and the
  cost **flashes**; **less than one coin short** and the placement is **queued** and plays itself the
  moment the gold arrives. Picking any other card first cancels the queue — and the gold is only ever
  spent when the troop actually lands.
* **Hover** grows a card 1.25× and lifts it half out of the strip. It stays solid until a troop
  stands anywhere behind it, then drops to 40 %; a troop behind the art window also blanks the
  art, so the board stays readable (`HandPanel.HOVER_ALPHA` / `HOVER_OCCLUDED_ALPHA`,
  `DDCardFace.art_rect()`).
* **Picking a card up** — press-and-drag and click-then-move are the same gesture: the card leaves
  the strip and follows the cursor whether or not the button is held. Clicking the same card again
  puts it back.
* Over the board it becomes a **20 % ghost of itself with no art, snapped to the grid** (the tile centre,
  or a 2x2 building's whole footprint) on top of the **board preview**: tile outline, tinted swarm
  ghost, spell radius.
* **Release or click on the board** deploys it; anywhere else leaves it armed.
* **It always flies back into its slot** (0.34 s, eased) instead of snapping — after a deploy, on right click, on
  Esc, or when it is carried back off the board after being on it.
* **Drawing while you hold a card keeps holding it**: when a full hand throws its leftmost card away
  every slot shifts, and the selection follows the card (that exact copy) rather than the slot.
* **NEXT** — the next card's edge is traced by a progress line that starts and ends at its top-left
  corner and fills with the draw timer. It is your team colour, and your opponent's while the hand
  is full (the next draw throws the leftmost card away).

### Hover previews

While a card is armed, the tile under the cursor is outlined on the grid and a ghost of the
placement is drawn on the **tile centre**: swarms show the whole formation, the ghost is
half-transparent and tinted the placing team's colour, and spells draw their damage radius.
Legal tiles highlight green, illegal red.

The **Firebolt** is the exception: it locks onto an enemy **troop** under the cursor, rings it instead
of outlining a tile, and both its preview and its cast follow the troop's live position — so it keeps
tracking a moving target and lands on it, not on the ground under it.

### Towers

Towers fire an **aimed single-target bolt** — no splash, so a stacked pair only loses one body per shot.

### Boomerang rules

* Outbound it strikes **only the unit (or tower) it was aimed at** — one hit per throw, even against a
  fast target, and towers are fair game.
* On the way home it can still clip **anything closer than that target**, once each.
* It travels at 2 tiles/s, so a long throw is a slow, readable commitment.

## The bots

Player 2 is bot-controlled by default; **B** toggles it, and a bot's "thinking" (the card it is
about to play, plus a target ring) is only drawn while **both hands are visible** (Tab).

* `scripts/bot.gd` — **v1**, the flat utility scorer. The baseline the harness measures against.
* `scripts/bot2.gd` — **v2**, perception → state → scored play, all card knowledge in roles.
* `scripts/bot_matrix.gd` — card roles + the answers table.
* `scripts/bot_sim.gd` — the headless A/B harness.

### v1 (baseline)

~2 Hz decision tick plus a 0.55 s telegraph. Candidates are every affordable card × a jittered set
of anchor tiles (near enemies, near enemy towers, our lane openings, our towers, the band). One flat
score: gold pressure + enemy threat within 4 tiles + progress toward the nearest enemy tower + spell
damage fraction + a band bonus − a cost penalty. Top 3 go through a seeded softmax.

### v2

It reads the board first, then picks a state:

| state | when | what it does |
| --- | --- | --- |
| **DEFEND** | enemy units threatening one of my towers past a pressure threshold | plays the best *answer* to that cluster, lands it beside the cluster, no softmax — a tower is at stake |
| **COUNTER** | my troops are alive on their half | supports the survivors from behind |
| **ATTACK** | board is quiet and gold ≥ 6 | pushes the weakest non-crown tower: tank first, ranged/splash once something is walking |
| **HOLD** | none of the above | spends nothing rather than feeding |

"How good is this card here" comes from the **role matrix**, never from card names — decks shuffle, so
the bot reasons about the hand it actually holds. Roles are derived from card data: `stationary` →
building, `swarm_offsets` ≥ 3 → swarm, `flying_unit` → air, `reach` ≥ 1.8 → ranged, `hp` ≥ 150 →
tank, `type` = spell → spell. A new card needs tags, not a new row:

| answer ↓ / threat → | swarm | tank | ranged | melee | building | air |
| --- | --- | --- | --- | --- | --- | --- |
| air | | | | 2.0 | 2.5 | |
| melee | | 1.6 | 2.0 | | 1.0 | |
| swarm | | 2.0 | 1.2 | | 0.8 | |
| splash | 2.6 | | 1.0 | | 2.0 | |
| ranged | | | | | 0.6 | 1.5 |
| spell | 2.2 | | 1.0 | | 1.2 | |
| tank | 0.8 | | 1.2 | | | |

A card that cannot hit air scores nothing against a flyer (except spells), and a defensive play that
lands more than ~3.4 tiles from the danger is refused outright.

### Measuring it: the A/B harness

```
godot --headless --path . --fixed-fps 60 -- --botsim=<seed>      # v2 vs v1 (side flips with seed parity)
godot --headless --path . --fixed-fps 60 -- --botsim=<100+seed>  # control: v1 vs v1
```

One line per match, ~20 s of wall time for 150 s of game:

```
BOTSIM result seed=0 v2=0 winner=-1 time=150.0 hp0=331 hp1=363 tow0=3 tow1=2 plays0=18 plays1=16 gold0=51 gold1=47
```

Decks are shuffled from the seed, the two hero abilities are handed out evenly across seeds, the v2
side flips with parity so lane bias cancels, and a match ends exactly like a real one: a commander
tower falls, or the 150 s clock runs out and the tower HP is summed. Same seed = same match, byte for
byte.

**Last measured at 0.3.9** — the card set, abilities and match rules have all changed since, so
re-run the baseline before trusting these numbers. 8 seeds, 4 per side: v2 went **5 wins, 3 losses** and
averaged **+129 tower HP**. A v1-vs-v1 control over 6 seeds shows the weaker side of the board is
worth ±138 HP on its own, so the side-corrected gain is ≈ +130 HP — smaller than the **+363 HP / 3-0**
it scored before the clock rules landed, because overtime's double gold makes the last minute a
scramble where card-count and tempo matter less.

An "always spend on a quiet board" tempo bonus was also tried: it made v2 push into nothing and fall
to 2W-2L / **−26 HP** average, so it was reverted. The remaining known gaps are the same as v1's,
in priority order: the hero ability still fires whenever gold ≥ 5 instead of when it will connect,
no tracking of the opponent's gold, spells valued only for damage, no retreating, and lane control
is still a flat bonus rather than a plan.

## Sound

`scripts/sfx.gd` (`DDSfx`) owns the card audio. The files live in `SFX/` and are
Pixabay recordings, credited in their own filenames.

* **Dealing the opening hand** — `freesound_community opening hand.mp3` is one take
  containing **eight** card draws. The three card deal plays a **random window of three
  draws** out of those eight (`slice = length / 8`, start picked per deal), so the
  opening never sounds the same twice.
* **Placing a card** — `oxidvideos-place cardmp3.mp3`, fired from `deploy()` for
  every successful placement (troops, buildings and spells alike).

Both run through six pooled `AudioStreamPlayer` voices at −6 dB, so quick plays
overlap instead of cutting each other off.

* **Match music**: once the three-card deal has played, one song from
  `musictoreplace/` (picked at random each fight) loops at −12 dB for the rest of
  the match (every audio file in `DDSfx.MUSIC_DIR`, read when the song is picked, so adding or removing a file
  needs no code change; `music_files()`, `start_music()`). These are placeholders, and
  there is no music when running headless.
* **Volume**: a slider in the top-left corner of the match sets the Master bus
  (music and sounds together, squared so mid-slider sounds like half). It is saved
  to `user://settings.cfg` and carries over between fights and plays
  (`DDSfx.get_volume()` / `set_volume()`).

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

Bot A/B harness — one headless match per run, deterministic for a seed:

```
godot --headless --path . --fixed-fps 60 -- --botsim=<seed>      # v2 vs v1, sides alternate
godot --headless --path . --fixed-fps 60 -- --botsim=<100+seed>  # control: v1 vs v1
```

Animation captures: `--scenario=pennygif` renders Penny and a passive knight into a
transparent SubViewport and dumps 72 raw RGBA frames; `node docs/make_gif.mjs
<frames> docs/penny.gif` turns them into the transparent GIF in `docs/` (hand-rolled
encoder — this machine has no ffmpeg, ImageMagick or Pillow).

**What counts as verification here**, cheapest first: an eval assertion for
behaviour (rects, ranges, cooldowns, states); the seeded sim line for a refactor
(run before and after and compare bytes); a *single full-resolution* screenshot for
rendering-only questions. Art and game feel cannot be verified from inside the
engine — those go to the human.

> Adding a card: [`NOTES.md` §2](NOTES.md) has the checklist (data, art in two
> dispatch tables, attack name, optional behaviour hook, README row).
