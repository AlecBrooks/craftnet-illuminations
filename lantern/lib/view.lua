local view = {}

-- Browsing state: the current page, a vertical scroll offset (the
-- number of leading lines hidden above the top of the frame), which
-- link is selected, and a back-history stack of previously visited
-- targets. The viewport width is fixed and lines are cropped to it,
-- not panned -- only the vertical axis scrolls.
function view.new()
    return {
        title = nil,
        lines = {},
        scrollY = 0,
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
    state.scrollY = 0

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


-- Clamps scrollY so the selected link's line is within the visible
-- window, scrolling the minimum amount necessary either direction.
local function ensureSelectionVisible(state, viewportHeight)
    if not state.selectedLinkIndex or not viewportHeight then
        return
    end

    local index = state.selectedLinkIndex

    if index <= state.scrollY then
        state.scrollY = index - 1
    elseif index > state.scrollY + viewportHeight then
        state.scrollY = index - viewportHeight
    end
end


local function moveSelection(state, step, viewportHeight)
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
    ensureSelectionVisible(state, viewportHeight)
end


function view.selectNextLink(state, viewportHeight)
    moveSelection(state, 1, viewportHeight)
end


function view.selectPreviousLink(state, viewportHeight)
    moveSelection(state, -1, viewportHeight)
end


-- Shifts the vertical scroll offset, clamped so it never scrolls
-- past the last line that can still fill the top of the viewport
-- (and never negative).
function view.scroll(state, delta, viewportHeight)
    local maximumOffset =
        math.max(0, #state.lines - viewportHeight)

    local target = state.scrollY + delta
    state.scrollY = math.max(0, math.min(target, maximumOffset))
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
