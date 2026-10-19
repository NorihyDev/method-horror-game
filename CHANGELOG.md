# Changelog

All notable changes are recorded here. Versions follow semantic versioning;
dates are ISO 8601.

## [Unreleased]

## [0.4.0] - 2026-10-19

### Added
- **Real first-person arms.** The player's own character (the one chosen in
  Profile) is cut down to its arms and hands and posed live by IK: the right
  hand grips the flashlight and follows its sway and bob, both arms pump when
  sprinting, and the left hand reaches out to use things, picks items up,
  swaps the battery and holds what is being inspected. The old box hand
  remains as the fallback.
- **Teammates look where they look.** In co-op a teammate's head and chest
  tilt up and down with their view, on top of whatever they are doing
  (walking, crouching), and their flashlight beam follows. The pitch rides in
  spare bits of the existing motion packet, so older builds still connect.

### Fixed
- Furniture facing the wrong way: the dining chairs in the house, the staff
  room and library chairs in the school turned their backs to their tables,
  and three tool chests (Black Ward, Last Train) faced the wall. A new test
  builds every map and checks that seats face their table, cabinets, sofas,
  shelves, the stove and clocks turn their fronts to the room, beds have
  their headboard to the wall and pictures hang the right way round.
- The first-person hands were turned the wrong way: the palms faced the
  player (the flashlight lay in an open palm). They now show the backs of the
  hands: a fist round the flashlight, a reach back-of-hand up.
- On the host, teammates never animated: their position was snapped on every
  packet, so they slid around in the idle pose, and crouching and their
  flashlight state were ignored. The host now moves them smoothly like
  clients do, so they walk, jog, run and crouch.
- The miner (Last Train) stood with his arms stuck out in a T-pose: his arms
  were fitted at the wrong height. The plague doctor's raised arm tore his
  coat; he now attacks by rearing back and lunging. Walks swing the arms more.

## [0.3.1] - 2026-10-19

### Fixed
- Release and build exports failed: the dedicated server preset had no
  texture format selected (Godot 4.7 refuses to export without one), and the
  release workflow did not create the folders it exports into. 0.3.0 was
  tagged but never built.

## [0.3.0] - 2026-10-19

### Added
- **A horror interface.** Every menu now sits under a heavy vignette, film
  grain, faint scanlines and a slow red glow, and the light fails for a
  moment now and then. The title is printed in worn ink with a blood-red
  echo that glitches, and titles have a dripping blood rule. New bundled
  fonts: IM Fell English SC for titles, Special Elite (typewriter) for
  buttons, tabs and captions, Crimson Pro for reading. Buttons are black
  slabs with a blood-red edge, toggles are red switches. Reduced motion and
  reduced flashing keep it still.
- **Real furniture.** Cars, beds, sofas, chairs, tables, desks, cabinets,
  shelves, crates, the stove, a grandfather clock, a wall clock and picture
  frames are photo-scanned CC0 models from Poly Haven, fitted to the space
  the old box furniture took, with the same collisions. Floors, walls,
  wood, metal, fabric and concrete use CC0 photo textures from ambientCG,
  with dust, streaks and wear in the surface shader.
- **Imported monster models** for each map's enemy when the monster packs
  are installed locally (they are not in the repository; the procedural
  rigs remain the fallback).
- **Choose your character.** Profile → Character picks who teammates see
  you as in co-op. Tsila joins Punky: short curly hair and a black METHOD
  jersey with neon-green trim, with the same six animations. The choice
  travels with you when you join, and unknown values fall back to Punky.
  Mianja is the third: a black snapback cap and the pro METHOD jersey.
  Paulino, Nox and Ninja (with glasses) wear a teal baseball METHOD
  jersey. Skin now matches between face and body on every character.
  Every character's head is now the real person's, rebuilt from his photo
  with KeenTools FaceBuilder, with clean skin, hair grown from the real
  skull and, for Mianja, a snapback fitted to his head. Norihy is the new
  first and default character. Dekai (braids) and Kanzaki join them. Necks join the jersey cleanly, the hair is
  made of coiled strands, and teammates walk, jog and run with heel strike,
  hip turn and opposite arm swing, with the head kept level.
