-- CraftNet Illuminations bootstrap. Place this on a CC:Tweaked
-- computer as /bootstrap.lua and run it (see README.md for the
-- one-liner). Pulls Lamp or Lantern straight from GitHub and installs
-- it to /lamp or /lantern, replacing any previous install atomically.
--
-- Assumes CraftNet's Host role is already installed and running on
-- this computer (see https://github.com/AlecBrooks/craftnet) -- this
-- bootstrap never touches /startup.lua or anything under /craftnet.
-- Install, then run the printed command yourself, same as any other
-- program on the shell path.

local OWNER = "AlecBrooks"
local REPOSITORY = "craftnet-illuminations"
local BRANCH = "main"

local TREE_URL =
    "https://api.github.com/repos/"
    .. OWNER .. "/" .. REPOSITORY
    .. "/git/trees/" .. BRANCH
    .. "?recursive=1"

local RAW_BASE_URL =
    "https://raw.githubusercontent.com/"
    .. OWNER .. "/" .. REPOSITORY
    .. "/" .. BRANCH .. "/"

local API_HEADERS = {
    ["Accept"] = "application/vnd.github+json",
    ["User-Agent"] = "CraftNet-Illuminations-Bootstrap",
    ["X-GitHub-Api-Version"] = "2022-11-28",
}

-- No hardcoded file lists here on purpose -- see craftnet's own
-- bootstrap.lua notes on why a whitelist that has to be kept in sync
-- by hand is a bug waiting to happen. Everything under
-- sourceDirectory/ in the repo is installed, whatever it is.
local PROGRAMS = {
    lamp = {
        label = "Lamp",
        sourceDirectory = "lamp",
        installDirectory = "/lamp",
        entryPoint = "lamp.lua",
        usage = "lamp [port] [siteDirectory]",
    },

    lantern = {
        label = "Lantern",
        sourceDirectory = "lantern",
        installDirectory = "/lantern",
        entryPoint = "lantern.lua",
        usage = "lantern [startAddress]",
    },
}

local arguments = { ... }


local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end


local function normalizeProgram(value)
    value = string.lower(trim(value))

    if value == "1" or value == "lamp" then
        return "lamp"
    end

    if value == "2" or value == "lantern" then
        return "lantern"
    end

    return nil
end


local function chooseProgram()
    print("CraftNet Illuminations installer")
    print("")
    print("1. Lamp")
    print("   Web server -- serves .lcm files by path.")
    print("")
    print("2. Lantern")
    print("   Browser -- fetches and renders .lcm pages.")
    print("")

    while true do
        term.write("Install lamp or lantern? ")

        local choice = normalizeProgram(read())

        if choice then
            return choice
        end

        printError("Enter 1, 2, lamp, or lantern.")
    end
end


local function resolveProgram()
    return normalizeProgram(arguments[1]) or chooseProgram()
end


local function ensureParentDirectory(path)
    local parent = fs.getDir(path)

    if parent ~= "" and not fs.exists(parent) then
        fs.makeDir(parent)
    end
end


local function deleteIfExists(path)
    if fs.exists(path) then
        fs.delete(path)
    end
end


local function encodeRepositoryPath(path)
    local encodedSegments = {}

    for segment in path:gmatch("[^/]+") do
        encodedSegments[#encodedSegments + 1] =
            textutils.urlEncode(segment)
    end

    return table.concat(encodedSegments, "/")
end


local function readFailedResponse(requestError, errorResponse)
    local message = tostring(requestError or "Unknown HTTP error")

    if errorResponse then
        local responseCode = errorResponse.getResponseCode()
        errorResponse.close()

        message = "HTTP " .. tostring(responseCode) .. ": " .. message
    end

    return message
end


local function download(url, headers, binary)
    local response, requestError, errorResponse =
        http.get({
            url = url,
            headers = headers or {},
            binary = binary == true,
            redirect = true,
            timeout = 20,
        })

    if not response then
        return nil, readFailedResponse(requestError, errorResponse)
    end

    local contents = response.readAll()
    response.close()

    return contents
end


-- Every blob in the repo tree under "<sourceDirectory>/", relative to
-- that directory. No whitelist -- whatever's actually in the repo.
local function getRepositoryFiles(program)
    print("Reading the repository file list...")

    local manifestSource, downloadError = download(TREE_URL, API_HEADERS, false)

    if not manifestSource then
        return nil, "Could not read repository tree: " .. tostring(downloadError)
    end

    local decodeSucceeded, manifest =
        pcall(textutils.unserializeJSON, manifestSource)

    if not decodeSucceeded
        or type(manifest) ~= "table"
        or type(manifest.tree) ~= "table"
    then
        return nil, "GitHub returned an invalid repository tree."
    end

    if manifest.truncated == true then
        return nil, "GitHub truncated the repository tree."
    end

    local files = {}
    local found = {}
    local sourcePrefix = program.sourceDirectory .. "/"

    for _, entry in ipairs(manifest.tree) do
        if entry.type == "blob"
            and type(entry.path) == "string"
            and entry.path:sub(1, #sourcePrefix) == sourcePrefix
        then
            local relativePath = entry.path:sub(#sourcePrefix + 1)

            if relativePath ~= "" and relativePath ~= "README.md" then
                files[#files + 1] = {
                    repositoryPath = entry.path,
                    relativePath = relativePath,
                }

                found[relativePath] = true
            end
        end
    end

    if #files == 0 then
        return nil, "No files were found for " .. program.label .. "."
    end

    if not found[program.entryPoint] then
        return nil,
            "The repository does not contain "
            .. sourcePrefix .. program.entryPoint .. "."
    end

    table.sort(files, function(left, right)
        return left.repositoryPath < right.repositoryPath
    end)

    return files
end


local function writeDownloadedFile(stagingDirectory, relativePath, contents)
    local destination = fs.combine(stagingDirectory, relativePath)

    ensureParentDirectory(destination)

    local file = fs.open(destination, "wb")

    if not file then
        return false, "Could not write " .. destination
    end

    file.write(contents)
    file.close()

    return true
end


local function downloadFiles(files, stagingDirectory)
    deleteIfExists(stagingDirectory)
    fs.makeDir(stagingDirectory)

    for index, fileInfo in ipairs(files) do
        print(
            "["
                .. tostring(index) .. "/" .. tostring(#files)
                .. "] " .. fileInfo.relativePath
        )

        local url = RAW_BASE_URL .. encodeRepositoryPath(fileInfo.repositoryPath)
        local contents, downloadError = download(url, nil, true)

        if not contents then
            deleteIfExists(stagingDirectory)

            return false,
                "Could not download " .. fileInfo.repositoryPath
                .. ": " .. tostring(downloadError)
        end

        local written, writeError =
            writeDownloadedFile(stagingDirectory, fileInfo.relativePath, contents)

        if not written then
            deleteIfExists(stagingDirectory)
            return false, writeError
        end
    end

    return true
end


-- Atomic swap: move the current install aside, move staging into
-- place, delete the old one -- with a rollback if the swap itself
-- fails partway through.
local function installFiles(stagingDirectory, installDirectory)
    local backupDirectory = installDirectory .. "-backup"

    deleteIfExists(backupDirectory)

    local hadExistingInstall = fs.exists(installDirectory)

    if hadExistingInstall then
        local moved, moveError =
            pcall(fs.move, installDirectory, backupDirectory)

        if not moved then
            return false, "Could not preserve current install: " .. tostring(moveError)
        end
    end

    local moved, moveError =
        pcall(fs.move, stagingDirectory, installDirectory)

    if not moved then
        if hadExistingInstall
            and fs.exists(backupDirectory)
            and not fs.exists(installDirectory)
        then
            pcall(fs.move, backupDirectory, installDirectory)
        end

        return false, "Could not activate update: " .. tostring(moveError)
    end

    deleteIfExists(backupDirectory)

    return true
end


local key = resolveProgram()
local program = PROGRAMS[key]
local stagingDirectory = program.installDirectory .. "-update"

print("")
print("Installing " .. program.label .. " from GitHub...")

local files, filesError = getRepositoryFiles(program)

if not files then
    printError(filesError)
    return
end

local downloaded, downloadError = downloadFiles(files, stagingDirectory)

if not downloaded then
    printError(downloadError)
    return
end

local installed, installError = installFiles(stagingDirectory, program.installDirectory)

if not installed then
    deleteIfExists(stagingDirectory)
    printError(installError)
    return
end

print("")
print(tostring(#files) .. " files installed to " .. program.installDirectory .. ".")
print("")
print("Make sure this computer is connected first (\"cnet connect")
print("<gatewayId> <subdomain>\" -- once, it's remembered after that).")
print("")
print("Then run it with:")
print("  " .. program.usage)
