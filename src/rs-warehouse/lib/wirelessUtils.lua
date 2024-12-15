local lib = {}

-- tries to find a wireless modem.
-- will prioritize all directly connected modems over modems
-- connected using a wired modem
function lib.getWirelessModem()
    local modem = nil

    -- get all directly connected modems
    -- they will get listed as the side they are connected on
    for i, side in ipairs(redstone.getSides()) do
        if peripheral.getType(side) == "modem" then
            local possibleWirelessModem = peripheral.wrap(side)
            if possibleWirelessModem.isWireless() then
                modem = possibleWirelessModem
            end
        end
    end

    -- if a modem was alread found, return
    if modem ~= nil then
        return modem
    end

    -- get all wireless modems connected by wired modems
    -- they will get listed using their device name
    local peripheralNames = peripheral.getNames()
    for i, peripheralName in ipairs(peripheralNames) do
        if peripheralName:find("modem_", 1, true) == 1 then
            local possibleWirelessModem = peripheral.wrap(peripheralName)
            if possibleWirelessModem.isWireless() then
                modem = possibleWirelessModem
            end
        end
    end

    return modem
end

-- prepares the modem for hosting a message protocol using rednet
function lib.initModemHost(modem, protocol, hostname)
    rednet.open(peripheral.getName(modem))
    rednet.host(protocol, hostname)
end

return lib