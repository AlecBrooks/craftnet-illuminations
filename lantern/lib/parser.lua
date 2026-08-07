local address = require("lib.address")

local parser = {}

-- CC:Tweaked's colors API palette (see lcm/SPEC.md).
local COLOR_NAMES = {
    white = true, orange = true, magenta = true, lightBlue = true,
    yellow = true, lime = true, pink = true, gray = true,
    lightGray = true, cyan = true, purple = true, blue = true,
    brown = true, green = true, red = true, black = true,
}

parser.DEFAULT_FG = "white"
parser.DEFAULT_BG = "black"

-- Default width @p wraps to and @c centers within, used only when the
-- caller doesn't pass an explicit width to parser.parse. Lantern
-- always passes the real content viewport width (ui.contentWidth())
-- so text actually fills the screen instead of wrapping to a guess
-- that doesn't match -- this default exists for callers (tests,
-- anything inspecting a .lcm file without a live viewport) that don't
-- have a real width to give it.
parser.BLOCK_WIDTH = 48


local function trim(text)
    return tostring(text or ""):match("^%s*(.-)%s*$")
end


-- Splits source text into an array of lines, stripping one trailing
-- newline (the usual "file ends with a newline" convention) so it
-- doesn't produce a phantom blank line at the end.
local function splitLines(source)
    local text = tostring(source or ""):gsub("\n$", "")
    local lines = {}

    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        lines[#lines + 1] = line
    end

    return lines
end


-- Greedy word-wrap: never breaks a word, never exceeds maxWidth per
-- line (unless a single word is itself longer than maxWidth, which
-- can't be helped without breaking it).
local function wrapText(text, maxWidth)
    local lines = {}
    local current = ""

    for word in text:gmatch("%S+") do
        if current == "" then
            current = word
        elseif #current + 1 + #word <= maxWidth then
            current = current .. " " .. word
        else
            lines[#lines + 1] = current
            current = word
        end
    end

    if current ~= "" then
        lines[#lines + 1] = current
    end

    return lines
end


-- Pads text with an equal number of spaces on each side to center it
-- within `width` columns.
local function centerLine(text, width)
    local padding = math.max(0, math.floor((width - #text) / 2))
    return string.rep(" ", padding) .. text .. string.rep(" ", padding)
end


-- Expands @p ... @p (word-wrapped to BLOCK_WIDTH) and @c ... @c
-- (centered within BLOCK_WIDTH) into plain content lines, before the
-- regular per-line directive parser ever sees them. Either can open
-- and close on the same source line, or span several -- whatever's
-- easiest to write in the .lcm file; text between the markers is
-- joined with spaces regardless of how it was broken across lines.
--
-- Finds `tag` ("@p" or "@c") as a whole token -- not immediately
-- followed by another letter, so "@color" is never mistaken for a
-- "@c" marker (it starts with the same two characters).
local function findMarker(text, tag)
    local searchFrom = 1

    while true do
        local startIndex = text:find(tag, searchFrom, true)

        if not startIndex then
            return nil
        end

        local afterChar = text:sub(startIndex + #tag, startIndex + #tag)

        if afterChar == "" or not afterChar:match("%a") then
            return startIndex
        end

        searchFrom = startIndex + 1
    end
end


local function expandBlocks(sourceLines, blockWidth)
    local outputLines = {}
    local mode = nil -- nil | "paragraph" | "center"
    local accumulator = {}

    local function flush()
        local text = trim(table.concat(accumulator, " "))
        accumulator = {}

        if text == "" then
            return
        end

        if mode == "paragraph" then
            for _, wrapped in ipairs(wrapText(text, blockWidth)) do
                outputLines[#outputLines + 1] = wrapped
            end
        else
            outputLines[#outputLines + 1] = centerLine(text, blockWidth)
        end
    end

    local function marker()
        return mode == "paragraph" and "@p" or "@c"
    end

    for _, line in ipairs(sourceLines) do
        local remaining = line

        -- True only for the untouched start of this source line --
        -- lets a genuinely blank line still come through as one
        -- (preserving intentional spacing), while an empty fragment
        -- left over after consuming a marker earlier on the same
        -- line doesn't produce a spurious blank line.
        local isFreshLine = true

        while remaining ~= nil do
            if mode == nil then
                local pIndex = findMarker(remaining, "@p")
                local cIndex = findMarker(remaining, "@c")

                if pIndex and (not cIndex or pIndex < cIndex) then
                    local before = trim(remaining:sub(1, pIndex - 1))
                    if before ~= "" then
                        outputLines[#outputLines + 1] = before
                    end
                    mode = "paragraph"
                    remaining = remaining:sub(pIndex + 2)

                elseif cIndex then
                    local before = trim(remaining:sub(1, cIndex - 1))
                    if before ~= "" then
                        outputLines[#outputLines + 1] = before
                    end
                    mode = "center"
                    remaining = remaining:sub(cIndex + 2)

                else
                    if isFreshLine then
                        outputLines[#outputLines + 1] = remaining
                    elseif trim(remaining) ~= "" then
                        outputLines[#outputLines + 1] = trim(remaining)
                    end
                    remaining = nil
                end

            else
                local closeIndex = findMarker(remaining, marker())

                if closeIndex then
                    local before = remaining:sub(1, closeIndex - 1)
                    if trim(before) ~= "" then
                        accumulator[#accumulator + 1] = trim(before)
                    end
                    flush()
                    mode = nil
                    remaining = remaining:sub(closeIndex + 2)

                else
                    if trim(remaining) ~= "" then
                        accumulator[#accumulator + 1] = trim(remaining)
                    end
                    remaining = nil
                end
            end

            isFreshLine = false
        end
    end

    -- An unterminated block at EOF still gets flushed rather than
    -- silently dropped.
    if mode ~= nil then
        flush()
    end

    return outputLines
end


-- @color <fg> [on <bg>] -- an unrecognized color name leaves the
-- current color unchanged rather than failing the whole page.
local function applyColorDirective(argumentText, fg, bg)
    local fgName, bgName = argumentText:match("^(%S+)%s+on%s+(%S+)$")

    if not fgName then
        fgName = argumentText:match("^(%S+)$")
    end

    if fgName and COLOR_NAMES[fgName] then
        fg = fgName
    end

    if bgName and COLOR_NAMES[bgName] then
        bg = bgName
    end

    return fg, bg
end


-- Parses LCM source text into { title = string|nil, lines = {...} }.
-- Each line is one of:
--   { kind = "text", text = string, fg = string, bg = string }
--   { kind = "link", text = string, fg = string, bg = string,
--     target = { address, port, path } or { relative = true, path } }
--   { kind = "box", color = string, width = number }
--   { kind = "hr", color = string }
-- Unrecognized "@" directives are silently skipped, per the v0 spec,
-- so older Lantern builds don't choke on newer LCM files.
--
-- blockWidth: the width @p wraps to and @c centers within. Defaults
-- to BLOCK_WIDTH if omitted -- pass the real viewport width (e.g.
-- ui.contentWidth()) so wrapped text actually fills the screen.
function parser.parse(source, blockWidth)
    local page = { title = nil, lines = {} }

    local fg = parser.DEFAULT_FG
    local bg = parser.DEFAULT_BG

    local lines = expandBlocks(splitLines(source), blockWidth or parser.BLOCK_WIDTH)

    for _, line in ipairs(lines) do
        if line:sub(1, 1) == "@" then
            local directive, argumentText = line:match("^@(%S+)%s*(.-)$")
            argumentText = argumentText or ""

            if directive == "title" then
                page.title = trim(argumentText)

            elseif directive == "color" then
                fg, bg = applyColorDirective(trim(argumentText), fg, bg)

            elseif directive == "link" then
                local targetToken, linkText =
                    argumentText:match("^(%S+)%s*(.-)$")

                local target = nil

                if targetToken and targetToken:sub(1, 1) == "/" then
                    -- A path with no host -- resolved against
                    -- whatever page it appears on, so a site never
                    -- has to hardcode its own address to link to
                    -- itself.
                    target = { relative = true, path = targetToken }
                elseif targetToken then
                    target = address.parse(targetToken)
                end

                if target then
                    page.lines[#page.lines + 1] = {
                        kind = "link",
                        text = trim(linkText),
                        fg = fg,
                        bg = bg,
                        target = target,
                    }
                end

            elseif directive == "box" then
                local colorName, widthText, heightText =
                    argumentText:match("^(%S+)%s+(%d+)%s+(%d+)$")

                local width = tonumber(widthText)
                local height = tonumber(heightText)
                local color = COLOR_NAMES[colorName] and colorName or fg

                if width and height then
                    for _ = 1, height do
                        page.lines[#page.lines + 1] = {
                            kind = "box",
                            color = color,
                            width = width,
                        }
                    end
                end

            elseif directive == "hr" then
                page.lines[#page.lines + 1] = {
                    kind = "hr",
                    color = fg,
                }
            end

            -- Any other directive is ignored on purpose.

        else
            page.lines[#page.lines + 1] = {
                kind = "text",
                text = line,
                fg = fg,
                bg = bg,
            }
        end
    end

    return page
end


return parser
