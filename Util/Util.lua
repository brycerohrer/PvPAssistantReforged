---@class PvPAssistant
local PvPAssistant = select(2, ...)

local GGUI = PvPAssistant.GGUI
local GUTIL = PvPAssistant.GUTIL
local f = GUTIL:GetFormatter()

---@class PvPAssistant.Util
PvPAssistant.UTIL = {}

--- Formats large numbers into readable strings (e.g., 1.5M, 2K).
---@param number number
---@return string
function PvPAssistant.UTIL:FormatDamageNumber(number)
    if number >= 1e9 then
        return GUTIL:Round(number / 1e9, 2) .. "B"
    elseif number >= 1e6 then
        return GUTIL:Round(number / 1e6, 2) .. "M"
    elseif number >= 1e3 then
        return GUTIL:Round(number / 1e3) .. "K"
    else
        return tostring(number)
    end
end

--- Colors text based on PvP rating thresholds.
---@param text string
---@param rating number
---@return string
function PvPAssistant.UTIL:ColorByRating(text, rating)
    if rating >= 2200 then
        return f.l(text)
    elseif rating >= 1800 then
        return f.e(text)
    else
        return f.white(text)
    end
end

--- Retrieves a unique player ID based on the unit.
---@param unit UnitId
---@return string playerUID
function PvPAssistant.UTIL:GetPlayerUIDByUnit(unit)
    local playerName, playerRealm = UnitNameUnmodified(unit)
    playerRealm = playerRealm or GetNormalizedRealmName()
    return playerName .. "-" .. playerRealm
end

--- Retrieves the specialization ID for a given unit.
---@param unit UnitId
---@return number? specializationID
function PvPAssistant.UTIL:GetSpecializationIDByUnit(unit)
    local guid = UnitGUID(unit)
    if guid then
        local _, _, _, _, _, npcID = strsplit("-", guid)
        npcID = tonumber(npcID)
        if npcID then
            local specID = GetInspectSpecialization(unit)
            if specID and specID > 0 then
                return specID
            end
        end
    end
    return nil
end

--- Abbreviates map names.
---@param mapName string
---@return string
function PvPAssistant.UTIL:GetMapAbbreviation(mapName)
    local custom = PvPAssistant.CONST.MAP_ABBREVIATIONS[mapName]
    if custom then return custom end

    local words = { strsplit(" ", mapName) }
    local firstLetters = GUTIL:Map(words, function(word)
        return word:sub(1, 1):upper()
    end)
    return table.concat(firstLetters, "")
end

--- Retrieves an icon path based on PvP rating.
---@param rating number
---@return string?
function PvPAssistant.UTIL:GetIconByRating(rating)
    local rankingIcon
    for _, ratingData in ipairs(PvPAssistant.CONST.RATING_ICON_MAP) do
        if rating >= ratingData.rating then
            rankingIcon = ratingData.icon
        end
    end
    return rankingIcon
end

--- Defines the InspectArenaData type.
---@class InspectArenaData
---@field pvpMode PvPAssistant.Const.PVPModes
---@field rating number
---@field seasonPlayed number
---@field seasonWon number
---@field weeklyPlayed number
---@field weeklyWon number

--- Converts arena data for inspection.
---@param pvpMode PvPAssistant.Const.PVPModes
---@param data table
---@return InspectArenaData inspectArenaData
function PvPAssistant.UTIL:ConvertInspectArenaData(pvpMode, data)
    ---@type InspectArenaData
    local inspectArenaData = {
        pvpMode = pvpMode,
        rating = data[1],
        seasonPlayed = data[2],
        seasonWon = data[3],
        weeklyPlayed = data[4],
        weeklyWon = data[5],
    }
    return inspectArenaData
end

--- Creates a logo for the addon UI.
---@param parent Frame
---@param anchorPoints GGUI.AnchorPoint[]
---@param scale number?
---@return GGUI.Text
function PvPAssistant.UTIL:CreateLogo(parent, anchorPoints, scale)
    scale = scale or 1

    ---@class PvPAssistantLogoFrame : Frame
    ---@field titleLogo GGUI.Text
    local parentFrame = parent
    parentFrame.titleLogo = GGUI.Text {
        parent = parentFrame,
        anchorPoints = anchorPoints,
        text = f.bb("PvPAssistant"),
        scale = 1.7 * scale,
    }
    return parentFrame.titleLogo
