local view = {}

-- How many pages back/forward you can navigate in either direction.
view.HISTORY_LIMIT = 5


-- Browsing state: the current page, a vertical scroll offset (the
-- number of leading lines hidden above the top of the frame), and
-- bounded back/forward history stacks. The viewport width is fixed
-- and lines are cropped to it, not panned -- only the vertical axis
-- scrolls. Links are followed by clicking them directly (no keyboard
-- selection state to track).
function view.new()
    return {
        title = nil,
        lines = {},
        scrollY = 0,
        backStack = {},
        forwardStack = {},
    }
end


-- Loads a freshly parsed page into the state, resetting scroll.
-- Doesn't touch history -- callers record the visit themselves via
-- view.recordVisit, since "follow a link" and "go back" build history
-- differently.
function view.setPage(state, title, lines)
    state.title = title
    state.lines = lines
    state.scrollY = 0
end


-- The line at viewport row `row` (0-indexed, relative to the top of
-- the content area), accounting for the current scroll offset. The
-- same math ui.lua's renderer uses, so a click and the row it visibly
-- lines up with always agree.
function view.lineAt(state, row)
    return state.lines[state.scrollY + row + 1]
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


local function pushBounded(stack, value)
    stack[#stack + 1] = value

    if #stack > view.HISTORY_LIMIT then
        table.remove(stack, 1)
    end
end


-- Records that `target` is being left behind for a newly navigated-to
-- page (a clicked link, a typed address -- anything that isn't back/
-- forward itself). Clears forward history, same as any real browser:
-- navigating somewhere new invalidates the "redo" path.
function view.recordVisit(state, target)
    pushBounded(state.backStack, target)
    state.forwardStack = {}
end


function view.canGoBack(state)
    return #state.backStack > 0
end


function view.canGoForward(state)
    return #state.forwardStack > 0
end


-- Moves one step back, given the target being left behind (so it can
-- be pushed onto forward history). Returns the target to load, or nil
-- if there's nowhere to go back to.
function view.goBack(state, currentTarget)
    local count = #state.backStack

    if count == 0 then
        return nil
    end

    local previous = state.backStack[count]
    state.backStack[count] = nil

    pushBounded(state.forwardStack, currentTarget)

    return previous
end


-- The mirror of goBack.
function view.goForward(state, currentTarget)
    local count = #state.forwardStack

    if count == 0 then
        return nil
    end

    local next = state.forwardStack[count]
    state.forwardStack[count] = nil

    pushBounded(state.backStack, currentTarget)

    return next
end


return view
