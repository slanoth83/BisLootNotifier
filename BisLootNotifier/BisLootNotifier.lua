-- == 1. VARIABLES & SETUP ==
local AddonName = "BisLootNotifier"
local EventFrame = CreateFrame("Frame")

-- Default Settings
local DefaultSettings = {
    slots = {}, 
    minimapPos = 45,
    minimapLocked = false,
    rollFrameLocked = false, 
    rollFramePos = nil       
}

local SlotNames = {
    "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist",
    "Hands", "Waist", "Legs", "Feet", "Ring", 
    "Trinket", "Weapon"
}
local TOTAL_SLOTS = 13
local SUB_SLOTS = 10 

-- VALIDATION RULES
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

-- Initialize DB
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == AddonName then
        if not BisLootSettings then BisLootSettings = DefaultSettings end
        if not BisLootSettings.slots then BisLootSettings.slots = {} end
        if BisLootSettings.rollFrameLocked == nil then BisLootSettings.rollFrameLocked = false end
        
        for i=1, TOTAL_SLOTS do
            if type(BisLootSettings.slots[i]) ~= "table" then
                BisLootSettings.slots[i] = { nil, nil, nil, nil, nil, nil, nil, nil, nil, nil }
            end
        end

        self:UnregisterEvent("ADDON_LOADED")
        if BisLootMapBtn then BisLootMapBtn:UpdatePosition() end
        
        -- Restore Roll Frame Position
        if BisRollFrame and BisLootSettings.rollFramePos then
            BisRollFrame:ClearAllPoints()
            local p = BisLootSettings.rollFramePos
            if p.point and p.relativePoint and p.x and p.y then
                BisRollFrame:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
            else
                BisRollFrame:SetPoint("CENTER", 0, 200)
            end
        end
        print("|cff00ff00BiS Manager Loaded.|r Type /bis reset to reset positions.")
    end
end)

-- RESET COMMAND
SLASH_BISRESET1 = "/bisreset" -- Alternative command
SlashCmdList["BISRESET"] = function()
    BisLootSettings = DefaultSettings
    ReloadUI()
end

-- Hook /bis reset argument
local Original_SlashCmd = SlashCmdList["BISLOOT"]
SLASH_BISLOOT1 = "/bis"
SlashCmdList["BISLOOT"] = function(msg)
    if msg == "reset" then
        BisLootSettings = nil
        ReloadUI()
    else
        if BisMainFrame:IsShown() then BisMainFrame:Hide() else BisMainFrame:Show() end
    end
end

-- == 2. MAIN UI ==
local MainFrame = CreateFrame("Frame", "BisMainFrame", UIParent)
MainFrame:SetSize(380, 500) 
MainFrame:SetPoint("CENTER")
MainFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
MainFrame:SetBackdropBorderColor(0.1, 1.0, 0.1, 1) -- Fel Green
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
Title:SetText("|cff00ff00BiS List|r")

local CloseBtn = CreateFrame("Button", nil, MainFrame, "UIPanelCloseButton")
CloseBtn:SetPoint("TOPRIGHT", -5, -5)
CloseBtn:SetScript("OnClick", function() MainFrame:Hide() end)

-- TEST ALERT BUTTON
local TestBtn = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
TestBtn:SetSize(80, 22)
TestBtn:SetPoint("TOPLEFT", 10, -10)
TestBtn:SetText("Test Alert")
TestBtn:SetScript("OnClick", function()
    if BisRollFrame:IsShown() then 
        BisRollFrame:Hide() 
    else 
        BisRollLinkText:SetText("Test Item Link")
        SetItemButtonTexture(BisRollIcon, "Interface\\Icons\\INV_Sword_04")
        BisRollFrame:Show() 
        print("Opening Roll Frame for testing...")
    end
end)

-- == 3. SIDE FRAME ==
local SideFrame = CreateFrame("Frame", "BisSideFrame", MainFrame)
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

local function GetItemID(link)
    if not link then return nil end
    local found, _, id = string.find(link, "item:(%d+)")
    if found then return tonumber(id) end
    return nil
