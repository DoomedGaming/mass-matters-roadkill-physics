local clientPath = assert(arg[1], "client Lua path is required")
local sharedDirectory = assert(arg[2], "shared Lua directory is required")
package.path = sharedDirectory .. "/?.lua;" .. package.path

local handlers = {}
local function event(name)
    return {
        Add = function(callback)
            handlers[name] = callback
        end,
    }
end

Events = {
    OnTickEvenPaused = event("OnTickEvenPaused"),
    OnTick = event("OnTick"),
    OnCharacterDeath = event("OnCharacterDeath"),
    OnGameStart = event("OnGameStart"),
}

SandboxVars = {
    DoomedRoadkillPhysics = {
        AnimalImpulseMultiplier = 1.0,
        ZombieImpulseMultiplier = 0.5,
        CorpseImpulseMultiplier = 1.0,
    },
}

local clientMode = true
function isClient()
    return clientMode
end

local function vector2()
    return {}
end

local function vector3()
    local value = { _x = 0, _y = 0, _z = 0 }
    function value:x() return self._x end
    function value:y() return self._y end
    function value:z() return self._z end
    return value
end

Vector2 = { new = vector2 }
Vector3f = { new = vector3 }

function instanceof(value, className)
    return value and value.__class == className
end

function getCore()
    return { getVersionNumber = function() return "42.20" end }
end

local function list(values)
    return {
        size = function() return #values end,
        get = function(_, index) return values[index + 1] end,
    }
end

-- IsoCell:getVehicles() returns java.util.Set in Build 42.20.  Deliberately do
-- not provide get(index), so the mock catches accidental List-style access.
local function javaSet(values)
    return {
        size = function() return #values end,
        iterator = function()
            local index = 0
            return {
                hasNext = function() return index < #values end,
                next = function()
                    index = index + 1
                    return values[index]
                end,
            }
        end,
    }
end

local function targetBase(className)
    local target = {
        __class = className,
        alive = true,
        vehicleCollision = false,
        colliding = false,
        proneColliding = false,
        x = 0.6,
        y = 0.8,
        z = 0,
    }
    function target:isAlive() return self.alive end
    function target:isVehicleCollision() return self.vehicleCollision end
    function target:getHitDir() return self.hitDir end
    function target:getX() return self.x end
    function target:getY() return self.y end
    function target:getZ() return self.z end
    return target
end

local function newAnimal(weight)
    local animal = targetBase("IsoAnimal")
    animal.weight = weight or 0.5
    animal.roadKill = false
    animal.stateName = "AnimalIdleState"
    function animal:isRoadKill() return self.roadKill end
    function animal:getCurrentStateName() return self.stateName end
    function animal:getData()
        local currentWeight = self.weight
        return { getWeight = function() return currentWeight end }
    end
    return animal
end

local function newZombie(prone)
    local zombie = targetBase("IsoZombie")
    zombie.mass = 100
    zombie.prone = prone or false
    zombie.canBeHit = true
    zombie.canSlow = true
    function zombie:getMass() return self.mass end
    function zombie:isProne() return self.prone end
    function zombie:canBeHitByVehicle() return self.canBeHit end
    function zombie:canSlowDownVehicleWhenHit() return self.canSlow end
    return zombie
end

local corpseData = {}
local corpse = { __class = "IsoDeadBody" }
function corpse:getWeight() return 0 end
function corpse:isAnimal() return false end
function corpse:getModData() return corpseData end

local currentAnimals = {}
local currentZombies = {}
local recordedImpulses = {}
local recordedCorpseSizes = {}
local persistent = setmetatable({}, { __mode = "k" })
local vehicle = {
    x = 0,
    y = 0,
    z = 0,
    collideObjects = true,
    localPhysics = true,
    velocityX = 3,
    velocityZ = 4,
}
function vehicle:isLocalPhysicSim() return self.localPhysics end
function vehicle:getScript()
    return {
        getExtents = function()
            return { x = function() return 2 end, z = function() return 4 end }
        end,
    }
end
function vehicle:getFudgedMass() return 1000 end
function vehicle:shouldCollideWithCharacters() return true end
function vehicle:isPersistentContact(target) return persistent[target] == true end
function vehicle:testCollisionWithCharacter(target) return target.colliding and {} or nil end
function vehicle:testCollisionWithProneCharacter(target)
    error("client mod must not call side-effectful prone collision test")
