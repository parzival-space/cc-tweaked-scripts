local terminalUtils = require("lib/terminalUtils")
local wirelessUtils = require("lib/wirelessUtils")
local configLoader = require("lib/configLoader")
local WarehouseManagerClient = require("WarehouseManagerClient")

-- load config
local config = configLoader.load("rsWarehousePocket.json")

-- init devices
terminalUtils.initTerminal(0x1, 0x8000, false)
local modem = wirelessUtils.getWirelessModem()

local client = WarehouseManagerClient:new(nil, modem, config.targetHostname, config.use24HourFormat)

-- main loop
parallel.waitForAll(
    function()
        while true do
            client:handle()
        end
    end
)