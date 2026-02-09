-- == 1. VARIABLES & SETUP ==
local AddonName = "BisLootNotifier"
local EventFrame = CreateFrame("Frame")
local PlayerName = UnitName("player") -- Haetaan hahmon nimi
local CurrentDB -- Tämä viittaa nykyisen hahmon tallennuksiin

-- Oletusasetukset uudelle hahmolle
local function GetDefaultSettings()
    return {
        slots = {}, 
        minimapPos = 45,
        minimapLocked = false,
        rollFrameLocked = false, 
        rollFramePos = nil       
    }
end

local SlotNames = {
    "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist",
    "Hands", "Waist", "Legs", "Feet", "Ring", 
    "Trinket", "Weapon", "Misc" 
}
local TOTAL_SLOTS = 14 
local SUB_SLOTS = 10 

local SlotValidations = {
    [1]  = { ["INVTYPE_HEAD"]=true },
    [2]  = { ["INVTYPE_NECK"]=true },
    [3]  = { ["INVTYPE_SHOULDER"]=true },
    [4]  = { ["INVTYPE_CLOAK"]=true },
    [5]  = { ["INVTYPE_CHEST"]=true, ["INVTYPE_ROBE"]=true },
    [6]  = { ["INVTYPE_WRIST"]=true },
    [7]  = { ["INVTYPE_HAND"]=true },
    [8]  = { ["INVTYPE_WAIST"]=true },
    [9]  = { ["INVTYPE_LEGS"]=true },
    [10] = { ["INVTYPE_FEET"]=true },
    [11] = { ["INVTYPE_FINGER"]=true },
    [12] = { ["INVTYPE_TRINKET"]=true },
    [13] = { 
        ["INVTYPE_WEAPON"]=true, ["INVTYPE_SHIELD"]=true, 
        ["INVTYPE_2HWEAPON"]=true, ["INVTYPE_WEAPONMAINHAND"]=true, 
        ["INVTYPE_WEAPONOFFHAND"]=true, ["INVTYPE_HOLDABLE"]=true,
        ["INVTYPE_RANGED"]=true, ["INVTYPE_THROWN"]=true, 
        ["INVTYPE_RELIC"]=true, ["INVTYPE_RANGEDRIGHT"]=true
    }
}

-- Forward Declarations
local MainFrame, SideFrame, RollFrame, HelpFrame
local BisRollIcon, BisRollLinkText, MapBtn 

-- == 2. HELPER FUNCTIONS ==
local function GetItemID(link)
    if not link then return nil end
    local found, _, id = string.find(link, "item:(%d+)")
    if found then return tonumber(id) end
    return nil
end

-- == 3. EVENT HANDLER ==
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:RegisterEvent("CHAT_MSG_RAID_WARNING")
EventFrame:RegisterEvent("CHAT_MSG_RAID")
EventFrame:RegisterEvent("CHAT_MSG_RAID_LEADER")
EventFrame:RegisterEvent("CHAT_MSG_LOOT")

