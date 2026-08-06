local server = {}

server.DEFAULT_DOCUMENT = "index.lcm"

server.NOT_FOUND_BODY =
    "@title Not Found\n"
    .. "@color red\n"
    .. "404 -- that page does not exist on this server."


-- Resolves a requested path against a site directory, defaulting to
-- DEFAULT_DOCUMENT for "/" or an empty path, and stripping ".." so a
-- request can never walk outside siteDirectory.
function server.resolvePath(siteDirectory, requestedPath)
    requestedPath = tostring(requestedPath or "")

    if requestedPath == "" or requestedPath == "/" then
        requestedPath = "/" .. server.DEFAULT_DOCUMENT
    end

    requestedPath = requestedPath:gsub("%.%.", "")

    return fs.combine(siteDirectory, requestedPath)
end


-- Loads the file for a requested path, or nil if it doesn't exist
-- (or is a directory).
function server.loadPage(siteDirectory, requestedPath)
    local filePath = server.resolvePath(siteDirectory, requestedPath)

    if not fs.exists(filePath) or fs.isDir(filePath) then
        return nil
    end

    local file = fs.open(filePath, "r")

    if not file then
        return nil
    end

    local contents = file.readAll()
    file.close()

    return contents
end


-- Handles one received packet: loads the requested page (or the 404
-- body) and replies. Returns the same true/false, ... shape as
-- cnet.reply, plus a short status label for logging.
function server.handleRequest(cnet, siteDirectory, packet)
    local requestedPath = packet.data
    local page = server.loadPage(siteDirectory, requestedPath)

    local status = page and "200" or "404"
    local body = page or server.NOT_FOUND_BODY

    local replied, replyError = cnet.reply(packet, body)

    return replied, status, replyError
end


-- Serves forever on an already-connected Host. Broken out from
-- lamp.lua so command-line parsing stays in the entry point and this
-- can be driven by tests instead. Doesn't call cnet.connect itself --
-- that always does a full reconnect handshake even if you're already
-- connected, so Lamp just reads the connection the Host already has
-- (via "cnet connect", set up once, same as any other CraftNet Host)
-- instead of asking for a gatewayId/subdomain of its own.
function server.run(cnet, port, siteDirectory)
    local statusOk, status = cnet.status()

    if not statusOk then
        return false, status
    end

    if not status.connected then
        return false,
            "Not connected to a gateway. Run "
            .. "\"cnet connect <gatewayId> <subdomain>\" first."
    end

    local listened, listenError = cnet.listen(port)

    if not listened then
        return false, listenError
    end

    print(
        "Lamp serving " .. siteDirectory
        .. " on port " .. tostring(port)
        .. " as " .. tostring(status.publicAddress)
        .. ". Ctrl+T to stop."
    )

    while true do
        local packet, receiveError = cnet.receive(port)

        if packet then
            local replied, status, replyError =
                server.handleRequest(cnet, siteDirectory, packet)

            if replied then
                print(
                    status .. " " .. tostring(packet.data)
                    .. " -> " .. tostring(packet.source)
                )
            else
                printError(
                    "Could not reply to " .. tostring(packet.source)
                    .. ": " .. tostring(replyError)
                )
            end
        elseif receiveError and receiveError ~= "Timed out." then
            printError(tostring(receiveError))
        end
    end
end


return server
