# Third-Party Notices

## Godot Engine 4.7.2-stable

METHOD HORROR is built with the Godot Engine, which is distributed under the
MIT license.

    Copyright (c) 2014-present Godot Engine contributors.
    Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.

Godot also bundles third-party components (FreeType, HarfBuzz, ENet, mbedTLS,
Jolt Physics, and others). Their full notices are available at runtime through
`Engine.get_copyright_info()` / `Engine.get_license_info()` and are shown on the
in-game Credits screen. The engine's default UI font is part of the engine
distribution.

## Fonts

Three fonts are bundled in `game/assets/fonts/`, each with its license text
beside it (exported builds include those files). System fonts are used only as
fallbacks for missing glyphs.

- **IM Fell English SC** (titles) — Copyright (c) 2007 Igino Marini
  (www.iginomarini.com), with Reserved Font Name "IM FELL English SC".
  SIL Open Font License 1.1 (`IMFellEnglishSC-OFL.txt`).
- **Crimson Pro** (body text) — Copyright 2018 The Crimson Pro Project Authors
  (https://github.com/Fonthausen/CrimsonPro). SIL Open Font License 1.1
  (`CrimsonPro-OFL.txt`).
- **Special Elite** (buttons, captions) — Copyright (c) 2010 Brian J.
  Bonislawsky DBA Astigmatic (AOETI). Apache License 2.0
  (`SpecialElite-LICENSE.txt`).

The font files are unmodified. They were taken from the Google Fonts
repository (github.com/google/fonts); IM Fell English SC's file is renamed
from `IMFeENsc28P.ttf`.

## Textures and models

- Surface photo textures: ambientCG (ambientcg.com), CC0 1.0.
- Furniture and decor models: Poly Haven (polyhaven.com), CC0 1.0, reduced
  and re-encoded by `tools/props/`.

No attribution is required for CC0 assets; they are listed in
`docs/asset-manifest.md` for provenance.

## Audio and textures

All audio and textures in `game/assets/` are original procedural output from
the generator scripts in `game/tools/`. See `docs/asset-manifest.md`.