- **More horror.**
  - A scare director plays local-only frights in quiet moments: whispers,
    knocking, running steps, lamps bursting, the flashlight dying, a distant
    scream, a slammed door, and a figure down the corridor that vanishes in
    the beam.
  - Being caught turns you to face the enemy with a scream and a torn, red
    screen.
  - The screen throbs with your heartbeat while the enemy is near.
  - Nine new synthesized sounds, with captions.
- **Better graphics.** Flashlight beams glow through the dust (new "Light
  shafts" setting), and every room is dressed with seeded blood, scratches,
  tally marks and stains.
- **More to explore.**
  - The House has a west wing (pantry, bathroom, nursery) that loops back
    to the hallway.
  - The Black Ward has a morgue and a cold store.
  - Estimates rise to 25 and 26 minutes.
- **Tougher over time.** The enemy's rage builds with every minute it has
  been in the building: up to +10 % on Normal, +20 % on Hard and +30 % on
  Nightmare.
- **Easier on touch screens.**
  - Buttons sit in a thumb arc measured from the corner.
  - Pushing the stick past its ring runs.
  - Taps go to the nearest button.
  - Use has aim assist.
- **Punky**, a realistic, rigged teammate model with idle, walk, run, crouch,
  crouch-walk and downed-crawl animations. Co-op teammates now appear as him
  instead of capsules.
  - Built from scripts with Blender + MPFB (CC0 MakeHuman assets), with a face
    projected from a consenting person's photo. The photo is not in the repo.
  - About 23.7k triangles. See docs/characters.md.
- **Online co-op over the internet** through a relay on Cloudflare (Worker +
  one Durable Object per room, free plan, secure WebSockets), deployed.
  - The room creator's device hosts the match, and others join with a
    6-digit code from any network: 2–4 players, optional password.
  - The relay validates membership, roles, sizes and rates. Guests rejoin
    their slot after a drop, and the room ends explicitly if its creator
    leaves.
  - Online matches award no coins.
  - Verified with 20 protocol checks and two Godot clients through the
    deployed relay.
- Godot 4.7.2-stable project (Mobile renderer), METHOD theme, four focused
  autoload services, atomic checksummed saves with backups and migrations.
- Procedural audio (74 sounds/loops) and texture (11 surfaces) generators with
  committed outputs and import conventions.
- *The Abandoned House*: nine ground-floor rooms, stairwell, basement and
  garage exit; seeded item placement proven solvable; fuse-circuit, painted-code
  keypad, repair and crank-timing puzzles; optional files and tape.
- *Orientation* tutorial with no hostile enemy.
- The Watcher: articulated procedural rig with ten animations; sight/hearing/
  light/crouch perception, investigate/search/chase/attack/check-hiding states,
  door use, stuck recovery, flicker and key cues.
- First-person controller with stamina, crouch, flashlight battery, hiding,
  inventory and damage; multitouch controls with layout editor; controller and
  rebindable keyboard input.
- Full menu flow (splash, notice, name entry, main menu with 3D diorama, solo
  setup, multiplayer status, loading/briefing, HUD, pause with hints, inventory,
  notes, keypad, death, results, settings, shop, chapters, profile, credits).
- Local coin economy with idempotent rewards and a cosmetic shop.
- English and French localization.
- 62 automated tests, startup smoke mode, lint/format tooling, CI/build/release
  workflows, export presets for Windows, Linux, Linux dedicated server and
  Android.
- Online co-op: lobby service (guest identity, private rooms with six-digit
  codes and optional passwords, rate limits, room-bound tickets, server
  allocation, verified wallet), dedicated server mode, authoritative
  `NetBridge` with a server-controlled start barrier, snapshots and reconnect.
- Multiplayer menus: create/join room, lobby (ready, owner controls, kick,
  start feedback, ping), LAN development mode labeled as lower trust with no
  coins.
- In-match co-op: teammate status list, pings, downed/revive/bleed-out,
  spectating after death or escape, round-trip time, online results with the
  verified wallet balance.
- Online end-to-end test with separate processes and an impaired-link relay;
  networking and deployment documentation.

- *The Black Ward*: a clinical wing with card doors, an emergency power board
  (relay + breaker pattern from a schematic), observation monitors, a
  night-round code and a bay shutter; The Sister, a blind enemy who hunts by
  sound and hums until she does.
- *Last Train*: a sealed station with a collapsed exit, power cells, a signal
  lever frame and route card, a help point and an evacuation train to hold
  out for; ghost trains as moving sound sources that mask noise; The
  Lineman, who sees only along his headlamp beam.
- Enemy profiles: one tested state machine, per-map senses, speeds, sounds
  and body styles. 26 new procedural sounds, 4 new surfaces, 5 items.
- Map unlocks in order: offline per device, online verified by the lobby
  service, which also limits in-lobby map changes to the owner's unlocks.
- The shop can use the verified online wallet with idempotent purchases.
- *The Silent School*: classrooms, a staff-room PA and music-room chimes; a
  music box to find by ear (the wing key lies beside it), a seeded bell tune
  played over the PA and back on the chimes to open a tuned lock, bolt
  cutters for the chained doors. The Headmistress cannot move while someone
  looks at her in light.
- *METHOD Facility*, the finale: card door, maglock release, power cells,
  cell monitors + trial protocol keypad and a freight-lift hold-out. Subject
  Zero hunts by sound in the dark and gains sight when the generator runs.
  The story's letters are explained.
- Enemy profile rules (frozen while watched, runtime profile swap), two rig
  styles, 19 new procedural sounds with captions, new surfaces, school and
  laboratory props, wing key and bolt cutters, repeatable consoles, a lift
  style for the hold-out car.
- Frame-time benchmark for device profiling (development builds): per-map
  frame times, GPU/CPU/script/physics cost, draw calls and memory, saved as
  JSON and printed to the log.
- Automated accessibility audit: text contrast, touch-target size, screen-reader
  names and focus on every menu screen, and caption coverage of every cue.

### Fixed
- The enemy got stuck at doors on four of the five maps. Door panels no
  longer trap it, it opens any shut door it is about to pass, navigation now
  avoids hiding cabinets and locked doors, quick successive door unlocks no
  longer leave its paths out of date, its clearance matches its body, and
  furniture that sealed a doorway (Black Ward reception) and half of the
  study (House) was moved. A new test walks it to every patrol point on
  every map with the doors shut.
- The interface theme never reached any screen (a window theme does not pass
  into canvas layers): its colours, styles and fonts now apply everywhere.
- A dropped item could fall inside a counter, out of sight and reach.
- The school office clock went through the ceiling, and a hall picture in
  the house hung in the middle of a doorway.
- A crate stood in the house's garage doorway, so a player could not enter the
  garage, and through it the utility room, the stairwell and the basement.
  The waiting chairs in The Black Ward's observation corridor blocked
  observation room B's door. Both moved; a new test walks every map with the
  player's own collision shape.
- The lobby's Ready / Start buttons could be cut off at the bottom of the
  screen, and the Multiplayer, Solo and Shop screens had buttons off screen
  at larger interface scales. Their main buttons are now pinned on screen,
  and columns scroll or wrap on narrow screens. Create room and Join with
  code are tabs.
- Faint informational text (notes, locked-map reasons, hints) and red status
  text now meet WCAG AA contrast; disabled controls keep the dim tone.
- Settings sliders, toggles and map cards had no screen-reader name; sliders
  were below the touch-target minimum.
- Long sounds played from emitters (the Sister's humming, ghost and arriving
  trains, the garage motor, enemy breathing) never produced captions; the
  Lineman's breathing had none. The ward monitors' fast beeping is now
  captioned too.
- Locked-map reasons no longer run past the map card.
- METHOD files found in The Black Ward and Last Train were counted but could
  not be read on the progress screen and had no text; every map's files are
  now listed and written in EN and FR.
- Multiplayer: a client could send Ready before its connection existed;
  server-side leaves, kicks and flood disconnects did not mark players away.
- The house's basement cage gate and door materials were never applied.
- The enemy could pick a furniture top as a navigation target.
- CI: shell scripts are executable; gitleaks no longer flags the fake test
  ticket secret.
- A NUL sentinel string produced Unicode warnings at every startup.
- Navigation bake no longer warns about agent radius/climb rounding.

### Security
- Server-side validation of every interaction (range, line of sight, rate,
  payload types/sizes), puzzle answers withheld from client snapshots, and
  lag-bounded crank timing.

[Unreleased]: https://github.com/NorihyDev/method-horror-game/compare/v0.4.0...main
[0.4.0]: https://github.com/NorihyDev/method-horror-game/releases/tag/v0.4.0
[0.3.1]: https://github.com/NorihyDev/method-horror-game/releases/tag/v0.3.1
[0.3.0]: https://github.com/NorihyDev/method-horror-game/releases/tag/v0.3.0
