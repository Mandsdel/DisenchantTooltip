local addonName = ...

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

local function addDisenchantData(tooltip, tooltipData)
    local data = DisenchantTooltipData
    if type(data) ~= "table" or type(data.items) ~= "table" then
        return
    end

    local itemId
    if tooltipData ~= nil then
        itemId = getItemFromTooltipData(tooltipData)
    else
        itemId = getItemFromTooltip(tooltip)
    end
    if itemId == nil or tooltip.__disenchantTooltipItemId == itemId then
        return
    end

    local sourceMode = data.source and data.source.mode
    local isMock = sourceMode == "mock"
    local entries = isMock and data.mockEntries
        or data.items[itemId]
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
