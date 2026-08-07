-- Lantern: a CraftNet browser. An address bar, a fixed-width frame,
-- and an LCM renderer with mouse-driven navigation.
--
-- Depends on an existing CraftNet Host install for its public
-- lib/cnet.lua developer API (https://github.com/AlecBrooks/craftnet).
-- Lantern never bundles or modifies any CraftNet source of its own --
-- it just widens its own require path to reach the installed copy.

local currentDirectory = fs.getDir(shell.getRunningProgram())

package.path =
    "/craftnet/?.lua;/craftnet/?/init.lua;"
    .. currentDirectory .. "/?.lua;"
    .. currentDirectory .. "/?/init.lua;"
    .. package.path

local cnet = require("lib.cnet")
local address = require("lib.address")
local parser = require("lib.parser")
local view = require("lib.view")
local ui = require("lib.ui")

local arguments = { ... }

local startAddressText = arguments[1]

local browsing = view.new()
local currentTarget = nil
local currentAddressText = ""
local statusText = ""
local statusColor = colors.black


local function redraw()
    ui.draw(browsing, {
        addressText = currentAddressText,
        statusText = statusText,
        statusColor = statusColor,
        canGoBack = view.canGoBack(browsing),
        canGoForward = view.canGoForward(browsing),
    })
end


-- cnet.request()'s own default timeout is only 5 seconds -- fine for
-- a same-gateway request, tight for one that has to cross the relay
-- (two extra network hops on top of the local Rednet ones). Lantern
-- already shows a "Loading..." status for the whole wait, so there's
-- no UX cost to giving it more room.
local REQUEST_TIMEOUT_SECONDS = 20

-- recordVisit: true for a fresh navigation (a clicked link, a typed
-- address) -- pushes the page being left onto back history and clears
-- forward history. false when the caller (startup, back/forward) has
-- already handled history itself, or there's nothing to record yet.
local function loadTarget(target, recordVisit)
    if recordVisit and currentTarget then
        view.recordVisit(browsing, currentTarget)
    end

    statusText = "Loading " .. address.format(target) .. " ..."
    statusColor = colors.gray
    redraw()

    local packet, requestError =
        cnet.request(
            target.address,
            target.port,
            target.path,
            REQUEST_TIMEOUT_SECONDS
        )

    if not packet then
        statusText =
            "Could not load " .. address.format(target)
            .. ": " .. tostring(requestError)
        statusColor = colors.red
        redraw()
        return
    end

    local page = parser.parse(packet.data, ui.contentWidth())
    view.setPage(browsing, page.title, page.lines)

    currentTarget = target
    currentAddressText = address.format(target)
    statusText = "Loaded " .. currentAddressText .. "."
    statusColor = colors.gray
    redraw()
end


local function promptForAddress()
    ui.draw(browsing, {
        addressText = "",
        editingAddress = true,
        statusText = statusText,
        statusColor = statusColor,
        canGoBack = view.canGoBack(browsing),
        canGoForward = view.canGoForward(browsing),
    })

    local x, y = ui.addressInputPosition()
    term.setCursorPos(x, y)
    term.setTextColor(colors.black)
    term.setBackgroundColor(colors.white)
    term.setCursorBlink(true)

    -- Deliberately not prefilled with currentAddressText: CC:Tweaked's
    -- read() puts the cursor at the end of a default value rather than
    -- selecting it, so typing a new address without first clearing the
    -- old one merges the two instead of replacing it.
    local input = read()

    term.setCursorBlink(false)

    if input == nil or input == "" then
        redraw()
        return
    end

    local target, parseError = address.parse(input)

    if not target then
        statusText = tostring(parseError)
        statusColor = colors.red
        redraw()
        return
    end

    loadTarget(target, true)
end


local function goBack()
    local target = view.goBack(browsing, currentTarget)

    if target then
        loadTarget(target, false)
    end
end


local function goForward()
    local target = view.goForward(browsing, currentTarget)

    if target then
        loadTarget(target, false)
    end
end


local function followLink(x, y)
    local row = ui.contentRowAt(x, y)

    if not row then
        return
    end

    local line = view.lineAt(browsing, row)

    if not line or line.kind ~= "link" or not currentTarget then
        return
    end

    loadTarget(address.resolve(currentTarget, line.target), true)
end


-- Restores a normal shell prompt instead of leaving Lantern's chrome
-- frozen on screen. Just returns -- cnetd is a separate daemon and
-- keeps running exactly as it was regardless of what Lantern does.
local function shutdown()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
    print("Lantern closed.")
end


local statusOk, status = cnet.status()

if not statusOk then
    printError(tostring(status))
    return
end

if not status.connected then
    printError(
        "Not connected to a gateway. Run "
        .. "\"cnet connect <gatewayId> <subdomain>\" first."
    )
    return
end

if startAddressText then
    local target, parseError = address.parse(startAddressText)

    if target then
        loadTarget(target, false)
    else
        statusText = tostring(parseError)
        statusColor = colors.red
        redraw()
    end
else
    redraw()
end

while true do
    local event, a, b, c = os.pullEvent()

    if event == "mouse_click" then
        local button, x, y = a, b, c

        if button == 1 then
            if ui.isCloseButton(x, y) then
                shutdown()
                return

            elseif ui.isAddressBar(x, y) then
                promptForAddress()

            elseif ui.isBackButton(x, y) then
                goBack()
                redraw()

            elseif ui.isForwardButton(x, y) then
                goForward()
                redraw()

            else
                followLink(x, y)
            end
        end

    elseif event == "mouse_scroll" then
        local direction = a
        view.scroll(browsing, direction, ui.contentHeight())
        redraw()

    elseif event == "key" then
        local keyCode = a

        if keyCode == keys.up then
            view.scroll(browsing, -1, ui.contentHeight())
            redraw()

        elseif keyCode == keys.down then
            view.scroll(browsing, 1, ui.contentHeight())
            redraw()
        end
    end
end
