# Contributing to METHOD HORROR

## Before you start

1. Install **Godot 4.7.2-stable** exactly (`tools/godot-version.txt`) and Python 3
   for lint tooling: `python -m pip install -r tools/requirements-dev.txt`.
2. `./tools/check.sh` must print `0 failed`.
3. Read [docs/architecture.md](docs/architecture.md). The one rule that matters
   most: **world state changes only through `MatchController` on the
   authority**; entities present state in `apply_state()`.

## Branches and commits

- `main` holds stable work. Use short-lived branches named by area, e.g.
  `gameplay/first-person-controller`, `network/private-rooms`, `ui/main-menu`,
  `build/android-pipeline`.
- **Commit messages are plain imperative sentences.** No Conventional Commit
  prefixes (`feat:`, `fix:`, `chore:` …). Good: `Add the first-person mobile
  controller`, `Improve enemy search behavior`, `Update the readme file`.
- PR titles follow the same style. Keep PRs focused; fill in the template.

## Before opening a PR

```bash
./tools/lint.sh                                       # gdformat --check + gdlint
./tools/check.sh                                      # compile every script
./tools/godot.sh --headless --path game -- --test     # all tests
./tools/godot.sh --headless --path game -- --smoke    # startup smoke
```

- Add or update tests for rules and anything security-relevant (validation,
  rewards, saves). Tests must prove behavior, not restate implementation.
- New player-visible text goes into **both** `localization/en.json` and
  `fr.json` (a test enforces parity and that every key used in code exists).
- New settings must change real behavior; add a label and `_TIP` translation.
- New assets: record source, author, license and placeholder status in
  [docs/asset-manifest.md](docs/asset-manifest.md). No unlicensed content.
- Never commit keystores, tokens, `.env` files or credentials.
- Update docs when behavior changes; distinguish implemented / tested /
  planned honestly.

## Style

- Typed GDScript; `:=` only when the right side has a static type (Godot 4.7
  errors on Variant inference).
- `snake_case` files and functions, `PascalCase` classes, `UPPER_CASE` consts.
- Keep autoloads to the existing four unless a new one has a single clear job.
- Formatting is enforced by `gdformat` (120 columns).

## Ownership

See [docs/ownership.md](docs/ownership.md) for how to set up `CODEOWNERS` once
team members and the remote are known.
