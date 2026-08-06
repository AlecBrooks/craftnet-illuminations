# Lamp

The web server. Runs as a CraftNet Host, using only CraftNet's public `lib/cnet.lua` developer API — see `craftnet-illuminations/README.md` for the standing rule that this project never touches craftnet's own source.

## Layout

- `lamp.lua` — entry point. Widens `package.path` to reach an installed CraftNet Host's `lib/cnet.lua` (assumed at `/craftnet`) and its own `lib/`, parses arguments, hands off to `lib/server.lua`.
- `lib/server.lua` — the actual logic: resolve a requested path against a site directory (`/` → `index.lcm`, `..` stripped), load the matching `.lcm` file, reply with it or a 404 body. Kept separate from the entry point so it's testable outside a real CC:Tweaked instance.
- `site/` — a sample two-page site (`index.lcm`, `about.lcm`) demonstrating an `@link` between pages.

## Running

```
lamp <gatewayId> <subdomain> [port] [siteDirectory]
```

`port` defaults to 80, `siteDirectory` defaults to `site/` next to `lamp.lua`.

## Status

Serving logic is written and unit-tested against a CC:Tweaked stub harness (path resolution, 404 handling, the full connect/listen/serve loop). Not yet run against a real CC:Tweaked computer — the one thing that couldn't be verified this way is whether `package.path` manipulation actually reaches across from `/lamp` into `/craftnet`'s own nested `require()` calls the way it's assumed to here. Worth a real-game smoke test before trusting this further.
