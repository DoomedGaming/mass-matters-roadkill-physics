local clientPath = assert(arg[1], "client Lua path is required")
local serverPath = assert(arg[2], "server Lua path is required")
local sharedDirectory = assert(arg[3], "shared Lua directory is required")
local targetVersion = arg[4] or "42.21"
package.path = sharedDirectory .. "/?.lua;" .. package.path

local originalPrint = print
local unsupportedVersions = assert(({
    ["42.21"] = {
        "42.20", "42.20.0", "42.20.4", "42.21.1", "42.21.10",
        "42.22", "42.22.2", "43.0", "142.21", "42.210", "42.21-unstable",
    },
    ["42.22"] = {
        "42.20", "42.20.0", "42.21", "42.21.0", "42.21.1",
        "42.22.0", "42.22.1", "42.22.3", "42.22.20", "42.22.2.0",
        "42.23", "43.0", "142.22.2", "42.220.2", "42.22.2-unstable", "",
    },
})[targetVersion], "No negative-runtime matrix for " .. targetVersion)

for _, runtimeVersion in ipairs(unsupportedVersions) do
    package.loaded.DoomedRoadkillPhysics_Core = nil
    DoomedRoadkillPhysics = nil
    local messages = {}
    function print(message)
        messages[#messages + 1] = tostring(message)
    end
    function getCore()
        return { getVersionNumber = function() return runtimeVersion end }
    end

    -- An unsupported build may lack these APIs entirely. The version gate
    -- must run before allocating vectors, reading world state, or adding hooks.
    Vector2 = nil
    Vector3f = nil
    SandboxVars = nil
    getCell = nil
    local registered = {}
    local function event(name)
        return {
            Add = function(callback)
                registered[name] = callback
            end,
        }
    end
    Events = {
        OnTickEvenPaused = event("OnTickEvenPaused"),
        OnTick = event("OnTick"),
        OnCharacterDeath = event("OnCharacterDeath"),
        OnGameStart = event("OnGameStart"),
        OnServerStarted = event("OnServerStarted"),
    }

    local ok, err = pcall(dofile, clientPath)
    assert(ok, "unsupported client must return safely: " .. tostring(err))
    assert(next(registered) == nil,
        "unsupported client registered an event on " .. runtimeVersion)
    assert(#messages == 1, "unsupported client must emit one version warning")
    assert(messages[1]:find("WARNING:", 1, true))
    assert(messages[1]:find(targetVersion, 1, true))
    assert(messages[1]:find(runtimeVersion, 1, true))
    assert(messages[1]:find("corrections disabled", 1, true))

    messages = {}
    dofile(serverPath)
    assert(registered.OnServerStarted, "server must register its diagnostic")
    registered.OnServerStarted()
    assert(#messages == 1, "unsupported server must emit one version warning")
    assert(messages[1]:find("WARNING:", 1, true))
    assert(messages[1]:find(runtimeVersion, 1, true))
    assert(messages[1]:find("client corrections are disabled", 1, true))
    assert(not messages[1]:find("loaded on server", 1, true),
        "unsupported server must not claim support")
end

print = originalPrint
print("Unsupported-version client safety and server diagnostics tests passed for "
    .. targetVersion .. " (" .. #unsupportedVersions .. " rejected runtimes).")
