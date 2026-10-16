## What and why

<!-- One or two sentences. Title style: plain imperative, no "feat:" prefixes. -->

## How it was verified

- [ ] `./tools/lint.sh`
- [ ] `./tools/check.sh`
- [ ] `godot --headless --path game -- --test` (paste the summary line)
- [ ] `godot --headless --path game -- --smoke`
- [ ] Manual checks (device / OS / what was tried):

## Checklist

- [ ] World state changes only go through `MatchController` on the authority.
- [ ] New player-facing text added to `en.json` **and** `fr.json`.
- [ ] New assets recorded in `docs/asset-manifest.md` with license.
- [ ] Docs updated; status of features described honestly (implemented / tested / planned).
- [ ] No secrets, keystores or credentials added.
- [ ] `CHANGELOG.md` updated under **[Unreleased]** if user-visible.
