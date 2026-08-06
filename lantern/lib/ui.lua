-- Renders Lantern's chrome and the current page. Talks directly to
-- CC:Tweaked's term/colors APIs, so unlike the rest of lantern/lib
-- this module isn't covered by the stub-harness unit tests -- see
-- lantern/README.md for what that leaves unverified.

local ui = {}

local width, height
local frameX1, frameY1, frameX2, frameY2
local contentX1, contentY1, contentX2, contentY2


function ui.getLocalEnv()
    width, height = term.getSize()

    frameX1, frameY1 = 2, 3
    frameX2, frameY2 = width - 1, height - 2

    -- One-space margin between the frame border and the content
    -- itself on every side, so text never sits flush against it.
    contentX1 = frameX1 + 2
    contentX2 = frameX2 - 2
    contentY1 = frameY1 + 2
    contentY2 = frameY2 - 2
end


function ui.contentWidth()
    return math.max(0, contentX2 - contentX1 + 1)
end


function ui.contentHeight()
    return math.max(0, contentY2 - contentY1 + 1)
end


-- Where the blocking read() call for address entry should place its
-- cursor -- right after the "Go to: " label ui.draw() writes when
-- editingAddress is true. Only valid after draw() has run at least
-- once (it depends on getLocalEnv's layout math).
function ui.addressInputPosition()
    return frameX1 + 7, 2
end


local function resolveColor(name)
    return colors[name] or colors.white
end


local function drawFrame(x1, y1, x2, y2, frameColor, backgroundColor)
    term.setBackgroundColor(frameColor)

    term.setCursorPos(x1, y1)
    term.write(string.rep(" ", x2 - x1 + 1))

    term.setCursorPos(x1, y2)
    term.write(string.rep(" ", x2 - x1 + 1))

    for y = y1 + 1, y2 - 1 do
        term.setCursorPos(x1, y)
        term.write(" ")

        term.setCursorPos(x2, y)
        term.write(" ")
    end

    term.setBackgroundColor(backgroundColor)
end


local function drawHeader(title)
    local message = title and ("Lantern -- " .. title) or "Lantern"

    if #message > width - 2 then
        message = message:sub(1, width - 2)
    end

    local headerX = math.floor((width - #message) / 2) + 1

    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.white)
    term.setCursorPos(1, 1)
    term.clearLine()

    term.setBackgroundColor(colors.magenta)
    term.setCursorPos(headerX, 1)
    term.write(message)
end


local function drawAddressBar(addressText, editingAddress)
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.white)
    term.setCursorPos(1, 2)
    term.clearLine()

    term.setCursorPos(frameX1, 2)
    term.write(editingAddress and "Go to: " or "Address: ")

    term.setTextColor(editingAddress and colors.yellow or colors.lightGray)
    term.write(addressText or "")

    if editingAddress then
        term.write("_")
    end
end


-- One content row: text/link lines are cropped to the fixed viewport
-- width (never panned); box/hr lines paint a solid run of background
-- color, also cropped to that width.
local function drawContentLine(y, line, viewportWidth, selected)
    term.setCursorPos(contentX1, y)

    if line.kind == "box" then
        term.setBackgroundColor(resolveColor(line.color))
        local visible = math.max(0, math.min(line.width, viewportWidth))
        term.write(string.rep(" ", visible))

    elseif line.kind == "hr" then
        term.setBackgroundColor(resolveColor(line.color))
        term.write(string.rep(" ", viewportWidth))

    else
        local text = line.text or ""

        if line.kind == "link" then
            text = "> " .. text
        end

        if selected then
            term.setBackgroundColor(resolveColor(line.fg))
            term.setTextColor(resolveColor(line.bg))
        else
            term.setBackgroundColor(resolveColor(line.bg))
            term.setTextColor(resolveColor(line.fg))
        end

        local visible = text:sub(1, viewportWidth)
        term.write(visible)

        local padding = viewportWidth - #visible
        if padding > 0 then
            term.write(string.rep(" ", padding))
        end
    end
end


local function drawContent(browsing)
    local viewportWidth = ui.contentWidth()
    local viewportHeight = ui.contentHeight()

    term.setBackgroundColor(colors.blue)

    for row = 0, viewportHeight - 1 do
        local y = contentY1 + row
        local lineIndex = browsing.scrollY + row + 1
        local line = browsing.lines[lineIndex]

        if line then
            local selected = lineIndex == browsing.selectedLinkIndex
            drawContentLine(y, line, viewportWidth, selected)
        else
            term.setCursorPos(contentX1, y)
            term.write(string.rep(" ", viewportWidth))
        end
    end
end


local function drawStatus(statusText, statusColor)
    term.setBackgroundColor(colors.blue)
    term.setTextColor(statusColor or colors.lightGray)
    term.setCursorPos(1, height - 1)
    term.clearLine()

    term.setCursorPos(2, height - 1)
    term.write((statusText or ""):sub(1, width - 2))
end


local function drawHint()
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.lightGray)
    term.setCursorPos(1, height)
    term.clearLine()

    term.setCursorPos(2, height)
    term.write(
        "[a] go  [tab] next link  [enter] follow  "
        .. "[up/down] scroll  [backspace] back  Ctrl+T to quit"
    )
end


-- browsing: a lib/view.lua state table.
-- options: { addressText, editingAddress, statusText, statusColor }
function ui.draw(browsing, options)
    options = options or {}

    ui.getLocalEnv()

    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.white)
    term.clear()

    drawHeader(browsing.title)
    drawAddressBar(options.addressText, options.editingAddress)

    drawFrame(frameX1, frameY1, frameX2, frameY2, colors.white, colors.blue)
    drawContent(browsing)

    drawStatus(options.statusText, options.statusColor)
    drawHint()
end


return ui
