# CraftNet Illuminations

Illuminations is a small suite of applications built entirely on top of [CraftNet](https://github.com/AlecBrooks/craftnet)'s public `cnet` developer library — nothing more.

It exists to answer one question: can real software actually be built on CraftNet's primitives, with zero special-case support added to CraftNet itself? If Illuminations ever needs something CraftNet doesn't provide, that's a bug in Illuminations' design, not a feature request against CraftNet. This repository never modifies CraftNet's source. It only ever `require()`s the public `lib/cnet.lua` API a CraftNet Host already exposes.

## The suite

- **Lantern** — a browser. An address bar, a search bar, a full-screen dashboard-style UI (in the spirit of the CraftNet Gateway's own dashboard), rendering of simple pages, and hyperlink navigation between them.
- **Lamp** — a web server. Serves `.lcm` files by path over a single CraftNet port, `index.lcm` as the default document, same as any conventional web server's routing convention.
- **LCM (Light Craft Markup)** — the content format Lamp serves and Lantern renders. A simple markup language: text, structure, and hyperlinks.

## How it fits together

```text
Lantern                                    Lamp
   │                                          │
   │ cnet.request(address, port, "/page.lcm")  │
   ├─────────────────────────────────────────▶│
   │                                          │  reads /page.lcm, cnet.reply(...)
   │◀─────────────────────────────────────────┤
   │  renders the returned LCM content         │
```

Everything above the arrows is CraftNet: addressing (a Lamp instance is just a CraftNet subdomain), routing, and the request/response round trip. Everything at the endpoints — what a "path" means, what LCM looks like, how a page gets drawn — is Illuminations' own concern, layered entirely on top.

## Requirements

- A working CraftNet installation — see [AlecBrooks/craftnet](https://github.com/AlecBrooks/craftnet). Lamp runs as a CraftNet Host; Lantern runs as a CraftNet Host too (it only ever *sends* requests, same as any other client).
- Nothing else. No CraftNet source changes, no forked dependency, no vendored copy of `cnet` — Illuminations depends on CraftNet the same way any third-party program would.

## Installing

On a CC:Tweaked computer that already has CraftNet's Host role installed and running:

```
wget https://raw.githubusercontent.com/AlecBrooks/craftnet-illuminations/main/bootstrap.lua bootstrap.lua
bootstrap lamp
```

(or `bootstrap lantern`, or just `bootstrap` to be asked which). It pulls the current `lamp/` or `lantern/` tree straight from GitHub — same self-updating idea as CraftNet's own `bootstrap.lua`, just simpler: it doesn't touch `/startup.lua` or try to auto-launch anything, since a computer running this already has CraftNet's own startup wired up. Re-run `bootstrap lamp`/`bootstrap lantern` any time to pull the latest version; it replaces the previous install atomically.

Connect the computer to a gateway first, same as any CraftNet Host (`cnet connect <gatewayId> <subdomain>` — once, it's remembered after that). Then run either program directly — neither takes a gatewayId/subdomain of its own, they just read the connection the Host already has:

```
lamp [port] [siteDirectory]
lantern [startAddress]
```

## Project structure

```text
craftnet-illuminations/
├── lantern/   the browser
├── lamp/      the web server
└── lcm/       the markup format: spec, parser, renderer
```

LCM has a v0 spec ([lcm/SPEC.md](lcm/SPEC.md)). Lamp and Lantern both have working implementations ([lamp/](lamp/), [lantern/](lantern/)).

## Status

CraftNet's primitives (subdomain addressing, request/response with free-form payloads, and — critically — many independent services sharing the same conventional port across different subdomains on one gateway) were confirmed working end-to-end, including in real gameplay, before this repository was created. That's the whole premise Illuminations is built on.

Lamp serves `.lcm` files from a local directory over `cnet.listen`/`cnet.receive`/`cnet.reply`. Lantern connects, sends `cnet.request()`, parses the LCM response, and renders it in a fixed-width frame with address-bar navigation, link cycling, vertical scroll, and back-history. Both have their pure logic unit-tested against a CC:Tweaked stub harness and cross-checked against each other (Lantern's parser correctly renders Lamp's actual sample site).

Both have now run in a real game session too: installed via `bootstrap.lua`, connected, Lamp served its sample site, Lantern rendered and fetched it. That first real test caught two things worth knowing about — see [lamp/README.md](lamp/README.md) and [lantern/README.md](lantern/README.md) for what they were and how they were fixed (in short: neither program needs a gatewayId/subdomain of its own anymore, and links within a site should be relative, not hardcoded to a specific domain).