EventFrame:SetScript("OnEvent", function(self, event, arg1)
    -- INITIALIZATION
    if event == "ADDON_LOADED" and arg1 == AddonName then
        -- 1. Varmistetaan että päätaulukko on olemassa
        if not BisLootSettings then BisLootSettings = {} end
        
        -- 2. Migraatio vanhasta versiosta (jos käyttäjällä on vanhaa dataa ilman hahmon nimeä)
        if BisLootSettings.slots then
            -- Siirretään vanha "globaali" data nykyiselle hahmolle, jotta se ei katoa
            if not BisLootSettings[PlayerName] then
                BisLootSettings[PlayerName] = {
                    slots = BisLootSettings.slots,
                    minimapPos = BisLootSettings.minimapPos,
                    minimapLocked = BisLootSettings.minimapLocked,
                    rollFrameLocked = BisLootSettings.rollFrameLocked,
                    rollFramePos = BisLootSettings.rollFramePos
                }
            end
            -- Poistetaan vanha globaali data sotkemasta
            BisLootSettings.slots = nil
            BisLootSettings.minimapPos = nil
            BisLootSettings.minimapLocked = nil
            BisLootSettings.rollFrameLocked = nil
            BisLootSettings.rollFramePos = nil
            print("|cff00ff00BiS Manager:|r Data migrated to character profile: " .. PlayerName)
        end

        -- 3. Luodaan nykyiselle hahmolle profiili jos ei ole
        if not BisLootSettings[PlayerName] then
            BisLootSettings[PlayerName] = GetDefaultSettings()
        end
        
        -- 4. Asetetaan CurrentDB osoittamaan nykyiseen hahmoon
        CurrentDB = BisLootSettings[PlayerName]

        -- 5. Varmistetaan taulukon rakenne
        if not CurrentDB.slots then CurrentDB.slots = {} end
        if CurrentDB.rollFrameLocked == nil then CurrentDB.rollFrameLocked = false end
        
        for i=1, TOTAL_SLOTS do
            if type(CurrentDB.slots[i]) ~= "table" then
                CurrentDB.slots[i] = { nil, nil, nil, nil, nil, nil, nil, nil, nil, nil }
            end
        end

        self:UnregisterEvent("ADDON_LOADED")
        
        -- Päivitetään UI elementit ladatulla datalla
        if BisLootMapBtn and MapBtn and MapBtn.UpdatePosition then 
            MapBtn:UpdatePosition() 
        end
        
        if RollFrame and CurrentDB.rollFramePos then
            RollFrame:ClearAllPoints()
            local p = CurrentDB.rollFramePos
            if p.point and p.relativePoint then
                RollFrame:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
            else
                RollFrame:SetPoint("CENTER", 0, 200)
            end
        end
        print("|cff00ff00BiS Manager Loaded for:|r " .. PlayerName)
        
    -- CHAT SCANNING
    elseif (event == "CHAT_MSG_LOOT" or event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_WARNING" or event == "CHAT_MSG_RAID_LEADER") then
        local msg = arg1
        if not msg or not CurrentDB then return end -- Check CurrentDB exists
        
        for itemLink in string.gmatch(msg, "|c%x+|Hitem:.-|h%[.-%]|h|r") do
            local id = GetItemID(itemLink)
            if id then
                for slotIndex=1, TOTAL_SLOTS do
                    local slotData = CurrentDB.slots[slotIndex]
                    if slotData then
                        for k=1, SUB_SLOTS do
                            if slotData[k] and tonumber(slotData[k]) == id then
                                local itemName, _, _, _, _, _, _, _, _, icon = GetItemInfo(id)
                                if not icon then icon = "Interface\\Icons\\INV_Misc_QuestionMark" end
                                
                                PlaySound("RaidWarning")
                                SetItemButtonTexture(BisRollIcon, icon)
                                BisRollIcon.itemLink = itemLink 
                                BisRollLinkText:SetText(itemLink)
                                RollFrame:Show()
                                print("|cff00ff00[BiS ALERT]|r Drop detected: " .. itemLink)
                                return 
                            end
                        end
                    end
                end
            end
        end
    end
end)

SLASH_BISRESET1 = "/bisreset"
SlashCmdList["BISRESET"] = function()
    BisLootSettings[PlayerName] = GetDefaultSettings()
    CurrentDB = BisLootSettings[PlayerName]
    ReloadUI()
end

SLASH_BISLOOT1 = "/bis"
SlashCmdList["BISLOOT"] = function(msg)
    if msg == "reset" then
        BisLootSettings[PlayerName] = nil
        ReloadUI()
    else
        if BisMainFrame:IsShown() then BisMainFrame:Hide() else BisMainFrame:Show() end
    end
end

-- == 4. MAIN UI FRAME ==
MainFrame = CreateFrame("Frame", "BisMainFrame", UIParent)
MainFrame:SetSize(380, 500) 
MainFrame:SetPoint("CENTER")
MainFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
MainFrame:SetBackdropBorderColor(0.1, 1.0, 0.1, 1)
MainFrame:SetBackdropColor(0, 0.1, 0, 0.9)
MainFrame:SetMovable(true)
MainFrame:EnableMouse(true)
MainFrame:SetClampedToScreen(true)
MainFrame:RegisterForDrag("LeftButton")
MainFrame:SetScript("OnDragStart", MainFrame.StartMoving)
MainFrame:SetScript("OnDragStop", MainFrame.StopMovingOrSizing)
MainFrame:Hide()

local Title = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
Title:SetPoint("TOP", 0, -15)
Title:SetText("|cff00ff00BiS List|r (" .. PlayerName .. ")")

local CloseBtn = CreateFrame("Button", nil, MainFrame, "UIPanelCloseButton")
CloseBtn:SetPoint("TOPRIGHT", -5, -5)
CloseBtn:SetScript("OnClick", function() MainFrame:Hide() end)

-- INFO BUTTON (?)
local InfoBtn = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
InfoBtn:SetSize(22, 22)
InfoBtn:SetPoint("RIGHT", CloseBtn, "LEFT", -2, 0)
InfoBtn:SetText("?")
InfoBtn:SetScript("OnClick", function() 
    if HelpFrame:IsShown() then HelpFrame:Hide() else HelpFrame:Show() end
end)

-- HELP FRAME
HelpFrame = CreateFrame("Frame", "BisHelpFrame", MainFrame)
HelpFrame:SetSize(300, 320)
HelpFrame:SetPoint("CENTER", 0, 0)
HelpFrame:SetFrameStrata("DIALOG")
HelpFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
HelpFrame:SetBackdropBorderColor(0.1, 1.0, 0.1, 1)
HelpFrame:SetBackdropColor(0, 0.05, 0, 0.95)
HelpFrame:Hide()

local HelpTitle = HelpFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
HelpTitle:SetPoint("TOP", 0, -15)
HelpTitle:SetText("Instructions")

local HelpText = HelpFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HelpText:SetPoint("TOPLEFT", 20, -50)
HelpText:SetPoint("BOTTOMRIGHT", -20, 50)
HelpText:SetJustifyH("LEFT")
HelpText:SetJustifyV("TOP")
HelpText:SetText(
    "1. Click a gear slot to open the\n" ..
    "   editor view.\n\n" ..
    "2. Drag items from your bags/character\n" ..
    "   to the list, or Shift-click links\n" ..
    "   from the chat window.\n\n" ..
    "3. 'Misc' slot accepts any item\n" ..
    "   (mounts, pets, shirts, etc).\n\n" ..
    "4. When a saved item drops in a raid\n" ..
    "   or dungeon, the alert window will\n" ..
    "   open automatically.\n\n" ..
    "5. You can lock the alert window by\n" ..
    "   clicking the lock icon."
)

local CloseHelpBtn = CreateFrame("Button", nil, HelpFrame, "UIPanelButtonTemplate")
CloseHelpBtn:SetSize(80, 25)
CloseHelpBtn:SetPoint("BOTTOM", 0, 15)
CloseHelpBtn:SetText("Close")
CloseHelpBtn:SetScript("OnClick", function() HelpFrame:Hide() end)


-- TEST ALERT BUTTON
local TestBtn = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
TestBtn:SetSize(80, 22)
TestBtn:SetPoint("TOPLEFT", 10, -10)
TestBtn:SetText("Test Alert")
TestBtn:SetScript("OnClick", function()
    if RollFrame:IsShown() then 
        RollFrame:Hide() 
    else 
        BisRollLinkText:SetText("Test Item Link")
        SetItemButtonTexture(BisRollIcon, "Interface\\Icons\\INV_Sword_04")
        RollFrame:Show() 
        print("Opening Roll Frame for testing...")
    end
end)

-- == 5. SIDE EDIT FRAME ==
SideFrame = CreateFrame("Frame", "BisSideFrame", MainFrame)
SideFrame:SetSize(280, 480) 
SideFrame:SetPoint("TOPLEFT", MainFrame, "TOPRIGHT", -3, 0)
SideFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
SideFrame:SetBackdropBorderColor(0.1, 1.0, 0.1, 1)
SideFrame:SetBackdropColor(0, 0.05, 0, 0.9)
SideFrame:Hide()

local SideTitle = SideFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
SideTitle:SetPoint("TOP", 0, -15)
SideTitle:SetText("Edit Slot")

local currentEditingSlot = 1
SideFrame.Rows = {}

function UpdateSideFrame()
    if not SideFrame:IsShown() then return end
    SideTitle:SetText("Edit: " .. SlotNames[currentEditingSlot])
    
    if not CurrentDB then return end
    local data = CurrentDB.slots[currentEditingSlot] or {}
    
    for i=1, SUB_SLOTS do
        local row = SideFrame.Rows[i]
        row.itemID = data[i]
        
        row.editBox:SetText("")
        row.icon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
        
        if row.itemID then
            local name, link, _, _, _, _, _, _, _, icon = GetItemInfo(row.itemID)
            if icon then 
                row.icon:SetTexture(icon)
                row.editBox:SetText(link or name)
                row.editBox:SetCursorPosition(0)
            else
                GetItemInfo(row.itemID) 
                row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                row.editBox:SetText("ID: "..row.itemID)
            end
        end
    end
end

local function SaveItemToSlot(subSlotIndex, itemLink)
    if not CurrentDB then return end
    local id = GetItemID(itemLink)
    if id then
        local _, _, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(id)
        
        if not itemEquipLoc and not GetItemInfo(id) then 
            print("|cffff0000BiS Error:|r Item info not loaded yet. Click it again.")
            return 
        end

        local allowed = SlotValidations[currentEditingSlot]
        
        if currentEditingSlot == 14 or (allowed and allowed[itemEquipLoc]) then
            if not CurrentDB.slots[currentEditingSlot] then
                CurrentDB.slots[currentEditingSlot] = {}
            end
            CurrentDB.slots[currentEditingSlot][subSlotIndex] = id
            UpdateSideFrame()
            MainFrame:UpdateMainIcons()
            print("|cff00ff00Saved:|r Option "..subSlotIndex.." for "..SlotNames[currentEditingSlot])
        else
            print("|cffff0000BiS Error:|r This item does not go into the " .. SlotNames[currentEditingSlot] .. " slot!")
            PlaySound("igQuestFailed")
        end
    end
end

for i=1, SUB_SLOTS do
    local row = CreateFrame("Frame", nil, SideFrame)
    row:SetSize(250, 40)
    row:SetPoint("TOP", 0, -35 - ((i-1)*40)) 
    row:EnableMouse(true)
    
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(30, 30)
    icon:SetPoint("LEFT", 10, 0)
    icon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
    row.icon = icon
    
    row:SetScript("OnEnter", function(self)
        if self.itemID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:"..self.itemID)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local delBtn = CreateFrame("Button", nil, row, "UIPanelCloseButton")
    delBtn:SetSize(26, 26)
    delBtn:SetPoint("RIGHT", -5, 0)
    delBtn:SetScript("OnClick", function()
        if CurrentDB and CurrentDB.slots[currentEditingSlot] then
            CurrentDB.slots[currentEditingSlot][i] = nil
            UpdateSideFrame()
            MainFrame:UpdateMainIcons()
        end
    end)
    
    local eb = CreateFrame("EditBox", nil, row)
    eb:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    eb:SetPoint("RIGHT", delBtn, "LEFT", -5, 0)
    eb:SetHeight(28)
    eb:SetFontObject("GameFontHighlightSmall")
    eb:SetAutoFocus(false)
    eb:SetTextInsets(5, 5, 0, 0)
    
    eb:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    eb:SetBackdropColor(0, 0, 0, 0.5)
    eb:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    eb:SetScript("OnReceiveDrag", function(self)
        local infoType, info1, info2 = GetCursorInfo()
        if infoType == "item" then
            local _, link = GetItemInfo(info1)
            SaveItemToSlot(i, link)
            ClearCursor()
        end
    end)
    eb:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        if text and text ~= "" and string.find(text, "item:") then
            SaveItemToSlot(i, text)
        end
        self:ClearFocus()
    end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    row.editBox = eb
    SideFrame.Rows[i] = row
end

hooksecurefunc("ChatEdit_InsertLink", function(link)
    if SideFrame:IsShown() then
        for i=1, SUB_SLOTS do
            local eb = SideFrame.Rows[i].editBox
            if eb and eb:HasFocus() then
                eb:Insert(link)
                local fullText = eb:GetText()
                if fullText and string.find(fullText, "item:") then
                    SaveItemToSlot(i, fullText)
                    eb:ClearFocus()
                end
                return true
            end
        end
    end
end)

local function ClearFocusHandler()
    if SideFrame:IsShown() then
        for i=1, SUB_SLOTS do
            local eb = SideFrame.Rows[i].editBox
            if eb then eb:ClearFocus() end
        end
    end
end
WorldFrame:HookScript("OnMouseDown", ClearFocusHandler)
MainFrame:SetScript("OnMouseDown", ClearFocusHandler)

-- == 6. MAIN SLOTS UI ==
MainFrame.SlotButtons = {}
local function CreateMainSlot(id, anchor, relativeTo, relativePoint, x, y)
    local btn = CreateFrame("Button", "BisSlotButton"..id, MainFrame, "ItemButtonTemplate")
    btn:SetSize(36, 36)
    btn:SetPoint(anchor, relativeTo, relativePoint, x, y)
    
    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("BOTTOM", btn, "TOP", 0, 1)
    lbl:SetText(SlotNames[id])
    
    local glow = btn:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetVertexColor(0, 1, 0, 0.5)
    glow:SetBlendMode("ADD")
    glow:SetAllPoints()
    
    btn:SetScript("OnClick", function()
        currentEditingSlot = id
        SideFrame:Show()
        UpdateSideFrame()
    end)
    
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if not CurrentDB then return end
        local data = CurrentDB.slots[id]
        local primaryItem = nil
        
        if data then
            for k=1, SUB_SLOTS do
                if data[k] then primaryItem = data[k] break end
            end
        end
        
        if primaryItem then
            GameTooltip:SetHyperlink("item:"..primaryItem)
            local count = 0
            for k=1, SUB_SLOTS do if data[k] then count = count + 1 end end
            if count > 1 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Also saved:", 1, 1, 1)
                for k=1, SUB_SLOTS do
                    if data[k] and data[k] ~= primaryItem then
                         local name = GetItemInfo(data[k])
                         GameTooltip:AddLine("- " .. (name or "Loading..."), 0.7, 0.7, 0.7)
                    end
                end
            end
        else
            GameTooltip:AddLine(SlotNames[id])
            GameTooltip:AddLine("Click to add items", 0.5, 0.5, 0.5)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    MainFrame.SlotButtons[id] = btn
end

function MainFrame:UpdateMainIcons()
    if not CurrentDB then return end
    for i=1, TOTAL_SLOTS do
        local btn = self.SlotButtons[i]
        local data = CurrentDB.slots[i]
        local foundIcon = nil
        if data then
            for k=1, SUB_SLOTS do
                if data[k] then
                    local _, _, _, _, _, _, _, _, _, icon = GetItemInfo(data[k])
                    if icon then foundIcon = icon break end
                end
            end
        end
        if foundIcon then SetItemButtonTexture(btn, foundIcon) else SetItemButtonTexture(btn, nil) end
    end
end
MainFrame:SetScript("OnShow", MainFrame.UpdateMainIcons)

local startX, startY = 55, -50
local vSpace = -44
CreateMainSlot(1, "TOPLEFT", MainFrame, "TOPLEFT", startX, startY)
CreateMainSlot(2, "TOP", MainFrame.SlotButtons[1], "BOTTOM", 0, vSpace)
CreateMainSlot(3, "TOP", MainFrame.SlotButtons[2], "BOTTOM", 0, vSpace)
CreateMainSlot(4, "TOP", MainFrame.SlotButtons[3], "BOTTOM", 0, vSpace)
CreateMainSlot(5, "TOP", MainFrame.SlotButtons[4], "BOTTOM", 0, vSpace)
CreateMainSlot(6, "TOP", MainFrame.SlotButtons[5], "BOTTOM", 0, vSpace)

CreateMainSlot(7, "TOPRIGHT", MainFrame, "TOPRIGHT", -startX, startY)
CreateMainSlot(8, "TOP", MainFrame.SlotButtons[7], "BOTTOM", 0, vSpace)
CreateMainSlot(9, "TOP", MainFrame.SlotButtons[8], "BOTTOM", 0, vSpace)
CreateMainSlot(10, "TOP", MainFrame.SlotButtons[9], "BOTTOM", 0, vSpace)
CreateMainSlot(11, "TOP", MainFrame.SlotButtons[10], "BOTTOM", 0, vSpace) 
CreateMainSlot(12, "TOP", MainFrame.SlotButtons[11], "BOTTOM", 0, vSpace)

CreateMainSlot(14, "BOTTOM", MainFrame, "BOTTOM", 0, 85) -- Misc
CreateMainSlot(13, "BOTTOM", MainFrame, "BOTTOM", 0, 30) -- Weapon

-- == 7. MINIMAP BUTTON ==
MapBtn = CreateFrame("Button", "BisLootMapBtn", Minimap)
MapBtn:SetSize(33, 33)
MapBtn:SetFrameLevel(9)
MapBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
MapBtn:RegisterForDrag("LeftButton")
local MapBtnBg = MapBtn:CreateTexture(nil, "BACKGROUND")
MapBtnBg:SetSize(20, 20)
MapBtnBg:SetPoint("CENTER", 0, 1)
MapBtnBg:SetTexture("Interface\\Icons\\Ability_Warlock_ChaosBolt")
local MapBtnBorder = MapBtn:CreateTexture(nil, "OVERLAY")
MapBtnBorder:SetSize(52, 52)
MapBtnBorder:SetPoint("TOPLEFT", 0, 0)
MapBtnBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

function MapBtn:UpdatePosition()
    if not CurrentDB then return end
    local angle = math.rad(CurrentDB.minimapPos or 45)
    local x = math.cos(angle) * 80
    local y = math.sin(angle) * 80
    MapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end
MapBtn:SetScript("OnDragStart", function(self)
    if not CurrentDB or CurrentDB.minimapLocked then return end
    self:LockHighlight()
    self.isDragging = true
    self:SetScript("OnUpdate", function()
        local xpos, ypos = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        local cx, cy = Minimap:GetCenter()
        local x = (xpos/scale - cx)
        local y = (ypos/scale - cy)
        CurrentDB.minimapPos = math.deg(math.atan2(y, x))
        self:UpdatePosition()
    end)
end)
MapBtn:SetScript("OnDragStop", function(self)
    self:UnlockHighlight()
    self.isDragging = false
    self:SetScript("OnUpdate", nil)
end)
MapBtn:SetScript("OnClick", function(self, btn)
    if not CurrentDB then return end
    if btn == "RightButton" then
        CurrentDB.minimapLocked = not CurrentDB.minimapLocked
        print("Minimap Locked: " .. tostring(CurrentDB.minimapLocked))
    else
        if MainFrame:IsShown() then MainFrame:Hide() else MainFrame:Show() end
    end
end)

-- == 8. ALERT ROLL FRAME ==
RollFrame = CreateFrame("Frame", "BisRollFrame", UIParent)
RollFrame:SetSize(250, 160)
RollFrame:SetPoint("CENTER", 0, 200)
RollFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
RollFrame:SetBackdropBorderColor(0.1, 1.0, 0.1, 1)
RollFrame:SetMovable(true)
RollFrame:EnableMouse(true)
RollFrame:SetClampedToScreen(true)
RollFrame:SetFrameStrata("DIALOG") -- Main frame high strata

-- DRAG IMPLEMENTATION (User Requested Fix)
RollFrame:RegisterForDrag("LeftButton")
RollFrame:SetScript("OnDragStart", function(self)
    if CurrentDB and not CurrentDB.rollFrameLocked then
        self:StartMoving()
    end
end)
RollFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
    if CurrentDB then
        CurrentDB.rollFramePos = { point = point, relativePoint = relativePoint, x = xOfs, y = yOfs }
    end
end)
RollFrame:Hide()

local RollTitle = RollFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
RollTitle:SetPoint("TOP", 0, -15)
RollTitle:SetText("|cff00ff00BiS DROP!|r")

-- == LOCK BUTTON START ==
local RollLockBtn = CreateFrame("Button", nil, RollFrame)
RollLockBtn:SetSize(28, 28)
RollLockBtn:SetPoint("TOPLEFT", RollFrame, "TOPLEFT", 6, -6)
RollLockBtn:SetFrameStrata("TOOLTIP") -- Highest possible strata to force visibility
RollLockBtn:SetFrameLevel(100)

local LockIcon = RollLockBtn:CreateTexture(nil, "ARTWORK")
LockIcon:SetAllPoints(RollLockBtn)
-- Default to Unlocked icon
LockIcon:SetTexture("Interface\\Icons\\INV_Misc_Unlock_01") -- Try unlock icon if available, or just use Lock

local function UpdateLockTexture()
    if not CurrentDB then return end
    if CurrentDB.rollFrameLocked then
        LockIcon:SetTexture("Interface\\Icons\\INV_Misc_Lock_01") -- Closed Lock
        LockIcon:SetVertexColor(1, 0.2, 0.2) -- Red tint
    else
        LockIcon:SetTexture("Interface\\Icons\\INV_Misc_Key_01") -- Open/Key/Unlock
        LockIcon:SetVertexColor(0.2, 1, 0.2) -- Green tint
    end
end

RollLockBtn:SetScript("OnClick", function()
    if not CurrentDB then return end
    CurrentDB.rollFrameLocked = not CurrentDB.rollFrameLocked
    UpdateLockTexture()
    if CurrentDB.rollFrameLocked then
        print("|cffff0000BiS:|r Roll Frame LOCKED.")
    else
        print("|cff00ff00BiS:|r Roll Frame UNLOCKED.")
    end
end)

RollLockBtn:SetScript("OnEnter", function(self)
    if not CurrentDB then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(CurrentDB.rollFrameLocked and "Unlock Frame" or "Lock Frame")
    GameTooltip:Show()
end)
RollLockBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

RollFrame:SetScript("OnShow", UpdateLockTexture)
-- == LOCK BUTTON END ==

-- Item Icon
BisRollIcon = CreateFrame("Button", "BisRollIcon", RollFrame, "ItemButtonTemplate")
BisRollIcon:SetSize(40, 40)
BisRollIcon:SetPoint("TOP", 0, -35)
BisRollIcon:SetScript("OnEnter", function(self)
    if self.itemLink then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.itemLink)
        GameTooltip:Show()
    end
end)
BisRollIcon:SetScript("OnLeave", function() GameTooltip:Hide() end)

BisRollLinkText = RollFrame:CreateFontString("BisRollLinkText", "OVERLAY", "GameFontHighlight")
BisRollLinkText:SetPoint("TOP", BisRollIcon, "BOTTOM", 0, -5)
BisRollLinkText:SetWidth(230)

-- Roll Button
local DoRollBtn = CreateFrame("Button", nil, RollFrame, "UIPanelButtonTemplate")
DoRollBtn:SetSize(100, 30)
DoRollBtn:SetPoint("BOTTOM", -60, 20)
DoRollBtn:SetText("ROLL NEED")
DoRollBtn:SetScript("OnClick", function() 
    RandomRoll(1, 100) 
    RollFrame:Hide() 
end)

-- Close Button
local CloseRollBtn = CreateFrame("Button", nil, RollFrame, "UIPanelButtonTemplate")
CloseRollBtn:SetSize(80, 30)
CloseRollBtn:SetPoint("BOTTOM", 60, 20)
CloseRollBtn:SetText("CLOSE")
CloseRollBtn:SetScript("OnClick", function() RollFrame:Hide() end)