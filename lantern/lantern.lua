-- Lantern: a CraftNet browser. An address bar, a fixed-width frame,
-- and an LCM renderer with hyperlink navigation.
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
local statusColor = colors.lightGray


local function redraw()
    ui.draw(browsing, {
        addressText = currentAddressText,
        statusText = statusText,
        statusColor = statusColor,
    })
end


-- cnet.request()'s own default timeout is only 5 seconds -- fine for
-- a same-gateway request, tight for one that has to cross the relay
-- (two extra network hops on top of the local Rednet ones). Lantern
-- already shows a "Loading..." status for the whole wait, so there's
-- no UX cost to giving it more room.
local REQUEST_TIMEOUT_SECONDS = 20

local function loadTarget(target, recordCurrentInHistory)
    if recordCurrentInHistory and currentTarget then
        view.pushHistory(browsing, currentTarget)
    end

    statusText = "Loading " .. address.format(target) .. " ..."
    statusColor = colors.yellow
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

    local page = parser.parse(packet.data)
    view.setPage(browsing, page.title, page.lines)

    currentTarget = target
    currentAddressText = address.format(target)
    statusText = "Loaded " .. currentAddressText .. "."
    statusColor = colors.lime
    redraw()
end


local function promptForAddress()
    ui.draw(browsing, {
        addressText = "",
        editingAddress = true,
        statusText = statusText,
        statusColor = statusColor,
    })

    local x, y = ui.addressInputPosition()
    term.setCursorPos(x, y)
    term.setTextColor(colors.yellow)
    term.setBackgroundColor(colors.blue)
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
    local event, param = os.pullEvent("key")

    if param == keys.a then
        promptForAddress()

    elseif param == keys.tab then
        view.selectNextLink(browsing, ui.contentHeight())
        redraw()

    elseif param == keys.enter then
        local target = view.selectedTarget(browsing)

        if target and currentTarget then
            loadTarget(address.resolve(currentTarget, target), true)
        end

    elseif param == keys.up then
        view.scroll(browsing, -1, ui.contentHeight())
        redraw()

    elseif param == keys.down then
        view.scroll(browsing, 1, ui.contentHeight())
        redraw()

    elseif param == keys.backspace then
        local target = view.popHistory(browsing)

        if target then
            loadTarget(target, false)
        end
    end
end
