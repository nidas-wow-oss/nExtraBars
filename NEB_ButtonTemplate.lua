--[[
  NEB_ButtonTemplate.lua
  Based on AlternateButtonTemplate by Massiner of Nathrezim
  Embedded and adapted for Nidhaus_ExtraBar
]]

NEB_ABTFrame = CreateFrame("FRAME");
NEB_ABTFrame.buttons = {};
NEB_ABTFrame.showGrid = false;
NEB_ABTFrame.worldLoaded = false;

NEB_ABTFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
NEB_ABTFrame:RegisterEvent("PLAYER_EXITING_WORLD");
NEB_ABTFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED");
NEB_ABTFrame:RegisterEvent("ACTIONBAR_UPDATE_STATE");
NEB_ABTFrame:RegisterEvent("ACTIONBAR_UPDATE_USABLE");
NEB_ABTFrame:RegisterEvent("SPELL_UPDATE_USABLE");
NEB_ABTFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN");
NEB_ABTFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN");
NEB_ABTFrame:RegisterEvent("BAG_UPDATE_COOLDOWN");
NEB_ABTFrame:RegisterEvent("ACTIONBAR_SHOWGRID");
NEB_ABTFrame:RegisterEvent("ACTIONBAR_HIDEGRID");
NEB_ABTFrame:RegisterEvent("CURSOR_UPDATE");
NEB_ABTFrame:RegisterEvent("LEARNED_SPELL_IN_TAB");
NEB_ABTFrame:RegisterEvent("PLAYER_TALENT_UPDATE");
NEB_ABTFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED");
NEB_ABTFrame:RegisterEvent("UPDATE_MACROS");
NEB_ABTFrame:RegisterEvent("UPDATE_BINDINGS");
NEB_ABTFrame:RegisterEvent("UPDATE_INVENTORY_ALERTS");
NEB_ABTFrame:RegisterEvent("BAG_UPDATE");
NEB_ABTFrame:RegisterEvent("PLAYER_TARGET_CHANGED");
NEB_ABTFrame:RegisterEvent("TRADE_SKILL_SHOW");
NEB_ABTFrame:RegisterEvent("TRADE_SKILL_CLOSE");
NEB_ABTFrame:RegisterEvent("PLAYER_ENTER_COMBAT");
NEB_ABTFrame:RegisterEvent("PLAYER_LEAVE_COMBAT");
NEB_ABTFrame:RegisterEvent("START_AUTOREPEAT_SPELL");
NEB_ABTFrame:RegisterEvent("STOP_AUTOREPEAT_SPELL");
NEB_ABTFrame:RegisterEvent("UNIT_ENTERED_VEHICLE");
NEB_ABTFrame:RegisterEvent("UNIT_EXITED_VEHICLE");
NEB_ABTFrame:RegisterEvent("COMPANION_UPDATE");
NEB_ABTFrame:RegisterEvent("COMPANION_LEARNED");
NEB_ABTFrame:RegisterEvent("PET_BAR_UPDATE");
NEB_ABTFrame:RegisterEvent("PET_BAR_UPDATE_COOLDOWN");
NEB_ABTFrame:RegisterEvent("UNIT_PET");
NEB_ABTFrame:RegisterEvent("PLAYER_CONTROL_LOST");
NEB_ABTFrame:RegisterEvent("PLAYER_CONTROL_GAINED");
NEB_ABTFrame:RegisterEvent("UNIT_AURA");

