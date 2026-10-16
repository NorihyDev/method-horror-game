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

- Desktop: run with `--print-fps` or the Godot profiler/monitors; F3 shows the
  dev inspector with FPS in debug builds.
- Android: `adb shell dumpsys gfxinfo com.method.horror`, Android GPU Inspector,
  Godot's remote debugger (one-click deploy) for script/physics times.
- Record frame-time percentiles (p50/p95/p99), memory, load time, APK size,
  draw calls and temperature in a table here per device and build.
