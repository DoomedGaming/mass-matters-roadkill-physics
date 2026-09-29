local serverPath = assert(arg[1], "server Lua path is required")
local sharedDirectory = assert(arg[2], "shared Lua directory is required")
local runtimeVersion = arg[3] or "42.20"
package.path = sharedDirectory .. "/?.lua;" .. package.path

local started = nil
Events = {
    OnServerStarted = {
        Add = function(callback) started = callback end,
    },
}
function getCore()
    return { getVersionNumber = function() return runtimeVersion end }
end

dofile(serverPath)
assert(started)
local originalPrint = print
local messages = {}
function print(message)
    messages[#messages + 1] = tostring(message)
end
started()
print = originalPrint
assert(#messages == 1, "server startup must emit one diagnostic")
assert(messages[1]:find(runtimeVersion, 1, true))
if DoomedRoadkillPhysics.isTargetGameVersion(runtimeVersion) then
    assert(messages[1]:find("loaded on server", 1, true))
    assert(not messages[1]:find("WARNING:", 1, true))
else
    assert(messages[1]:find("WARNING:", 1, true))
    assert(not messages[1]:find("loaded on server", 1, true))
end
print(messages[1])
print("Pure Lua server runtime test passed.")
