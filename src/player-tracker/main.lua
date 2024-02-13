local player = peripheral.find("playerDetector") or error("Player Detector not found")
local monitor = peripheral.find("monitor") or error("Monitor not found")
local updateInterval = 1
local padding = 20

monitor.clear();
monitor.setCursorPos(1, 1)
monitor.write("Loading...")
monitor.setCursorBlink(false)
monitor.setTextScale(0.75)

function padEnd(str, length, char)
    local padding = length - #str
    if padding > 0 then
        return str .. string.rep(char, padding)
    else
        return str
    end
end

-- start timer
local timer = os.startTimer(updateInterval)
while true do
    local event, id = os.pullEvent("timer")
    if id == timer then
        local players = player.getOnlinePlayers()
        for i, playerName in ipairs(players) do
            local formatedName = padEnd(playerName, padding, " ")
            local position = player.getPlayerPos(playerName)
            monitor.setCursorPos(1, i)
            monitor.clearLine()
            monitor.write(formatedName .. " > X: " .. padEnd(position.x .. ",", 8, " ") .. "Y: " .. padEnd(position.y .. ",", 8, " ") .. "Z: " .. padEnd(position.z .. "", 8, " "))
        end
        
        timer = os.startTimer(updateInterval)
    end
end