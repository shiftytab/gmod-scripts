--@name SPY_DRONE
--@author 142kb
--@owneronly
--@shared
--@github https://github.com/shiftytab/gmod-scripts/blob/main/Starfall/spy-drone.lua

local MAX_LOGS = 20
local LOG_COLOR = {
    DEFAULT = 1,
    RED     = 2,
    GREEN   = 3,
    BLUE    = 4,
    AMBER   = 5,
    GREY    = 6
}

if SERVER then
    wire.adjustInputs(
        { "Activate",  "TargetName", "Base",   "Drone", "INCREASE_FOV", "DECREASE_FOV" },
        { "number",    "string",     "entity", "entity", "number", "number" }
    )

    wire.adjustOutputs(
        { "TargetPos" },
        { "vector" }
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
    local function addLog(...)
        local args = { ... }
        net.start("drone_log")
        net.writeUInt(#args, 6) -- Up to 64 arguments per log line
        
        for _, val in ipairs(args) do
            if type(val) == "number" then
                net.writeBool(true)  -- True = Color Enum ID
                net.writeUInt(val, 4) 
            else
                net.writeBool(false) -- False = Text string
                net.writeString(tostring(val))
            end
        end
        net.send()
    end

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
            addLog(LOG_COLOR.BLUE, "[Drone]", LOG_COLOR.DEFAULT, " Target found: ", LOG_COLOR.GREEN, target:getName())
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
        addLog(LOG_COLOR.BLUE, "[Drone]", LOG_COLOR.AMBER, " Returning to base...")
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
            addLog(LOG_COLOR.RED, "[Error]", LOG_COLOR.DEFAULT, " No base defined for the drone!")
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
            if isRunning then refreshTarget() end

        elseif portName == "Drone" or portName == "Base" then
            if valid(value) then
                addLog(LOG_COLOR.BLUE, "[Drone]", LOG_COLOR.GREY, " Entity '" .. portName .. "' connected")
            end
        end

    end)
    
    hook.add("remove", "onChipRemoved", function()
        timer.remove(TIMER_NAME)
    end)


    -- STARTUP MESSAGES
    timer.simple(0.5, function()
        addLog(LOG_COLOR.BLUE, "[Drone]", LOG_COLOR.GREEN, " System successfully deployed")
    end)
end

if CLIENT then
    local logTable = {}

    local colorPalette = {
        [LOG_COLOR.DEFAULT] = Color(220, 220, 220),
        [LOG_COLOR.RED]     = Color(255, 60, 60),
        [LOG_COLOR.GREEN]   = Color(100, 255, 120),
        [LOG_COLOR.BLUE]    = Color(60, 160, 255),
        [LOG_COLOR.AMBER]   = Color(255, 160, 40),
        [LOG_COLOR.GREY]    = Color(140, 145, 150)
    }

    net.receive("drone_log", function()
        local count = net.readUInt(6)
        local segment = {}
        
        for i = 1, count do
            local isColor = net.readBool()
            if isColor then
                table.insert(segment, { isColor = true, value = net.readUInt(4) })
            else
                table.insert(segment, { isColor = false, value = net.readString() })
            end
        end
        
        table.insert(logTable, segment)
        if #logTable > MAX_LOGS then
            table.remove(logTable, 1)
        end
    end)


    hook.add("render", "drawColoredLogs", function()
        render.clear(Color(15, 15, 20))

        local mat = Matrix()
        mat:translate(Vector(650, 0, 0))
        mat:rotate(Angle(0, 90, 0))
        
        render.pushMatrix(mat)
        
        render.setColor(colorPalette[LOG_COLOR.GREEN])
        
        render.drawText(20, 20, "SYSTEM LOGS // SPY_DRONE")
        render.setColor(Color(50, 50, 55))
        render.drawText(20, 40, "_________________________________")
        
        local y = 80
        for i, logSegments in ipairs(logTable) do
            local x = 20
            local currentColor = colorPalette[LOG_COLOR.DEFAULT]

            for _, element in ipairs(logSegments) do
                if element.isColor then
                    currentColor = colorPalette[element.value] or colorPalette[LOG_COLOR.DEFAULT]
                else
                    render.setColor(currentColor)
                    render.drawText(x, y, element.value)
                    
                    local segmentWidth, _ = render.getTextSize(element.value)
                    x = x + segmentWidth
                end
            end

            y = y + 25
        end
        
        render.popMatrix()
    end)
end
