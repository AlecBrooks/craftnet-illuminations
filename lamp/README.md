# Lamp

The web server. Runs as a CraftNet Host, using only CraftNet's public `lib/cnet.lua` developer API — see `craftnet-illuminations/README.md` for the standing rule that this project never touches craftnet's own source.

## Layout

- `lamp.lua` — entry point. Widens `package.path` to reach an installed CraftNet Host's `lib/cnet.lua` (assumed at `/craftnet`) and its own `lib/`, parses arguments, hands off to `lib/server.lua`.
- `lib/server.lua` — the actual logic: resolve a requested path against a site directory (`/` → `index.lcm`, `..` stripped), load the matching `.lcm` file, reply with it or a 404 body. Kept separate from the entry point so it's testable outside a real CC:Tweaked instance.
- `site/` — a sample two-page site (`index.lcm`, `about.lcm`) demonstrating an `@link` between pages.

## Running

Connect the computer to a gateway first, same as any CraftNet Host (`cnet connect <gatewayId> <subdomain>` — once, it's remembered after that). Then:

```
lamp [port] [siteDirectory]
```

`port` defaults to 80, `siteDirectory` defaults to `site/` next to `lamp.lua`. Lamp doesn't take a gatewayId/subdomain of its own — it reads the connection the Host already has via `cnet.status()`, rather than duplicating what `cnet connect` already set up. (Calling `cnet.connect()` again always does a full reconnect handshake, even if you're already connected, so Lamp deliberately never calls it.)

## Serving the root domain

A Host is always required to claim a real subdomain when it connects — `root` and `@` are reserved and can never be claimed as a Host's own identity (see craftnet's README, "Port Routing Reference"). So a Lamp instance's *own* address is always something like `mysite.cnet.craft`, never the bare `cnet.craft`.

To make the bare root domain serve that same Lamp instance too, add a route on the **gateway** pointing root traffic at that computer's ID — this is gateway-side config, nothing Lamp itself needs to know about or handle differently:

```
ports route 80 to 80 <lamp's computer ID> root
```

Lamp doesn't need to be told about this, or care which address was used to reach it — `cnet.receive()` just gets the request either way, since the routing/subdomain-matching happens entirely on the gateway before delivery.

## Status

Confirmed working in a real game session (2026-08-06): installed via `bootstrap.lua`, connected, and served its sample site to Lantern. Two real things surfaced by that test and since fixed: it used to require re-typing `<gatewayId> <subdomain>` even though the Host was already connected (see above), and `site/index.lcm`'s link to `about.lcm` used to hardcode a placeholder domain (`mythra.craftnet.craft`) that didn't match wherever the site actually got deployed — now a relative link (`@link /about.lcm ...`, see [lcm/SPEC.md](../lcm/SPEC.md)) that resolves against whatever address the site is actually served from.

Serving logic is unit-tested against a CC:Tweaked stub harness (path resolution, 404 handling, the full status/listen/serve loop).
