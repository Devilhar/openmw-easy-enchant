
local core = require('openmw.core')
local interfaces = require('openmw.interfaces')
local storage = require("openmw.storage")
local types = require("openmw.types")
local world = require("openmw.world")

local settings = storage.globalSection("SettingsEasyEnchant")

local function getInventory(object)
    if (object.type == types.NPC or object.type == types.Creature or object.type == types.Player) then
        return types.Actor.inventory(object)
    elseif (object.type == types.Container) then
        return types.Container.content(object)
    end
end

local function isValidTargetContainer(cont)
    if settings:get("UseOwnedContainers") then
        return true
    end

    if cont.owner.recordId or cont.owner.factionId then
        return false
    end

    return true
end
local function isValidTargetActor(cont)
    return types.Actor.stats.dynamic.health(cont).current == 0
end

local validTargetFuncs = {
    [types.Container] = isValidTargetContainer,
    [types.Creature] = isValidTargetActor,
    [types.NPC] = isValidTargetActor,
}

local function containerIsValid(cont)
    local validFunc = validTargetFuncs[cont.type]

    if not validFunc then
        return false
    end

    return validFunc(cont)
end

local function collectItemsFromContainer(player, cont, outItemsTable)
    if not containerIsValid(cont) then
        return
    end

    local inventory = getInventory(cont)

    if not inventory:isResolved() then
        return
    end

    local miscellaneous = inventory:getAll(types.Miscellaneous)

    for _, misc in ipairs(miscellaneous) do
        local itemData = types.Item.itemData(misc)

        if itemData.soul then
            if not outItemsTable[misc.recordId] then
                outItemsTable[misc.recordId] = {}
            end

            if not outItemsTable[misc.recordId][itemData.soul] then
                outItemsTable[misc.recordId][itemData.soul] = {}
            end

            outItemsTable[misc.recordId][itemData.soul][cont] = misc.count

            misc:moveInto(types.Actor.inventory(player))
        end
    end
end

local function collectItems(player)
    local itemsTable = {}

    for _, cont in ipairs(player.cell:getAll(types.Container)) do
        collectItemsFromContainer(player, cont, itemsTable)
    end

    if settings:get("UseDeadBodies") then
        for _, cont in ipairs(player.cell:getAll(types.NPC)) do
            collectItemsFromContainer(player, cont, itemsTable)
        end
        for _, cont in ipairs(player.cell:getAll(types.Creature)) do
            collectItemsFromContainer(player, cont, itemsTable)
        end
    end
    --[[
    if I.CCC_cont and I.CCC_cont.getContainersCarriedByPlayer then
        table.insert(allConts, I.CCC_cont.getContainersCarriedByPlayer())
        if I.CCC_cont.getContainersNearbyPlayer then
            table.insert(allConts, I.CCC_cont.getContainersNearbyPlayer())
        end
    end
    ]]

    if next(itemsTable) == nil then
        return nil
    end

    return itemsTable
end

local function returnItems(player, itemsTable)
    local miscellaneous = types.Actor.inventory(player):getAll(types.Miscellaneous)

    for _, misc in ipairs(miscellaneous) do
        local csouls = itemsTable[misc.recordId]

        if csouls then
            local itemData = types.Item.itemData(misc)

            local ccontainers = csouls[itemData.soul]

            if ccontainers then
                for container, count in pairs(ccontainers) do
                    misc:split(math.min(count, misc.count)):moveInto(container)

                    if misc.count == 0 then
                        break
                    end
                end
            end
        end
    end
end

local function onActivateMiscellaneous(object, actor)
    if core.isWorldPaused() then
        return true
    end

    local mwscript = world.mwscript.getLocalScript(object)

    if not mwscript or mwscript.variables.easyenchant == nil then
        return true
    end

    actor:sendEvent('EasyEnchantOpenUI')

    return false
end

interfaces.Activation.addHandlerForType(types.Miscellaneous, onActivateMiscellaneous)

-- [item.recordId][soul.recordId][container] = count
local itemsTable = nil

local function EasyEnchantEnter(data)
    if itemsTable then
        return
    end

    itemsTable = collectItems(data.player)

    if data.openUI then
        data.player:sendEvent('EasyEnchantOpenUI', { omitEnterEvent = true })
    end
end

local function EasyEnchantExit(data)
    returnItems(data.player, itemsTable)

    itemsTable = nil
end

local function EasyEnchantSettingUpdated(data)
    settings:set(data.key, data.value)
end

return {
    eventHandlers  = {
        EasyEnchantEnter = EasyEnchantEnter,
        EasyEnchantExit = EasyEnchantExit,
        EasyEnchantSettingUpdated = EasyEnchantSettingUpdated,
    }
}