end
function vehicle:isEngineRunning() return true end
function vehicle:getDriverRegardlessOfTow() return {} end
function vehicle:getLinearVelocity(out)
    out._x, out._y, out._z = self.velocityX, 0, self.velocityZ
    return out
end
function vehicle:applyImpulseFromHitObject(target, scalar)
    recordedImpulses[#recordedImpulses + 1] = {
        vehicle = self,
        target = target,
        scalar = scalar,
        method = "object",
    }
end
function vehicle:applyImpulseGeneric(fromX, fromY, fromZ, dirX, dirY, dirZ,
        scalar)
    recordedImpulses[#recordedImpulses + 1] = {
        vehicle = self,
        target = currentZombies[1],
        scalar = scalar,
        method = "generic",
        fromX = fromX,
        fromY = fromY,
        fromZ = fromZ,
        dirX = dirX,
        dirY = dirY,
        dirZ = dirZ,
    }
end
function vehicle:testCollisionWithCorpse(body, playSound)
    assert(body == corpse)
    assert(playSound == false)
    recordedCorpseSizes[#recordedCorpseSizes + 1] = corpseData.corpseSize
    return 1
end
function vehicle:getCurrentAbsoluteSpeedKmHour() return 30 end
function vehicle:shouldCollideWithObjects() return self.collideObjects end
function vehicle:getX() return self.x end
function vehicle:getY() return self.y end
function vehicle:getZ() return self.z end

local empty = list({})
local centerSquare = { getStaticMovingObjects = function() return list({ corpse }) end }
local vehicles = javaSet({ vehicle })
assert(vehicles.get == nil, "vehicle Set mock must not expose indexed access")
local cell = {}
function cell:getVehicles() return vehicles end
function cell:getAnimals() return list(currentAnimals) end
function cell:getZombieList() return list(currentZombies) end
function cell:getGridSquare(x, y, z)
    if x == 0 and y == 0 and z == 0 then
        return centerSquare
    end
    return { getStaticMovingObjects = function() return empty end }
end

function getCell() return cell end

local function assertNear(expected, actual, tolerance)
    tolerance = tolerance or 0.0001
    assert(actual ~= nil, "actual value is nil")
    assert(math.abs(expected - actual) <= tolerance,
        string.format("expected %.8f, got %.8f", expected, actual))
end

local tick = 0
local function preTick()
    tick = tick + 1
    handlers.OnTickEvenPaused(tick)
end
local function postTick()
    handlers.OnTick(tick)
end
local function impulsesFor(target)
    local result = {}
    for _, impulse in ipairs(recordedImpulses) do
        if impulse.target == target then
            result[#result + 1] = impulse.scalar
        end
    end
    return result
end
local function impulseRecordsFor(target)
    local result = {}
    for _, impulse in ipairs(recordedImpulses) do
        if impulse.target == target then
            result[#result + 1] = impulse
        end
    end
    return result
end

dofile(clientPath)
assert(handlers.OnTickEvenPaused)
assert(handlers.OnTick)
assert(handlers.OnCharacterDeath)
assert(handlers.OnGameStart)

-- A false -> true persistent-contact edge proves the full animal hit even if
-- the post-hit geometry no longer overlaps.
local rat = newAnimal(0.5)
rat.hitDir = {
    getX = function() return 0.6 end,
    getY = function() return 0.8 end,
}
currentAnimals = { rat }
preTick()
rat.roadKill = true
rat.vehicleCollision = true
persistent[rat] = true
rat.colliding = false
postTick()
local ratImpulses = impulsesFor(rat)
assert(#ratImpulses == 1)
local vanilla = 1000 * 7 * 5 / 15 + 1
local desired = 0.5 * 12 * 5 / 15 + 0.5 / 100
assertNear(-(vanilla - desired), ratImpulses[1])
assertNear(0.1, recordedCorpseSizes[1])
assert(corpseData.corpseSize == nil, "temporary corpseSize was not restored")

-- On a multiplayer client, the engine leaves vehicleCollision false for an
-- animal hit.  Until the server's falldown state arrives, sustained overlap
-- can queue the full main + fixed reaction again; the pre/post bracket catches
-- it without relying on that flag.
rat.colliding = true
rat.vehicleCollision = false
preTick()
postTick()
ratImpulses = impulsesFor(rat)
assert(#ratImpulses == 2)
assertNear(-(vanilla - desired), ratImpulses[2])

-- Once falldown was already active before the collision update, hitAnimal's
-- main impulse is skipped and only the unconditional fixed +1 is corrected.
rat.stateName = "AnimalFalldownState"
preTick()
postTick()
ratImpulses = impulsesFor(rat)
assert(#ratImpulses == 3)
assertNear(-(1 - 0.5 / 100), ratImpulses[3])

-- No collision means no continuation correction.
rat.colliding = false
rat.vehicleCollision = false
preTick()
postTick()
assert(#impulsesFor(rat) == 3)

-- Once the engine's persistent-contact window expires, a new edge can safely
-- identify and correct another full impact by the same vehicle.
persistent[rat] = false
rat.stateName = "AnimalIdleState"
preTick()
persistent[rat] = true
rat.vehicleCollision = true
postTick()
assert(#impulsesFor(rat) == 4)
assertNear(-(vanilla - desired), impulsesFor(rat)[4])

-- A newly observed animal that collides during the world update still gets a
-- full correction through the collision/contact fallback.
currentAnimals = {}
preTick()
local spawnedRat = newAnimal(0.5)
spawnedRat.roadKill = true
spawnedRat.vehicleCollision = false
spawnedRat.colliding = true
persistent[spawnedRat] = true
currentAnimals = { spawnedRat }
postTick()
assert(#impulsesFor(spawnedRat) == 1)
assertNear(-(vanilla - desired), impulsesFor(spawnedRat)[1])

-- A synchronous animal death and the later OnTick share one frame guard.
local killedRat = newAnimal(0.5)
currentAnimals = { killedRat }
clientMode = false
preTick()
killedRat.roadKill = true
killedRat.vehicleCollision = true
killedRat.colliding = true
handlers.OnCharacterDeath(killedRat)
persistent[killedRat] = true
currentAnimals = {}
postTick()
assert(#impulsesFor(killedRat) == 1)
clientMode = true

-- The completed OnTick invalidates its death fallback.  An asynchronous later
-- callback cannot append a negative impulse to a stale vehicle queue.
handlers.OnCharacterDeath(killedRat)
assert(#impulsesFor(killedRat) == 1)

-- A fresh later snapshot of an already-roadkill animal is not a current hit
-- baseline, even if it happens to die while overlapping the vehicle.
local delayedDeathRat = newAnimal(0.5)
delayedDeathRat.roadKill = true
delayedDeathRat.colliding = true
currentAnimals = { delayedDeathRat }
clientMode = false
preTick()
handlers.OnCharacterDeath(delayedDeathRat)
assert(#impulsesFor(delayedDeathRat) == 0)
postTick()
clientMode = true

-- If vehicle B forms the exact new edge while vehicle A has an older
-- persistent overlap, correct only B.  Pair-level deduplication would let A
-- become a false "sole" continuation candidate later in the same OnTick.
local persistentB = setmetatable({}, { __mode = "k" })
local vehicleB = setmetatable({
    x = -1,
    y = 0,
    z = 0,
    collideObjects = true,
    localPhysics = true,
    velocityX = 3,
    velocityZ = 4,
}, { __index = vehicle })
function vehicleB:isPersistentContact(target)
    return persistentB[target] == true
end
local twoVehicleRat = newAnimal(0.5)
twoVehicleRat.colliding = true
persistent[twoVehicleRat] = true
persistentB[twoVehicleRat] = false
vehicles = javaSet({ vehicle, vehicleB })
currentAnimals = { twoVehicleRat }
preTick()
persistentB[twoVehicleRat] = true
postTick()
local twoVehicleImpulses = impulsesFor(twoVehicleRat)
assert(#twoVehicleImpulses == 1)
for _, impulse in ipairs(recordedImpulses) do
    if impulse.target == twoVehicleRat then
        assert(impulse.vehicle == vehicleB)
    end
end
vehicles = javaSet({ vehicle })

-- Standing live-zombie slowdown: mass 100, speed 5, factor .8 gives vanilla
-- scalar 400.  Multiplier .5 removes exactly 200 without touching damage.
local zombie = newZombie(false)
zombie.hitDir = rat.hitDir
currentZombies = { zombie }
preTick()
zombie.vehicleCollision = true
persistent[zombie] = true
zombie.colliding = false
-- The zombie may slide before OnTick.  The correction must retain hitDir and
-- must not derive its vector or contact offset from this later position.
zombie.x, zombie.y = -0.8, 0.6
postTick()
assert(#impulsesFor(zombie) == 1)
assertNear(200, impulsesFor(zombie)[1])
local firstZombieCorrection = impulseRecordsFor(zombie)[1]
assert(firstZombieCorrection.method == "generic")
assertNear(vehicle:getX(), firstZombieCorrection.fromX)
assertNear(vehicle:getY(), firstZombieCorrection.fromY)
assertNear(vehicle:getZ(), firstZombieCorrection.fromZ)
assertNear(0.6, firstZombieCorrection.dirX)
assertNear(0.8, firstZombieCorrection.dirY)
assertNear(0.0, firstZombieCorrection.dirZ)

-- A continued standing hit remains tunable even when the hit slides the
-- zombie out of the post-update geometry test.
zombie.colliding = true
preTick()
zombie.colliding = false
postTick()
assert(#impulsesFor(zombie) == 2)
assertNear(200, impulsesFor(zombie)[2])

zombie.colliding = false
zombie.vehicleCollision = false
preTick()
postTick()
assert(#impulsesFor(zombie) == 2)

-- Build 42.20 multiplayer does not reliably retain vehicleCollision after a
-- successful hit.  Persistent standing overlap on both sides of the bracket
-- is the conservative continuation signal, matching the live-animal path.
local inferredZombie = newZombie(false)
inferredZombie.colliding = true
persistent[inferredZombie] = true
currentZombies = { inferredZombie }
preTick()
inferredZombie.vehicleCollision = false
postTick()
assert(#impulsesFor(inferredZombie) == 1)
assertNear(200, impulsesFor(inferredZombie)[1])
local fallbackZombieCorrection = impulseRecordsFor(inferredZombie)[1]
assert(fallbackZombieCorrection.method == "generic")
assertNear(0.6, fallbackZombieCorrection.dirX)
assertNear(0.8, fallbackZombieCorrection.dirY)

-- Without post-update overlap, an old persistent pair is not enough to queue
-- a negative correction by itself.
local separatedZombie = newZombie(false)
separatedZombie.colliding = true
persistent[separatedZombie] = true
currentZombies = { separatedZombie }
preTick()
separatedZombie.colliding = false
separatedZombie.vehicleCollision = false
postTick()
assert(#impulsesFor(separatedZombie) == 0)

-- Single-player keeps the stronger engine-reported requirement.
clientMode = false
local localInferredZombie = newZombie(false)
localInferredZombie.colliding = true
persistent[localInferredZombie] = true
currentZombies = { localInferredZombie }
preTick()
localInferredZombie.vehicleCollision = false
postTick()
assert(#impulsesFor(localInferredZombie) == 0)
clientMode = true

-- Live sandbox changes are read on every pre-tick.  A mid-session value of
-- zero cancels the complete standing pedestrian slowdown without a reload.
SandboxVars.DoomedRoadkillPhysics.ZombieImpulseMultiplier = 0.0
local zeroZombie = newZombie(false)
currentZombies = { zeroZombie }
preTick()
zeroZombie.vehicleCollision = true
persistent[zeroZombie] = true
postTick()
assert(#impulsesFor(zeroZombie) == 1)
assertNear(400, impulsesFor(zeroZombie)[1])
SandboxVars.DoomedRoadkillPhysics.ZombieImpulseMultiplier = 0.5

-- Snapshot the pre-hit prone stance: its vanilla scalar is 100, so half is 50.
local proneZombie = newZombie(true)
currentZombies = { proneZombie }
preTick()
proneZombie.vehicleCollision = true
persistent[proneZombie] = true
postTick()
assertNear(50, impulsesFor(proneZombie)[1])

-- Continued prone overlap uses the engine's collision result and the unique
-- snapshotted local vehicle.  The mod never calls the side-effectful prone
-- wheel test, but it still tunes the horizontal pedestrian impulse each tick.
preTick()
proneZombie.vehicleCollision = true
postTick()
assert(#impulsesFor(proneZombie) == 2)
assertNear(50, impulsesFor(proneZombie)[2])

-- The outer collision flag can be true even when hitCharacter's per-axis
-- position guard skipped the vanilla pedestrian impulse.  Never compensate in
-- that case, because doing so would accelerate the vehicle.
local alignedZombie = newZombie(false)
alignedZombie.x = 0
alignedZombie.colliding = true
persistent[alignedZombie] = true
currentZombies = { alignedZombie }
preTick()
alignedZombie.vehicleCollision = true
postTick()
assert(#impulsesFor(alignedZombie) == 0)

-- Require the axis guard on both sides of the update bracket.  If movement
-- ends exactly aligned after a pre-eligible snapshot, the safe result is to
-- leave vanilla untouched rather than risk a standalone negative impulse.
local crossingZombie = newZombie(false)
crossingZombie.colliding = true
persistent[crossingZombie] = true
currentZombies = { crossingZombie }
preTick()
crossingZombie.x = 0
crossingZombie.vehicleCollision = true
postTick()
assert(#impulsesFor(crossingZombie) == 0)

-- A later/asynchronous death cannot turn a stale continuation flag into a
-- standalone correction.  Exact new-contact edges are handled separately.
local dyingZombie = newZombie(false)
dyingZombie.colliding = true
persistent[dyingZombie] = true
currentZombies = { dyingZombie }
preTick()
dyingZombie.alive = false
dyingZombie.vehicleCollision = true
postTick()
assert(#impulsesFor(dyingZombie) == 0)

-- The same safety rule applies below hitCharacter's 0.05 m/s speed threshold.
local slowZombie = newZombie(false)
slowZombie.colliding = true
persistent[slowZombie] = true
currentZombies = { slowZombie }
vehicle.velocityX, vehicle.velocityZ = 0.03, 0
preTick()
slowZombie.vehicleCollision = true
postTick()
assert(#impulsesFor(slowZombie) == 0)
vehicle.velocityX, vehicle.velocityZ = 3, 4

-- State-ineligible zombies are never given a compensating vehicle impulse.
local ineligibleZombie = newZombie(false)
ineligibleZombie.canSlow = false
currentZombies = { ineligibleZombie }
preTick()
ineligibleZombie.vehicleCollision = true
persistent[ineligibleZombie] = true
postTick()
assert(#impulsesFor(ineligibleZombie) == 0)

-- Default 1.0 preserves vanilla and avoids all per-zombie correction work.
SandboxVars.DoomedRoadkillPhysics.ZombieImpulseMultiplier = 1.0
local vanillaZombie = newZombie(false)
currentZombies = { vanillaZombie }
preTick()
vanillaZombie.vehicleCollision = true
persistent[vanillaZombie] = true
postTick()
assert(#impulsesFor(vanillaZombie) == 0)

-- A remote/non-authoritative vehicle cannot receive any correction.
vehicle.localPhysics = false
local remoteRat = newAnimal(0.5)
currentAnimals = { remoteRat }
preTick()
remoteRat.vehicleCollision = true
remoteRat.colliding = true
persistent[remoteRat] = true
postTick()
assert(#impulsesFor(remoteRat) == 0)
vehicle.localPhysics = true

-- Outside a multiplayer client, continued animal fallback requires the
-- engine's own vehicleCollision result instead of the MP overlap inference.
clientMode = false
local localRat = newAnimal(0.5)
localRat.colliding = true
persistent[localRat] = true
currentAnimals = { localRat }
preTick()
localRat.vehicleCollision = false
postTick()
assert(#impulsesFor(localRat) == 0)
preTick()
localRat.vehicleCollision = true
postTick()
assert(#impulsesFor(localRat) == 1)
assertNear(-(vanilla - desired), impulsesFor(localRat)[1])
clientMode = true

-- Match vanilla's object-collision gate for corpse replacement.
local corpseCalls = #recordedCorpseSizes
vehicle.collideObjects = false
currentAnimals = {}
currentZombies = {}
preTick()
postTick()
assert(#recordedCorpseSizes == corpseCalls)

handlers.OnGameStart()
print("Pure Lua client runtime test passed.")
