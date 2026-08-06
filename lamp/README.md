# Lamp

The web server. Runs as a CraftNet Host.

Not started. Expected shape: `cnet.listen()`/`cnet.receive()` on a conventional port (80), a path parsed out of the request's `data`, `index.lcm` as the default document, files read from local disk and served back via `cnet.reply()`.
