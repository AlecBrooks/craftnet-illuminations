local address = {}

address.DEFAULT_PORT = 80
address.DEFAULT_PATH = "/"


-- Parses "host[:port][/path]" into { address, port, path }. host is
-- required; port defaults to 80, path defaults to "/".
function address.parse(input)
    input = tostring(input or ""):match("^%s*(.-)%s*$")

    if input == "" then
        return nil, "Address cannot be empty."
    end

    local host, rest = input:match("^([^:/]+)(.*)$")

    if not host or host == "" then
        return nil, "Address is missing a host."
    end

    local port = address.DEFAULT_PORT
    local path = address.DEFAULT_PATH

    if rest:sub(1, 1) == ":" then
        local portString, remainder = rest:match("^:(%d+)(.*)$")

        if not portString then
            return nil, "Invalid port."
        end

        port = tonumber(portString)
        rest = remainder
    end

    if rest ~= "" then
        path = rest

        if path:sub(1, 1) ~= "/" then
            path = "/" .. path
        end
    end

    return { address = host, port = port, path = path }
end


-- Inverse of parse -- a canonical display string, omitting the
-- port/path when they're just the defaults.
function address.format(target)
    local text = target.address

    if target.port ~= address.DEFAULT_PORT then
        text = text .. ":" .. tostring(target.port)
    end

    if target.path ~= address.DEFAULT_PATH then
        text = text .. target.path
    end

    return text
end


return address
