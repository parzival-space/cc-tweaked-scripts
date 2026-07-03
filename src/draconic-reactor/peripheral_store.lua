local PeripheralStore = {
    store = {},
    path = "",
}

function PeripheralStore:new(instance, path)
    -- constructor
    instance = instance or {}
    setmetatable(instance, self)
    self.__index = self

    self.path = path
    if not fs.exists(path) then
        self:reset()
    end

    local handle = fs.open(path, "r")
    self.store = textutils.unserialiseJSON(handle.readAll())
    handle.close()

    return instance
end

function PeripheralStore:load(key)
    if not self.store[key] then
        return nil
    else
        return peripheral.wrap(self.store[key])
    end
end

function PeripheralStore:save(key, peripheral_instance)
    local peripheral_name = peripheral.getName(peripheral_instance)
    self.store[key] = peripheral_name

    -- write file
    local store_json = textutils.serialiseJSON(self.store)
    local handle = fs.open(self.path, "w+")
    handle.writeLine(store_json)
    handle.close()
end

function PeripheralStore:load_or_find(key, find_key, find_filter)
    local load_result = self:load(key)
    if not load_result then
        print("Could not resolve stored peripheral " .. key ..". Trying to find it.")
        load_result = peripheral.find(find_key, find_filter)
    else
        print("Resolved stored peripheral " .. key .. " as " .. peripheral.getName(load_result))
    end
    self:save(key, load_result)
    return load_result
end

function PeripheralStore:reset()
    local handle = fs.open(self.path, "w+")
    handle.writeLine("{}")
    handle.close()
    self.store = {}
end

return PeripheralStore