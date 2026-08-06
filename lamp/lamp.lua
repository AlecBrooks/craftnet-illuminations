-- Lamp: a CraftNet web server. Serves .lcm files by path from a
-- local site directory, with index.lcm as the default document.
--
-- Depends on an existing CraftNet Host install for its public
-- lib/cnet.lua developer API (https://github.com/AlecBrooks/craftnet).
-- Lamp never bundles or modifies any CraftNet source of its own --
-- it just widens its own require path to reach the installed copy.

local currentDirectory = fs.getDir(shell.getRunningProgram())

package.path =
    "/craftnet/?.lua;/craftnet/?/init.lua;"
    .. currentDirectory .. "/?.lua;"
    .. currentDirectory .. "/?/init.lua;"
    .. package.path

local cnet = require("lib.cnet")
local server = require("lib.server")

local arguments = { ... }

local gatewayId = tonumber(arguments[1])
local subdomain = arguments[2]
local port = tonumber(arguments[3]) or 80
local siteDirectory = arguments[4] or (currentDirectory .. "/site")

if not gatewayId or not subdomain then
    printError("Usage: lamp <gatewayId> <subdomain> [port] [siteDirectory]")
    return
end

print(
    "Lamp starting -- connecting to gateway " .. tostring(gatewayId)
    .. " as " .. tostring(subdomain) .. " ..."
)

local started, startError =
    server.run(cnet, gatewayId, subdomain, port, siteDirectory)

if not started then
    printError(tostring(startError))
end
