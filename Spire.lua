local SPIRE_ID, DISENCHANT_ID = 287025, 13262
local MAIN_HAND, OFF_HAND = 16, 17
local container = C_Container or _G
local bagSize = container.GetContainerNumSlots or GetContainerNumSlots
local bagLink = container.GetContainerItemLink or GetContainerItemLink
local bagInfo = container.GetContainerItemInfo or GetContainerItemInfo
local bagFree = container.GetContainerNumFreeSlots or GetContainerNumFreeSlots
local pickupBag = container.PickupContainerItem or PickupContainerItem
local itemInfo = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant

local function message(text)
    print("|cff00bfffDisenchantTooltip:|r " .. text)
end

if not (bagSize and bagLink and bagInfo and bagFree and pickupBag and itemInfo
    and PickupInventoryItem and GetInventoryItemLink and GetCursorInfo and CursorHasItem
    and InCombatLockdown and SpellIsTargeting and C_Timer and C_Timer.After) then
    message("Spire button disabled: a required inventory or spell API is unavailable.")
    return
end

local button = CreateFrame("Button", "DisenchantTooltipSpireButton", UIParent, "SecureActionButtonTemplate")
button:RegisterForClicks("AnyUp")
button:SetAttribute("spell", DISENCHANT_ID)
button:SetAttribute("useOnKeyDown", false)

local phase, generation, attempts = "idle", 0, 0
local restorePending = false

local function itemKey(link)
    return link and (link:match("item:[^|]+") or link) or false
end

local function itemId(link)
    return link and tonumber(link:match("item:(%d+)"))
end

local function worn(slot)
    return GetInventoryItemLink("player", slot)
end

local function validSaved(saved)
    local function validItem(value)
        return value == false or (type(value) == "string" and value:match("^item:%d+"))
    end
    return type(saved) == "table" and validItem(saved.main) and validItem(saved.off)
end

local function inCombat()
    return InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player"))
end

local function scanBags(predicate)
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for index = 1, bagSize(bag) do
            local link = bagLink(bag, index)
            if predicate(bag, index, link) then return bag, index end
        end
    end
end

local function locked(bag, index)
    local info, _, isLocked = bagInfo(bag, index)
    return type(info) == "table" and info.isLocked or isLocked
end

local function emptyBagSlot()
    return scanBags(function(bag, index, link)
        local _, family = bagFree(bag)
        return not link and (family == 0 or (bag == 0 and family == nil)) and not locked(bag, index)
    end)
end

local function setAction(enabled)
    if inCombat() then return false end
    button:SetAttribute("type", enabled and "spell" or nil)
    return true
end

local function later(delay, callback)
    local current = generation
    C_Timer.After(delay, function()
        if current == generation then callback() end
    end)
end

local function stopAction()
    generation = generation + 1
    if not setAction(false) then
        restorePending = true
        message("Waiting for combat to end before disabling the button and restoring weapons. Do not use the macro until then.")
        return false
    end
    return true
end

local function moveFromBag(bag, index, slot)
    pickupBag(bag, index)
    if not CursorHasItem() then return false end
    PickupInventoryItem(slot)
    if CursorHasItem() and not bagLink(bag, index) then pickupBag(bag, index) end
    if CursorHasItem() then
        local emptyBag, emptyIndex = emptyBagSlot()
        if emptyBag then pickupBag(emptyBag, emptyIndex) end
    end
    if CursorHasItem() then
        message("An item remains on your cursor. Place it in a bag, then use /dtspire restore.")
        return false
    end
    return true
end

local restore
local function retryRestore()
    attempts = attempts + 1
    if attempts <= 10 then
        later(0.3, restore)
    else
        phase = "restore"
        message("Could not restore weapons. Check your bags and cursor, then use /dtspire restore.")
    end
end

restore = function()
    local saved = DisenchantTooltipSpireRestore
    if not saved then
        phase, restorePending = "idle", false
        return
    end
    phase = "restore"
    if not validSaved(saved) then
        message("Saved weapon restore data is invalid. Restore manually, then use /dtspire forget.")
        return
    end
    if inCombat() then
        restorePending = true
        return
    end
    restorePending = false
    if GetCursorInfo() then
        message("Clear your cursor, then use /dtspire restore.")
        return
    end

    local main, off = itemKey(worn(MAIN_HAND)), itemKey(worn(OFF_HAND))
    if main ~= saved.main and itemId(worn(MAIN_HAND)) ~= SPIRE_ID and main ~= false then
        message("Main-hand equipment changed. Restore weapons manually or put the Spire back and use /dtspire restore.")
        return
    end
    if off ~= saved.off and off ~= false then
        message("Off-hand equipment changed. Restore weapons manually, then use /dtspire forget.")
        return
    end

    for _, slot in ipairs({ MAIN_HAND, OFF_HAND }) do
        local target = saved.off
        if slot == MAIN_HAND then target = saved.main end
        if itemKey(worn(slot)) ~= target then
            if IsInventoryItemLocked and IsInventoryItemLocked(slot) then
                retryRestore()
                return
            end
            if target == false then
                local bag, index = emptyBagSlot()
                if not bag then
                    message("No free general bag slot for the Spire. Free a slot, then use /dtspire restore.")
                    return
                end
                PickupInventoryItem(slot)
                if CursorHasItem() then pickupBag(bag, index) end
                if CursorHasItem() then
                    message("An item remains on your cursor. Place it in a bag, then use /dtspire restore.")
                    return
                end
            else
                local bag, index = scanBags(function(b, i, link)
                    return itemKey(link) == target and not locked(b, i)
                end)
                if not bag then
                    retryRestore()
                    return
                end
                if not moveFromBag(bag, index, slot) then return end
            end
            retryRestore()
            return
        end
    end

    DisenchantTooltipSpireRestore = nil
    phase, attempts = "idle", 0
    message("Previous weapons restored.")
