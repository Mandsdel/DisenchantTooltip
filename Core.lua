local addonName = ...

local classicUncommonTiers = {
    { minimum = 1, maximum = 15, dust = "Strange Dust", dustMinimum = 1, dustMaximum = 2, armorDust = 0.80, essence = "Lesser Magic Essence", essenceMinimum = 1, essenceMaximum = 2, armorEssence = 0.20 },
    { minimum = 16, maximum = 20, dust = "Strange Dust", dustMinimum = 2, dustMaximum = 3, armorDust = 0.75, essence = "Greater Magic Essence", essenceMinimum = 1, essenceMaximum = 2, armorEssence = 0.20, shard = "Small Glimmering Shard", shardChance = 0.05 },
    { minimum = 21, maximum = 25, dust = "Strange Dust", dustMinimum = 4, dustMaximum = 6, armorDust = 0.75, essence = "Lesser Astral Essence", essenceMinimum = 1, essenceMaximum = 2, armorEssence = 0.15, shard = "Small Glimmering Shard", shardChance = 0.10 },
    { minimum = 26, maximum = 30, dust = "Soul Dust", dustMinimum = 1, dustMaximum = 2, armorDust = 0.75, essence = "Greater Astral Essence", essenceMinimum = 1, essenceMaximum = 2, armorEssence = 0.20, shard = "Large Glimmering Shard", shardChance = 0.05 },
    { minimum = 31, maximum = 35, dust = "Soul Dust", dustMinimum = 2, dustMaximum = 5, armorDust = 0.75, essence = "Lesser Mystic Essence", essenceMinimum = 1, essenceMaximum = 2, armorEssence = 0.20, shard = "Small Glowing Shard", shardChance = 0.05 },
    { minimum = 36, maximum = 40, dust = "Vision Dust", dustMinimum = 1, dustMaximum = 2, armorDust = 0.75, essence = "Greater Mystic Essence", essenceMinimum = 1, essenceMaximum = 2, armorEssence = 0.20, shard = "Large Glowing Shard", shardChance = 0.05 },
    { minimum = 41, maximum = 45, dust = "Vision Dust", dustMinimum = 2, dustMaximum = 5, armorDust = 0.75, essence = "Lesser Nether Essence", essenceMinimum = 1, essenceMaximum = 2, armorEssence = 0.20, shard = "Small Radiant Shard", shardChance = 0.05 },
    { minimum = 46, maximum = 50, dust = "Dream Dust", dustMinimum = 1, dustMaximum = 2, armorDust = 0.75, essence = "Greater Nether Essence", essenceMinimum = 1, essenceMaximum = 2, armorEssence = 0.20, shard = "Large Radiant Shard", shardChance = 0.05 },
    { minimum = 51, maximum = 55, dust = "Dream Dust", dustMinimum = 2, dustMaximum = 5, armorDust = 0.75, essence = "Lesser Eternal Essence", essenceMinimum = 1, essenceMaximum = 2, armorEssence = 0.20, shard = "Small Brilliant Shard", shardChance = 0.05 },
    { minimum = 56, maximum = 60, dust = "Illusion Dust", dustMinimum = 1, dustMaximum = 2, armorDust = 0.75, essence = "Greater Eternal Essence", essenceMinimum = 1, essenceMaximum = 2, armorEssence = 0.20, shard = "Large Brilliant Shard", shardChance = 0.05 },
    { minimum = 61, maximum = 65, dust = "Illusion Dust", dustMinimum = 2, dustMaximum = 5, armorDust = 0.75, essence = "Greater Eternal Essence", essenceMinimum = 2, essenceMaximum = 3, armorEssence = 0.20, shard = "Large Brilliant Shard", shardChance = 0.05 },
}

local function isPositiveInteger(value)
    return type(value) == "number" and value > 0 and value == math.floor(value)
end

local function isValidEntry(entry, minimumSampleSize)
    if type(entry) ~= "table"
        or type(entry.name) ~= "string"
        or entry.name == ""
        or type(entry.probability) ~= "number"
        or entry.probability < 0
        or entry.probability > 1
        or not isPositiveInteger(entry.sampleSize)
        or entry.sampleSize < minimumSampleSize then
        return false
    end

    if entry.minQuantity ~= nil and not isPositiveInteger(entry.minQuantity) then
        return false
    end

    if entry.maxQuantity ~= nil
        and (not isPositiveInteger(entry.maxQuantity)
            or (entry.minQuantity ~= nil and entry.maxQuantity < entry.minQuantity)) then
        return false
    end

    return true
end

