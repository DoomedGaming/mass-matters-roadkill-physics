DoomedRoadkillPhysics = DoomedRoadkillPhysics or {}

local Core = DoomedRoadkillPhysics

Core.MOD_ID = "DoomedRoadkillPhysics"
Core.MOD_VERSION = "1.1.0"
Core.TARGET_GAME_VERSION = "42.21"

function Core.isTargetGameVersion(value)
    local version = tostring(value)
    return version == Core.TARGET_GAME_VERSION
        or version == Core.TARGET_GAME_VERSION .. ".0"
end

local function finitePositive(value)
    value = tonumber(value)
    return value and value > 0 and value == value and value < math.huge
end

local function boundedMultiplier(value)
    value = tonumber(value) or 1.0
    return math.max(0.0, math.min(2.0, value))
end

local function boundedReductionMultiplier(value)
    value = tonumber(value) or 1.0
    return math.max(0.0, math.min(1.0, value))
end

-- Build 42.21's live-animal reaction is based on vehicle mass.  Return the
-- excess scalar that should be removed from the same pending impulse queue.
function Core.animalImpulseExcess(vehicleMass, animalMass, planarSpeed, impactDot,
        mainImpulseWasQueued, multiplier)
    if not finitePositive(vehicleMass) or not finitePositive(animalMass) then
        return nil
    end

    planarSpeed = tonumber(planarSpeed) or 0.0
    impactDot = tonumber(impactDot) or 0.0
    multiplier = boundedMultiplier(multiplier)

    local vanillaMain = 0.0
    local desiredMain = 0.0
    if mainImpulseWasQueued and planarSpeed >= 0.05 and impactDot < 0.0 then
        local cappedSpeed = math.min(planarSpeed, 15.0)
        local alignment = math.abs(impactDot)
        vanillaMain = vehicleMass * 7.0 * cappedSpeed / 15.0 * alignment
        desiredMain = math.min(
            vanillaMain,
            animalMass * 12.0 * multiplier * cappedSpeed / 15.0 * alignment
        )
    end

    local vanillaFixed = 1.0
    local desiredFixed = math.min(vanillaFixed, animalMass / 100.0 * multiplier)
    return math.max(0.0, (vanillaMain + vanillaFixed) - (desiredMain + desiredFixed))
end

-- Build 42.21's standing/prone pedestrian slowdown already uses character
-- mass.  Return only the portion removed by the reduce-only zombie option.
-- This intentionally excludes target damage and the separate prone-wheel
-- impulse path.
function Core.zombieImpulseExcess(zombieMass, planarSpeed, impactDot, isProne,
        multiplier)
    if not finitePositive(zombieMass) then
        return nil
    end

    planarSpeed = tonumber(planarSpeed) or 0.0
    impactDot = tonumber(impactDot) or 0.0
    multiplier = boundedReductionMultiplier(multiplier)
    -- BaseVehicle.hitCharacter returns before the pedestrian impulse below
    -- 0.05 m/s, even though the outer collision test can still report true.
    if planarSpeed < 0.05 or impactDot > 0.0 then
        return 0.0
    end

    local stanceFactor = isProne and 0.2 or 0.8
    local vanilla = math.max(0.0, -impactDot)
        * zombieMass * stanceFactor * planarSpeed
    return vanilla * (1.0 - multiplier)
end

-- Build 42.21 multiplies corpse wheel lift by corpseSize.  This replacement
-- makes the stored per-wheel impulse depend on body mass instead of vehicle
-- mass while never increasing the vanilla reaction.
function Core.corpseSizeForVehicle(originalSize, corpseMass, vehicleMass, multiplier)
    originalSize = tonumber(originalSize)
    if originalSize == nil then
        originalSize = 1.0
    end
    if not finitePositive(corpseMass) or not finitePositive(vehicleMass) then
        return nil
    end

    originalSize = math.max(0.0, originalSize)
    multiplier = boundedMultiplier(multiplier)
    return math.min(originalSize, corpseMass * multiplier / vehicleMass)
end

function Core.isFinitePositive(value)
    return finitePositive(value)
end

return Core
