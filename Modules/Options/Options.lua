---@class PvPAssistant
local PvPAssistant = select(2, ...)

local GGUI = PvPAssistant.GGUI
local GUTIL = PvPAssistant.GUTIL
local f = GUTIL:GetFormatter()

---@class PvPAssistant.Options
PvPAssistant.OPTIONS = {}

function PvPAssistant.OPTIONS:Init()
    -- Create the options panel frame
    PvPAssistant.OPTIONS.optionsPanel = CreateFrame("Frame", "PvPAssistantOptionsPanel", UIParent)
    PvPAssistant.OPTIONS.optionsPanel.name = "PvPAssistant"
    
    -- Set a title for the options panel (optional)
    local title = PvPAssistant.OPTIONS.optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("PvPAssistant Options")

    -- Register the options panel using the new Settings API
    local category = Settings.RegisterCanvasLayoutCategory(PvPAssistant.OPTIONS.optionsPanel, "PvPAssistant Options")
    Settings.RegisterAddOnCategory(category)
end
