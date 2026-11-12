local callback
local guidCalls = 0
GameTooltip = { GetPrimaryTooltipData = function() end }
Enum = { TooltipDataType = { Item = 1 } }
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) callback = fn end }
issecretvalue = function(value) return value == "secret" end
C_Item = { GetItemLinkByGUID = function()
    guidCalls = guidCalls + 1
    return "item:42"
end }
DisenchantTooltipData = {
    source = { name = "ForeverDB.net", mode = "foreverdb" },
    minimumSampleSize = 1,
    items = {
        [42] = {
            { name = "Essence", probability = 0.25, minQuantity = 1, maxQuantity = 1, sampleSize = 5 },
            { name = "Dust", probability = 0.75, minQuantity = 1, maxQuantity = 2, sampleSize = 5 },
        },
    },
}
assert(loadfile("Core.lua"))("DisenchantTooltip")

local function check(data, expectedCalls, expectedLines)
    local lines = {}
    local tooltip = { AddLine = function(_, text) lines[#lines + 1] = text end }
    guidCalls = 0
    callback(tooltip, data)
    assert(guidCalls == expectedCalls)
    assert(#lines == expectedLines)
    if expectedLines > 0 then
        assert(lines[1] == "Disenchanting")
        assert(lines[2] == "Dust - 75% (1-2)")
        assert(lines[3] == "Essence - 25% (1)")
        assert(lines[4] == "Data from ForeverDB.net (https://foreverdb.net)")
    end
end

check({ id = 42, guid = "guid" }, 0, 4)
check({ hyperlink = "item:42", guid = "guid" }, 0, 4)
check({ guid = "guid" }, 1, 4)
check({ id = "secret", hyperlink = "item:42" }, 0, 4)
check({ hyperlink = "secret", guid = "guid" }, 1, 4)
check({ guid = "secret" }, 0, 0)
check({ id = 43, guid = "guid" }, 0, 0)
check({}, 0, 0)

local warnings = {}
local originalPrint = print
print = function(message) warnings[#warnings + 1] = message end
for _, mode in ipairs({ "classic-estimate", "mock", "foreverdb" }) do
    DisenchantTooltipData.source.mode = mode
    assert(loadfile("Core.lua"))("DisenchantTooltip")
end
print = originalPrint
assert(#warnings == 2)
assert(warnings[1]:find("Update Disenchant Data.cmd", 1, true))
assert(warnings[2]:find("Update Disenchant Data.cmd", 1, true))
print("DisenchantTooltip core checks passed")
