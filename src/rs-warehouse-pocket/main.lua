local terminalUtils = require("lib/terminalUtils")
local wirelessUtils = require("lib/wirelessUtils")
local WarehouseManagerClient = require("WarehouseManagerClient")

-- init devices
terminalUtils.initTerminal(0x1, 0x8000, false)
local modem = wirelessUtils.getWirelessModem()

local client = WarehouseManagerClient:new(nil, modem, "rsWarehouse", true)

-- main loop
parallel.waitForAll(
    function()
        while true do
            client:handle()
        end
    end
)