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

No font files are bundled. UI text uses the engine default font, and the title
treatment requests a system serif font (`SystemFont`) that falls back to the
engine default if unavailable.

## Audio and textures

All audio and textures in `game/assets/` are original procedural output from
the generator scripts in `game/tools/`. See `docs/asset-manifest.md`.
