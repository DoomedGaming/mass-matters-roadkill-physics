local serverPath = assert(arg[1], "server Lua path is required")
local sharedDirectory = assert(arg[2], "shared Lua directory is required")
package.path = sharedDirectory .. "/?.lua;" .. package.path

local started = nil
Events = {
    OnServerStarted = {
        Add = function(callback) started = callback end,
    },
}
function getCore()
    return { getVersionNumber = function() return "42.20" end }
end

dofile(serverPath)
assert(started)
started()
print("Pure Lua server runtime test passed.")
