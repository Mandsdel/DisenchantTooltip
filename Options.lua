local panel = CreateFrame("Frame", "DisenchantTooltipSettingsPanel", UIParent)
panel.name = "Disenchant Tooltip"
panel:Hide()
local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Disenchant Tooltip")
local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -18)
description:SetWidth(500)
description:SetJustifyH("LEFT")
description:SetText("There are no configurable settings. Disenchant outcomes are shown automatically in item tooltips.\n\n"
    .. "For the Enchantress' Spire workflow, use a macro containing:\n"
    .. "#showtooltip Disenchant\n/click DisenchantTooltipSpireButton\n\n"
    .. "Use /dtspire restore to retry restoring weapons, or /dtspire forget after restoring them manually.")

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
    if Settings and type(Settings.RegisterCanvasLayoutCategory) == "function"
        and type(Settings.RegisterAddOnCategory) == "function" then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "Disenchant Tooltip")
        Settings.RegisterAddOnCategory(category)
    elseif type(InterfaceOptions_AddCategory) == "function" then
        InterfaceOptions_AddCategory(panel)
    else
        print("|cff00bfffDisenchantTooltip:|r AddOns options registration is unavailable.")
    end
end)
