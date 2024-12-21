local terminalUtils = require("lib/terminalUtils")
local wirelessUtils = require("lib/wirelessUtils")

local DAY_CYCLE_MAP = {
    { trigger = 0, cycle = "night", color = 0x4000 },
    { trigger = 4, cycle = "sunrise", color = 0x2 },
    { trigger = 6, cycle = "day", color = 0x10 },
    { trigger = 18, cycle = "sunset", color = 0x2 },
    { trigger = 19.5, cycle = "night", color = 0x4000 },
}
local COUNTDOWN_COLOR_MAP = {
    { trigger = 0, color = 0x4000 },
    { trigger = 5, color = 0x10 },
    { trigger = 15, color = nil },
}
local PROTOCOL_NAME = "rsWarehouse"

-- helper function, returns the cycle phase name and color of the
-- current day based on DAY_CYCLE_MAP
local function getCurrentDayCycle()
    local currentTime = os.time()

    -- get current daytime
    local cycleName = "???"
    local cycleColor = nil
    for i = #DAY_CYCLE_MAP, 1, -1 do
        local cycleEntry = DAY_CYCLE_MAP[i]
        if currentTime >= cycleEntry.trigger then
            cycleName = cycleEntry.cycle
            cycleColor = cycleEntry.color
            break
        end
    end

    return cycleName, cycleColor
end

local WarehouseManagerClient = {
    modem = nil,
    hostId = nil,
    useTwentyFourHour = true,
}
function WarehouseManagerClient:new(o, modem, host, useTwentyFourHour)
    -- required for class structure
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    self.modem = modem or error("Modem not found")
    self.useTwentyFourHour = useTwentyFourHour or true

    -- try to lookup host
    if host ~= nil then
        rednet.open(peripheral.getName(self.modem))
        self.hostId = rednet.lookup(PROTOCOL_NAME, host) or error("No host found")
    else
        error("No host defined")
    end

    return o
end

-- updates the request list
function WarehouseManagerClient:_updateRequestList(equipmentRequests, builderRequests, otherRequests)
    local rowIndex = 2 -- start at row 2 because the first row is the header
    terminalUtils.clearRows(rowIndex, nil)

    -- builder requests
    if #builderRequests > 0 then
        rowIndex = rowIndex + 2
        terminalUtils.writeLineJustified(rowIndex, "CENTER", "Builder Requests", nil, nil)

        -- iterate over request and display them row by row
        for i, builderRequest in ipairs(builderRequests) do
            rowIndex = rowIndex + 1
            local amountString = string.format("%d/%s", builderRequest.provided, builderRequest.name)
            terminalUtils.writeLineJustified(rowIndex, "START", amountString, builderRequest.displayColor, nil)
            -- terminalUtils.writeLineJustified(rowIndex, "END", builderRequest.target, builderRequest.displayColor, nil)
        end
    end

    -- equipment requests
    if #equipmentRequests > 0 then
        rowIndex = rowIndex + 2
        terminalUtils.writeLineJustified(rowIndex, "CENTER", "Equipment", nil, nil)

        -- iterate over request and display them row by row
        for i, equipmentRequest in ipairs(equipmentRequests) do
            rowIndex = rowIndex + 1
            local amountString = string.format("%d/%d %s", equipmentRequest.provided, equipmentRequest.requested, equipmentRequest.name)
            terminalUtils.writeLineJustified(rowIndex, "START", amountString, equipmentRequest.displayColor, nil)
            -- terminalUtils.writeLineJustified(rowIndex, "END", equipmentRequest.target, equipmentRequest.displayColor, nil)
        end
    end

    -- other requests
    if #otherRequests > 0 then
        rowIndex = rowIndex + 2
        terminalUtils.writeLineJustified(rowIndex, "CENTER", "Other Requests", nil, nil)

        -- iterate over request and display them row by row
        for i, otherRequest in ipairs(otherRequests) do
            -- other request may required additional formating based on number requirements or not
            local amountString = string.format("%d %s", otherRequest.requested, otherRequest.name)
            if tonumber(otherRequest.name:sub(1,1)) ~= nil then
                amountString = string.format("%d/%s", otherRequest.provided, otherRequest.name)
            end

            rowIndex = rowIndex + 1
            terminalUtils.writeLineJustified(rowIndex, "START", amountString, otherRequest.displayColor, nil)
            -- terminalUtils.writeLineJustified(rowIndex, "END", otherRequest.target, otherRequest.displayColor, nil)
        end
    end
end

-- updates the info header
-- format: 0:00     5s
function WarehouseManagerClient:_updateHeader(secondsUntilNextScan)
    local currentTime = os.time()

    -- get current daytime
    local cycleName, cycleColor = getCurrentDayCycle()

    -- draw time
    local timeString = string.format("%s [%s]     ", textutils.formatTime(currentTime, self.useTwentyFourHour), string.sub(cycleName, 1, 1))
    terminalUtils.writeLineJustified(1, "START", timeString, cycleColor, nil)

    -- get countdown color
    local cdColor = nil
    for i = #COUNTDOWN_COLOR_MAP, 1, -1 do
        local cdEntry = COUNTDOWN_COLOR_MAP[i]
        if secondsUntilNextScan >= cdEntry.trigger then
            cdColor = cdEntry.color
            break
        end
    end

    -- draw update countdown
    if cycleName ~= "night" then
        local countdownString = string.format("    %ss", secondsUntilNextScan)
        terminalUtils.writeLineJustified(1, "END", countdownString, cdColor, nil)
    else
        terminalUtils.writeLineJustified(1, "END", "PAUSED", 0x4000, nil)
    end
end

-- write a progress bar
function WarehouseManagerClient:_updateFooter(secondsUntilNextScan, updateInterval)
    -- get current daytime
    local cycleName, cycleColor = getCurrentDayCycle()

    -- get countdown color
    local cdColor = 0x4000
    if cycleName ~= "night" then
        for i = #COUNTDOWN_COLOR_MAP, 1, -1 do
            local cdEntry = COUNTDOWN_COLOR_MAP[i]
            if secondsUntilNextScan >= cdEntry.trigger then
                cdColor = cdEntry.color
                break
            end
        end
    end

    terminalUtils.progressBar(-1, (updateInterval - secondsUntilNextScan) / updateInterval, cdColor, nil)
end

-- logic loop, should be called in a loop
function WarehouseManagerClient:handle()
    local sender, netMessage = rednet.receive(PROTOCOL_NAME)

    -- only accept messages from defined host
    if sender == self.hostId then
        local netPackage = textutils.unserialize(netMessage)

        if netPackage.type == "HEADER" then
            self:_updateHeader(netPackage.secondsUntilNextScan)
        elseif netPackage.type == "BODY" then
            self:_updateRequestList(netPackage.equipmentRequests, netPackage.builderRequests, netPackage.otherRequests)
        elseif netPackage.type == "FOOTER" then
            self:_updateFooter(netPackage.secondsUntilNextScan, netPackage.updateInterval)
        else
            print("Warning: Unknown package type '" .. netPackage.type .. "'")
        end
    else
        print("Skipping message from " .. sender)
    end
end

return WarehouseManagerClient