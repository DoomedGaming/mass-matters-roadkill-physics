local corePath = assert(arg[1], "core Lua path is required")
local expectedVersion = arg[2] or "42.20"
dofile(corePath)

local Core = assert(DoomedRoadkillPhysics)

assert(Core.TARGET_GAME_VERSION == expectedVersion)
assert(Core.isTargetGameVersion(expectedVersion))
if expectedVersion ~= "42.22" then
    assert(not Core.isTargetGameVersion(expectedVersion .. ".1"))
end
assert(not Core.isTargetGameVersion("1" .. expectedVersion))
assert(not Core.isTargetGameVersion(expectedVersion .. "-unstable"))
assert(not Core.isTargetGameVersion(nil))
if expectedVersion == "42.21" then
    assert(Core.isTargetGameVersion("42.21.0"))
    assert(not Core.isTargetGameVersion("42.20"))
    assert(not Core.isTargetGameVersion("42.22"))
elseif expectedVersion == "42.22" then
    for _, version in ipairs({
        "42.22.0", "42.22.1", "42.22.2", "42.22.3", "42.22.20",
        "42.22.999999", "42.22.0002", "42.22.12345678901234567890",
    }) do
        assert(Core.isTargetGameVersion(version), "numeric patch rejected: " .. version)
    end
    for _, version in ipairs({
        "42.20", "42.21", "42.21.0", "42.23", "43.0", "43.22",
        "142.22", "142.22.2", "42.220", "42.220.2", "42.22.",
        "42.22.2.0", "42.22.-1", "42.22.+1", "42.22.1e2",
        "42.22.2-unstable", " 42.22", "42.22 ", " 42.22.2", "42.22.2 ",
    }) do
        assert(not Core.isTargetGameVersion(version), "unexpected support for " .. version)
    end
else
    assert(not Core.isTargetGameVersion(expectedVersion .. ".0"))
end

local function assertNear(expected, actual, tolerance)
    tolerance = tolerance or 0.0001
    assert(actual ~= nil, "actual value is nil")
    assert(math.abs(expected - actual) <= tolerance,
        string.format("expected %.8f, got %.8f", expected, actual))
end

-- A 0.1 kg rat hit by a 1000 kg vehicle at 10 internal speed units.
local animalExcess = Core.animalImpulseExcess(1000, 0.1, 10, -1, true, 1)
local vanillaAnimal = 1000 * 7 * 10 / 15 + 1
local desiredAnimal = 0.1 * 12 * 10 / 15 + 0.1 / 100
assertNear(vanillaAnimal - desiredAnimal, animalExcess)

-- The upper multiplier bound still cannot exceed vanilla.
assertNear(0.0, Core.animalImpulseExcess(1000, 1000, 10, -1, true, 99))

-- A falldown contact has only the fixed vanilla 1.0 impulse to scale.
assertNear(0.999, Core.animalImpulseExcess(1000, 0.1, 10, -1, false, 1))

-- A standing 100 kg zombie at speed 5 has a vanilla scalar of 400.
assertNear(0.0, Core.zombieImpulseExcess(100, 5, -1, false, 1))
assertNear(200.0, Core.zombieImpulseExcess(100, 5, -1, false, 0.5))
assertNear(400.0, Core.zombieImpulseExcess(100, 5, -1, false, 0))

-- Prone pedestrian slowdown is one quarter of the standing value.
assertNear(50.0, Core.zombieImpulseExcess(100, 5, -1, true, 0.5))
assertNear(0.0, Core.zombieImpulseExcess(100, 5, 1, false, 0))
assertNear(0.0, Core.zombieImpulseExcess(100, 0, -1, false, 0))
assertNear(0.0, Core.zombieImpulseExcess(100, 0.049, -1, false, 0))
assertNear(4.0, Core.zombieImpulseExcess(100, 0.05, -1, false, 0))
assertNear(0.0, Core.zombieImpulseExcess(100, 5, -1, false, 99))

-- A normal 100 kg corpse under a 1000 kg vehicle uses corpseSize 0.1.
assertNear(0.1, Core.corpseSizeForVehicle(nil, 100, 1000, 1))
assertNear(0.2, Core.corpseSizeForVehicle(nil, 100, 1000, 2))
assertNear(0.0, Core.corpseSizeForVehicle(nil, 100, 1000, 0))

-- Existing content-authored values remain an upper bound.
assertNear(0.05, Core.corpseSizeForVehicle(0.05, 100, 1000, 1))
assertNear(0.0, Core.corpseSizeForVehicle(-1, 100, 1000, 1))

assert(Core.animalImpulseExcess(1000, 0, 10, -1, true, 1) == nil)
assert(Core.zombieImpulseExcess(0, 10, -1, false, 0) == nil)
assert(Core.corpseSizeForVehicle(nil, 100, 0, 1) == nil)

print("Pure Lua mass formula tests passed.")
