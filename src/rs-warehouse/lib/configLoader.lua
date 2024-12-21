local lib = {}

local CONFIG_DEFAULTS = {
    hostname = "rsWarehouse",
    updateInterval = 15,
    use24HourFormat = true
}

function lib.update(filename, config)
    local createFileHandle = fs.open(filename, "w+")
    local defaultSettingsJson = textutils.serializeJSON(config)
    createFileHandle.write(defaultSettingsJson)
    createFileHandle.close()
end

function lib.load(filename)
    if not fs.exists(filename) then
        lib.update(filename, CONFIG_DEFAULTS)
    end

    -- load config
    local readFileHandle = fs.open(filename, "r")
    local configFileContent = readFileHandle.readAll()
    return textutils.unserialiseJSON(configFileContent)
end

return lib