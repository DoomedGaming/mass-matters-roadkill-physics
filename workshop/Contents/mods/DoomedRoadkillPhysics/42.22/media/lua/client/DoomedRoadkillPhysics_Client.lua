require "DoomedRoadkillPhysics_Core"

local Core = DoomedRoadkillPhysics
local gameVersion = tostring(getCore():getVersionNumber())
if not Core.isTargetGameVersion(gameVersion) then
    print("[" .. Core.MOD_ID .. "] WARNING: collision correction profile "
        .. Core.TARGET_GAME_VERSION .. " does not support Project Zomboid "
        .. gameVersion .. "; corrections disabled.")
    return
end

local collisionProbe = Vector2.new()
local linearVelocity = Vector3f.new()
local frameSnapshot = nil
local warnedRuntimeError = false
local zombieStateMethodsAvailable = nil
local lastZombieMultiplier = nil
local loggedZombieCorrection = false

local function option(name, fallback)
    local page = SandboxVars and SandboxVars[Core.MOD_ID]
    local value = page and tonumber(page[name]) or fallback
    return value or fallback
end

local function warnOnce(message)
    if warnedRuntimeError then
        return
    end
    warnedRuntimeError = true
    print("[" .. Core.MOD_ID .. "] WARNING: " .. tostring(message))
end

local function locallySimulated(vehicle)
    return vehicle
        and vehicle:isLocalPhysicSim()
        and vehicle:getScript()
        and vehicle:getFudgedMass() > 0
end

