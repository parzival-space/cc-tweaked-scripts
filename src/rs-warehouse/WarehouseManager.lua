local monitorUtils = require("lib/monitorUtils")

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
local MAX_EQUIPMENT_LEVEL_MATCHER = "maximal level:%s*([^%s]+)"
local BUILDER_MATCHER = "^Builder%s"


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


local WarehouseManager = {
    monitors = {},
    colonyIntegrator = {},
    rsBridge = {},
    inventoryPeripheral = {},
    secondsUntilNextScan = 0,
    updateInterval = 0,
    useTwentyFourHour = true
}
function WarehouseManager:new(o, monitors, colonyIntegrator, rsBridge, inventoryPeripheral, updateInterval, useTwentyFourHour)
    -- required for class structure
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    self.monitors = monitors or error("No monitors provided")
    self.colonyIntegrator = colonyIntegrator or error("Colony Integrator not provided")
    self.rsBridge = rsBridge or error("RS Bridge not provided")
    self.inventoryPeripheral = inventoryPeripheral or error("Inventory not provided")
    self.secondsUntilNextScan = updateInterval or 15
    self.updateInterval = updateInterval or 15
    self.useTwentyFourHour = useTwentyFourHour or true

    -- run initial request handling
    self:triggerRequestHandling()
    return o
end

-- updates the request list on every connected display.
function WarehouseManager:_updateRequestList(equipmentRequests, builderRequests, otherRequests)
    local rowIndex = 2 -- start at row 2 because the first row is the header
    monitorUtils.clearRows(self.monitors, rowIndex, nil)

    -- builder requests
    if #builderRequests > 0 then
        rowIndex = rowIndex + 2
        monitorUtils.writeLineJustifiedMultiple(self.monitors, rowIndex, "CENTER", "Builder Requests", nil, nil)

        -- iterate over request and display them row by row
        for i, builderRequest in ipairs(builderRequests) do
            rowIndex = rowIndex + 1
            local amountString = string.format("%d/%s", builderRequest.provided, builderRequest.name)
            monitorUtils.writeLineJustifiedMultiple(self.monitors, rowIndex, "START", amountString, builderRequest.displayColor, nil)
            monitorUtils.writeLineJustifiedMultiple(self.monitors, rowIndex, "END", builderRequest.target, builderRequest.displayColor, nil)
        end
    end

    -- equipment requests
    if #equipmentRequests > 0 then
        rowIndex = rowIndex + 2
        monitorUtils.writeLineJustifiedMultiple(self.monitors, rowIndex, "CENTER", "Equipment", nil, nil)

        -- iterate over request and display them row by row
        for i, equipmentRequest in ipairs(equipmentRequests) do
            rowIndex = rowIndex + 1
            local amountString = string.format("%d/%d %s", equipmentRequest.provided, equipmentRequest.requested, equipmentRequest.name)
            monitorUtils.writeLineJustifiedMultiple(self.monitors, rowIndex, "START", amountString, equipmentRequest.displayColor, nil)
            monitorUtils.writeLineJustifiedMultiple(self.monitors, rowIndex, "END", equipmentRequest.target, equipmentRequest.displayColor, nil)
        end
    end

    -- other requests
    if #otherRequests > 0 then
        rowIndex = rowIndex + 2
        monitorUtils.writeLineJustifiedMultiple(self.monitors, rowIndex, "CENTER", "Other Requests", nil, nil)

        -- iterate over request and display them row by row
        for i, otherRequest in ipairs(otherRequests) do
            -- other request may required additional formating based on number requirements or not
            local amountString = string.format("%d %s", otherRequest.requested, otherRequest.name)
            if tonumber(otherRequest.name:sub(1,1)) ~= nil then
                amountString = string.format("%d/%s", otherRequest.provided, otherRequest.name)
            end

            rowIndex = rowIndex + 1
            monitorUtils.writeLineJustifiedMultiple(self.monitors, rowIndex, "START", amountString, otherRequest.displayColor, nil)
            monitorUtils.writeLineJustifiedMultiple(self.monitors, rowIndex, "END", otherRequest.target, otherRequest.displayColor, nil)
        end
    end
end