local function formatQuantity(entry)
    if entry.minQuantity == nil then
        return ""
    end

    if entry.maxQuantity == nil or entry.maxQuantity == entry.minQuantity then
        return string.format(" (%d)", entry.minQuantity)
    end

    return string.format(" (%d-%d)", entry.minQuantity, entry.maxQuantity)
end

local function isSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) and true or false
end

local function getItemIdFromLink(itemLink)
    if type(itemLink) ~= "string" or isSecret(itemLink) then
        return nil
    end

    return tonumber(itemLink:match("item:(%d+)"))
end

-- Comparison tooltips (ShoppingTooltip1/2) on Forever do not have GetItem, so prefer the
-- tooltip data supplied by TooltipDataProcessor.
local function getItemFromTooltipData(tooltipData)
    if type(tooltipData) ~= "table" then
        return nil
    end

    local itemLink = tooltipData.hyperlink
    if isSecret(itemLink) or type(itemLink) ~= "string" then
        itemLink = nil
    end

    local guid = tooltipData.guid
    if itemLink == nil
        and guid ~= nil
        and not isSecret(guid)
        and C_Item
        and type(C_Item.GetItemLinkByGUID) == "function" then
        itemLink = C_Item.GetItemLinkByGUID(guid)
        if isSecret(itemLink) or type(itemLink) ~= "string" then
            itemLink = nil
        end
    end

    local itemId = tooltipData.id
    if isSecret(itemId) or not isPositiveInteger(itemId) then
        itemId = getItemIdFromLink(itemLink)
    end

    if itemId == nil then
        return nil
    end

    return itemId, itemLink or itemId
end

local function getItemFromTooltip(tooltip)
    if type(tooltip.GetItem) ~= "function" then
        return nil
    end

    local _, itemLink = tooltip:GetItem()
    local itemId = getItemIdFromLink(itemLink)
    if itemId == nil then
        return nil
    end

    return itemId, itemLink
end

local function getClassicEstimate(itemLink)
    if not C_Item or type(C_Item.GetItemInfo) ~= "function" then
        return nil
    end

    local _, _, quality, itemLevel, _, _, _, _, _, _, _, classId = C_Item.GetItemInfo(itemLink)
    if quality ~= 2 or (classId ~= 2 and classId ~= 4) or type(itemLevel) ~= "number" then
        return nil
    end

    local tier
    for _, candidate in ipairs(classicUncommonTiers) do
        if itemLevel >= candidate.minimum and itemLevel <= candidate.maximum then
            tier = candidate
            break
        end
    end
    if tier == nil then
        return nil
    end

    local armor = classId == 4
    local dustChance = armor and tier.armorDust or 1 - tier.armorDust - (tier.shardChance or 0)
    local essenceChance = armor and tier.armorEssence or 1 - tier.armorEssence - (tier.shardChance or 0)
    local entries = {
        {
            name = tier.dust,
            probability = dustChance,
            minQuantity = tier.dustMinimum,
            maxQuantity = tier.dustMaximum,
            sampleSize = 1,
        },
        {
            name = tier.essence,
            probability = essenceChance,
            minQuantity = tier.essenceMinimum,
            maxQuantity = tier.essenceMaximum,
            sampleSize = 1,
        },
    }

    if tier.shard then
        table.insert(entries, {
            name = tier.shard,
            probability = tier.shardChance,
            minQuantity = 1,
            maxQuantity = 1,
            sampleSize = 1,
        })
    end

    return entries
end

