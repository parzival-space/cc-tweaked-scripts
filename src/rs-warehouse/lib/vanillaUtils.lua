local lib = {}

-- items: wood = gold < stone < iron < diamond < netherite
-- armro: leather < chainmail = golden < iron < turtle < diamond < netherite
local VANILLA_ITEM_TIERS = {
    ["wooden"] = 0,
    ["golden"] = 0,
    ["leather"] = 0,
    ["stone"] = 1,
    ["chainmail"] = 1,
    ["iron"] = 2,
    ["diamond"] = 3,
    ["netherite"] = 4
}

function lib.getHighestItemByLevel(items)
    local highestLevel = -1
    local highestItem = nil

    for _, itemName in ipairs(items) do
        local itemLevelName = string.match(itemName, "minecraft:([^_]+)")
        local itemLevel = VANILLA_ITEM_TIERS[itemLevelName]
        if itemLevel and itemLevel > highestLevel then
            highestLevel = itemLevel
            highestItem = itemName
        end
    end

    return highestItem
end

return lib