-- updates the info header on every connected display.
-- format: Time: 0:00 [night]    Remaining 5s
function WarehouseManager:_updateHeader()
    local currentTime = os.time()

    -- get current daytime
    local cycleName, cycleColor = getCurrentDayCycle()

    -- draw time
    local timeString = string.format("Time: %s [%s]   ", textutils.formatTime(currentTime, self.useTwentyFourHour), cycleName)
    monitorUtils.writeLineJustifiedMultiple(self.monitors, 1, "START", timeString, cycleColor, nil)

    -- get countdown color
    local cdColor = nil
    for i = #COUNTDOWN_COLOR_MAP, 1, -1 do
        local cdEntry = COUNTDOWN_COLOR_MAP[i]
        if self.secondsUntilNextScan >= cdEntry.trigger then
            cdColor = cdEntry.color
            break
        end
    end

    -- draw update countdown
    if cycleName ~= "night" then
        local countdownString = string.format("     Remaining: %ss", self.secondsUntilNextScan)
        monitorUtils.writeLineJustifiedMultiple(self.monitors, 1, "END", countdownString, cdColor, nil)
    else
        monitorUtils.writeLineJustifiedMultiple(self.monitors, 1, "END", "     Remaining: PAUSED", 0x4000, nil)
    end
end

-- handles the minecolony requests and updates all connected displays
function WarehouseManager:_handleRequests()
    local equipmentRequests = {}
    local builderRequests = {}
    local otherRequests = {}

    -- fetch open request and categorize them
    local colonyRequests = self.colonyIntegrator.getRequests()
    for i, colonyRequest in ipairs(colonyRequests) do
        -- always use first items: these are available options to satisfy the request
        local requestedItem = colonyRequest.items[1]
        local amountRequested = colonyRequest.count
        local amountProvided = 0 -- items provided after this scann
        local resultColor = 0x1

        -- costruct shorted name
        local targetTitle, targetName = colonyRequest.target:match("^(%S+)%s.*%s(%S+)$")
        local targetName = targetTitle .. " " .. targetName

        -- export requested items from refined storage
        local exportPeripheralName = peripheral.getName(self.inventoryPeripheral)
        amountProvided, err = self.rsBridge.exportItemToPeripheral({ name=requestedItem.name, count=amountRequested }, exportPeripheralName)
        if err ~= nil then
            print(err)
        end

        -- start autocrafting if possible
        resultColor = 0x2000
        if amountProvided < amountRequested then
            if self.rsBridge.isItemCrafting({name=requestedItem.name, count=amountRequested}) then
                resultColor = 0x10
                print("[Crafting]", amountRequested, "x", requestedItem.name)
            elseif self.rsBridge.craftItem({name=requestedItem.name, count=amountRequested}) then
                resultColor = 0x10
                print("[Scheduled]", amountRequested, "x", requestedItem.name)
            else
                resultColor = 0x4000
                print("[Failed]", requestedItem.name)
            end
        end

        -- sort requests
        if colonyRequest.desc:match(MAX_EQUIPMENT_LEVEL_MATCHER) ~= nil then
            local equipmentLevel = colonyRequest.desc:match(MAX_EQUIPMENT_LEVEL_MATCHER)
            local requestName = equipmentLevel .. " " .. colonyRequest.name
            table.insert(equipmentRequests, { name=requestName, item=requestedItem.name, target=targetName, requested=amountRequested, provided=amountProvided, displayColor=resultColor })
        elseif colonyRequest.target:match(BUILDER_MATCHER) ~= nil then
            table.insert(builderRequests, { name=colonyRequest.name, item=requestedItem.name, target=targetName, requested=amountRequested, provided=amountProvided, displayColor=resultColor })
        else
            table.insert(otherRequests, { name=colonyRequest.name, item=requestedItem.name, target=targetName, requested=amountRequested, provided=amountProvided, displayColor=resultColor })
        end
    end

    -- display requests
    self:_updateRequestList(equipmentRequests, builderRequests, otherRequests)
end

-- logic loop, should be called every second
function WarehouseManager:tick()
    self:_updateHeader()

    -- skip if its currently night => citizen will sleep anyway
    local dayPhase = getCurrentDayCycle();
    if dayPhase == "night" then return end

    -- reset countdown and handle colony requests
    self.secondsUntilNextScan = self.secondsUntilNextScan - 1
    if self.secondsUntilNextScan <= 0 then
        self:_handleRequests()
        self.secondsUntilNextScan = self.updateInterval
    end
end

-- force-triggers the colony request handling, also resets the timer
function WarehouseManager:triggerRequestHandling()
    self:_updateHeader()
    self:_handleRequests()
    self.secondsUntilNextScan = self.updateInterval
end

return WarehouseManager