local function getItemLevelGuess(itemLink)
    if not C_Item or type(C_Item.GetItemInfo) ~= "function" then
        return nil
    end

    local _, _, quality, itemLevel, _, _, _, _, _, _, _, classId = C_Item.GetItemInfo(itemLink)
    if (quality ~= 2 and quality ~= 3 and quality ~= 4)
        or (classId ~= 2 and classId ~= 4)
        or type(itemLevel) ~= "number" then
        return nil
    end

    local tier = classicUncommonTiers[#classicUncommonTiers]
    for _, candidate in ipairs(classicUncommonTiers) do
        if itemLevel <= candidate.maximum then
            tier = candidate
            break
        end
    end

    if quality == 3 then
        return {
            {
                name = tier.shard or "Small Glimmering Shard",
                probability = 1,
                minQuantity = 1,
                maxQuantity = 1,
                sampleSize = 1,
            },
        }
    end

    if quality == 4 then
        return {
            {
                name = tier.shard or "Small Glimmering Shard",
                probability = 1,
                minQuantity = 2,
                maxQuantity = 4,
                sampleSize = 1,
            },
        }
    end

    local armor = classId == 4
    local dustChance = armor and tier.armorDust or 1 - tier.armorDust - (tier.shardChance or 0)
    local essenceChance = armor and tier.armorEssence or 1 - tier.armorEssence - (tier.shardChance or 0)
    local entries = {
        {
            name = tier.dust,
            probability = dustChance,
            minQuantity = tier.dustMinimum,
            maxQuantity = tier.dustMaximum,
            sampleSize = 1,
        },
        {
            name = tier.essence,
            probability = essenceChance,
            minQuantity = tier.essenceMinimum,
            maxQuantity = tier.essenceMaximum,
            sampleSize = 1,
        },
    }

    if tier.shard then
        table.insert(entries, {
            name = tier.shard,
            probability = tier.shardChance,
            minQuantity = 1,
            maxQuantity = 1,
            sampleSize = 1,
        })
    end

    return entries
end

local function addDisenchantData(tooltip, tooltipData)
    local data = DisenchantTooltipData
    if type(data) ~= "table" or type(data.items) ~= "table" then
        return
    end

    local itemId, itemLink
    if tooltipData ~= nil then
        itemId, itemLink = getItemFromTooltipData(tooltipData)
    else
        itemId, itemLink = getItemFromTooltip(tooltip)
    end
    if itemId == nil or tooltip.__disenchantTooltipItemId == itemId then
        return
    end

    local sourceMode = data.source and data.source.mode
    local isMock = sourceMode == "mock"
    local isClassicEstimate = sourceMode == "classic-estimate"
    local entries = isMock and data.mockEntries
        or data.items[itemId]
    local isItemLevelGuess = false
    if isClassicEstimate then
        entries = getClassicEstimate(itemLink)
        if entries == nil then
            entries = getItemLevelGuess(itemLink)
            isItemLevelGuess = entries ~= nil
        end
    end
    if type(entries) ~= "table" then
        return
    end

    local minimumSampleSize = type(data.minimumSampleSize) == "number" and data.minimumSampleSize or 1
    local validEntries = {}
    for _, entry in ipairs(entries) do
        if isValidEntry(entry, minimumSampleSize) then
            table.insert(validEntries, entry)
        end
    end

    if #validEntries == 0 then
        return
    end

    table.sort(validEntries, function(left, right)
        if left.probability == right.probability then
            return left.name < right.name
        end
        return left.probability > right.probability
    end)

    tooltip.__disenchantTooltipItemId = itemId
    local title = "Disenchanting"
    if isMock then
        title = "Disenchanting (mock data)"
    elseif isClassicEstimate then
        title = isItemLevelGuess and "Disenchanting (item-level guess)" or "Disenchanting (Classic estimate)"
    end
    tooltip:AddLine(title, 0.55, 0.82, 1)

    for index = 1, math.min(3, #validEntries) do
        local entry = validEntries[index]
        tooltip:AddLine(string.format(
            "%s - %.0f%%%s",
            entry.name,
            entry.probability * 100,
            formatQuantity(entry)
        ), 1, 1, 1)
    end

    if not isMock and data.source and data.source.name == "ForeverDB.net" then
        tooltip:AddLine("Data from ForeverDB.net (https://foreverdb.net)", 0.5, 0.7, 0.9)
    elseif isClassicEstimate then
        tooltip:AddLine(isItemLevelGuess and "Rarity/level guess; may differ on Forever." or "Classic rules; may differ on Forever.", 1, 0.82, 0)
    end

    -- TooltipDataProcessor shows the tooltip itself after post-calls.
    if tooltipData == nil then
        tooltip:Show()
    end
end

local function clearTooltipState(tooltip)
    tooltip.__disenchantTooltipItemId = nil
end

local function hookTooltip(tooltip)
    if not tooltip or not tooltip.HasScript then
        return
    end

    if tooltip:HasScript("OnTooltipSetItem") then
        tooltip:HookScript("OnTooltipSetItem", addDisenchantData)
    end

    if tooltip:HasScript("OnTooltipCleared") then
        tooltip:HookScript("OnTooltipCleared", clearTooltipState)
    end
end

local usesNativeTooltipCallbacks = type(GameTooltip.GetPrimaryTooltipData) == "function"
    and TooltipDataProcessor
    and type(TooltipDataProcessor.AddTooltipPostCall) == "function"
    and Enum
    and Enum.TooltipDataType
    and Enum.TooltipDataType.Item

if usesNativeTooltipCallbacks then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, tooltipData)
        clearTooltipState(tooltip)
        addDisenchantData(tooltip, tooltipData or {})
    end)
else
    hookTooltip(GameTooltip)
    hookTooltip(ItemRefTooltip)
    hookTooltip(ShoppingTooltip1)
    hookTooltip(ShoppingTooltip2)
end
