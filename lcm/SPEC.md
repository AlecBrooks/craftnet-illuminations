# LCM v0 — Light Craft Markup

An `.lcm` file is plain text. Each line is either a **directive** (starts with `@`) or a **content line** (everything else, rendered as-is).

Lantern does not reflow or wrap content lines — each line in the file becomes exactly one row on screen, at whatever length it is. A line wider than the viewport needs horizontal scrolling to read the rest of it; that's deliberate, and matches how a CC:Tweaked terminal already behaves rather than fighting it.

## Directives

```text
@title <text>
```
Sets the page title.

```text
@color <foreground> [on <background>]
```
Sets the color for every content line that follows, until the next `@color`. Names match CC:Tweaked's `colors` API (`white`, `orange`, `magenta`, `lightBlue`, `yellow`, `lime`, `pink`, `gray`, `lightGray`, `cyan`, `purple`, `blue`, `brown`, `green`, `red`, `black`). A page starts as white on black.

```text
@link <address>:<port>/<path> <link text>
```
Renders `<link text>` as a distinct, navigable line. Selecting it in Lantern issues a new request to `<address>` on `<port>` for `<path>`.

```text
@box <color> <width> <height>
```
Draws a solid block `<width>` columns by `<height>` rows in `<color>`, starting at the current position — the same colored-space-character technique the Gateway's own dashboard uses to draw its frame. This is the whole "graphics" primitive for v0: banners, dividers, simple layout blocks.

```text
@hr
```
A horizontal rule spanning the current line. Shorthand for a 1-row `@box` in the current color.

## Content lines

Any line not starting with `@` is rendered literally, in whatever color is currently in effect, starting at the left edge of the page.

## What v0 deliberately leaves out

No inline color changes within a single line (a line is one color, set by the last `@color` before it). No automatic text wrapping. No images. No forms/inputs. All of this can be added later without breaking existing `.lcm` files, since an unrecognized directive can simply be ignored by a stricter renderer rather than crashing it — but v0 doesn't need any of it to prove the concept.

## Example

```text
@title Home
@color white on blue
Welcome to my CraftNet site!

@color white
This page is being served by Lamp, straight off a CraftNet gateway --
no special support was added to CraftNet to make this work, just the
same request/response primitives any program can use.

@color yellow
@link mythra.craftnet.craft:80/about.lcm About this site

@color white
@hr
Thanks for stopping by.
```