end

local currentEditingSlot = 1
SideFrame.Rows = {}

local function UpdateSideFrame()
    if not SideFrame:IsShown() then return end
    SideTitle:SetText("Edit: " .. SlotNames[currentEditingSlot])
    
    local data = BisLootSettings.slots[currentEditingSlot] or {}
    
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
    local id = GetItemID(itemLink)
    if id then
        local _, _, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(id)
        if not itemEquipLoc then 
            print("|cffff0000BiS Error:|r Item info not loaded yet. Try again.")
            return 
        end

        local allowed = SlotValidations[currentEditingSlot]
        if allowed and allowed[itemEquipLoc] then
            if not BisLootSettings.slots[currentEditingSlot] then
                BisLootSettings.slots[currentEditingSlot] = {}
            end
            BisLootSettings.slots[currentEditingSlot][subSlotIndex] = id
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
        if BisLootSettings.slots[currentEditingSlot] then
            BisLootSettings.slots[currentEditingSlot][i] = nil
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

WorldFrame:HookScript("OnMouseDown", function()
    if SideFrame:IsShown() then
        for i=1, SUB_SLOTS do
            local eb = SideFrame.Rows[i].editBox
            if eb then eb:ClearFocus() end
        end
    end
end)
MainFrame:SetScript("OnMouseDown", function()
    if SideFrame:IsShown() then
        for i=1, SUB_SLOTS do
            local eb = SideFrame.Rows[i].editBox
            if eb then eb:ClearFocus() end
        end
    end
end)

-- == 4. MAIN SLOTS ==
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
        local data = BisLootSettings.slots[id]
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
    for i=1, TOTAL_SLOTS do
        local btn = self.SlotButtons[i]
        local data = BisLootSettings.slots[i]
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
CreateMainSlot(13, "BOTTOM", MainFrame, "BOTTOM", 0, 40) 

-- == 5. MINIMAP BUTTON ==
local MapBtn = CreateFrame("Button", "BisLootMapBtn", Minimap)
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
    local angle = math.rad(BisLootSettings.minimapPos or 45)
    local x = math.cos(angle) * 80
    local y = math.sin(angle) * 80
    MapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end
MapBtn:SetScript("OnDragStart", function(self)
    if BisLootSettings.minimapLocked then return end
    self:LockHighlight()
    self.isDragging = true
    self:SetScript("OnUpdate", function()
        local xpos, ypos = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        local cx, cy = Minimap:GetCenter()
        local x = (xpos/scale - cx)
        local y = (ypos/scale - cy)
        BisLootSettings.minimapPos = math.deg(math.atan2(y, x))
        self:UpdatePosition()
    end)
end)
MapBtn:SetScript("OnDragStop", function(self)
    self:UnlockHighlight()
    self.isDragging = false
    self:SetScript("OnUpdate", nil)
end)
MapBtn:SetScript("OnClick", function(self, btn)
    if btn == "RightButton" then
        BisLootSettings.minimapLocked = not BisLootSettings.minimapLocked
        print("Minimap Locked: " .. tostring(BisLootSettings.minimapLocked))
    else
        if MainFrame:IsShown() then MainFrame:Hide() else MainFrame:Show() end
    end
end)

-- == 6. ALERT SYSTEM (FIXED LOCK BUTTON) ==
local RollFrame = CreateFrame("Frame", "BisRollFrame", UIParent)
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
RollFrame:RegisterForDrag("LeftButton")
RollFrame:Hide()

RollFrame:SetScript("OnDragStart", function(self)
    if not BisLootSettings.rollFrameLocked then
        self:StartMoving()
    end
end)
RollFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
    BisLootSettings.rollFramePos = { point = point, relativePoint = relativePoint, x = xOfs, y = yOfs }
end)

local RollTitle = RollFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
RollTitle:SetPoint("TOP", 0, -15)
RollTitle:SetText("|cff00ff00BiS DROP!|r")

