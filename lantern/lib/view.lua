local view = {}

-- Browsing state: the current page, a horizontal scroll offset (the
-- number of leading columns hidden off the left edge of every line),
-- which link is selected, and a back-history stack of previously
-- visited targets. No vertical scroll offset yet -- v0 shows only as
-- many rows as fit in the frame; see lantern/README.md.
function view.new()
    return {
        title = nil,
        lines = {},
        scrollX = 0,
        selectedLinkIndex = nil,
        history = {},
    }
end


local function linkIndexes(state)
    local indexes = {}

    for index, line in ipairs(state.lines) do
        if line.kind == "link" then
            indexes[#indexes + 1] = index
        end
    end

    return indexes
end


-- Loads a freshly parsed page into the state, resetting scroll and
-- selecting the first link (if any). Does not touch history --
-- callers push onto history themselves so "back" and "follow a link"
-- can behave differently.
function view.setPage(state, title, lines)
    state.title = title
    state.lines = lines
    state.scrollX = 0

    local indexes = linkIndexes(state)
    state.selectedLinkIndex = indexes[1]
end


function view.hasLinks(state)
    return state.selectedLinkIndex ~= nil
end


-- Returns the target of the currently selected link, or nil if the
-- page has no links.
function view.selectedTarget(state)
    if not state.selectedLinkIndex then
        return nil
    end

    local line = state.lines[state.selectedLinkIndex]
    return line and line.target
end


local function moveSelection(state, step)
    local indexes = linkIndexes(state)

    if #indexes == 0 then
        state.selectedLinkIndex = nil
        return
    end

    local currentPosition = 1

    for position, index in ipairs(indexes) do
        if index == state.selectedLinkIndex then
            currentPosition = position
            break
        end
    end

    local nextPosition =
        ((currentPosition - 1 + step) % #indexes) + 1

    state.selectedLinkIndex = indexes[nextPosition]
end


function view.selectNextLink(state)
    moveSelection(state, 1)
end


function view.selectPreviousLink(state)
    moveSelection(state, -1)
end


local function longestLineWidth(state)
    local longest = 0

    for _, line in ipairs(state.lines) do
        local width

        if line.kind == "box" or line.kind == "hr" then
            width = line.width or 0
        else
            width = #(line.text or "")
        end

        if width > longest then
            longest = width
        end
    end

    return longest
end


-- Shifts the horizontal scroll offset, clamped so it never scrolls
-- past the widest line on the page (and never negative).
function view.scroll(state, delta, viewportWidth)
    local maximumOffset =
        math.max(0, longestLineWidth(state) - viewportWidth)

    local target = state.scrollX + delta
    state.scrollX = math.max(0, math.min(target, maximumOffset))
end


function view.pushHistory(state, target)
    local history = state.history
    history[#history + 1] = target
end


-- Pops and returns the previous target, or nil if there is no
-- history to go back to.
function view.popHistory(state)
    local history = state.history
    local count = #history

    if count == 0 then
        return nil
    end

    local target = history[count]
    history[count] = nil
    return target
end


return view
