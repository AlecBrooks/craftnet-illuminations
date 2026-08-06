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

Lamp serves `.lcm` files from a local directory over `cnet.listen`/`cnet.receive`/`cnet.reply`. Lantern connects, sends `cnet.request()`, parses the LCM response, and renders it in a fixed-width frame with address-bar navigation, link cycling, horizontal scroll, and back-history. Both have their pure logic unit-tested against a CC:Tweaked stub harness and cross-checked against each other (Lantern's parser correctly renders Lamp's actual sample site). Neither has been run against a real CC:Tweaked computer yet — that's the next step, not further building ahead of it.
