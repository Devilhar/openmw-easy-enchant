
local async = require('openmw.async')
local core = require('openmw.core')
local interfaces = require('openmw.interfaces')
local self = require('openmw.self')
local storage = require('openmw.storage')
local types = require('openmw.types')
local ui = require("openmw.ui")

local enabledModes = {
    ['Enchanting'] = true,
    ['Recharge'] = true,
}

interfaces.Settings.registerPage {
    key = "EasyEnchant",
    l10n = "EasyEnchant",
    name = "EasyEnchant",
    description = ""
}
interfaces.Settings.registerGroup {
    key = "SettingsEasyEnchant",
    page = "EasyEnchant",
    l10n = "EasyEnchant",
    name = 'Settings',
    permanentStorage = true,
    settings = {
        {
            key = "UseOwnedContainers",
            renderer = "checkbox",
            name = "Allow using Owned Containers",
            description = "If set to true, you will be able to use soul gems from containers that are owned by other actors.",
            default = false
        },
        {
            key = "UseDeadBodies",
            renderer = "checkbox",
            name = "Allow using Dead Bodies",
            description = "If set to true, you will be able to use soul gems from nearby dead creatures or NPCs. Note that they may despawn if they are permanent.",
            default = false
        },
    }
}

local settings = storage.playerSection("SettingsEasyEnchant")

settings:subscribe(async:callback(function(section, key)
    if key then
        core.sendGlobalEvent("EasyEnchantSettingUpdated", { key = key, value = settings:get(key) })
    end
end))

local function UiModeChanged(data)
    if enabledModes[data.newMode] and not enabledModes[data.oldMode] then
        core.sendGlobalEvent('EasyEnchantEnter', { player = self, openUI = false })
    elseif not enabledModes[data.newMode] and enabledModes[data.oldMode] then
        core.sendGlobalEvent('EasyEnchantExit', { player = self })
    end
end

local function EasyEnchantOpenUI(data)
    if not data or not data.omitEnterEvent then
        core.sendGlobalEvent('EasyEnchantEnter', { player = self, openUI = true })

        return
    end

    local miscellaneous = types.Actor.inventory(self):getAll(types.Miscellaneous)

    for _, misc in ipairs(miscellaneous) do
        local itemData = types.Item.itemData(misc)

        if itemData.soul then
            interfaces.UI.addMode(interfaces.UI.MODE.Enchanting, { target = misc })

            return
        end
    end

    ui.showMessage('No soul gems available')
    core.sendGlobalEvent('EasyEnchantExit', { player = self })
end

return {
    eventHandlers = {
        UiModeChanged = UiModeChanged,
        EasyEnchantOpenUI = EasyEnchantOpenUI,
    }
}
