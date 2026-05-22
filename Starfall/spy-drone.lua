--@name SPY_DRONE
--@author 142kb
--@owneronly
--@server
--@github https://github.com/shiftytab/gmod-scripts/blob/main/Starfall/spy-drone.lua

wire.adjustInputs(
    { "Activate",  "TargetName", "Base",   "Drone", "INCREASE_FOV", "DECREASE_FOV"   },
    { "number",    "string",     "entity", "entity", "number", "number"  }
)

wire.adjustOutputs(
    { "TargetPos" },
    { "vector"    }
)

local CAMERA_DISTANCE = 1.5
local CAMERA_MIN_DISTANCE = 1.2
local CAMERA_MAX_DISTANCE = 5
local LOOP_INTERVAL   = 0.01
local TIMER_NAME      = "drone_loop"
local DRONE_BASE_HEIGHT = 0.5

local target     = nil
local isRunning  = false

--[[ 
    HELPERS SECTION
--]]
local function valid(e)
    return e ~= nil and e:isValid()
end

local function getDrone()
    return wire.ports.Drone
end

local function getBase()
    return wire.ports.Base
end

--[[ 
    CORE FUNCTIONS
--]]
local function findPlayerByName(name)
    if not name or name == "" then return nil end
    local low = name:lower()
    for _, ply in ipairs(find.allPlayers()) do
        if ply:getName():lower():find(low, 1, true) then
            return ply
        end
    end
    return nil
end

local function refreshTarget()
    target = findPlayerByName(wire.ports.TargetName)
    if target then
        print(Color(80, 200, 255), "[Drone] Target found: " .. target:getName())
    end
end

local function teleportToTarget()
    local drone = getDrone()
    if not valid(drone) or not valid(target) then return end

    local pos = target:getPos() + Vector(0, 0, CAMERA_DISTANCE * 100)
    drone:setMaterial("Models/effects/comball_tape")
    drone:setPos(pos)
    drone:setAngles(Angle(25, target:getEyeAngles().y + 180, 0))
    wire.ports.TargetPos = pos
end

local function returnToBase()
    local drone = getDrone()
    local base  = getBase()

    if valid(drone) and valid(base) then
        drone:setPos(base:getPos() + Vector(0, 0, DRONE_BASE_HEIGHT * 100))
        drone:setAngles(Angle(0, 0, 0))
        drone:setMaterial("models/XQM/CellShadedCamo_diffuse")
    end

    wire.ports.TargetPos = Vector(0, 0, 0)
    print(Color(255, 180, 50), "[Drone] Returning to base")
end


--- LOOP
local function droneLoop()
    if not isRunning then return end
    
    if not valid(target) then
        refreshTarget()
    end

    if valid(target) then
        teleportToTarget()
    else
        returnToBase()
    end
end

--[[ 
    CORE FUNCTIONS
--]]

local function activate()
    local base = getBase()
    if not valid(base) then
        print(Color(255, 80, 80),   "[Error] ",
              Color(255, 255, 255), "No base defined for the drone!")
        return
    end

    isRunning = true
    refreshTarget()
    timer.create(TIMER_NAME, LOOP_INTERVAL, 0, droneLoop)
end

local function deactivate()
    isRunning = false
    timer.remove(TIMER_NAME)
    target = nil
    returnToBase()
end

-- HOOKS
hook.add("input", "onWireInput", function(portName, value)

    if portName == "Activate" then
        if value == 1 then
            activate()
        else
            deactivate()
        end
        
    elseif portName == "INCREASE_FOV" then
        if CAMERA_DISTANCE < CAMERA_MAX_DISTANCE then
            CAMERA_DISTANCE = CAMERA_DISTANCE + 0.15
        end

    elseif portName == "DECREASE_FOV" then
        if CAMERA_DISTANCE > CAMERA_MIN_DISTANCE then
            CAMERA_DISTANCE = CAMERA_DISTANCE - 0.15
        end
    
    elseif portName == "TargetName" then
        target = nil
        if isRunning then refreshTarget(2) end

    elseif portName == "Drone" or portName == "Base" then
        if valid(value) then
            print(Color(180, 180, 255), "[Drone] Entity '" .. portName .. "' connected")
        end
    end

end)

hook.add("remove", "onChipRemoved", function()
    timer.remove(TIMER_NAME)
end)


-- STARTUP MESSAGES
print(Color(100, 200, 255), "[Drone] Deployed")
