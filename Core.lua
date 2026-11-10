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

local function getItemId(tooltip)
    local _, itemLink = tooltip:GetItem()
    if type(itemLink) ~= "string" then
        return nil
    end

    return tonumber(itemLink:match("item:(%d+)"))
end

local function addDisenchantData(tooltip)
    local data = DisenchantTooltipData
    if type(data) ~= "table" or type(data.items) ~= "table" then
        return
    end

    local itemId = getItemId(tooltip)
    if itemId == nil or tooltip.__disenchantTooltipItemId == itemId then
        return
    end

    local entries = data.items[itemId]
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
    local isMock = data.source and data.source.mode == "mock"
    tooltip:AddLine(isMock and "Disenchanting (mock data)" or "Disenchanting", 0.55, 0.82, 1)

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

    tooltip:Show()
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

hookTooltip(GameTooltip)
hookTooltip(ItemRefTooltip)
hookTooltip(ShoppingTooltip1)
hookTooltip(ShoppingTooltip2)