-- == LOCK BUTTON (Using Item Icon) ==
local RollLockBtn = CreateFrame("Button", nil, RollFrame)
RollLockBtn:SetSize(32, 32)
RollLockBtn:SetPoint("TOPLEFT", 5, -5)
RollLockBtn:SetFrameLevel(RollFrame:GetFrameLevel() + 10) -- Ensure visibility

-- Use PADLOCK Item Icon (Guaranteed to exist)
local LockIcon = RollLockBtn:CreateTexture(nil, "OVERLAY")
LockIcon:SetAllPoints()
LockIcon:SetTexture("Interface\\Icons\\INV_Misc_Lock_01") 

local function UpdateLockTexture()
    if BisLootSettings.rollFrameLocked then
        LockIcon:SetVertexColor(1, 0, 0) -- RED = Locked
    else
        LockIcon:SetVertexColor(0, 1, 0) -- GREEN = Unlocked
    end
end

RollLockBtn:SetScript("OnClick", function()
    BisLootSettings.rollFrameLocked = not BisLootSettings.rollFrameLocked
    UpdateLockTexture()
    if BisLootSettings.rollFrameLocked then
        print("|cffff0000BiS:|r Roll Frame LOCKED.")
    else
        print("|cff00ff00BiS:|r Roll Frame UNLOCKED.")
    end
end)
RollFrame:SetScript("OnShow", UpdateLockTexture)


-- Icon
local RollIcon = CreateFrame("Button", "BisRollIcon", RollFrame, "ItemButtonTemplate")
RollIcon:SetSize(40, 40)
RollIcon:SetPoint("TOP", 0, -35)
RollIcon:SetScript("OnEnter", function(self)
    if self.itemLink then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.itemLink)
        GameTooltip:Show()
    end
end)
RollIcon:SetScript("OnLeave", function() GameTooltip:Hide() end)

local RollItemLink = RollFrame:CreateFontString("BisRollLinkText", "OVERLAY", "GameFontHighlight")
RollItemLink:SetPoint("TOP", RollIcon, "BOTTOM", 0, -5)

local DoRollBtn = CreateFrame("Button", nil, RollFrame, "UIPanelButtonTemplate")
DoRollBtn:SetSize(100, 30)
DoRollBtn:SetPoint("BOTTOM", -60, 20)
DoRollBtn:SetText("ROLL NEED")
DoRollBtn:SetScript("OnClick", function() RandomRoll(1, 100) RollFrame:Hide() end)

local CloseRollBtn = CreateFrame("Button", nil, RollFrame, "UIPanelButtonTemplate")
CloseRollBtn:SetSize(80, 30)
CloseRollBtn:SetPoint("BOTTOM", 60, 20)
CloseRollBtn:SetText("CLOSE")
CloseRollBtn:SetScript("OnClick", function() RollFrame:Hide() end)

EventFrame:RegisterEvent("CHAT_MSG_RAID_WARNING")
EventFrame:RegisterEvent("CHAT_MSG_RAID")
EventFrame:RegisterEvent("CHAT_MSG_RAID_LEADER")
EventFrame:RegisterEvent("CHAT_MSG_LOOT")

EventFrame:HookScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then return end
    
    local msg = arg1
    for itemLink in string.gmatch(msg, "|c%x+|Hitem:.-|h%[.-%]|h|r") do
        local id = GetItemID(itemLink)
        if id then
            for slotIndex=1, TOTAL_SLOTS do
                local slotData = BisLootSettings.slots[slotIndex]
                if slotData then
                    for k=1, SUB_SLOTS do
                        if slotData[k] and tonumber(slotData[k]) == id then
                            local _, _, _, _, _, _, _, _, _, icon = GetItemInfo(id)
                            PlaySound("RaidWarning")
                            SetItemButtonTexture(RollIcon, icon)
                            RollIcon.itemLink = itemLink 
                            RollItemLink:SetText(itemLink)
                            RollFrame:Show()
                            print("|cff00ff00[BiS ALERT]|r " .. itemLink)
                            return
                        end
                    end
                end
            end
        end
    end
end)