-- Renders Lantern's chrome and the current page. Talks directly to
-- CC:Tweaked's term/colors APIs, so unlike the rest of lantern/lib
-- this module isn't covered by the stub-harness unit tests -- see
-- lantern/README.md for what that leaves unverified.
--
-- Layout (all click targets, hit-tested by lantern.lua against the
-- same coordinates used to draw them):
--   row 1            : title (left) + close button (right), on the
--                       bare screen background, outside the frame
--   row 2            : address bar, same background, click to edit
--   frame            : flush with the screen's left/right edges,
--                       "< >" back/forward buttons on its own top
--                       border, gray instead of white
--   last row         : status line (no separate hint row anymore --
--                       everything is a click target now, nothing to
--                       remind anyone how to press a key for)

local ui = {}

local width, height
local frameX1, frameY1, frameX2, frameY2
local contentX1, contentY1, contentX2, contentY2
local closeButtonX1, closeButtonX2
local backButtonX, forwardButtonX

local OUTER_BACKGROUND = colors.lightGray
local OUTER_TEXT = colors.black
local FRAME_COLOR = colors.gray
local CONTENT_BACKGROUND = colors.blue


function ui.getLocalEnv()
    width, height = term.getSize()

    frameX1, frameY1 = 1, 3
    frameX2, frameY2 = width, height - 1

    contentX1 = frameX1 + 2
    contentX2 = frameX2 - 2
    contentY1 = frameY1 + 2
    contentY2 = frameY2 - 2

    closeButtonX2 = width
    closeButtonX1 = width - 2

    backButtonX = frameX1 + 1
    forwardButtonX = frameX1 + 3
end


function ui.contentWidth()
    return math.max(0, contentX2 - contentX1 + 1)
end


function ui.contentHeight()
    return math.max(0, contentY2 - contentY1 + 1)
end


-- Where the blocking read() call for address entry should place its
-- cursor -- right after the "Go to: " label drawAddressBar writes
-- when editingAddress is true.
local ADDRESS_EDIT_LABEL = "Go to: "

function ui.addressInputPosition()
    return 1 + #ADDRESS_EDIT_LABEL, 2
end


-- Hit-testing helpers -- lantern.lua calls these with a raw
-- mouse_click (x, y) to decide what was clicked. Kept here so the
-- click regions can never drift out of sync with what's actually
-- drawn.

function ui.isCloseButton(x, y)
    return y == 1 and x >= closeButtonX1 and x <= closeButtonX2
end


function ui.isAddressBar(x, y)
    return y == 2
end


function ui.isBackButton(x, y)
    return y == frameY1 and x == backButtonX
end


function ui.isForwardButton(x, y)
    return y == frameY1 and x == forwardButtonX
end


-- Returns the 0-indexed content row a click landed on, or nil if the
-- click was outside the content area entirely.
function ui.contentRowAt(x, y)
    if x < contentX1 or x > contentX2
        or y < contentY1 or y > contentY2
    then
        return nil
    end

    return y - contentY1
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

    -- The whole interior, flush against the border -- content text is
    -- inset from this by its own margin (see contentX1/Y1 etc.), but
    -- the background fill itself reaches all the way to the frame, so
    -- there's no gap showing the screen's own background through.
    term.setBackgroundColor(backgroundColor)

    local blankRow = string.rep(" ", math.max(0, x2 - x1 - 1))

    for y = y1 + 1, y2 - 1 do
        term.setCursorPos(x1 + 1, y)
        term.write(blankRow)
    end
end


-- "< >" on the frame's own top border -- bright when that direction
-- has history to go to, dimmed into the border color when it doesn't.
local function drawHistoryButtons(canGoBack, canGoForward)
    term.setBackgroundColor(FRAME_COLOR)

    term.setCursorPos(backButtonX, frameY1)
    term.setTextColor(canGoBack and colors.white or FRAME_COLOR)
    term.write("<")

    term.setCursorPos(forwardButtonX, frameY1)
    term.setTextColor(canGoForward and colors.white or FRAME_COLOR)
    term.write(">")
end


local function drawHeader(title)
    term.setBackgroundColor(OUTER_BACKGROUND)
    term.setTextColor(OUTER_TEXT)
    term.setCursorPos(1, 1)
    term.clearLine()

    local message = title and ("Lantern -- " .. title) or "Lantern"
    local maximumLength = math.max(0, closeButtonX1 - 2)

    if #message > maximumLength then
        message = message:sub(1, maximumLength)
    end

    term.setCursorPos(1, 1)
    term.write(message)

    term.setBackgroundColor(colors.red)
    term.setTextColor(colors.white)
    term.setCursorPos(closeButtonX1, 1)
    term.write("[X]")
end


local function drawAddressBar(addressText, editingAddress)
    term.setBackgroundColor(
        editingAddress and colors.white or OUTER_BACKGROUND
    )
    term.setTextColor(OUTER_TEXT)
    term.setCursorPos(1, 2)
    term.clearLine()

    term.setCursorPos(1, 2)
    term.write(editingAddress and ADDRESS_EDIT_LABEL or "Address: ")

    term.write(addressText or "")
end


-- One content row: text/link lines are cropped to the fixed viewport
-- width (never panned); box/hr lines paint a solid run of background
-- color, also cropped to that width.
local function drawContentLine(y, line, viewportWidth)
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

        term.setBackgroundColor(resolveColor(line.bg))
        term.setTextColor(resolveColor(line.fg))

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

    term.setBackgroundColor(CONTENT_BACKGROUND)

    for row = 0, viewportHeight - 1 do
        local y = contentY1 + row
        local line = browsing.lines[browsing.scrollY + row + 1]

        if line then
            drawContentLine(y, line, viewportWidth)
        else
            term.setCursorPos(contentX1, y)
            term.write(string.rep(" ", viewportWidth))
        end
    end
end


local function drawStatus(statusText, statusColor)
    term.setBackgroundColor(OUTER_BACKGROUND)
    term.setTextColor(statusColor or OUTER_TEXT)
    term.setCursorPos(1, height)
    term.clearLine()

    term.setCursorPos(1, height)
    term.write((statusText or ""):sub(1, width))
end


-- browsing: a lib/view.lua state table.
-- options: { addressText, editingAddress, statusText, statusColor,
--            canGoBack, canGoForward }
function ui.draw(browsing, options)
    options = options or {}

    ui.getLocalEnv()

    term.setBackgroundColor(OUTER_BACKGROUND)
    term.setTextColor(OUTER_TEXT)
    term.clear()

    drawHeader(browsing.title)
    drawAddressBar(options.addressText, options.editingAddress)

    drawFrame(frameX1, frameY1, frameX2, frameY2, FRAME_COLOR, CONTENT_BACKGROUND)
    drawHistoryButtons(options.canGoBack, options.canGoForward)
    drawContent(browsing)

    drawStatus(options.statusText, options.statusColor)
end


return ui
