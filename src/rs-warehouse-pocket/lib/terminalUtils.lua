local lib = {};

-- prepares the terminal for later use
function lib.initTerminal(textColor, bgColor, enableCursorBlink)
    textColor = textColor or 0x1 -- white
    bgColor = bgColor or 0x800 -- black
    enableCursorBlink = enableCursorBlink or false

    term.setTextColor(textColor)
    term.setBackgroundColor(bgColor)
    term.setCursorPos(1, 1)
    term.setCursorBlink(enableCursorBlink)
    term.clear() -- clear last to apply changes
end

-- writes the text at a specific line with the given alignment
-- alignment: "START", "CENTER", "END"
function lib.writeLineJustified(row, align, text, textColor, bgColor)
    local width, height = term.getSize()
    local origTextColor = term.getTextColor()
    local origBgColor = term.getBackgroundColor()

    -- calculate x position
    local x = 1
    if align == "START" then x = 1 end
    if align == "CENTER" then x = math.floor((width - #text) / 2) end
    if align == "END" then x = width - #text end

    -- draw
    term.setTextColor(textColor or term.getTextColor())
    term.setBackgroundColor(bgColor or term.getBackgroundColor())
    term.setCursorPos(x, row)
    term.write(text)
    term.setTextColor(origTextColor)
    term.setBackgroundColor(origBgColor)
end

-- clears all rows of the terminal in the given range
function lib.clearRows(startRow, endRow)
    local monWidth, monHeight = term.getSize()
    endRow = endRow or monHeight
    for y=startRow,endRow,1 do
        term.setCursorPos(1,y)
        for i=1,monWidth do
            term.write(" ")
        end
    end
end

return lib