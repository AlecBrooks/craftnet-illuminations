# LCM (Light Craft Markup)

The content format Lamp serves and Lantern renders.

Plain text, line by line: a line starting with `@` is a directive (color, title, a link, a drawn block), anything else is content rendered as-is at the color currently in effect. No auto-wrap, no reflow — one file line is one screen row, matching how CraftNet's own Gateway dashboard already draws things (explicit color and position, not flowing text).

Spec: [SPEC.md](SPEC.md). No parser/renderer yet — that's Lantern's job, not started.

A single `.lcm` file is still just a request/reply body, so it's bound by CraftNet's per-message size limit. No pagination/chunking in v0; worth revisiting once real pages start bumping into that ceiling.
