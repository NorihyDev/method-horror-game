# Game Design

## Premise

METHOD was a private research organization that ran "perception trials" in
ordinary places — houses, wards, stations, schools — between the 1970s and
1998, then vanished. Its field sites were sealed with their subjects inside.
Someone still sends invitations stamped with the METHOD mark.

Players are investigators who answer those invitations. Each location has a
self-contained local story told through notes, tapes, painted marks and METHOD
files, and one supernatural threat whose behavior follows understandable rules.
METHOD is both the studio and part of the fiction's visual language
(crimson stencils, emergency lighting, clinical memos).

## Pillars

1. **Anticipation over shock.** Footsteps behind walls, keys jingling, lamps
   that flicker when it is near. Jump scares are earned (first sight at close
   range) and rate-limited (75 s cooldown, reducible in settings).
2. **Readable rules.** The threat sees and hears in ways players can learn.
   No vision through walls, no teleporting, no spawning on players.
3. **Noise has a cost.** Sprinting, doors, wrong keypad codes, a short circuit,
   a missed crank — all are noise events the enemy reacts to.
4. **Darkness with silhouettes.** Ambient light is low but never black; the
   flashlight never fully dies (a weak beam remains at 0 %).
5. **Every required puzzle is solvable alone.** Co-op helps (wider timing
   window) but is never required.

## Session shape (15–25 minutes)

| Phase | Trigger | What changes |
|---|---|---|
| Explore | Match start | The Watcher circles outside (positional steps/keys). Grace period by difficulty. |
| Arrival | Grace period ends | It enters the house far from and out of sight of all players. |
| Escalate | Power restored | Lights work (and expose you); +5% sight; basement opens. |
| Final | Motor started | The garage door rises over 30–50 s; the motor is a 60 m noise source every 2 s; +12% speed, +15% sight. |
| End | All players escaped/dead | Victory if anyone escaped. Solo death offers checkpoint retry / restart / give up. |

## Map 1 — The Abandoned House (Field Site 01)

The caretaker Edwin Marsh was "Subject 07" of Dr. I. Varga's perception trial.
Brass lenses were fitted where his eyes were; he learned to "see what people
hide" and stopped sleeping. The site was chained shut in 1998.

### Objective chain (data-driven, `scripts/maps/house/house_rules.gd`)

1. **Find a way out** — try the chained front door or the garage door/motor.
2. **Restore the power** — collect 3 fuses (some may be in the locked study:
   find the small brass key first). The utility-room panel has sockets I–IV;
   one (seeded) is scorched — a fuse there shorts out loudly and drops to the
   floor. The kitchen breaker chart names it.
3. **Open the basement storage cage** — power releases the basement maglock.
   Four red digits are painted beside symbols (kitchen, living-room fireplace,
   garage, basement); the keypad plate prints the symbol order. Seeded.
4. **Repair the garage door motor** — gear (in the cage) + drive belt (seeded
   location) → assemble at the garage workbench → install on the motor.
5. **Crank-start the motor** — press while the gauge needle crosses the marked
   window, three times. Misses are loud. A second player standing next to the
   motor widens the window ×1.6.
6. **Escape through the garage** — crouch under the door once there is room.

Optional: recover 3 of 6 METHOD files (seeded which 3), listen to Dr. Varga's
tape (subtitled), escape without being caught.

Checkpoints (solo, if the difficulty allows) save after each main objective.

### Solvability

`ReachabilitySolver` models zones (ground, study ← key, basement ← power,
cage ← code), item placements and actions (panel consumes 3 fuses → power,
etc.). Every seed's layout is solved before play; `MapRules.validate()` also
checks each candidate spawn individually so a mistake like "study key inside
the study" is caught by tests.

## The Watcher

### Senses

| Sense | Rule |
|---|---|
| Sight | 120° cone, base 13 m × difficulty. Flashlight on ×1.35, lit room ×1.25, dark ×0.55, crouching ×0.75. Within 1.6 m it notices you in any direction. Walls, doors and large furniture block sight. |
| Detection | Suspicion rises faster the closer you are (≈0.3 s at 3 m, ≈1 s at 6 m). Partial suspicion makes it investigate where it glimpsed you; full suspicion starts a chase. |
| Hearing | Every noise has a radius (walk 5.5 m, crouch 1.6 m, sprint 13 m, door 5–6.5 m, short circuit 24 m, crank miss 22 m, garage motor 60 m) × difficulty hearing × co-op scaling. Walls/floors between muffle to 60 %. |
| Memory | Rooms with noise in the last 60 s are favored when it patrols. It tracks you for 1.4 s after losing sight, then searches where it last saw you. |