function NEB_ABTFrame:OnEvent(event, ...)
    local arg1 = ...;

    if (event == "ACTIONBAR_SLOT_CHANGED") then
        for i,v in ipairs(self.buttons) do NEB_ABT_Update(v); end

    elseif (event == "SPELL_UPDATE_COOLDOWN" or event == "BAG_UPDATE_COOLDOWN" or event == "ACTIONBAR_UPDATE_COOLDOWN") then
        for i,v in ipairs(self.buttons) do NEB_ABT_UpdateCooldown(v); end

    elseif (event == "ACTIONBAR_UPDATE_USABLE" or event == "SPELL_UPDATE_USABLE") then
        for i,v in ipairs(self.buttons) do NEB_ABT_UpdateUsable(v); end

    elseif (event == "PLAYER_TARGET_CHANGED") then
        for i,v in ipairs(self.buttons) do v.rangeTimer = -1; end

    elseif (event == "PLAYER_ENTER_COMBAT") then
        for i,v in ipairs(self.buttons) do
            local command, value = NEB_ABT_GetCommand(v);
            if (command == "spell" and IsAttackSpell(value)) then NEB_ABT_StartFlash(v); end
        end

    elseif (event == "PLAYER_LEAVE_COMBAT") then
        for i,v in ipairs(self.buttons) do
            local command, value = NEB_ABT_GetCommand(v);
            if (command == "spell" and IsAttackSpell(value)) then NEB_ABT_StopFlash(v); end
        end

    elseif (event == "START_AUTOREPEAT_SPELL") then
        for i,v in ipairs(self.buttons) do
            local command, value = NEB_ABT_GetCommand(v);
            if (command == "spell" and IsAutoRepeatSpell(value)) then NEB_ABT_StartFlash(v); end
        end

    elseif (event == "STOP_AUTOREPEAT_SPELL") then
        for i,v in ipairs(self.buttons) do
            local command, value = NEB_ABT_GetCommand(v);
            if (v.flashing == 1 and not (command == "spell" and IsAttackSpell(value))) then NEB_ABT_StopFlash(v); end
        end

    elseif (event == "CURSOR_UPDATE") then
        if (GetCursorInfo() == "item") then
            self.showGrid = true;
            for i,v in ipairs(self.buttons) do NEB_ABT_UpdateShow(v); end
        elseif (self.showGrid) then
            self.showGrid = false;
            for i,v in ipairs(self.buttons) do NEB_ABT_UpdateShow(v); end
        end

    elseif (event == "ACTIONBAR_SHOWGRID") then
        NEB_ABTFrame.showGrid = true;
        for i,v in ipairs(self.buttons) do NEB_ABT_UpdateShow(v); end

    elseif (event == "ACTIONBAR_HIDEGRID") then
        NEB_ABTFrame.showGrid = false;
        for i,v in ipairs(self.buttons) do NEB_ABT_UpdateShow(v); end

    elseif (event == "BAG_UPDATE") then
        for i,v in ipairs(self.buttons) do
            NEB_ABT_UpdateEquipped(v);
            NEB_ABT_UpdateText(v);
        end

    elseif (event == "ACTIONBAR_UPDATE_STATE"
            or ((event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE") and arg1 == "player")
            or (event == "COMPANION_UPDATE")
            or event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_CLOSE") then
        for i,v in ipairs(self.buttons) do NEB_ABT_UpdateChecked(v); end

    elseif (event == "UPDATE_BINDINGS") then
        for i,v in ipairs(self.buttons) do NEB_ABT_UpdateHotkeys(v); end

    elseif (event == "UPDATE_MACROS") then
        for i,v in ipairs(self.buttons) do NEB_ABT_UpdateMacro(v); end

    elseif (event == "ACTIVE_TALENT_GROUP_CHANGED") then
        for i,v in ipairs(self.buttons) do NEB_ABT_SetFromStoredCommand(v); end

    elseif (event == "LEARNED_SPELL_IN_TAB" or event == "PLAYER_TALENT_UPDATE") then
        for i,v in ipairs(self.buttons) do NEB_ABT_UpdateSpell(v); end

    elseif (event == "COMPANION_LEARNED") then
        for i,v in ipairs(self.buttons) do NEB_ABT_UpdateCompanion(v); end

    elseif (event == "PET_BAR_UPDATE" or event == "UNIT_PET") then
        -- Actualizar todos los botones cuando la barra de mascota cambia
        -- Esto incluye cuando la pet recibe Fear, Polymorph, etc.
        for i,v in ipairs(self.buttons) do NEB_ABT_Update(v); end

    elseif (event == "PET_BAR_UPDATE_COOLDOWN") then
        -- Actualizar cooldowns cuando la barra de mascota se actualiza
        for i,v in ipairs(self.buttons) do NEB_ABT_UpdateCooldown(v); end

    elseif (event == "PLAYER_CONTROL_LOST" or event == "PLAYER_CONTROL_GAINED") then
        -- Cuando el jugador pierde/gana control (Fear, Stun, etc.), actualizar todo
        -- Esto sincroniza la pet bar cuando el jugador Y la pet reciben CC
        for i,v in ipairs(self.buttons) do NEB_ABT_Update(v); end

    elseif (event == "UNIT_AURA") then
        -- Actualizar cuando player o pet reciben/pierden auras (Fear, etc.)
        if (arg1 == "player" or arg1 == "pet") then
            for i,v in ipairs(self.buttons) do NEB_ABT_Update(v); end
        end

    elseif (event == "PLAYER_ENTERING_WORLD") then
        self.worldLoaded = true;
        for i,v in ipairs(self.buttons) do
            NEB_ABT_UpdateMacro(v);
            NEB_ABT_UpdateCompanion(v);
            NEB_ABT_UpdateSpell(v);
            NEB_ABT_Update(v);
        end

    elseif (event == "PLAYER_EXITING_WORLD") then
        self.worldLoaded = false;
    end
end
NEB_ABTFrame:SetScript("OnEvent", NEB_ABTFrame.OnEvent);


-- PreClick: capture cursor before secure handler eats it
function NEB_ABT_PreClick(self)
    if (InCombatLockdown()) then return; end
    self.cursorCommand, self.cursorValue, self.cursorSubValue = GetCursorInfo();
    if (self.cursorCommand) then
        self:SetAttribute("type", "none");
    end
end

-- PostClick: restore button after cursor swap
function NEB_ABT_PostClick(self)
    if (InCombatLockdown()) then return; end
    if (self.cursorCommand) then
        local set = GetActiveTalentGroup();
        self:SetAttribute("type", self["set"..set.."type"]);
        NEB_ABT_SetFromCursorInfo(self, self.cursorCommand, self.cursorValue, self.cursorSubValue);
        self.cursorCommand = nil;
        self.cursorValue   = nil;
        self.cursorSubValue = nil;
    end
end

function NEB_ABT_OnDragStart(self)
    if (InCombatLockdown() or self.locked) then return; end
    local command, value = NEB_ABT_GetCommand(self, true);
    NEB_ABT_SetCursor(command, value);
    NEB_ABT_SetCommand(self, "none", "", "", "", "");
end

function NEB_ABT_OnReceiveDrag(self)
    local command, value, subValue = GetCursorInfo();
    if ((not InCombatLockdown()) and (command == "spell" or command == "item" or command == "macro" or command == "companion")) then
        NEB_ABT_SetFromCursorInfo(self, command, value, subValue);
    end
end

function NEB_ABT_OnUpdate(self, elapsed)
    NEB_ABT_AnimateFlash(self, elapsed);
    NEB_ABT_RangeIndicator(self, elapsed);
end

function NEB_ABT_Update(self)
    NEB_ABT_UpdateTexture(self);
    NEB_ABT_UpdateChecked(self);
    NEB_ABT_UpdateCooldown(self);
    NEB_ABT_UpdateUsable(self);
    NEB_ABT_UpdateEquipped(self);
    NEB_ABT_UpdateHotkeys(self);
    NEB_ABT_UpdateText(self);
    if (GameTooltip:GetOwner() == self) then NEB_ABT_UpdateTooltip(self); end
    NEB_ABT_UpdateShow(self);
end

function NEB_ABT_OnLoad(self)
    self:SetAttribute("checkselfcast", true);
    self:SetAttribute("checkfocuscast", true);
    self:SetAttribute("useparent-unit", true);
    self:SetAttribute("useparent-actionpage", true);

    self.set1type = "none"; self.set1value = ""; self.set1actualtype = ""; self.set1name = ""; self.set1id = "";
    self.set2type = "none"; self.set2value = ""; self.set2actualtype = ""; self.set2name = ""; self.set2id = "";

    self.rangeTimer = -1;
    self.enabled = true;
    self.alwaysShowGrid = false;
    self.locked = false;
    self.disableTooltip = false;
    self:RegisterForDrag("LeftButton", "RightButton");
    self:RegisterForClicks("AnyUp");

    _G[self:GetName().."NormalTexture"]:SetVertexColor(1.0, 1.0, 1.0, 0.5);
    table.insert(NEB_ABTFrame.buttons, self);
end

function NEB_ABT_LoadAll(entries, settings)
    for k,v in pairs(entries) do
        local button = _G[k];
        if (button) then
            button.set1type = settings[k.."Set1Type"];
            button.set1value = settings[k.."Set1Value"];
            button.set1actualtype = settings[k.."Set1ActualType"];
            button.set1name = settings[k.."Set1Name"];
            button.set1id = settings[k.."Set1Id"];
            button.set2type = settings[k.."Set2Type"];
            button.set2value = settings[k.."Set2Value"];
            button.set2actualtype = settings[k.."Set2ActualType"];
            button.set2name = settings[k.."Set2Name"];
            button.set2id = settings[k.."Set2Id"];
            NEB_ABT_UpdateSpell(button);
            NEB_ABT_UpdateMacro(button);
            NEB_ABT_UpdateCompanion(button);
            NEB_ABT_SetFromStoredCommand(button);
        end
    end
end

function NEB_ABT_UpdateTexture(self)
    local icon = _G[self:GetName().."Icon"];
    local command, value = NEB_ABT_GetCommand(self);
    local realCommand, realValue = NEB_ABT_GetCommand(self, true);
    local texture = nil;

    if (command == "spell") then
        texture = GetSpellTexture(value);
    elseif (command == "item") then
        texture = GetItemIcon(value);
        if (not texture) then texture = GetItemIcon(NEB_ABT_GetId(self)); end
    elseif (command == "MOUNT" or command == "CRITTER") then
        local id, name, spellId;
        id, name, spellId, texture = GetCompanionInfo(command, value);
    end

    if (realCommand == "macro") then
        local macroName, macroTexture = GetMacroInfo(realValue);
        if (not texture or macroTexture ~= "Interface\\Icons\\INV_Misc_QuestionMark") then
            texture = macroTexture;
        end
    end

    if (texture) then
        icon:SetTexture(texture);
        icon:SetVertexColor(1.0, 1.0, 1.0, 1.0);
        icon:Show();
        self:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2");
    elseif (command == "spell") then
        icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark");
        icon:SetVertexColor(1.0, 1.0, 1.0, 0.5);
        icon:Show();
        self:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2");
    else
        local buttonCooldown = _G[self:GetName().."Cooldown"];
        icon:Hide();
        buttonCooldown:Hide();
        self:SetNormalTexture("Interface\\Buttons\\UI-Quickslot");
    end
end

function NEB_ABT_UpdateText(self)
    local text = _G[self:GetName().."Count"];
    local actionName = _G[self:GetName().."Name"];
    local command, value = NEB_ABT_GetCommand(self);

    text:SetText("");
    actionName:SetText("");

    if (command == "spell" and IsConsumableSpell(value)) then
        text:SetText(GetSpellCount(value));
    elseif (command == "item" and IsConsumableItem(value)) then
        text:SetText(GetItemCount(value));
    elseif (command == "item" and GetItemCount(value) > 1) then
        text:SetText(GetItemCount(value));
    elseif (self:GetAttribute("type") == "macro") then
        actionName:SetText(GetMacroInfo(self:GetAttribute("macro")));
    end
end

function NEB_ABT_UpdateTooltip(self)
    local command, value = NEB_ABT_GetCommand(self);
    if (self.disableTooltip) then self.UpdateTooltip = nil; return; end

    if (GetCVar("UberTooltips") == "1") then
        GameTooltip_SetDefaultAnchor(GameTooltip, self);
    else
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
    end

    if (command == "spell") then
        local spellId = NEB_ABT_FindSpellID(value);
        if (spellId and GameTooltip:SetSpell(spellId, BOOKTYPE_SPELL)) then
            self.UpdateTooltip = NEB_ABT_UpdateTooltip;
        else self.UpdateTooltip = nil; end
    elseif (command == "MOUNT" or command == "CRITTER") then
        local id, name, spellId = GetCompanionInfo(command, value);
        if (spellId and GameTooltip:SetHyperlink("spell:"..spellId)) then
            self.UpdateTooltip = NEB_ABT_UpdateTooltip;
        else self.UpdateTooltip = nil; end
    elseif (command == "item") then
        local res = false;
        local EquipSlot = NEB_ABT_FindItemEquipped(value);
        if (EquipSlot) then
            res = GameTooltip:SetInventoryItem("player", EquipSlot);
        else
            local bag, slot = NEB_ABT_FindItemInv(value);
            if (bag) then res = GameTooltip:SetBagItem(bag, slot);
            else
                local name, hyperLink = GetItemInfo(NEB_ABT_GetId(self));
                if (hyperLink) then res = GameTooltip:SetHyperlink(hyperLink); end
            end
        end
        if (res) then self.UpdateTooltip = NEB_ABT_UpdateTooltip; else self.UpdateTooltip = nil; end
    elseif (command == "macro") then
        local set = GetActiveTalentGroup();
        if (GameTooltip:SetText(self["set"..set.."name"], 1.0, 1.0, 1.0)) then
            self.UpdateTooltip = NEB_ABT_UpdateTooltip;
        else self.UpdateTooltip = nil; end
    end
end

function NEB_ABT_UpdateHotkeys(self)
    local hotkey = _G[self:GetName().."HotKey"];
    local key = GetBindingKey("CLICK "..self:GetName()..":LeftButton");
    local text = GetBindingText(key, "KEY_", 1);
    if (text == "") then
        hotkey:SetText(RANGE_INDICATOR);
        hotkey:SetPoint("TOPLEFT", self, "TOPLEFT", 1, -2);
        hotkey:Hide();
    else
        hotkey:SetText(text);
        hotkey:SetPoint("TOPLEFT", self, "TOPLEFT", -2, -2);
        hotkey:Show();
    end
end

function NEB_ABT_UpdateChecked(self)
    local command, value = NEB_ABT_GetCommand(self);
    if (command == "spell" and (IsCurrentSpell(value) or IsAutoRepeatSpell(value))) then
        self:SetChecked(1);
    elseif (command == "item" and IsCurrentItem(value)) then
        self:SetChecked(1);
    elseif (command == "MOUNT" or command == "CRITTER") then
        local id, name, spellId, texture, isCurrent = GetCompanionInfo(command, value);
        self:SetChecked(isCurrent);
        local castName = UnitCastingInfo("player");
        if (castName == name) then self:SetChecked(1); end
    else
        self:SetChecked(0);
    end
end

function NEB_ABT_UpdateCooldown(self)
    local cooldown = _G[self:GetName().."Cooldown"];
    local start, duration, enable;
    local command, value = NEB_ABT_GetCommand(self);

    if (command == "spell") then
        -- GetSpellCooldown works by name for player AND pet spells.
        -- No need to check FindSpellID (which only searches player spellbook).
        start, duration, enable = GetSpellCooldown(value);
    elseif (command == "item") then
        start, duration, enable = GetItemCooldown(value);
    elseif (command == "MOUNT" or command == "CRITTER") then
        start, duration, enable = GetCompanionCooldown(command, value);
    end

    if (start == nil) then start, duration, enable = 0, 0, 0; end
    CooldownFrame_SetTimer(cooldown, start, duration, enable);
end

function NEB_ABT_UpdateUsable(self)
    local name = self:GetName();
    local icon = _G[name.."Icon"];
    local normalTexture = _G[name.."NormalTexture"];
    local isUsable, notEnoughMana = true, false;
    local command, value = NEB_ABT_GetCommand(self);

    if (command == "spell") then
        isUsable, notEnoughMana = IsUsableSpell(value);
    elseif (command == "item" and GetItemCount(value) == 0) then
        isUsable = false;
    end

    if (isUsable) then
        icon:SetVertexColor(1.0, 1.0, 1.0);
        normalTexture:SetVertexColor(1.0, 1.0, 1.0);
    elseif (notEnoughMana) then
        icon:SetVertexColor(0.5, 0.5, 1.0);
        normalTexture:SetVertexColor(0.5, 0.5, 1.0);
    else
        icon:SetVertexColor(0.4, 0.4, 0.4);
        normalTexture:SetVertexColor(1.0, 1.0, 1.0);
    end
end

function NEB_ABT_UpdateEquipped(self)
    local command, value = NEB_ABT_GetCommand(self);
    local border = _G[self:GetName().."Border"];
    if (command == "item" and IsEquippedItem(value)) then
        border:SetVertexColor(0, 1.0, 0, 0.35);
        border:Show();
    else
        border:Hide();
    end
end

function NEB_ABT_UpdateShow(self)
    if (InCombatLockdown()) then return; end
    -- showGrid sources:
    --   self.alwaysShowGrid       = addon "Always Show Grid" checkbox
    --   NEB_ABTFrame.showGrid     = live drag state (ACTIONBAR_SHOWGRID event)
    --   NEB_ABTFrame.blizzShowGrid = Blizzard "Always Show Action Bars" CVar,
    --                               set by NEB:SyncBlizzShowGrid() in nExtraBars.lua
    local shouldShow = (self:GetAttribute("type") ~= "none"
                        or self.alwaysShowGrid
                        or NEB_ABTFrame.showGrid
                        or NEB_ABTFrame.blizzShowGrid);
    if (self:IsShown()) then
        if (not self.enabled or not shouldShow) then
            self:Hide();
        end
    else
        if (self.enabled and shouldShow) then
            self:Show();
        end
    end
end

function NEB_ABT_GetCommand(self, real)
    local set = GetActiveTalentGroup();
    local command = self["set"..set.."actualtype"];
    local value = self:GetAttribute(command);

    if (command == "macro" and not real) then
        local spellName, spellRank = GetMacroSpell(value);
        if (spellName) then
            command = "spell";
            value = spellName.."("..(spellRank or "")..")";
        else
            local itemName, itemLink = GetMacroItem(value);
            if (itemName) then command = "item"; value = itemLink; end
        end
    elseif (command == "MOUNT" or command == "CRITTER") then
        value = self["set"..set.."id"];
    end
    return command, value;
end

function NEB_ABT_GetId(self, set)
    if (not set) then set = GetActiveTalentGroup(); end
    return self["set"..set.."id"];
end

function NEB_ABT_SetCommand(self, command, value, actualType, name, id, noSave, set)
    if (InCombatLockdown()) then
        UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1.0, 0.1, 0.1, 1.0);
        return false;
    end
    local currentSet = GetActiveTalentGroup();
    if (not set) then set = currentSet; end

    self["set"..set.."type"] = command;
    self["set"..set.."value"] = value;
    self["set"..set.."actualtype"] = actualType;
    self["set"..set.."name"] = name;
    self["set"..set.."id"] = id;

    if (set == currentSet) then
        local currentCommand = self:GetAttribute("type");
        self:SetAttribute(command, value);
        self:SetAttribute("type", command);
        if command ~= currentCommand then self:SetAttribute(currentCommand, ""); end
        NEB_ABT_Update(self);
    end

    if (not noSave) then NEB_ABT_Save(self); end
    return true;
end

function NEB_ABT_Save(self)
    local entries = _G[self:GetAttribute("saveentries")];
    local settings = _G[self:GetAttribute("savesettings")];
    if (not entries or not settings) then return; end

    local selfName = self:GetName();
    entries[selfName] = 1;

    settings[selfName.."Set1Type"] = self.set1type;
    settings[selfName.."Set1Value"] = self.set1value;
    settings[selfName.."Set1ActualType"] = self.set1actualtype;
    settings[selfName.."Set1Name"] = self.set1name;
    settings[selfName.."Set1Id"] = self.set1id;
    settings[selfName.."Set2Type"] = self.set2type;
    settings[selfName.."Set2Value"] = self.set2value;
    settings[selfName.."Set2ActualType"] = self.set2actualtype;
    settings[selfName.."Set2Name"] = self.set2name;
    settings[selfName.."Set2Id"] = self.set2id;
end

function NEB_ABT_SetFromCursorInfo(self, command, value, subValue)
    local currentCommand, currentValue = NEB_ABT_GetCommand(self, true);

    if (command == "spell") then
        local spellNameFull, spell = NEB_ABT_GetSpellName(value, BOOKTYPE_SPELL);
        if (spellNameFull) then
            NEB_ABT_SetCommand(self, command, spellNameFull, "spell", spell, "");
        end
    elseif (command == "item") then
        local itemName = GetItemInfo(value);
        NEB_ABT_SetCommand(self, command, itemName, "item", subValue, value);
    elseif (command == "macro") then
        local macroName = GetMacroInfo(value);
        NEB_ABT_SetCommand(self, command, value, "macro", macroName, "");
    elseif (command == "companion") then
        local id, name, spellId = GetCompanionInfo(subValue, value);
        local spellName = GetSpellInfo(spellId);
        NEB_ABT_SetCommand(self, "spell", spellName, subValue, name, value);
    end
    NEB_ABT_SetCursor(currentCommand, currentValue);
end

function NEB_ABT_SetFromStoredCommand(self)
    local set = GetActiveTalentGroup();
    NEB_ABT_SetCommand(self, self["set"..set.."type"], self["set"..set.."value"],
                       self["set"..set.."actualtype"], self["set"..set.."name"],
                       self["set"..set.."id"], true);
end

function NEB_ABT_SetCursor(command, value)
    if (InCombatLockdown()) then return; end
    ClearCursor();
    if (command == "spell") then PickupSpell(value);
    elseif (command == "item") then PickupItem(value);
    elseif (command == "macro") then PickupMacro(value);
    elseif (command == "MOUNT" or command == "CRITTER") then PickupCompanion(command, value);
    end
end

function NEB_ABT_GetSpellName(spell, ...)
    local name, rank = GetSpellName(spell, ...);
    if (name) then return name.."("..rank..")", name; end
    return nil, nil;
end

function NEB_ABT_FindSpellID(spellName)
    local i = 1;
    while true do
        local spell = NEB_ABT_GetSpellName(i, BOOKTYPE_SPELL);
        if (not spell) then break; end
        if (spellName == spell) then return i; end
        i = i + 1;
    end
    return nil;
end

function NEB_ABT_FindCompanionID(compType, compName)
    for i = 1, GetNumCompanions(compType) do
        local id, name = GetCompanionInfo(compType, i);
        if (name == compName) then return i; end
    end
    return nil;
end

-- Find highest rank of a spell by base name (iterates spellbook numerically)
local function NEB_ABT_FindHighestRankByName(baseName)
    local i = 1
    local bestFull = nil
    while true do
        local name, rank = GetSpellName(i, BOOKTYPE_SPELL)
        if (not name) then break end
        if (name == baseName) then
            bestFull = name.."("..rank..")"
        end
        i = i + 1
    end
    return bestFull
end

function NEB_ABT_UpdateSpell(self)
    if (InCombatLockdown() or not NEB_ABTFrame.worldLoaded) then return; end
    if (self.set1actualtype == "spell") then
        local maxSpell = NEB_ABT_FindHighestRankByName(self.set1name);
        if (maxSpell and maxSpell ~= self.set1value) then
            NEB_ABT_SetCommand(self, "spell", maxSpell, "spell", self.set1name, "", false, 1);
        end
    end
    if (self.set2actualtype == "spell") then
        local maxSpell = NEB_ABT_FindHighestRankByName(self.set2name);
        if (maxSpell and maxSpell ~= self.set2value) then
            NEB_ABT_SetCommand(self, "spell", maxSpell, "spell", self.set2name, "", false, 2);
        end
    end
end

function NEB_ABT_UpdateMacro(self)
    if (InCombatLockdown() or not NEB_ABTFrame.worldLoaded) then return; end
    if (self.set1actualtype == "macro") then
        local macroID = GetMacroIndexByName(self.set1name);
        if (macroID == 0) then NEB_ABT_SetCommand(self, "none", "", "", "", "", false, 1);
        elseif (macroID ~= self.set1value) then NEB_ABT_SetCommand(self, "macro", macroID, "macro", self.set1name, "", false, 1); end
    end
    if (self.set2actualtype == "macro") then
        local macroID = GetMacroIndexByName(self.set2name);
        if (macroID == 0) then NEB_ABT_SetCommand(self, "none", "", "", "", "", false, 2);
        elseif (macroID ~= self.set2value) then NEB_ABT_SetCommand(self, "macro", macroID, "macro", self.set2name, "", false, 2); end
    end
end

function NEB_ABT_UpdateCompanion(self)
    if (InCombatLockdown() or not NEB_ABTFrame.worldLoaded) then return; end
    if (self.set1actualtype == "MOUNT" or self.set1actualtype == "CRITTER") then
        local id = NEB_ABT_FindCompanionID(self.set1actualtype, self.set1name);
        if (id and id ~= self.set1id) then NEB_ABT_SetCommand(self, "spell", self.set1value, self.set1actualtype, self.set1name, id, false, 1); end
    end
    if (self.set2actualtype == "MOUNT" or self.set2actualtype == "CRITTER") then
        local id = NEB_ABT_FindCompanionID(self.set2actualtype, self.set2name);
        if (id and id ~= self.set2id) then NEB_ABT_SetCommand(self, "spell", self.set2value, self.set2actualtype, self.set2name, id, false, 2); end
    end
end

function NEB_ABT_UpdateFlash(self)
    local command, value = NEB_ABT_GetCommand(self);
    if (command == "spell" and (IsAutoRepeatSpell(value) or (IsAttackSpell(value) and IsCurrentSpell(value)))) then
        NEB_ABT_StartFlash(self);
    else
        NEB_ABT_StopFlash(self);
    end
end

function NEB_ABT_StartFlash(self)
    self.flashing = 1;
    self.flashtime = 0;
    NEB_ABT_UpdateChecked(self);
end

function NEB_ABT_StopFlash(self)
    self.flashing = 0;
    _G[self:GetName().."Flash"]:Hide();
    NEB_ABT_UpdateChecked(self);
end

function NEB_ABT_AnimateFlash(self, elapsed)
    if (self.flashing == 1) then
        local flashtime = self.flashtime - elapsed;
        if (flashtime <= 0) then
            local overtime = -flashtime;
            if (overtime >= ATTACK_BUTTON_FLASH_TIME) then overtime = 0; end
            flashtime = ATTACK_BUTTON_FLASH_TIME - overtime;
            local flashTexture = _G[self:GetName().."Flash"];
            if (flashTexture:IsShown()) then flashTexture:Hide(); else flashTexture:Show(); end
        end
        self.flashtime = flashtime;
    end
end

function NEB_ABT_RangeIndicator(self, elapsed)
    local rangeTimer = self.rangeTimer;
    if (rangeTimer) then
        rangeTimer = rangeTimer - elapsed;
        if (rangeTimer <= 0) then
            local count = _G[self:GetName().."HotKey"];
            local command, value = NEB_ABT_GetCommand(self);
            local valid;
            if (command == "spell") then valid = IsSpellInRange(value);
            elseif (command == "item") then valid = IsItemInRange(value); end
            if (count:GetText() == RANGE_INDICATOR) then
                if (valid == 0) then count:Show(); count:SetVertexColor(1.0, 0.1, 0.1);
                elseif (valid == 1) then count:Show(); count:SetVertexColor(0.6, 0.6, 0.6);
                else count:Hide(); end
            else
                if (valid == 0) then count:SetVertexColor(1.0, 0.1, 0.1);
                else count:SetVertexColor(0.6, 0.6, 0.6); end
            end
            rangeTimer = TOOLTIP_UPDATE_TIME;
        end
        self.rangeTimer = rangeTimer;
    end
end

function NEB_ABT_SetAlwaysShowGrid(self, value)
    self.alwaysShowGrid = value;
    NEB_ABT_UpdateShow(self);
end

function NEB_ABT_SetLockButton(self, value)
    self.locked = value;
end

function NEB_ABT_SetDisableTooltip(self, value)
    self.disableTooltip = value;
end

function NEB_ABT_SetEnabled(self, value)
    self.enabled = value;
    NEB_ABT_UpdateShow(self);
end

function NEB_ABT_UpdateSavedDataVersion(entries, settings)
    if (not settings["version"] or settings["version"]+0 < 0.6) then
        local tempSettings = {};
        for k,v in pairs(entries) do
            tempSettings[k.."Set1Type"] = settings[k.."Set1Type"];
            tempSettings[k.."Set1Value"] = settings[k.."Set1Value"];
            local actualType = settings[k.."Set1Type"];
            local name;
            if (actualType == "spell") then name = settings[k.."Set1SpellName"];
            elseif (actualType == "item") then name = "";
            elseif (actualType == "macro") then name = settings[k.."Set1MacroName"]; end
            tempSettings[k.."Set1ActualType"] = actualType;
            tempSettings[k.."Set1Name"] = name;
            tempSettings[k.."Set1Id"] = "";
            tempSettings[k.."Set2Type"] = settings[k.."Set2Type"];
            tempSettings[k.."Set2Value"] = settings[k.."Set2Value"];
            actualType = settings[k.."Set2Type"];
            if (actualType == "spell") then name = settings[k.."Set2SpellName"];
            elseif (actualType == "item") then name = "";
            elseif (actualType == "macro") then name = settings[k.."Set2MacroName"]; end
            tempSettings[k.."Set2ActualType"] = actualType;
            tempSettings[k.."Set2Name"] = name;
            tempSettings[k.."Set2Id"] = "";
        end
        settings = tempSettings;
        settings["version"] = 0.6;
    end

    if (settings["version"]+0 < 0.72) then
        for k,v in pairs(entries) do
            for s = 1, 2 do
                if (settings[k.."Set"..s.."Type"] == "item") then
                    settings[k.."Set"..s.."Id"], settings[k.."Set"..s.."Value"] = NEB_ABT_GetItemInfoFromLink(settings[k.."Set"..s.."Value"]);
                end
            end
        end
        settings["version"] = 0.72;
    end

    if (settings["version"]+0 < 1) then
        for k,v in pairs(entries) do
            for s = 1, 2 do
                if (settings[k.."Set"..s.."ActualType"] == "MOUNT" or settings[k.."Set"..s.."ActualType"] == "CRITTER") then
                    local creatureID, creatureName, spellID = GetCompanionInfo(settings[k.."Set"..s.."ActualType"], settings[k.."Set"..s.."Id"]);
                    local name = GetSpellInfo(spellID);
                    settings[k.."Set"..s.."Value"] = name;
                end
            end
        end
        settings["version"] = 1;
    end
    return entries, settings;
end

function NEB_ABT_GetItemInfoFromLink(ItemLink)
    if (not ItemLink) then return nil, nil; end
    local s, e, id, name = strfind(ItemLink, "item:(%d+):.-h%[(.-)%]");
    return id, name;
end

function NEB_ABT_FindItemInv(ItemName)
    for i = 0, 4 do
        local size = GetContainerNumSlots(i);
        for s = 1, size do
            local id, name = NEB_ABT_GetItemInfoFromLink(GetContainerItemLink(i, s));
            if (name == ItemName) then return i, s; end
        end
    end
    return nil, nil;
end

function NEB_ABT_FindItemEquipped(ItemName)
    for i = 0, 23 do
        local id, name = NEB_ABT_GetItemInfoFromLink(GetInventoryItemLink("player", i));
        if (name == ItemName) then return i; end
    end
    return nil;
end