# Lantern

The browser. Runs as a CraftNet Host, using only CraftNet's public `lib/cnet.lua` developer API — see `craftnet-illuminations/README.md` for the standing rule that this project never touches craftnet's own source.

"Just a frame and interpreter": a fixed-width viewport (whatever `term.getSize()` reports for this computer), no reflow. LCM content is line-based already (see [lcm/SPEC.md](../lcm/SPEC.md)), so a page longer than the viewport is simply not all visible at once for now — no vertical scrolling in v0, only horizontal, per the original design intent. Worth revisiting once real pages start hitting that ceiling; the view module's data model doesn't make that hard to add later.

## Layout

- `lantern.lua` — entry point. Same `package.path` widening trick as Lamp, to reach an installed CraftNet Host's `lib/cnet.lua` at `/craftnet` and its own `lib/`. Parses arguments, connects, wires the event loop.
- `lib/address.lua` — parses/formats `host[:port][/path]` address strings. Pure logic, unit tested.
- `lib/parser.lua` — turns LCM source text into `{ title, lines }`, where each line is `text`/`link`/`box`/`hr`. Pure logic, unit tested.
- `lib/view.lua` — browsing state: current page, horizontal scroll offset, which link is selected, a back-history stack. Pure logic, unit tested.
- `lib/ui.lua` — draws the chrome (header, address bar, frame, content, status/hint rows) via `term`/`colors`, in the visual style of the Gateway's own dashboard (`craftnet/src/lib/ui.lua`: magenta header, white-on-blue frame). CC:Tweaked-dependent, not unit tested — see below.

## Running

```
lantern <gatewayId> <subdomain> [startAddress]
```

`startAddress` is optional — an initial page to load on launch (e.g. `mythra.craftnet.craft/index.lcm`).

Keys: `a` to type an address, `tab` to cycle between links on the page, `enter` to follow the selected link, `left`/`right` to scroll horizontally, `backspace` to go back, `Ctrl+T` to quit.

## Status

`lib/address.lua`, `lib/parser.lua`, and `lib/view.lua` are unit-tested against a CC:Tweaked stub harness (37 checks: address parsing/formatting, every LCM directive, link cycling/wrapping, scroll clamping, back-history) and confirmed against Lamp's real sample site (`lamp/site/index.lcm`) end to end.

`lib/ui.lua` and the `lantern.lua` event loop are not — they're direct `term`/`keys`/`read()` calls that need a real CC:Tweaked computer to verify. Same open question as Lamp's `package.path` trick, plus two Lantern-specific ones worth a first in-game pass:

- Whether `read(nil, nil, nil, default)` (prefilling the address bar with the current address) behaves as expected in this CC:Tweaked version — the 4-argument form is a newer addition to `read()`.
- Whether the frame/content layout math actually looks right at real terminal sizes — it's only been reasoned about, never rendered.
