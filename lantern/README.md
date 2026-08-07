# Lantern

The browser. Runs as a CraftNet Host, using only CraftNet's public `lib/cnet.lua` developer API — see `craftnet-illuminations/README.md` for the standing rule that this project never touches craftnet's own source.

"Just a frame and interpreter": a fixed-width viewport (whatever `term.getSize()` reports for this computer), no reflow, no horizontal panning — a line longer than the width is cropped, not scrolled. Pages scroll vertically instead, since LCM content is line-based already (see [lcm/SPEC.md](../lcm/SPEC.md)) and can be any length top to bottom.

Runs on Advanced Computers (which have mouse events) — navigation is entirely click-driven: click a link to follow it, click the address bar to type a new one, click `<`/`>` to go back/forward, click the `X` to quit. There's no keyboard-only path for any of that.

## Layout

Row 1 and row 2 sit above the frame, on the bare screen background (light gray, not the frame's own color) — the title/close button and the address bar. The frame itself runs flush with the screen's left and right edges, with `<`/`>` history buttons built into its own top border. A single status line sits below the frame, at the very bottom of the screen.

- `lantern.lua` — entry point. Same `package.path` widening trick as Lamp, to reach an installed CraftNet Host's `lib/cnet.lua` at `/craftnet` and its own `lib/`. Reads the Host's existing connection via `cnet.status()`, wires the event loop (`mouse_click`, `mouse_scroll`, plus `up`/`down` keys as a redundant scroll path).
- `lib/address.lua` — parses/formats `host[:port][/path]` address strings, and resolves relative link targets (`address.resolve`) against whatever page they appeared on. Pure logic, unit tested.
- `lib/parser.lua` — turns LCM source text into `{ title, lines }`, where each line is `text`/`link`/`box`/`hr`. Pure logic, unit tested.
- `lib/view.lua` — browsing state: current page, vertical scroll offset, and bounded (`HISTORY_LIMIT` = 5) back/forward history stacks. Pure logic, unit tested.
- `lib/ui.lua` — draws the chrome via `term`/`colors`, and owns every click-region's exact coordinates (`ui.isCloseButton`/`isAddressBar`/`isBackButton`/`isForwardButton`/`contentRowAt`) so what's drawn and what's clickable can never drift apart. CC:Tweaked-dependent, not unit tested — see below.

## Running

Connect the computer to a gateway first, same as any CraftNet Host (`cnet connect <gatewayId> <subdomain>` — once, it's remembered after that). Then:

```
lantern [startAddress]
```

`startAddress` is optional — an initial page to load on launch (e.g. `illuminations.cnet.craft`). Lantern doesn't take a gatewayId/subdomain of its own, same reasoning as Lamp (see its README) — it reads the connection the Host already has instead of asking you to repeat it.

Everything is a click: a link line, the address bar, the `<`/`>` buttons on the frame's own top border (dim when there's nothing to go back/forward to), the `X` in the top-right corner of the screen (safe to click any time — just ends the program cleanly, `cnetd` keeps running exactly as it was). Scroll wheel and the `up`/`down` keys both scroll the content, redundantly.

## Status

Confirmed working in a real game session (2026-08-06): installed via `bootstrap.lua`, rendered the chrome correctly (frame, header, address bar), and successfully fetched and rendered Lamp's real sample site. Two things that surfaced in that same test and have since been fixed: it used to require re-typing `<gatewayId> <subdomain>` even though the Host was already connected, and following a link failed with a stale hardcoded address because the sample site didn't use a relative link (see Lamp's README and [lcm/SPEC.md](../lcm/SPEC.md)). Also added a one-space margin around the content area — text was rendering flush against the frame's top and right edges.

`lib/address.lua`, `lib/parser.lua`, and `lib/view.lua` are unit-tested against a CC:Tweaked stub harness (checks covering address parsing/formatting/relative-resolution, every LCM directive including `@p`/`@c`, vertical scroll clamping, bounded back/forward history) and confirmed against Lamp's real sample site end to end.

`lib/ui.lua` and the `lantern.lua` event loop are direct `term`/`keys`/`read()` calls, not unit tested — but now confirmed to actually render and navigate correctly on a real computer, not just reasoned about.

One thing that *was* flagged as unverified and turned out to be a real problem: the address bar used to prefill with the current address via `read(nil, nil, nil, default)`. CC:Tweaked's `read()` puts the cursor at the *end* of a default value rather than selecting it, so typing a new address without first clearing the old one merges the two — e.g. typing `cnet.craft` over a prefilled `illuminations.cnet.craft` silently became `illuminations.cnet.craftcnet.craft`, not the root address you meant. Removed the prefill; the field now always starts blank.

A second real-game timeout, separate from the above: a request routed to a Lamp instance via a `root` route (rather than that host's own subdomain) timed out even after the address-bar fix. `cnet.reply()` doesn't check which destination address a request arrived on at all — confirmed by reading it, it only uses the return token and source address — so a Lamp-side rejection isn't structurally possible there. The far more likely cause: `cnet.request()`'s own default timeout is only 5 seconds, the same number that caused the original cross-gateway timing issue in craftnet itself (see its README/CLAUDE notes on `cnet.await`). A request through `root` routing still crosses the relay same as any cross-gateway request. Lantern now passes an explicit 20-second timeout on every request instead of relying on the 5-second default — not yet confirmed against a real repeat of this failure, since the relay's own logs don't record enough detail (only connection-level noise, no per-message application logging) to prove the timeout theory directly.

**Update, same day**: that timeout theory turned out to be wrong. Alec ran a controlled comparison — the exact same request succeeded via the Lamp instance's own subdomain and failed only via `root` — an addressing signature, not a latency one, and he said so directly. The real bug was in craftnet's `local_gateway.lua`: a reply always claimed to be from the host's own subdomain regardless of which address the request actually arrived on, so a root-routed reply got silently rejected by the requester's own `RETURN_SOURCE_MISMATCH` check. Fixed in craftnet itself (an explicitly authorized one-time exception to the "never touch craftnet" rule — see craftnet's own CLAUDE notes for the fix). Not a Lantern bug at all, but it's why the earlier timeout theory here is left in place above rather than deleted — it was a real (if wrong) hypothesis at the time, worth keeping for anyone hitting a similar-looking symptom later.

**Full mouse-driven redesign, same day**: Alec asked for a substantial rework after using it hands-on — gray frame flush to the screen edges (was white, inset by one column), a light gray/off-white background outside the frame instead of blue ("looks less commodore"), `<`/`>` back/forward buttons built into the frame's own top border with a proper bounded (5-entry) two-directional history model, a red `X` close button in the screen's top-right corner for a safe shutdown, click-to-follow-a-link and click-to-edit-the-address-bar instead of tab-cycle-then-enter, scroll wheel support alongside the (now unadvertised, since there's no hint row anymore) arrow keys. `view.lua`'s `selectedLinkIndex`/tab-cycling was removed entirely and replaced with `recordVisit`/`goBack`/`goForward` (classic browser history: navigating somewhere new clears forward history). `ui.lua` now also owns the click-region hit-testing (`isCloseButton`/`isAddressBar`/`isBackButton`/`isForwardButton`/`contentRowAt`) so the drawn chrome and the clickable regions can't drift apart. LCM gained `@p` (word-wrap to 48 characters, never breaking a word) and `@c` (center within 48 columns) for real paragraph content — Lamp's sample site grew from 2 pages to 4, cross-linked, plus a Lorem Ipsum article long enough to actually demonstrate scrolling. Not yet run in-game — this is a same-day rewrite of most of the UI layer, worth a real test before trusting the click coordinates and colors look right on an actual Advanced Computer.