### States

Patrol → Investigate (heard/glimpsed) → Search (looks around, wanders near the
last known position) → Chase → Attack (telegraphed wind-up, strike, recovery,
cooldown) → Lost → Search → Patrol. Plus Check-Hiding.

### Hiding

Lockers and wardrobes hide you from sight, not from consequences:

- If it was chasing you and could see you get in, it walks over, opens the
  locker and attacks.
- When it searches the exact spot where it lost you, it may check an occupied
  spot within 4.5 m (chance 20 % × difficulty persistence).
- Otherwise you are safe; audio is muffled and the view narrows to the slats.

### Warning cues

Lamps within 9 m flicker (slow dimming with *Reduce flashing*), its key ring
jingles while it patrols, heavy breathing and footsteps are positional, and
sound captions describe them with direction when enabled.

### Fairness guarantees

No teleporting (stuck recovery snaps at most 1.5 m back onto the navmesh), no
spawning within 12 m of or in sight of any living player, locked doors block
its navigation, and every attack has a visible wind-up.

## Map 2 — The Black Ward (Clinical Annex 02)

A closed clinical wing where METHOD ran sensory-isolation trials. One floor,
about 30 × 24 m: ambulance bay (exit), reception (start), triage,
maintenance, a curtained patient ward, the staff wing behind a card reader
(generator room, pharmacy, security office, staff room) and an observation
wing whose one-way glass looks into the patient cells.

### Objective chain (`scripts/maps/ward/ward_rules.gd`)

1. **Find a way out** — the ambulance-bay shutter has no power.
2. **Get into the staff wing** — a blue staff card (seeded among reception,
   triage, ward, maintenance, bay).
3. **Restore emergency power** — fit the starter relay in the generator
   room's panel, then switch on exactly the circuits the electrician's
   schematic (maintenance) lists as live and pull the start lever. A wrong
   set trips every breaker open with a 24 m bang. *Puzzle: emergency
   circuits (seeded 2–3 of 5).*
4. **Get into the security office** — the red security card opens the
   observation wing; with power on, four bed monitors show a bed number and a
   reading; the night-round sheet (staff room) gives the bed order; the
   security keypad takes the readings in that order. *Puzzle: observation
   rooms + code.*
5. **Open the ambulance bay** — the security console raises the shutter
   (30–50 s, loud: final phase).
6. **Escape** through the bay. Optional: 3 of 6 files, the interview tape,
   escape without being caught.

## Map 3 — Last Train (Transit Annex 03, Kessel Street)

A sealed underground station: a ticket hall at street level (collapsed street
exit, ticket office, kiosk, gates), a stair shaft down to a side platform
beside two tracks, and maintenance rooms behind a locked door (signal box,
store, corridor).

### Objective chain (`scripts/maps/station/station_rules.gd`)

1. **Find a way out** — the street stairs have collapsed.
2. **Get into the maintenance tunnels** — the maintenance key (seeded in the
   ticket hall or on the platform).
3. **Power the signal box** — two power cells into the battery rack.
4. **Set the evacuation route** — set the four levers Normal/Reverse as the
   route card (ticket office) says, then press the plunger. A wrong route
   rings a 26 m conflict bell. *Puzzle: signal routing (seeded 1–2 reversed).*
5. **Call the evacuation train** from the platform help point.
6. **Hold out until it arrives** (40/60/75/90 s by difficulty). Station
   announcements count down; the approaching train's rumble grows and draws
   the enemy to the platform.
7. **Board the train** through its open doors. The platform edge stays
   closed until then. Optional: 3 of 6 files, the signalman's tape, escape
   without being caught.

### Moving sound sources

Every 70–110 s a train that should not exist rolls through on the far track
(9 s pass, lit windows, positional rumble that moves with it). While it is
within 14 m, every other noise there is cut to 30 % — for players and the
enemy alike — and its rumble draws the enemy to the platform edge. Players
can time noisy actions (levers, doors, running) to a pass.

