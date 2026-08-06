# Lantern

The browser. Runs as a CraftNet Host, using only CraftNet's public `lib/cnet.lua` developer API — see `craftnet-illuminations/README.md` for the standing rule that this project never touches craftnet's own source.

"Just a frame and interpreter": a fixed-width viewport (whatever `term.getSize()` reports for this computer), no reflow, no horizontal panning — a line longer than the width is cropped, not scrolled. Pages scroll vertically instead, since LCM content is line-based already (see [lcm/SPEC.md](../lcm/SPEC.md)) and can be any length top to bottom.

## Layout

- `lantern.lua` — entry point. Same `package.path` widening trick as Lamp, to reach an installed CraftNet Host's `lib/cnet.lua` at `/craftnet` and its own `lib/`. Reads the Host's existing connection via `cnet.status()`, wires the event loop.
- `lib/address.lua` — parses/formats `host[:port][/path]` address strings, and resolves relative link targets (`address.resolve`) against whatever page they appeared on. Pure logic, unit tested.
- `lib/parser.lua` — turns LCM source text into `{ title, lines }`, where each line is `text`/`link`/`box`/`hr`. Pure logic, unit tested.
- `lib/view.lua` — browsing state: current page, vertical scroll offset, which link is selected, a back-history stack. Pure logic, unit tested.
- `lib/ui.lua` — draws the chrome (header, address bar, frame, content, status/hint rows) via `term`/`colors`, in the visual style of the Gateway's own dashboard (`craftnet/src/lib/ui.lua`: magenta header, white-on-blue frame). CC:Tweaked-dependent, not unit tested — see below.

## Running

Connect the computer to a gateway first, same as any CraftNet Host (`cnet connect <gatewayId> <subdomain>` — once, it's remembered after that). Then:

```
lantern [startAddress]
```

`startAddress` is optional — an initial page to load on launch (e.g. `illuminations.cnet.craft`). Lantern doesn't take a gatewayId/subdomain of its own, same reasoning as Lamp (see its README) — it reads the connection the Host already has instead of asking you to repeat it.

Keys: `a` to type an address, `tab` to cycle between links on the page (auto-scrolling to keep the selected one visible), `enter` to follow the selected link, `up`/`down` to scroll vertically, `backspace` to go back, `Ctrl+T` to quit.

## Status

Confirmed working in a real game session (2026-08-06): installed via `bootstrap.lua`, rendered the chrome correctly (frame, header, address bar), and successfully fetched and rendered Lamp's real sample site. Two things that surfaced in that same test and have since been fixed: it used to require re-typing `<gatewayId> <subdomain>` even though the Host was already connected, and following a link failed with a stale hardcoded address because the sample site didn't use a relative link (see Lamp's README and [lcm/SPEC.md](../lcm/SPEC.md)). Also added a one-space margin around the content area — text was rendering flush against the frame's top and right edges.

`lib/address.lua`, `lib/parser.lua`, and `lib/view.lua` are unit-tested against a CC:Tweaked stub harness (checks covering address parsing/formatting/relative-resolution, every LCM directive, link cycling/wrapping with auto-scroll, vertical scroll clamping, back-history) and confirmed against Lamp's real sample site (`lamp/site/index.lcm`) end to end.

`lib/ui.lua` and the `lantern.lua` event loop are direct `term`/`keys`/`read()` calls, not unit tested — but now confirmed to actually render and navigate correctly on a real computer, not just reasoned about.

One thing that *was* flagged as unverified and turned out to be a real problem: the address bar used to prefill with the current address via `read(nil, nil, nil, default)`. CC:Tweaked's `read()` puts the cursor at the *end* of a default value rather than selecting it, so typing a new address without first clearing the old one merges the two — e.g. typing `cnet.craft` over a prefilled `illuminations.cnet.craft` silently became `illuminations.cnet.craftcnet.craft`, not the root address you meant. Removed the prefill; the field now always starts blank.