local function localVehicles(cell)
    local result = {}
    local info = {}
    local vehicles = cell and cell:getVehicles() or nil
    if vehicles then
        local iterator = vehicles:iterator()
        while iterator:hasNext() do
            local vehicle = iterator:next()
            if locallySimulated(vehicle) then
                result[#result + 1] = vehicle
                local extents = vehicle:getScript():getExtents()
                info[vehicle] = {
                    x = vehicle:getX(),
                    y = vehicle:getY(),
                    z = vehicle:getZ(),
                    radius = math.max(extents:x(), extents:z()) / 2.0 + 4.0,
                }
            end
        end
    end
    return result, info
end

local function nearVehicle(vehicle, target, info)
    info = info or {
        x = vehicle:getX(),
        y = vehicle:getY(),
        z = vehicle:getZ(),
        radius = 4.0,
    }
    if math.abs(info.z - target:getZ()) >= 1.0 then
        return false
    end
    local dx = info.x - target:getX()
    local dy = info.y - target:getY()
    return dx * dx + dy * dy <= info.radius * info.radius
end

local function standingCollision(vehicle, target)
    return vehicle:shouldCollideWithCharacters()
        and math.abs(vehicle:getZ() - target:getZ()) < 0.5
        and vehicle:testCollisionWithCharacter(target, 0.3, collisionProbe) ~= nil
end

local function hitPositionEligible(vehicle, target)
    return math.abs(target:getX() - vehicle:getX()) >= 0.01
        and math.abs(target:getY() - vehicle:getY()) >= 0.01
end

local function animalWeight(animal)
    local data = animal and animal:getData() or nil
    local weight = data and tonumber(data:getWeight()) or nil
    if Core.isFinitePositive(weight) then
        return weight
    end
    return nil
end

local function correctedThisFrame(snapshot, vehicle, target)
    local byTarget = snapshot.corrected[vehicle]
    return byTarget and byTarget[target] or false
end

local function targetCorrectedThisFrame(snapshot, target)
    return snapshot.correctedTargets[target] == true
end

local function markCorrectedThisFrame(snapshot, vehicle, target)
    local byTarget = snapshot.corrected[vehicle]
    if not byTarget then
        byTarget = {}
        snapshot.corrected[vehicle] = byTarget
    end
    byTarget[target] = true
    snapshot.correctedTargets[target] = true
end

local function impactKinematics(vehicle, target)
    vehicle:getLinearVelocity(linearVelocity)
    local velocityX = linearVelocity:x()
    local velocityY = linearVelocity:z()
    local planarSpeed = math.sqrt(velocityX * velocityX + velocityY * velocityY)
    if planarSpeed <= 0.0 then
        return planarSpeed, 0.0, nil, nil
    end

    -- Vehicle hits set target.hitDir from the collision geometry.  Prefer it
    -- because the target can slide before OnTick; position is a safe fallback.
    local hitDir = target:getHitDir()
    local hitDirX = hitDir and tonumber(hitDir:getX()) or nil
    local hitDirY = hitDir and tonumber(hitDir:getY()) or nil
    local hitDirLength = hitDirX and hitDirY
        and math.sqrt(hitDirX * hitDirX + hitDirY * hitDirY) or 0.0
    if hitDirLength > 0.0001 then
        local impactDot = -((velocityX / planarSpeed) * (hitDirX / hitDirLength)
            + (velocityY / planarSpeed) * (hitDirY / hitDirLength))
        return planarSpeed, impactDot, hitDirX, hitDirY
    end

    local directionX = vehicle:getX() - target:getX()
    local directionY = vehicle:getY() - target:getY()
    local directionLength = math.sqrt(directionX * directionX + directionY * directionY)
    if directionLength <= 0.0 then
        return planarSpeed, 0.0, nil, nil
    end
    return planarSpeed,
        (velocityX / planarSpeed) * (directionX / directionLength)
            + (velocityY / planarSpeed) * (directionY / directionLength),
        -directionX / directionLength,
        -directionY / directionLength
end

local function correctAnimalHit(animal, vehicle, mainImpulseWasQueued)
    local weight = animalWeight(animal)
    if not weight then
        return false
    end

    local planarSpeed, impactDot = impactKinematics(vehicle, animal)
    local excess = Core.animalImpulseExcess(
        vehicle:getFudgedMass(),
        weight,
        planarSpeed,
        impactDot,
        mainImpulseWasQueued,
        option("AnimalImpulseMultiplier", 1.0)
    )
    if excess and excess > 0.0001 then
        -- Negative values are accepted by this public API.  It appends to the
        -- same pending list as the vanilla hit, with the same direction and
        -- contact point, so the excess cancels before the next Bullet step.
        vehicle:applyImpulseFromHitObject(animal, -excess)
    end
    return true
end

local function correctZombieHit(zombie, vehicle, pair, multiplier, confirmedEdge,
        detector)
    if not pair.wasAlive
        or not pair.canBeHit
        or not pair.canSlow
        or (not confirmedEdge
            and (not pair.positionEligible
                or not hitPositionEligible(vehicle, zombie))) then
        return false
    end

    local planarSpeed, impactDot, correctionX, correctionY =
        impactKinematics(vehicle, zombie)
    local excess = Core.zombieImpulseExcess(
        pair.mass,
        planarSpeed,
        impactDot,
        pair.wasProne,
        multiplier
    )
    if excess and excess > 0.0001 and correctionX and correctionY then
        -- onHitByVehicle records hitDir opposite vanilla's vehicle impulse.
        -- Queue the excess along that exact direction at the vehicle center.
        -- With engine hitDir this avoids deriving a new direction from a
        -- zombie that moved after impact; the positional fallback is retained
        -- only when hitDir is unavailable.  Both paths are center-applied.
        vehicle:applyImpulseGeneric(
            vehicle:getX(),
            vehicle:getY(),
            vehicle:getZ(),
            correctionX,
            correctionY,
            0.0,
            excess
        )
        if not loggedZombieCorrection then
            loggedZombieCorrection = true
            print("[" .. Core.MOD_ID .. "] First live-zombie slowdown correction"
                .. " applied (multiplier=" .. tostring(multiplier)
                .. ", detector=" .. tostring(detector) .. ").")
        end
    end
    return true
end

local function targetSnapshot(snapshot, target)
    local state = snapshot.targets[target]
    if not state then
        state = { pairs = {} }
        snapshot.targets[target] = state
    end
    return state
end

local function zombieStateFlags(zombie, vehicle)
    if zombieStateMethodsAvailable == false then
        return false, false
    end
    if zombieStateMethodsAvailable == nil then
        local ok, canBeHit, canSlow = pcall(function()
            return zombie:canBeHitByVehicle(vehicle),
                zombie:canSlowDownVehicleWhenHit(vehicle)
        end)
        if not ok then
            zombieStateMethodsAvailable = false
            warnOnce("live-zombie state methods are unavailable: " .. tostring(canBeHit))
            return false, false
        end
        zombieStateMethodsAvailable = true
        return canBeHit == true, canSlow == true
    end
    return zombie:canBeHitByVehicle(vehicle) == true,
        zombie:canSlowDownVehicleWhenHit(vehicle) == true
end

local function snapshotAnimal(snapshot, animal)
    if not animal or not instanceof(animal, "IsoAnimal") then
        return
    end
    local state = nil
    for _, vehicle in ipairs(snapshot.vehicles) do
        if nearVehicle(vehicle, animal, snapshot.vehicleInfo[vehicle]) then
            if not state then
                state = targetSnapshot(snapshot, animal)
                state.kind = "animal"
                state.wasAlive = animal:isAlive()
                state.wasRoadKill = animal:isRoadKill()
                state.wasFalldown = tostring(animal:getCurrentStateName() or "")
                    == "AnimalFalldownState"
            end
            state.pairs[vehicle] = {
                contactBefore = vehicle:isPersistentContact(animal),
                overlapBefore = standingCollision(vehicle, animal),
                positionEligible = hitPositionEligible(vehicle, animal),
                wasFalldown = state.wasFalldown,
            }
        end
    end
end

local function snapshotZombie(snapshot, zombie)
    if not zombie or not instanceof(zombie, "IsoZombie") then
        return
    end
    local state = nil
    for _, vehicle in ipairs(snapshot.vehicles) do
        if nearVehicle(vehicle, zombie, snapshot.vehicleInfo[vehicle]) then
            if not state then
                state = targetSnapshot(snapshot, zombie)
                state.kind = "zombie"
                state.wasAlive = zombie:isAlive()
                state.wasProne = zombie:isProne()
                state.mass = tonumber(zombie:getMass())
            end
            local canBeHit, canSlow = zombieStateFlags(zombie, vehicle)
            state.pairs[vehicle] = {
                contactBefore = vehicle:isPersistentContact(zombie),
                overlapBefore = not state.wasProne
                    and standingCollision(vehicle, zombie) or false,
                wasAlive = state.wasAlive,
                wasProne = state.wasProne,
                mass = state.mass,
                canBeHit = canBeHit,
                canSlow = canSlow,
                positionEligible = hitPositionEligible(vehicle, zombie),
            }
        end
    end
end

local function onPreTick(tickToken)
    local cell = getCell()
    local vehicles, vehicleInfo = localVehicles(cell)
    local zombieMultiplier = option("ZombieImpulseMultiplier", 1.0)
    if lastZombieMultiplier ~= nil
        and zombieMultiplier ~= lastZombieMultiplier then
        print("[" .. Core.MOD_ID .. "] Live-zombie slowdown multiplier changed to "
            .. tostring(zombieMultiplier) .. ".")
        loggedZombieCorrection = false
    end
    lastZombieMultiplier = zombieMultiplier
    local snapshot = {
        token = tickToken,
        vehicles = vehicles,
        vehicleInfo = vehicleInfo,
        targets = {},
        observedAnimals = {},
        corrected = {},
        correctedTargets = {},
        multiplayerClient = isClient(),
        zombieMultiplier = zombieMultiplier,
    }
    frameSnapshot = snapshot

    if #snapshot.vehicles == 0 then
        return
    end

    local animals = cell and cell:getAnimals() or nil
    if animals then
        for index = 0, animals:size() - 1 do
            local animal = animals:get(index)
            snapshot.observedAnimals[animal] = true
            snapshotAnimal(snapshot, animal)
        end
    end

    -- The default 1.0 preserves vanilla and needs no per-zombie Lua work.
    if snapshot.zombieMultiplier < 0.9999 then
        local zombies = cell and cell:getZombieList() or nil
        if zombies then
            for index = 0, zombies:size() - 1 do
                snapshotZombie(snapshot, zombies:get(index))
            end
        end
    end
end

local function processContactEdges(snapshot)
    for target, state in pairs(snapshot.targets) do
        local candidates = {}
        for vehicle, pair in pairs(state.pairs) do
            if not pair.contactBefore
                and vehicle:isPersistentContact(target)
                and not correctedThisFrame(snapshot, vehicle, target) then
                candidates[#candidates + 1] = {
                    vehicle = vehicle,
                    pair = pair,
                }
            end
        end
        -- Only one private vehicle pointer can drive a character collision in
        -- this update.  Multiple apparent new edges are ambiguous, so never
        -- choose one from unordered table iteration for a large correction.
        if #candidates == 1 then
            local candidate = candidates[1]
            local handled = false
            if state.kind == "animal" and state.wasAlive then
                -- A new persistent contact proves hitAnimal completed all
                -- early-return guards and queued its main + fixed impulses.
                handled = correctAnimalHit(target, candidate.vehicle, true)
            elseif state.kind == "zombie" then
                handled = correctZombieHit(
                    target,
                    candidate.vehicle,
                    candidate.pair,
                    snapshot.zombieMultiplier,
                    true,
                    "contact-edge"
                )
            end
            if handled then
                markCorrectedThisFrame(snapshot, candidate.vehicle, target)
            end
        end
    end
end

local function processAnimalCollisions(snapshot, cell)
    local animals = cell and cell:getAnimals() or nil
    if not animals then
        return
    end
    for index = 0, animals:size() - 1 do
        local animal = animals:get(index)
        if animal
            and animal:isAlive()
            and not targetCorrectedThisFrame(snapshot, animal) then
            local state = snapshot.targets[animal]
            local candidates = {}
            for _, vehicle in ipairs(snapshot.vehicles) do
                local pair = state and state.pairs[vehicle] or nil
                if pair or nearVehicle(
                    vehicle,
                    animal,
                    snapshot.vehicleInfo[vehicle]
                ) then
                    local overlapNow = standingCollision(vehicle, animal)
                    local persistentNow = vehicle:isPersistentContact(animal)
                    -- On a Build 42.22.2 multiplayer client, IsoAnimal's
                    -- successful network-hit branch does not reliably write
                    -- vehicleCollision.  A persistent pair that overlaps both
                    -- sides of the bracket is the conservative signal for
                    -- another queued collision.  In single-player, the
                    -- engine's reported flag remains the stronger signal.  A
                    -- newly observed persistent pair is a same-update fallback.
                    local inferredClientHit = snapshot.multiplayerClient
                        and persistentNow
                        and overlapNow
                        and ((pair and pair.overlapBefore)
                            or (state == nil
                                and not snapshot.observedAnimals[animal]))
                    local reportedLocalHit = not snapshot.multiplayerClient
                        and animal:isVehicleCollision()
                        and persistentNow
                        and overlapNow
                    if not correctedThisFrame(snapshot, vehicle, animal)
                        and (inferredClientHit or reportedLocalHit) then
                        candidates[#candidates + 1] = {
                            vehicle = vehicle,
                            pair = pair,
                        }
                    end
                end
            end
            -- breakingObjects can assign only one private vehicle pointer to a
            -- target.  If more than one locally simulated vehicle is an
            -- equally plausible sustained candidate, skip instead of applying
            -- a large negative correction to the wrong vehicle.
            if #candidates == 1 then
                local candidate = candidates[1]
                local vehicle = candidate.vehicle
                local pair = candidate.pair
                -- Until the server's falldown state reaches a client,
                -- hitAnimal can queue its large main impulse again.  Once
                -- falldown was active before the bracket, only IsoAnimal's
                -- unconditional fixed +1 was queued.  The per-axis guards
                -- mirror hitAnimal and prevent a negative main correction when
                -- it returned early.
                local mainWasQueued = (pair == nil
                    and tostring(animal:getCurrentStateName() or "")
                        ~= "AnimalFalldownState"
                    and hitPositionEligible(vehicle, animal))
                    or (pair ~= nil
                        and not pair.wasFalldown
                        and pair.positionEligible
                        and hitPositionEligible(vehicle, animal))
                if correctAnimalHit(animal, vehicle, mainWasQueued) then
                    markCorrectedThisFrame(snapshot, vehicle, animal)
                end
            end
        end
    end
end

local function processZombieCollisions(snapshot, cell)
    if snapshot.zombieMultiplier >= 0.9999 then
        return
    end
    local zombies = cell and cell:getZombieList() or nil
    if not zombies then
        return
    end
    for index = 0, zombies:size() - 1 do
        local zombie = zombies:get(index)
        local state = snapshot.targets[zombie]
        if state
            and zombie:isAlive()
            and not targetCorrectedThisFrame(snapshot, zombie) then
            local candidates = {}
            for vehicle, pair in pairs(state.pairs) do
                -- Never call testCollisionWithProneCharacter here: it rewrites
                -- vanilla's wheel-lift slots and can play a duplicate sound.
                -- Retain the conservative fallback from the 42.20 profile;
                -- 42.22.2 multiplayer timing still needs driving validation.
                -- For a standing zombie only, overlap
                -- on both sides of the update bracket plus a persistent pair
                -- is the conservative fallback.  Prone continuation still
                -- requires the engine flag because its geometry test has the
                -- wheel-impulse side effects deliberately avoided above.
                local persistentNow = vehicle:isPersistentContact(zombie)
                local reportedHit = zombie:isVehicleCollision()
                    and pair.contactBefore
                    and (pair.overlapBefore or pair.wasProne)
                    and persistentNow
                local inferredClientHit = snapshot.multiplayerClient
                    and not pair.wasProne
                    and pair.contactBefore
                    and pair.overlapBefore
                    and persistentNow
                    and standingCollision(vehicle, zombie)
                if not correctedThisFrame(snapshot, vehicle, zombie)
                    and (reportedHit or inferredClientHit) then
                    candidates[#candidates + 1] = {
                        vehicle = vehicle,
                        pair = pair,
                        detector = reportedHit and "engine-flag"
                            or "multiplayer-overlap",
                    }
                end
            end
            if #candidates == 1 then
                local candidate = candidates[1]
                if correctZombieHit(
                    zombie,
                    candidate.vehicle,
                    candidate.pair,
                    snapshot.zombieMultiplier,
                    false,
                    candidate.detector
                ) then
                    markCorrectedThisFrame(
                        snapshot,
                        candidate.vehicle,
                        zombie
                    )
                end
            end
        end
    end
end

local function onCharacterDeath(character)
    local snapshot = frameSnapshot
    -- Single-player can convert the animal to a corpse before OnTick sees the
    -- exact contact edge.  Multiplayer death is authoritative and may arrive
    -- later, so it must never use this synchronous pending-impulse fallback.
    if not snapshot
        or snapshot.multiplayerClient
        or not character
        or not instanceof(character, "IsoAnimal")
        or not character:isRoadKill() then
        return
    end

    local state = snapshot.targets[character]
    if not state or not state.wasAlive or state.wasRoadKill ~= false then
        return
    end
    local candidates = {}
    for vehicle, pair in pairs(state.pairs) do
        if not pair.contactBefore
            and not targetCorrectedThisFrame(snapshot, character)
            and standingCollision(vehicle, character) then
            candidates[#candidates + 1] = vehicle
        end
    end
    if #candidates == 1 then
        local vehicle = candidates[1]
        if correctAnimalHit(character, vehicle, true) then
            markCorrectedThisFrame(snapshot, vehicle, character)
        end
    end
end

local function corpseMass(body)
    local weight = tonumber(body:getWeight())
    if Core.isFinitePositive(weight) then
        return weight
    end
    if not body:isAnimal() then
        -- Human/zombie IsoDeadBody weight is normally zero in 42.22.2.  This is
        -- the same 100 kg reference used by IsoGameCharacter vehicle physics.
        return 100.0
    end
    return nil
end

local function retuneCorpseForVehicle(vehicle, body, multiplier)
    local bodyMass = corpseMass(body)
    if not bodyMass then
        return
    end

    local modData = body:getModData()
    local original = modData.corpseSize
    local effective = Core.corpseSizeForVehicle(
        original,
        bodyMass,
        vehicle:getFudgedMass(),
        multiplier
    )
    if effective == nil then
        return
    end

    -- testCollisionWithCorpse rewrites the vehicle's one pending impulse per
    -- wheel.  Calling it after vanilla's vehicle scan replaces that frame's
    -- oversized value; false suppresses the duplicate run-over sound only.
    modData.corpseSize = effective
    local ok, err = pcall(function()
        vehicle:testCollisionWithCorpse(body, false)
    end)
    modData.corpseSize = original
    if not ok then
        warnOnce(err)
    end
end

local function scanCorpses(vehicle, multiplier)
    if not vehicle:shouldCollideWithObjects()
        or vehicle:getCurrentAbsoluteSpeedKmHour() < 3.0 then
        return
    end

    local extents = vehicle:getScript():getExtents()
    local radius = math.ceil(math.max(extents:x() / 2.0, extents:z() / 2.0) + 0.3 + 1.0)

    local cell = getCell()
    -- This is the exact yy/xx range and ordering used by BaseVehicle's
    -- breakingObjects scan.  Order matters when several bodies touch one
    -- wheel because the last body rewrites that wheel's pending slot.
    for yy = -radius, radius - 1 do
        for xx = -radius, radius - 1 do
            local square = cell:getGridSquare(
                vehicle:getX() + xx,
                vehicle:getY() + yy,
                vehicle:getZ()
            )
            local objects = square and square:getStaticMovingObjects() or nil
            if objects then
                for index = 0, objects:size() - 1 do
                    local body = objects:get(index)
                    if instanceof(body, "IsoDeadBody") then
                        retuneCorpseForVehicle(vehicle, body, multiplier)
                    end
                end
            end
        end
    end
end

local function onTick(tickToken)
    local cell = getCell()
    local snapshot = frameSnapshot
    if snapshot and snapshot.token == tickToken then
        processContactEdges(snapshot)
        processAnimalCollisions(snapshot, cell)
        processZombieCollisions(snapshot, cell)
    end
    -- OnCharacterDeath has no tick token.  Do not allow an asynchronous later
    -- death event to reuse a completed frame's pending-impulse snapshot.
    frameSnapshot = nil

    local vehicles = cell and cell:getVehicles() or nil
    if not vehicles then
        return
    end

    local multiplier = option("CorpseImpulseMultiplier", 1.0)
    local iterator = vehicles:iterator()
    while iterator:hasNext() do
        local vehicle = iterator:next()
        if locallySimulated(vehicle) then
            scanCorpses(vehicle, multiplier)
        end
    end
end

local function onGameStart()
    local actual = tostring(getCore():getVersionNumber())
    lastZombieMultiplier = option("ZombieImpulseMultiplier", 1.0)
    if not Core.isTargetGameVersion(actual) then
        print("[" .. Core.MOD_ID .. "] WARNING: built for Project Zomboid "
            .. Core.TARGET_GAME_VERSION .. "; running " .. actual)
    else
        print("[" .. Core.MOD_ID .. "] Pure Lua collision correction v"
            .. Core.MOD_VERSION .. " active for Project Zomboid " .. actual
            .. " (animal=" .. tostring(option("AnimalImpulseMultiplier", 1.0))
            .. ", zombie=" .. tostring(option("ZombieImpulseMultiplier", 1.0))
            .. ", corpse=" .. tostring(option("CorpseImpulseMultiplier", 1.0))
            .. ")")
    end
end

Events.OnTickEvenPaused.Add(onPreTick)
Events.OnTick.Add(onTick)
Events.OnCharacterDeath.Add(onCharacterDeath)
Events.OnGameStart.Add(onGameStart)
