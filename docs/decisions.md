# Decision Log

Reversible decisions taken while building, with reasons. Newest last.

| # | Decision | Why | Revisit when |
|---|---|---|---|
| 1 | Godot **4.7.2-stable**, pinned everywhere | Only engine present locally; verified against official SHA-512; latest stable | A 4.7.x patch fixes a bug we hit |
| 2 | **Mobile renderer** on all platforms | Android baseline; desktop shows the same feature set we ship | Device profiling shows Vulkan problems on the baseline tier (fallback: Compatibility/GLES3, re-verify effects) |
| 3 | Levels, props, enemy rig and animations **built in code** | No assets available; diff-able; zero missing-file risk | Real art arrives (see asset-replacement.md) |
| 4 | **JSON string tables** loaded at runtime instead of CSV import | Avoids generated `.translation` artifacts; diff-friendly | Translators need a PO/CSV workflow |
| 5 | **In-project test runner** (no GUT plugin) | No third-party dependency/licensing; runs with autoloads; watchdog | Test volume needs richer tooling |
| 6 | Interaction validation includes **server-side line of sight** | A client could otherwise grab items through walls within range | — |
| 7 | Furniture on a separate **`prop` physics layer** | Shelf/table colliders hid items from interaction rays; props still block movement, navigation and enemy sight | — |
| 8 | Crank timing accepts a **client press time within 0.4 s** | Network latency would make timing puzzles unfair online | Measured RTT distribution suggests another bound |
| 9 | The Watcher **enters through the front door after a grace period** | Anticipation phase + a fair, explainable arrival far from players | Playtests say the opening is too quiet/loud |
| 10 | Locked doors are **navigation obstacles**; unlocking re-bakes on a thread | The enemy must not path through locks | Larger maps make re-bakes expensive (use per-room regions / links) |
| 11 | **Local wallet only** in M2; never merged with a future verified wallet | Offline saves are tamperable by nature | M3/M4 online economy |
| 12 | Backend plan: **Node.js 24 LTS + TypeScript (native type stripping), zero runtime deps** (`node:http`, `node:crypto` scrypt/HMAC, `node:sqlite`), TLS at a reverse proxy | Small attack surface, no supply chain, LTS runtime available locally | M3 implementation review |
| 13 | gdtoolkit 4.5.0 formatting at **120 columns**, lint limit 140, method-count limits raised | Fits the codebase's service classes and long translated calls | — |
| 14 | No remote configured → **local commits on `main` + `gameplay/solo-vertical-slice`**, no merge | Prompt forbids fabricating remotes or merging without authorization | The owner adds a remote |
