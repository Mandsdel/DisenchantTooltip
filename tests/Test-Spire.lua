local frames, timers, messages = {}, {}, {}
local bags, equipped, cursor, targeting, combat, casts
local originalPrint = print
UIParent, SlashCmdList = {}, {}
NUM_BAG_SLOTS = 0

function CreateFrame(_, name)
    local frame = { scripts = {}, attributes = {} }
    function frame:SetScript(name, fn) self.scripts[name] = fn end
    function frame:RegisterEvent() end
    function frame:RegisterForClicks() end
    function frame:SetAttribute(name, value) self.attributes[name] = value end
    if name then frames[name] = frame else frames.events = frame end
    return frame
end
function print(text) messages[#messages + 1] = text end
function GetContainerNumSlots() return 4 end
function GetContainerItemLink(_, index) return bags[index] end
function GetContainerItemInfo() return { isLocked = false } end
function GetContainerNumFreeSlots() return 1, 0 end
function GetItemInfoInstant() return nil, nil, nil, "INVTYPE_2HWEAPON" end
function GetInventoryItemLink(_, slot) return equipped[slot] end
function GetCursorInfo() return cursor end
function CursorHasItem() return cursor ~= nil end
function InCombatLockdown() return combat end
function SpellIsTargeting() return targeting end
function PickupContainerItem(_, index) cursor, bags[index] = bags[index], cursor end
function PickupInventoryItem(slot)
    if slot == 16 and cursor == "item:287025" and equipped[17] then
        local empty
        for i = 1, 4 do if not bags[i] then empty = i; break end end
        assert(empty, "test requires a free bag slot")
        bags[empty], equipped[17] = equipped[17], nil
    end
    cursor, equipped[slot] = equipped[slot], cursor
end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }

local function tick()
    local queued = timers
    timers = {}
    for _, fn in ipairs(queued) do fn() end
end
local function click()
    local button = frames.DisenchantTooltipSpireButton
    button.scripts.PreClick(button)
    if button.attributes.type == "spell" then
        casts = casts + 1
        targeting = true
    end
    button.scripts.PostClick(button)
end
local function event(name, ...)
    frames.events.scripts.OnEvent(frames.events, name, ...)
end
local function reset(main, off, contents)
    bags, equipped = contents, { [16] = main, [17] = off }
    cursor, targeting, combat, casts = nil, false, false, 0
    timers, messages, frames = {}, {}, {}
    DisenchantTooltipSpireRestore = nil
    assert(loadfile("Spire.lua"))()
    event("ADDON_LOADED", "DisenchantTooltip")
end
local function finishRestore()
    for _ = 1, 5 do tick() end
end

reset("item:10", "item:11", { "item:287025" })
click()
assert(casts == 0 and equipped[16] == "item:287025" and not equipped[17])
tick()
click()
assert(casts == 1 and targeting)
tick()
assert(equipped[16] == "item:287025")
targeting = false
event("UNIT_SPELLCAST_START", "player", "cast", 13262)
tick()
assert(equipped[16] == "item:287025")
event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 13262)
finishRestore()
assert(equipped[16] == "item:10" and equipped[17] == "item:11")
assert(DisenchantTooltipSpireRestore == nil and not cursor)

-- A cancelled targeting cursor also restores an originally empty main hand.
reset(nil, "item:11", { "item:287025" })
click()
tick()
click()
targeting = false
tick()
finishRestore()
assert(not equipped[16] and equipped[17] == "item:11" and not cursor)

-- Do not prepare when a two-handed swap would displace an off-hand into a full bag.
reset("item:10", "item:11", { "item:287025", "item:20", "item:21", "item:22" })
click()
assert(equipped[16] == "item:10" and equipped[17] == "item:11" and casts == 0)
assert(DisenchantTooltipSpireRestore == nil and messages[#messages]:find("bag slot"))

-- Without the Spire, the same macro offers normal Disenchant.
reset("item:10", nil, {})
click()
tick()
click()
assert(casts == 1 and targeting and equipped[16] == "item:10")
targeting = false
tick()
assert(DisenchantTooltipSpireRestore == nil)

-- Restore is deferred during combat, and never attempted while targeting.
reset("item:10", nil, { "item:287025" })
click()
tick()
click()
SlashCmdList.DISENCHANTTOOLTIPSpire("restore")
assert(equipped[16] == "item:287025" and targeting)
targeting, combat = false, true
event("UNIT_SPELLCAST_INTERRUPTED", "player", "cast", 13262)
assert(equipped[16] == "item:287025")
combat = false
event("PLAYER_REGEN_ENABLED")
finishRestore()
assert(equipped[16] == "item:10" and not DisenchantTooltipSpireRestore)

-- A manual weapon change is never overwritten by the restore.
reset("item:10", nil, { "item:287025" })
click()
tick()
equipped[16] = "item:99"
event("PLAYER_EQUIPMENT_CHANGED", 16)
finishRestore()
assert(equipped[16] == "item:99" and DisenchantTooltipSpireRestore)
assert(messages[#messages]:find("changed"))

-- Invalid persisted state cannot move gear even when restoration is requested.
reset("item:10", nil, {})
DisenchantTooltipSpireRestore = { main = "invalid", off = false }
SlashCmdList.DISENCHANTTOOLTIPSpire("restore")
assert(equipped[16] == "item:10" and messages[#messages]:find("invalid"))
SlashCmdList.DISENCHANTTOOLTIPSpire("forget")
assert(not DisenchantTooltipSpireRestore and equipped[16] == "item:10")

originalPrint("DisenchantTooltip Spire checks passed")