end

local function beginRestore()
    if SpellIsTargeting() then
        message("Cancel spell targeting before restoring your weapons.")
        return
    end
    if not stopAction() then
        phase = "restore"
        return
    end
    attempts = 0
    restore()
end

local function ready()
    if inCombat() then
        phase = "restore"
        restorePending = true
        message("Combat started while preparing. Weapons will be restored after combat.")
        return
    end
    if DisenchantTooltipSpireRestore and itemId(worn(MAIN_HAND)) ~= SPIRE_ID then
        beginRestore()
        message("Could not equip the Spire; Disenchant was not cast.")
        return
    end
    phase = "ready"
    setAction(true)
    message("Ready. Press the macro again, then select an item to disenchant.")
end

local function prepare()
    if inCombat() then
        message("Prepare the Spire button outside combat; the secure action cannot be configured in combat.")
        return
    end
    if GetCursorInfo() or SpellIsTargeting() then
        message("Clear your cursor before using the Spire button.")
        return
    end
    if DisenchantTooltipSpireRestore then
        message("A weapon restore is pending. Use /dtspire restore first.")
        return
    end
    if itemId(worn(MAIN_HAND)) == SPIRE_ID then
        phase = "preparing"
        later(0, ready)
        return
    end
    local bag, index = scanBags(function(_, _, link) return itemId(link) == SPIRE_ID end)
    if not bag then
        phase = "preparing"
        message("Spire not found in your bags; normal Disenchant will be used.")
        later(0, ready)
        return
    end
    if locked(bag, index) or (IsInventoryItemLocked
        and (IsInventoryItemLocked(MAIN_HAND) or IsInventoryItemLocked(OFF_HAND))) then
        message("The Spire or a weapon slot is busy. Try again.")
        return
    end
    local link = bagLink(bag, index)
    local _, _, _, equipLoc = itemInfo(link)
    if equipLoc ~= "INVTYPE_2HWEAPON" and equipLoc ~= "INVTYPE_WEAPON"
        and equipLoc ~= "INVTYPE_WEAPONMAINHAND" then
        message("Cannot prepare the Spire: its weapon information is unavailable or unexpected.")
        return
    end
    if equipLoc == "INVTYPE_2HWEAPON" and worn(OFF_HAND) and not emptyBagSlot() then
        message("Free a general bag slot for your off-hand weapon before equipping the Spire.")
        return
    end
    DisenchantTooltipSpireRestore = { main = itemKey(worn(MAIN_HAND)), off = itemKey(worn(OFF_HAND)) }
    phase = "preparing"
    if not moveFromBag(bag, index, MAIN_HAND) then
        message("Could not move the Spire. Use /dtspire restore after clearing your cursor.")
        phase = "restore"
        return
    end
    later(0.5, ready)
end

button:SetScript("PreClick", function()
    if phase == "idle" then prepare() end
end)

button:SetScript("PostClick", function()
    if phase ~= "ready" then return end
    phase = "targeting"
    setAction(false)
    later(0.5, function()
        local function checkTarget()
            if phase ~= "targeting" then return end
            if SpellIsTargeting() then
                later(0.2, checkTarget)
            else
                beginRestore()
            end
        end
        checkTarget()
    end)
end)

local frame = CreateFrame("Frame")
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_REGEN_ENABLED", "PLAYER_EQUIPMENT_CHANGED", "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_STOP" }) do
    frame:RegisterEvent(event)
end
frame:SetScript("OnEvent", function(_, event, unit, _, spellId)
    if event == "ADDON_LOADED" and unit == "DisenchantTooltip" then
        if DisenchantTooltipSpireRestore then
            local saved = DisenchantTooltipSpireRestore
            if not validSaved(saved) then
                message("Saved weapon restore data is invalid. No gear was moved; use /dtspire forget to clear it.")
                phase = "restore"
                return
            end
            phase = "restore"
            message("A previous weapon restore is pending. Use /dtspire restore.")
        end
    elseif event == "PLAYER_REGEN_ENABLED" and restorePending then
        restorePending = false
        beginRestore()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" and phase == "ready"
        and DisenchantTooltipSpireRestore and itemId(worn(MAIN_HAND)) ~= SPIRE_ID then
        message("The Spire is no longer equipped; the prepared action is being cancelled.")
        beginRestore()
    elseif unit == "player" and spellId == DISENCHANT_ID then
        if event == "UNIT_SPELLCAST_START" and phase == "targeting" then
            phase = "casting"
        elseif (phase == "targeting" or phase == "casting")
            and (event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_FAILED"
                or event == "UNIT_SPELLCAST_INTERRUPTED") then
            beginRestore()
        elseif phase == "casting" and event == "UNIT_SPELLCAST_STOP" then
            later(0.5, function()
                if phase == "casting" then beginRestore() end
            end)
        end
    end
end)

SLASH_DISENCHANTTOOLTIPSpire1 = "/dtspire"
SlashCmdList.DISENCHANTTOOLTIPSpire = function(text)
    if text == "restore" then
        if phase == "casting" then
            message("Wait for the Disenchant cast to finish before restoring weapons.")
            return
        end
        beginRestore()
    elseif text == "forget" then
        if not stopAction() then return end
        DisenchantTooltipSpireRestore = nil
        phase, restorePending = "idle", false
        message("Saved weapons forgotten. No gear was moved.")
    else
        message("Use /dtspire restore to retry restoring weapons, or /dtspire forget after restoring them manually.")
    end
end