end

---@class PvPAssistant.ClassFilterFrameOptions
---@field parent Frame
---@field anchorPoint GGUI.AnchorPoint?
---@field clickCallback? fun(classFile: string, state: boolean)
---@field onRevertCallback? fun()

--- Creates a class filter frame for filtering classes in UI elements.
---@param options PvPAssistant.ClassFilterFrameOptions
---@return GGUI.Frame classFilterFrame
---@return table<string, boolean> activeClassFiltersTable
function PvPAssistant.UTIL:CreateClassFilterFrame(options)
    local activeClassFiltersTable = {}
    local anchorPoint = options.anchorPoint or {}
    local parent = options.parent

    ---@class PvPAssistant.ClassFilterFrame : GGUI.Frame
    local classFilterFrame = GGUI.Frame {
        parent = parent,
        anchorParent = anchorPoint.anchorParent or parent,
        anchorA = anchorPoint.anchorA or "TOP",
        anchorB = anchorPoint.anchorB or "TOP",
        backdropOptions = PvPAssistant.CONST.FILTER_FRAME_BACKDROP,
        sizeX = 430,
        sizeY = 85,
        offsetY = anchorPoint.offsetY or 0,
        offsetX = anchorPoint.offsetX or 0,
        tooltipOptions = {
            anchor = "ANCHOR_CURSOR_RIGHT",
            text = f.white("Toggle Class Filters off and on."
                .. "\nshift+" .. CreateAtlasMarkup(PvPAssistant.CONST.ATLAS.LEFT_MOUSE_BUTTON, 15, 20) .. ": Filter out everything else"
                .. "\nalt+" .. CreateAtlasMarkup(PvPAssistant.CONST.ATLAS.LEFT_MOUSE_BUTTON, 15, 20) .. ": Filter in everything else"),
        },
    }

    classFilterFrame.frame:SetFrameLevel(parent:GetFrameLevel() + 10)

    ---@type GGUI.ClassIcon[]
    classFilterFrame.classFilterButtons = {}

    local classFilterIconSize = 30
    local classFilterIconOffsetXRow1 = 10
    local classFilterIconOffsetYRow1 = 20
    local classFilterIconOffsetXRow2 = 10
    local classFilterIconOffsetYRow2 = -20
    local classFilterIconSpacingX = 14

    local function CreateClassFilterIcon(classFile, anchorParent, offX, offY, anchorA, anchorB)
        ---@class ClassFilterIcon : GGUI.ClassIcon
        local classFilterIcon = GGUI.ClassIcon {
            sizeX = classFilterIconSize,
            sizeY = classFilterIconSize,
            parent = classFilterFrame.content,
            anchorParent = anchorParent,
            initialClass = classFile,
            offsetX = offX,
            offsetY = offY,
            anchorA = anchorA,
            anchorB = anchorB,
            showTooltip = true,
        }

        --- Adds a Revert method to the classFilterIcon.
        ---@class ClassFilterIcon
        ---@field Revert fun(self: ClassFilterIcon)
        function classFilterIcon:Revert()
            activeClassFiltersTable[classFile] = false
            self:Saturate()
        end

        classFilterIcon.frame:SetScript("OnClick", function()
            if IsShiftKeyDown() then
                -- Toggle all off except current class
                for _, classIcon in ipairs(classFilterFrame.classFilterButtons) do
                    if classIcon.initialClass == classFile then
                        classIcon:Saturate()
                        activeClassFiltersTable[classIcon.initialClass] = false
                    else
                        classIcon:Desaturate()
                        activeClassFiltersTable[classIcon.initialClass] = true
                    end
                end
                if options.clickCallback then
                    options.clickCallback(classFile, false)
                end
            elseif IsAltKeyDown() then
                -- Toggle all on except current class
                for _, classIcon in ipairs(classFilterFrame.classFilterButtons) do
                    if classIcon.initialClass == classFile then
                        classIcon:Desaturate()
                        activeClassFiltersTable[classIcon.initialClass] = true
                    else
                        classIcon:Saturate()
                        activeClassFiltersTable[classIcon.initialClass] = false
                    end
                end
                if options.clickCallback then
                    options.clickCallback(classFile, false)
                end
            else
                -- Toggle current class
                if not activeClassFiltersTable[classFile] then
                    activeClassFiltersTable[classFile] = true
                    classFilterIcon:Desaturate()
                    if options.clickCallback then
                        options.clickCallback(classFile, true)
                    end
                else
                    activeClassFiltersTable[classFile] = false
                    classFilterIcon:Saturate()
                    if options.clickCallback then
                        options.clickCallback(classFile, false)
                    end
                end
            end
        end)

        return classFilterIcon
    end

    local classInfo = {}
    -- Replace deprecated function with the updated API
    for classID = 1, GetNumClasses() do
        local classData = C_CreatureInfo.GetClassInfo(classID)
        if classData and classData.classFile then -- Exclude EVOKER if not needed
            classInfo[classData.classFile] = classData.className
        end
    end

    local classFiles = {}
    for classFile in pairs(classInfo) do
        table.insert(classFiles, classFile)
    end
    table.sort(classFiles)

    local iconsFirstRow = 8
    local currentAnchor = classFilterFrame.frame
    for i, classFile in ipairs(classFiles) do
        local anchorB = "RIGHT"
        local offX = classFilterIconSpacingX
        local offY = 0
        if i == 1 then
            anchorB = "LEFT"
            offX = classFilterIconOffsetXRow1
            offY = classFilterIconOffsetYRow1
        end
        if i == iconsFirstRow then
            anchorB = "LEFT"
            offX = classFilterIconOffsetXRow2
            offY = classFilterIconOffsetYRow2
            currentAnchor = classFilterFrame.frame
        end
        local classFilterIcon = CreateClassFilterIcon(classFile, currentAnchor, offX, offY, "LEFT", anchorB)
        table.insert(classFilterFrame.classFilterButtons, classFilterIcon)
        currentAnchor = classFilterIcon.frame
    end

    classFilterFrame.content.revertButton = GGUI.Button {
        parent = classFilterFrame.content,
        anchorPoints = { { anchorParent = currentAnchor, anchorA = "LEFT", anchorB = "RIGHT", offsetX = classFilterIconSpacingX, offsetY = 1 } },
        buttonTextureOptions = PvPAssistant.CONST.ASSETS.BUTTONS.MAIN_BUTTON,
        label = PvPAssistant.MEDIA:GetAsTextIcon(PvPAssistant.MEDIA.IMAGES.REVERT, 0.3, 0, -1),
        sizeX = classFilterIconSize - 1,
        sizeY = classFilterIconSize - 1,
        tooltipOptions = {
            anchor = "ANCHOR_CURSOR_RIGHT",
            text = f.l("Revert Filters"),
        },
        clickCallback = function()
            for _, filterButton in ipairs(classFilterFrame.classFilterButtons) do
                filterButton:Revert()
            end
            if options.onRevertCallback then
                options.onRevertCallback()
            end
        end
    }

    return classFilterFrame, activeClassFiltersTable
end

--- Converts CamelCase strings to dash-separated strings.
---@param str string
---@return string
function PvPAssistant.UTIL:CamelCaseToDashSeparated(str)
    local result = ""
    local prevCharWasUpperCase = false

    for i = 1, #str do
        local char = string.sub(str, i, i)
        if char:match("%u") then -- Uppercase character
            if not prevCharWasUpperCase then
                if i == 1 then
                    result = result .. char:lower()
                else
                    result = result .. "-" .. char:lower()
                end
            else
                result = result .. char:lower()
            end
            prevCharWasUpperCase = true
        else
            result = result .. char
            prevCharWasUpperCase = false
        end
    end

    return result
end