## Enemies

All three share one state machine (`scripts/ai/watcher.gd`) and differ by
`EnemyProfile` (`scripts/ai/enemy_profile.gd`): senses, speeds, sounds and
body. Each map names its profile in its `.tres`.

| | The Watcher (house) | The Sister (ward) | The Lineman (station) |
|---|---|---|---|
| Sight | 120° cone, 13 m; light ×1.35/×1.25, dark ×0.55 | **Blind**: only contact within 1.9 m | 56° headlamp beam, 17 m; **your light level is irrelevant** inside it |
| Hearing | ×1.0 | **×1.35, hunts by sound**: player noise within 55 % of what she hears starts a direct hunt; louder or farther noise is investigated | ×0.9 |
| Tracking after losing you | 1.4 s | 2.6 s (refreshed by every noise you make) | 1.8 s |
| Speeds (walk / investigate / run, m/s) | 1.35 / 2.1 / 4.05 | 1.2 / 2.4 / 4.3 | 1.45 / 2.2 / 4.0 |
| Warning cues | flickering lamps, key ring, breathing | flickering lamps, humming that **stops while she hunts**, monitors beep faster | flickering lamps, a visible headlamp beam, a guard's whistle |
| How to survive | stay dark, crouch, break line of sight, hide where it did not see you | freeze, crouch-walk near her, never run close; she checks a locker only if she heard it shut | stay out of the beam, use passing trains as cover |

## Progression

Offline: The Black Ward unlocks after escaping The Abandoned House on this
device, Last Train after The Black Ward. Online: the lobby service checks the
room owner's **verified** online completions (`completions` table) and tells
the game server which maps the owner may switch to; LAN hosts offer what
their device has unlocked.

## Difficulty

| | Story | Normal | Hard | Nightmare |
|---|---|---|---|---|
| Enemy speed | ×0.8 | ×1.0 | ×1.1 | ×1.2 |
| Hearing | ×0.6 | ×1.0 | ×1.25 | ×1.5 |
| Sight | ×0.7 | ×1.0 | ×1.2 | ×1.35 |
| Search persistence | ×0.6 | ×1.0 | ×1.35 | ×1.7 |
| Attack wind-up | 0.95 s | 0.7 s | 0.55 s | 0.45 s |
| Attack cooldown | 3.0 s | 2.2 s | 1.8 s | 1.4 s |
| Grace before arrival | 90 s | 50 s | 30 s | 15 s |
| Hits you survive | 3 | 2 | 2 | 1 |
| Battery drain | ×0.6 | ×1.0 | ×1.35 | ×1.7 |
| Spare batteries | 4 | 3 | 2 | 1 |
| Crank timing window | 26 % | 17 % | 12 % | 9 % |
| Hint tiers unlock every | 60 s | 120 s | 240 s | off |
| Checkpoints | yes | yes | yes | no |
| Exit opening (garage door, bay shutter) | 30 s | 40 s | 45 s | 50 s |
| Evacuation train arrival (Last Train) | 40 s | 60 s | 75 s | 90 s |
| Revive time (co-op) | 3 s | 4 s | 5 s | 6 s |
| Bleed-out (co-op) | 75 s | 45 s | 30 s | 20 s |
| Coin multiplier | ×0.75 | ×1 | ×1.5 | ×2 |

Personal hint setting (Off / Normal / Frequent ×0.5 delay) affects only that
player's hints and never the shared rules.

### Co-op scaling (per extra player)

Hearing +8 %; attack cooldown −5 % (min ×0.7); +1 spare battery per two extra
players. Puzzles are identical; the crank assist is the only co-op mechanic
that changes a puzzle and it is optional.

## Tutorial — Orientation Wing

Four rooms, no hostile enemy: move/look, flashlight in a dark room, keycard
door, notes, hiding, symbol-ordered keypad, exit. Completing it marks the
tutorial done and grants no coins.

## Planned maps

| Map | Distinct mechanic (planned) |
|---|---|
| 4 · The Silent School | Audio-based investigation in locked wings. |
| 5 · METHOD Facility | Ties the story together using all systems. |

These are shown as "Coming later" and are not selectable.
