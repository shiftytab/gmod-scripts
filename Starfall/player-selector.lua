--@name PLAYER_SELECTOR
--@author 142kb
--@owneronly
--@server
--@github https://github.com/shiftytab/gmod-scripts/blob/main/Starfall/player-selector.lua

-- 
--  WIRE
-- 

wire.adjustInputs(
    { "Next",   "Prev",   "Refresh" },
    { "number", "number", "number"  }
)
wire.adjustOutputs(
    { "PlayerName", "PlayerIndex", "PlayerCount" },
    { "string",     "number",      "number"      }
)

-- 
--  STATE
-- 

local playerList = {}
local currentIndex = 1

-- 
--  CORE
-- 

local function refreshList()
    playerList = find.allPlayers()
    currentIndex = math.max(1, math.min(currentIndex, #playerList))
    wire.ports.PlayerCount = #playerList
end

local function outputCurrent()
    if #playerList == 0 then
        wire.ports.PlayerName  = ""
        wire.ports.PlayerIndex = 0
        wire.ports.PlayerCount = 0
        return
    end

    local ply = playerList[currentIndex]

    if not ply or not ply:isValid() then
        refreshList()
        return
    end

    wire.ports.PlayerName  = ply:getName()
    wire.ports.PlayerIndex = currentIndex
    wire.ports.PlayerCount = #playerList
end

local function next()
    if #playerList == 0 then return end
    currentIndex = (currentIndex % #playerList) + 1
    outputCurrent()
end

local function prev()
    if #playerList == 0 then return end
    currentIndex = ((currentIndex - 2) % #playerList) + 1
    outputCurrent()
end

-- 
--  HOOKS
-- 

hook.add("input", "onWireInput", function(portName, value)
    if value ~= 1 then return end

    if portName == "Next" then
        next()
    elseif portName == "Prev" then
        prev()
    elseif portName == "Refresh" then
        refreshList()
        outputCurrent()
    end
end)

-- 
--  STARTUP
-- 

refreshList()
outputCurrent()
