# Performance Budgets

**All numbers below are targets until measured on hardware.** No phone has
been profiled yet.

## Target devices (to confirm with the team)

| Tier | Example device class | Target |
|---|---|---|
| Baseline | 2021 mid-range Android (Snapdragon 7-series / Mali-G68 class, 4 GB RAM, Vulkan 1.1) | Stable 30 FPS at Medium |
| Capable | 2023+ upper-mid/flagship (Snapdragon 8 Gen 2 class) | 60 FPS at High |

Exact named devices should be chosen from the team's test phones; record them
in this file once picked.

## Frame budgets (baseline, 30 FPS = 33.3 ms)

| Item | Budget |
|---|---|
| Draw calls (opaque + shadow) | ≤ 250 |
| Visible triangles | ≤ 300 k |
| Dynamic lights affecting a mesh | ≤ 8 omni + 8 spot (Mobile renderer limit) |
| Shadowed lights | flashlight + ≤ 1 lamp (High only) |
| Particles | ≤ 130 (dust, two emitters); off on Low |
| Physics | 60 Hz; enemy senses every 0.15 s; door/LOS rays throttled |
| Script time | ≤ 4 ms |
| Memory | ≤ 900 MB total process |
| Load to briefing | ≤ 6 s (measured on desktop: level build ≈ 1–2 s; smoke run incl. 300 frames 5.2 s) |
| APK size | ≤ 60 MB (current debug: 37.6 MB) |

## What is already done to stay inside budget

- Static geometry merged per room × material (house ≈ 60–80 batches).
- One shared surface shader; 3 texture samples per pixel; textures VRAM
  compressed (ETC2/ASTC on Android, BPTC/S3TC desktop) with mipmaps; half-res
  texture set for Low.
- Lights: room lamps unshadowed except where settings allow; moonlight shafts
  disabled on Low; fog hides distance; camera far plane 45–70 m.
- 3D render scale, FSR 1, optional dynamic resolution (bounded to 60 % of the
  chosen scale), frame caps 30/60/90/120 and battery saver.
- Audio: QOA-compressed WAVs, pooled UI players, positional one-shots auto-free.

## Not done yet (planned after first device profile)

- Baked lightmaps (needs editor bake; would let us drop most dynamic lamps).
- Occlusion culling (`OccluderInstance3D`) per room.
- LOD for props (most props are a few boxes; may be unnecessary).
- Thermal soak test (20 min continuous play) and battery drain measurement.

## How to measure

### Built-in benchmark (development builds)

*Settings → Graphics → Run benchmark* (debug builds, from the main menu), or
`godot --path game -- --bench` on desktop. For each playable map it builds the
level at the current graphics settings, walks the patrol route with the enemy
present for 20 s (power off for the first half, on for the second) and
records:

- frame time as the player gets it (p50/p95/p99, % of frames under 30 FPS):
  this includes the frame cap and vsync;
- the engine's per-frame cost, which shows headroom regardless of the cap:
  GPU time and CPU render time (`viewport_get_measured_render_time_*`),
  script time and physics time;
- draw calls, primitives, video memory and static memory.

The full report (device, GPU, OS, renderer, settings snapshot, per-map
numbers) is saved to `user://bench/bench_<time>.json`. On Android that is
`/data/data/com.method.horror/files/bench/` (pull with
`adb shell run-as com.method.horror cat files/bench/<file>`), and the summary
is also printed to logcat with the `BENCH` prefix.

### Other tools

- Desktop: run with `--print-fps` or the Godot profiler/monitors; F3 shows the
  dev inspector with FPS in debug builds.
- Android: `adb shell dumpsys gfxinfo com.method.horror`, Android GPU Inspector,
  Godot's remote debugger (one-click deploy) for script/physics times.
- Record frame-time percentiles (p50/p95/p99), memory, load time, APK size,
  draw calls and temperature in a table here per device and build.

## Measurements

### Desktop reference (not a phone)

2026-10-17, laptop with an RTX 3050 Laptop GPU, Windows 11, Godot 4.7.2,
Mobile renderer, 1280×720, *High* preset, 60 FPS cap. Useful only to compare
maps and spot regressions; it says nothing about phone performance.

| Map | Frame p95 | GPU avg (p95) | CPU render | Scripts | Physics | Draw calls | Primitives | VRAM |
|---|---|---|---|---|---|---|---|---|
| The Abandoned House | 16.7 ms (cap) | 2.56 ms (4.31) | 0.68 ms | 2.17 ms | 0.66 ms | 183 | 60 k | 114 MB |
| The Black Ward | 16.7 ms (cap) | 2.35 ms (4.48) | 0.72 ms | 2.34 ms | 0.54 ms | 200 | 70 k | 118 MB |
| Last Train | 16.7 ms (cap) | 2.30 ms (5.48) | 0.49 ms | 1.84 ms | 0.57 ms | 196 | 44 k | 120 MB |

All three maps stay within the draw-call (≤ 250), triangle (≤ 300 k) and
script-time (≤ 4 ms) budgets above on this run.

### Phones

None yet. Run the benchmark on each test phone at *Medium* and *Low* and add a
row per device and build.
