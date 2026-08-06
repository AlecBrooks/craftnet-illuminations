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


local function trim(text)
    return tostring(text or ""):match("^%s*(.-)%s*$")
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
--     target = { address, port, path } }
--   { kind = "box", color = string, width = number }
--   { kind = "hr", color = string }
-- Unrecognized "@" directives are silently skipped, per the v0 spec,
-- so older Lantern builds don't choke on newer LCM files.
function parser.parse(source)
    local page = { title = nil, lines = {} }

    local fg = parser.DEFAULT_FG
    local bg = parser.DEFAULT_BG

    -- Strip one trailing newline (the usual "file ends with a
    -- newline" convention) so it doesn't render as a phantom blank
    -- row at the bottom of every page.
    local text = tostring(source or ""):gsub("\n$", "")

    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
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

                local target = targetToken and address.parse(targetToken)

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
