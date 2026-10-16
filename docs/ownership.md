# Ownership Guidance

No team members are listed in this repository yet, so there is no
`CODEOWNERS` file (an incorrect one would block or mis-route reviews). When the
team and remote exist, create `.github/CODEOWNERS` along these areas:

| Path | Area | Suggested owner role |
|---|---|---|
| `game/scripts/world/match_controller.gd`, `game/scripts/core/` | Rules & authority | Gameplay lead |
| `game/scripts/ai/` | Enemy behavior | AI / gameplay |
| `game/scripts/maps/`, `game/scripts/world/` | Levels | Level design |
| `game/scripts/ui/`, `game/localization/` | UI & text | UI lead |
| `game/scripts/audio/`, `game/assets/audio/` | Audio | Audio |
| `game/scripts/network/`, `server/`, `services/` | Multiplayer & backend | Network/backend lead |
| `.github/`, `tools/`, `game/export_presets.cfg` | Build & release | Release engineer |
| `docs/security.md`, validation code | Security review | Security reviewer (required on PRs touching validation) |

Example (replace with real handles):

```
/game/scripts/world/match_controller.gd   @org/gameplay-leads @org/security-reviewers
/game/scripts/network/                     @org/network
/.github/                                  @org/release
```

Recommended branch protection for `main` once hosted: require PRs, require CI
(`lint`, `godot`, `secrets`), require one review (two for `security`-labeled
PRs), forbid force-pushes, and restrict the `release` environment to release
engineers.
