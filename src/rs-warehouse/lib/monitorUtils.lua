local lib = {};

-- returns all connected monitor peripherals.
-- this includes monitors connected directly to the computer
-- or placed on the same network as the computer (modems)
function lib.getMonitors()
    local monitors = {}
    local peripheralNames = peripheral.getNames()

    -- get all connected monitors connected by modems
    -- they will get listed using their device name
    for i, peripheralName in ipairs(peripheralNames) do
        if peripheralName:find("monitor_", 1, true) == 1 then
            table.insert(monitors, peripheral.wrap(peripheralName))
        end
    end

    -- get all directly connected monitors
    -- they will get listed as the side they are connected on
    for i, side in ipairs(redstone.getSides()) do
        if peripheral.getType(side) == "monitor" then
            table.insert(monitors, peripheral.wrap(side))
        end
    end

    return monitors
end

-- prepares the monitors for later use
function lib.initMonitor(monitor, textScale, textColor, bgColor, enableCursorBlink)
    textScale = textScale or 1
    textColor = textColor or 0x1 -- white
    bgColor = bgColor or 0x800 -- black
    enableCursorBlink = enableCursorBlink or false

    monitor.setTextColor(textColor)
    monitor.setTextScale(textScale)
    monitor.setBackgroundColor(bgColor)
    monitor.setCursorPos(1, 1)
    monitor.setCursorBlink(enableCursorBlink)
    monitor.clear() -- clear last to apply changes
end

-- prepares the monitors for later use
function lib.initMonitors(monitors, textScale, textColor, bgColor, enableCursorBlink)
    for i, monitor in ipairs(monitors) do
        lib.initMonitor(monitor, textScale, textColor, bgColor, enableCursorBlink)
    end
end

-- writes the text at a specific line with the given alignment
-- alignment: "START", "CENTER", "END"
function lib.writeLineJustified(monitor, row, align, text, textColor, bgColor)
    local width, height = monitor.getSize()
    local origTextColor = monitor.getTextColor()
    local origBgColor = monitor.getBackgroundColor()

    -- calculate x position
    local x = 1
    if align == "START" then x = 1 end
    if align == "CENTER" then x = math.floor((width - #text) / 2) end
    if align == "END" then x = width - #text end

    -- draw
    monitor.setTextColor(textColor or monitor.getTextColor())
    monitor.setBackgroundColor(bgColor or monitor.getBackgroundColor())
    monitor.setCursorPos(x, row)
    monitor.write(text)
    monitor.setTextColor(origTextColor)
    monitor.setBackgroundColor(origBgColor)
end

-- writes the text at a specific line with the given alignment
-- on multiple monitors
-- alignment: "START", "CENTER", "END"
function lib.writeLineJustifiedMultiple(monitors, row, align, text, textColor, bgColor)
    for i, monitor in ipairs(monitors) do
        lib.writeLineJustified(monitor, row, align, text, textColor, bgColor)
    end
end

-- clears all rows of a monitor in the given range
function lib.clearRows(monitors, startRow, endRow)
    for i, monitor in ipairs(monitors) do
        local monWidth, monHeight = monitor.getSize()
        endRow = endRow or monHeight
        for y=startRow,endRow,1 do
            monitor.setCursorPos(1,y)
            for i=1,monWidth do
                monitor.write(" ")
            end
        end
    end
end

return lib