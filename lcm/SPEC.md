# LCM v0 — Light Craft Markup

An `.lcm` file is plain text. Each line is either a **directive** (starts with `@`) or a **content line** (everything else, rendered as-is).

Lantern does not reflow or wrap content lines — each line in the file becomes exactly one row on screen. The viewport width is fixed (whatever the computer's terminal reports) and never pans sideways, so a line longer than that is cropped rather than wrapped — keep lines within the target width. Pages can be any length top to bottom; Lantern scrolls vertically to read the rest.

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
@link /<path> <link text>
```
Renders `<link text>` as a distinct, navigable line. Selecting it in Lantern issues a new request to `<address>` on `<port>` for `<path>`.

The second form — just a path, starting with `/` — is relative: it targets the same address and port as the page it's on. Use it to link within a site so the file never has to hardcode its own address; a link written as `@link /about.lcm About this site` keeps working no matter what domain the site ends up served from.

```text
@box <color> <width> <height>
```
Draws a solid block `<width>` columns by `<height>` rows in `<color>`, starting at the current position — the same colored-space-character technique the Gateway's own dashboard uses to draw its frame. This is the whole "graphics" primitive for v0: banners, dividers, simple layout blocks.

```text
@hr
```
A horizontal rule spanning the current line. Shorthand for a 1-row `@box` in the current color.

```text
@p <text> @p
```
Word-wraps the text between the two markers to lines of at most 48 characters, never breaking a word. The opening and closing `@p` can be on the same source line or several lines apart — whatever's easiest to write; text is joined with single spaces regardless of how it was broken up in the file. Use this for actual paragraphs instead of hand-wrapping a plain content line yourself.

```text
@c <text> @c
```
Centers the text between the two markers within 48 columns (padded evenly on both sides; if the text is already 48 characters or longer, it's left as-is rather than compressed). Same open/close flexibility as `@p`. Meant for short lines — headings, a centered blurb — not long passages.

## Content lines

Any line not starting with `@` is rendered literally, in whatever color is currently in effect, starting at the left edge of the page.

## What v0 deliberately leaves out

No inline color changes within a single line (a line is one color, set by the last `@color` before it). No wrapping/centering to anything other than the fixed 48-column convention `@p`/`@c` use (not the real, possibly different, runtime viewport width). No images. No forms/inputs. All of this can be added later without breaking existing `.lcm` files, since an unrecognized directive can simply be ignored by a stricter renderer rather than crashing it — but v0 doesn't need any of it to prove the concept.

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
@link /about.lcm About this site

@color white
@hr
Thanks for stopping by.
```

A page using `@p`/`@c` (see `lamp/site/article.lcm` for the full version):

```text
@title A Long Article
@c Lorem Ipsum Lorem Ipsum @c

@p
Lorem ipsum dolor sit amet consectetur adipiscing elit. Quisque
faucibus ex sapien vitae pellentesque sem placerat.
@p
```
