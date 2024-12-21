local monitorUtils = require("lib/monitorUtils")
local wirelessUtils = require("lib/wirelessUtils")
local configLoader = require("lib/configLoader")
local WarehouseManager = require("WarehouseManager")

-- load config
local config = configLoader.load("rsWarehouse.json")

-- init devices
local monitors = monitorUtils.getMonitors()
monitorUtils.initMonitors(monitors, 0.75, 0x1, 0x8000, false)
local colonyIntegrator = peripheral.find("colonyIntegrator")
local rsBridge = peripheral.find("rsBridge")
local modem = wirelessUtils.getWirelessModem()
local inventory = peripheral.find("inventory")

local manager = WarehouseManager:new(nil, monitors, colonyIntegrator, rsBridge, inventory, modem, config.hostname, config.updateInterval, config.use24HourFormat)
local timer = os.startTimer(1)
parallel.waitForAll(
    -- logic loop of the warehouse manager, needs to be called every second
    function()
        while true do
            local event, sender = os.pullEvent("timer")
            if sender == timer then
                manager:tick()
                timer = os.startTimer(1)
            end
        end
    end,
    -- catch monitor clicks to force trigger request handling
    function()
        while true do
            os.pullEvent("monitor_touch")
            os.cancelTimer(timer)
            manager:triggerRequestHandling()
            timer = os.startTimer(1)
        end
    end
)