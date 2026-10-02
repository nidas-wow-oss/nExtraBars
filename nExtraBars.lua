--[[
  nExtraBars.lua  v2.4.1
  Author: Nidhaus

  Two extra action bars (Left & Right) that automatically track the
  WoW bottom-bar stack. Bars are NOT draggable — position is automatic.

  "Show Grid" (empty button visibility) is controlled exclusively by
  Blizzard's Interface > Action Bars > "Always Show Action Bars" CVar.

  Slash: /neb
  
  v2.4.0 - Rewrote pet bar handling using CT_BarMod's proven method:
           reparent the pet BUTTONS to our own frame (never move Blizzard's
           PetActionBarFrame) and wait for the slide animation (.completed)
           before repositioning. Fixes the pet bar dropping/overlapping.
  v2.3.1 - Yield pet/stance/totem/possess bars to CT_BarMod when its
           "Shift ... up" option is active (prevents mutual-hook loop that
           made the pet bar jump/overlap in arena)
  v2.3.0 - Fixed pet bar drift/orphan bug in arena (base position is now
           immutable; offset applied absolutely; combat-deferred re-apply)
  v2.2.2 - Fixed pet bar bug when player AND pet receive Fear/CC simultaneously
  v2.2.1 - Fixed pet bar bug when pet receives Fear or similar CC effects
]]

local ADDON_NAME = "nExtraBars"
local NEB        = CreateFrame("Frame")
local OFFSET_Y   = 45   -- pixels to push class/stance/totem bars upward
-- Offset vertical de la barra de mascota, RELATIVO a la pet bar de Blizzard.
-- CT_BarMod usa 2 (pegada). Subilo si querés más separación hacia arriba.
-- OJO: la pet bar se ancla sobre la de Blizzard, no sobre la barra extra,
-- así que este número es chico (no 45). Ajustá a gusto.
local PET_OFFSET_Y = 2

-- ─────────────────────────────────────────────
-- ArcaneBlue palette
-- ─────────────────────────────────────────────
local AB = {
    frameBG      = { 0.028, 0.048, 0.095, 0.97 },
    frameBorder  = { 0.22,  0.52,  0.92,  0.95 },
    titleBG      = { 0.035, 0.065, 0.140, 1.00 },
    titleBorder  = { 0.32,  0.72,  1.00,  1.00 },
    panelBG      = { 0.038, 0.075, 0.145, 0.75 },
    panelBorder  = { 0.22,  0.52,  0.90,  0.70 },
    accentBright = { 0.32,  0.72,  1.00,  0.80 },
    accentDim    = { 0.18,  0.44,  0.82,  0.45 },
    section      = { 0.40,  0.82,  1.00 },
    cbText       = { 0.82,  0.92,  1.00 },
    cbHover      = { 0.12,  0.22,  0.40,  0.75 },
    footer       = { 0.22,  0.52,  0.82 },
    titleText    = { 1.00,  0.82,  0.05 },   -- golden yellow
}

-- ─────────────────────────────────────────────
-- Options-panel layout
-- NUM_CBS = 2: Enable, Lock Buttons
-- ─────────────────────────────────────────────
local OPT_W        = 300
local PANEL_INDENT = 14
local CB_INDENT    = 12
local CB_SPACING   = 26
local NUM_CBS      = 2
local PANEL_PAD_T  = 8
local PANEL_PAD_B  = 6
local PANEL_H      = PANEL_PAD_T + (NUM_CBS * CB_SPACING) + PANEL_PAD_B  -- 66
-- La barra izquierda tiene un checkbox mas ("Raise class bars only if used").
local LEFT_PANEL_H = PANEL_H + CB_SPACING
local OPT_H = 340 + CB_SPACING

-- ─────────────────────────────────────────────
-- Utility
-- ─────────────────────────────────────────────
local function NVL(v1, v2)
    if type(v1) == "nil" then return v2 else return v1 end
end

local function SetABBackdrop(frame, tileSize, edgeSize, inset, bg, border)
    frame:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile     = true, tileSize = tileSize, edgeSize = edgeSize,
        insets   = { left = inset, right = inset, top = inset, bottom = inset },
    })
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
end

local function MakeLine(parent, yOff, col)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetTexture("Interface/Tooltips/UI-Tooltip-Border")
    t:SetHeight(1)
    t:SetPoint("TOPLEFT",  parent, "TOPLEFT",  16, yOff)
    t:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, yOff)
    t:SetVertexColor(col[1], col[2], col[3], col[4])
    return t
end

local function MakeSection(parent, label, yOff)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yOff)
    fs:SetTextColor(AB.section[1], AB.section[2], AB.section[3])
    fs:SetText(label)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetTexture("Interface/Tooltips/UI-Tooltip-Border")
    line:SetHeight(1)
    line:SetPoint("LEFT",  fs,     "RIGHT",  6,   0)
    line:SetPoint("RIGHT", parent, "RIGHT", -16,  0)
    line:SetVertexColor(AB.accentDim[1], AB.accentDim[2],
                        AB.accentDim[3], AB.accentDim[4])
end

-- ─────────────────────────────────────────────
-- Events
-- ─────────────────────────────────────────────
NEB:RegisterEvent("ADDON_LOADED")
NEB:RegisterEvent("PLAYER_ENTERING_WORLD")
NEB:RegisterEvent("PLAYER_REGEN_ENABLED")
NEB:RegisterEvent("CVAR_UPDATE")

NEB:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        self:InitSavedVars()

    elseif event == "PLAYER_ENTERING_WORLD" then
        self:InitBars()
        self:InitFrameMover()
        self:InitOptions()
        NEB_ABT_LoadAll(NEB_ButtonEntries, NEB_ButtonSettings)
        self:RefreshAllLayout()
        self:SyncBlizzShowGrid()
        self:InitLortiIntegration()
        NEB:UnregisterEvent("PLAYER_ENTERING_WORLD")

    elseif event == "PLAYER_REGEN_ENABLED" then
        self:RefreshAllLayout()
        self:RefreshBarVisibility("Left")
        self:RefreshBarVisibility("Right")

    elseif event == "CVAR_UPDATE" then
        if arg1 == "alwaysShowActionBars" then
            self:SyncBlizzShowGrid()
        end
    end
end)

-- ─────────────────────────────────────────────
-- SyncBlizzShowGrid
-- Reads Blizzard's "Always Show Action Bars" CVar and propagates
-- to every NEB button so empty slots show/hide accordingly.
-- ─────────────────────────────────────────────
function NEB:SyncBlizzShowGrid()
    if not NEB_ABTFrame then return end
    NEB_ABTFrame.blizzShowGrid = (GetCVar("alwaysShowActionBars") == "1")
    for _, v in ipairs(NEB_ABTFrame.buttons) do
        NEB_ABT_UpdateShow(v)
    end
end

-- ─────────────────────────────────────────────
-- Saved variables (unified in NEB_DB)
-- Global aliases NEB_ButtonEntries, NEB_ButtonSettings, NEB_Config
-- point into NEB_DB so existing code (XML attributes, Save, LoadAll) works unchanged.
-- ─────────────────────────────────────────────
function NEB:InitSavedVars()
    if not NEB_DB then NEB_DB = {} end
    if not NEB_DB.Entries  then NEB_DB.Entries  = {} end
    if not NEB_DB.Settings then NEB_DB.Settings = {} end
    if not NEB_DB.Config   then NEB_DB.Config   = {} end

    -- ── Migration from old 3-variable format ─────────────────
    -- If old globals exist (from before unification), absorb them into NEB_DB
    -- and nil out the old globals so WoW doesn't write them anymore.
    if _G["NEB_ButtonEntries"] and _G["NEB_ButtonEntries"] ~= NEB_DB.Entries then
        for k, v in pairs(_G["NEB_ButtonEntries"]) do NEB_DB.Entries[k] = v end
    end
    if _G["NEB_ButtonSettings"] and _G["NEB_ButtonSettings"] ~= NEB_DB.Settings then
        for k, v in pairs(_G["NEB_ButtonSettings"]) do NEB_DB.Settings[k] = v end
    end
    if _G["NEB_Config"] and _G["NEB_Config"] ~= NEB_DB.Config then
        for k, v in pairs(_G["NEB_Config"]) do NEB_DB.Config[k] = v end
    end

    -- Set global aliases (used by XML attributes and NEB_ABT_Save/LoadAll)
    NEB_ButtonEntries  = NEB_DB.Entries
    NEB_ButtonSettings = NEB_DB.Settings
    NEB_Config         = NEB_DB.Config

    if not NEB_Config["version"] then NEB_Config["version"] = 2.22 end

    -- Remove obsolete keys from earlier versions
    for _, k in ipairs({
        "LeftPosX","LeftPosY","LeftSavedXPRepH",
        "RightPosX","RightPosY","RightSavedXPRepH",
        "LeftOffsetX","LeftOffsetY","RightOffsetX","RightOffsetY",
        "LeftLockBar","RightLockBar",
        "LeftShowGrid","RightShowGrid",
        "LeftHideVehicle","RightHideVehicle",
    }) do NEB_Config[k] = nil end

    NEB_Config["LeftEnabled"]      = NVL(NEB_Config["LeftEnabled"],      true)
    NEB_Config["LeftLockButtons"]  = NVL(NEB_Config["LeftLockButtons"],  false)
    NEB_Config["LeftNumButtons"]   = NVL(NEB_Config["LeftNumButtons"],   12)
    -- Subir las barras de clase solo si la barra izquierda tiene algo puesto.
    NEB_Config["LeftShiftOnlyIfUsed"] = NVL(NEB_Config["LeftShiftOnlyIfUsed"], true)

    NEB_Config["RightEnabled"]     = NVL(NEB_Config["RightEnabled"],     false)
    NEB_Config["RightLockButtons"] = NVL(NEB_Config["RightLockButtons"], false)
    NEB_Config["RightNumButtons"]  = NVL(NEB_Config["RightNumButtons"],  12)

    NEB_ButtonEntries, NEB_ButtonSettings =
        NEB_ABT_UpdateSavedDataVersion(NEB_ButtonEntries, NEB_ButtonSettings)

    -- Sync back after version migration (may have replaced tables)
    NEB_DB.Entries  = NEB_ButtonEntries
    NEB_DB.Settings = NEB_ButtonSettings
end

-- ─────────────────────────────────────────────
-- Auto bar positioning
-- Anchors above MultiBarBottomLeft (when visible) or ActionButton1.
-- ─────────────────────────────────────────────
function NEB:PositionBar(side, bar)
    if not bar then return end
    bar:ClearAllPoints()
    local xOff = 0
    if (side == "Right") then
        xOff = (NEB_Config["LeftNumButtons"] or 12) * 42 + 8
    end
    if MultiBarBottomLeft and MultiBarBottomLeft:IsShown() then
        bar:SetPoint("BOTTOMLEFT", MultiBarBottomLeft, "TOPLEFT", xOff, 4)
    elseif ActionButton1 then
        bar:SetPoint("BOTTOMLEFT", ActionButton1, "TOPLEFT", xOff, 4)
    end
end

function NEB:RefreshAllLayout()
    if InCombatLockdown() then return end
    self:PositionBar("Left",  NEB_BarLeft)
    self:PositionBar("Right", NEB_BarRight)
    self:ApplyFrameOffsets()
end

-- ─────────────────────────────────────────────
-- API pública: re-aplicar NEB_Config sin /reload.
-- La usa "Character Setup" de Nidhaus UnitFrames cuando copia un personaje
-- (qué barras están prendidas, cuántos botones, bloqueo). NEB es local, por
-- eso hace falta esta puerta global.
-- ─────────────────────────────────────────────
-- ─────────────────────────────────────────────
-- ¿Subir las barras de clase? (posturas, auras, totems, mascota...)
--
-- Antes alcanzaba con que la barra izquierda estuviera PRENDIDA. Ahora,
-- con "Raise class bars only if used" (prendida por defecto), ademas
-- tiene que tener al menos un hechizo, objeto o macro en el talento
-- activo: una barra vacia no se ve, y subir las otras dejaba un hueco.
-- ─────────────────────────────────────────────
function NEB_LeftBarHasContent()
    local num = NEB_Config["LeftNumButtons"] or 12
    local set = (GetActiveTalentGroup and GetActiveTalentGroup()) or 1
    local st  = NEB_ButtonSettings
    for i = 1, num do
        local name = "NEB_BarLeftButton"..i
        local btn  = _G[name]
        -- El boton (lo vivo) o lo guardado (por si todavia no se cargo).
        local t1 = btn and btn["set"..set.."type"]
        local t2 = type(st) == "table" and st[name.."Set"..set.."Type"]
        if (t1 and t1 ~= "" and t1 ~= "none") or (t2 and t2 ~= "" and t2 ~= "none") then
            return true
        end
    end
    return false
end

function NEB_ClassBarsShifted()
    if not NEB_Config or not NEB_Config["LeftEnabled"] then return false end
    if NEB_Config["LeftShiftOnlyIfUsed"] == false then return true end
    return NEB_LeftBarHasContent()
end

-- Cuanto se suben. Nidhaus UnitFrames lo lee para su barra de posturas.
NEB_CLASSBAR_OFFSET = OFFSET_Y

-- Aviso: se llama cada vez que cambia si hay que subir o no. No hace nada;
-- existe para que otros addons (Nidhaus UnitFrames) se enganchen.
function NEB_ClassBarShiftChanged(shifted) end

function NEB_ApplyConfig()
    if InCombatLockdown() then return false end
    NEB:RefreshBar("Left")
    NEB:RefreshBar("Right")
    NEB:RefreshAllLayout()
    return true
end

-- ─────────────────────────────────────────────
-- Bar initialization
-- ─────────────────────────────────────────────
function NEB:InitBars()
    self:InitSingleBar("Left",  NEB_BarLeft)
    self:InitSingleBar("Right", NEB_BarRight)
end

function NEB:InitSingleBar(side, bar)
    if not bar then return end
    local name = bar:GetName()

    _G["BINDING_HEADER_"..name] = "nExtraBars "..side
    for i = 1, 12 do
        _G["BINDING_NAME_CLICK "..name.."Button"..i..":LeftButton"] =
            side.." Bar Button "..i
    end

    -- Bars are NOT draggable.
    -- Backdrop is set but kept fully transparent — it is never shown.
    -- It must still exist so SetBackdropColor can be called without error.
    bar:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    bar:SetBackdropColor(0, 0, 0, 0)          -- fully transparent
    bar:SetBackdropBorderColor(0, 0, 0, 0)    -- fully transparent

    bar:SetMovable(false)
    bar:EnableMouse(false)
    bar:SetClampedToScreen(true)

    bar:Execute([[nebButtons = newtable(); owner:GetChildList(nebButtons);]])
    bar:SetAttribute("_onshow", [[for k,v in ipairs(nebButtons) do v:Enable(); end]])
    bar:SetAttribute("_onhide", [[for k,v in ipairs(nebButtons) do v:Disable(); end]])

    self:RefreshBar(side)
end

-- ─────────────────────────────────────────────
-- Per-bar settings
-- ─────────────────────────────────────────────
function NEB:RefreshBar(side)
    self:ApplyEnabled(side)
    -- ShowGrid is driven by Blizzard CVar only; always pass false here.
    -- SyncBlizzShowGrid() sets NEB_ABTFrame.blizzShowGrid which NEB_ABT_UpdateShow checks.
    self:ApplyShowGrid(side)
    self:ApplyLockButtons(side)
    self:ApplyNumButtons(side)
end

function NEB:GetBar(side)
    if side == "Left" then return NEB_BarLeft end
    return NEB_BarRight
end

function NEB:RefreshBarVisibility(side)
    if InCombatLockdown() then return end
    self:ApplyEnabled(side)
end

function NEB:ApplyEnabled(side)
    if InCombatLockdown() then return end
    local bar = self:GetBar(side)
    if not bar then return end
    UnregisterStateDriver(bar, "visibility")
    if not NEB_Config[side.."Enabled"] then
        bar:Hide()
    else
        -- Show the bar immediately, then register the state driver for vehicle.
        -- bar:Show() ensures the bar is visible right now.
        -- The state driver overrides when vehicleui becomes active (driving/controlling).
        -- On Warmane 3.3.5a, RegisterStateDriver alone may not trigger an
        -- immediate re-evaluation after UnregisterStateDriver, leaving the bar hidden.
        bar:Show()
        RegisterStateDriver(bar, "visibility", "[vehicleui] hide; show")
    end
    self:ApplyFrameOffsets()
end

-- ShowGrid: always false from the addon side.
-- Visibility of empty buttons is handled entirely by SyncBlizzShowGrid()
-- via NEB_ABTFrame.blizzShowGrid and the ACTIONBAR_SHOWGRID/HIDEGRID events.
function NEB:ApplyShowGrid(side)
    local bar = self:GetBar(side)
    if not bar then return end
    for _, v in ipairs({ bar:GetChildren() }) do
        if v:GetObjectType() == "CheckButton" then
            NEB_ABT_SetAlwaysShowGrid(v, false)
        end
    end
end

function NEB:ApplyLockButtons(side)
    local bar = self:GetBar(side)
    if not bar then return end
    local val = NEB_Config[side.."LockButtons"]
    for _, v in ipairs({ bar:GetChildren() }) do
        if v:GetObjectType() == "CheckButton" then
            NEB_ABT_SetLockButton(v, val)
        end
    end
end

function NEB:ApplyNumButtons(side)
    if InCombatLockdown() then return end
    local bar = self:GetBar(side)
    if not bar then return end
    local num   = NEB_Config[side.."NumButtons"]
    local count = 0
    for _, v in ipairs({ bar:GetChildren() }) do
        if v:GetObjectType() == "CheckButton" then
            count = count + 1
            NEB_ABT_SetEnabled(v, count <= num)
        end
    end
    bar:SetWidth(num * 42 + 8)
    bar:SetHeight(46)
end

-- ─────────────────────────────────────────────
-- Frame mover — pushes class/pet/stance/totem bars upward
--
-- v2.4.0 REESCRITURA (barra de mascota):
--   Los intentos anteriores movían el frame CONTENEDOR (PetActionBarFrame)
--   hacia arriba. Blizzard es dueño de ese frame y lo reposiciona con una
--   ANIMACIÓN de deslizamiento cada vez que la mascota aparece/cambia. Mover
--   el frame mientras se desliza = pelea que Blizzard gana → la barra "se baja"
--   y se encima con la barra extra. Ese era el bug, y no se arregla peleando.
--
--   Solución: copiar el enfoque de CT_BarMod (que SÍ funciona):
--     1) NUNCA mover PetActionBarFrame. Dejarlo a Blizzard.
--     2) Crear un frame propio (NEB_PetHolder) anclado arriba de la barra extra.
--     3) Reparentar los BOTONES individuales (PetActionButton1-10) a ese frame.
--     4) Esperar a que PetActionBarFrame.completed == true (animación de
--        deslizamiento terminada) ANTES de reposicionar. Esta es la clave:
--        reposicionar durante la animación es lo que hacía que se bajara.
--     5) Guardar las funciones SetPoint/ClearAllPoints originales para poder
--        mover los botones aunque su SetPoint esté hookeado.
--
--   Las otras barras (shapeshift/possess/totem) NO tienen animación de
--   deslizamiento, así que se siguen moviendo con el método simple de offset,
--   pero cediendo a CT_BarMod si él las maneja.
-- ─────────────────────────────────────────────

-- Funciones originales guardadas (para mover botones con SetPoint hookeado).
-- Mismo método que CT_BarMod: tomarlas de un frame recién creado antes de
-- que nadie las hookee.
local NEB_probeFrame       = CreateFrame("Frame")
local frameSetPoint        = NEB_probeFrame.SetPoint
local frameClearAllPoints  = NEB_probeFrame.ClearAllPoints

-- Barras "simples" (sin animación de deslizamiento): offset del contenedor.
local simpleFrames = {
    "ShapeshiftBarFrame",
    "PossessBarFrame",
    "MultiCastActionBarFrame",
}

-- CT_BarMod maneja estas barras con su opción "Shift ... up" (activa por
-- default). Si detectamos su frame centinela, cedemos y no tocamos esa barra.
local ctBarModSentinels = {
    ShapeshiftBarFrame        = "CT_BarMod_ShapeshiftBarFrame",
    PetActionBarFrame         = "CT_BarMod_PetActionBarFrame",
    PossessBarFrame           = "CT_BarMod_PossessBarFrame",
    MultiCastActionBarFrame   = "CT_BarMod_MultiCastActionBarFrame",
}
local function CTBarModOwnsFrame(frameName)
    local sentinel = ctBarModSentinels[frameName]
    return sentinel and _G[sentinel] ~= nil
end

local isApplying        = false
local lastShiftNotified = nil
local basePositions     = {}
local appliedPositions  = {}
local applyPending      = false

local function PointsMatch(a, b)
    if not a or not b then return false end
    if #a ~= #b then return false end
    for i = 1, #a do
        local p, q = a[i], b[i]
        if p.point ~= q.point or p.relativePoint ~= q.relativePoint
           or p.relativeTo ~= q.relativeTo
           or math.abs((p.x or 0) - (q.x or 0)) > 0.5
           or math.abs((p.y or 0) - (q.y or 0)) > 0.5 then
            return false
        end
    end
    return true
end

local function ReadPoints(f)
    local n = f:GetNumPoints()
    if n == 0 then return nil end
    local pts = {}
    for i = 1, n do
        local pt, rel, relPt, x, y = f:GetPoint(i)
        pts[i] = { point = pt, relativeTo = rel or UIParent,
                   relativePoint = relPt, x = x or 0, y = y or 0 }
    end
    return pts
end

local function CaptureBaseIfNeeded(frameName)
    local f = _G[frameName]
    if not f then return end
    local current = ReadPoints(f)
    if not current then return end
    if appliedPositions[frameName] and PointsMatch(current, appliedPositions[frameName]) then
        return
    end
    basePositions[frameName] = current
end

local function ApplyOffsetToFrame(frameName, dy)
    local f = _G[frameName]
    if not f then return end
    if CTBarModOwnsFrame(frameName) then return end
    CaptureBaseIfNeeded(frameName)
    local base = basePositions[frameName]
    if not base then return end
    local final = {}
    for i, p in ipairs(base) do
        final[i] = { point = p.point, relativeTo = p.relativeTo,
                     relativePoint = p.relativePoint, x = p.x, y = p.y + dy }
    end
    f:ClearAllPoints()
    for _, p in ipairs(final) do
        f:SetPoint(p.point, p.relativeTo, p.relativePoint, p.x, p.y)
    end
    appliedPositions[frameName] = final
end

-- ═══════════════════════════════════════════════
-- PET BAR — método CT_BarMod (reparentar botones + esperar completed)
-- ═══════════════════════════════════════════════
local NEB_PetHolder          -- nuestro frame propio para los botones
local petIsShifted = false
local petNeedToMove = false

-- Reposiciona los botones de la pet bar dentro de NUESTRO frame.
local function NEB_Pet_UpdatePositions()
    if InCombatLockdown() then applyPending = true; return end
    if CTBarModOwnsFrame("PetActionBarFrame") then return end  -- CT_BarMod manda
    if not NEB_PetHolder then return end
    if not PetActionButton1 then return end

    local petBar = PetActionBarFrame
    if not petBar then return end

    local shift = NEB_ClassBarsShifted()

    if shift then
        -- Anclar NUESTRO frame arriba de la barra de mascota de Blizzard.
        -- No movemos PetActionBarFrame; solo lo usamos como referencia.
        NEB_PetHolder:SetHeight(petBar:GetHeight())
        NEB_PetHolder:SetWidth(petBar:GetWidth())
        NEB_PetHolder:ClearAllPoints()
        NEB_PetHolder:SetPoint("BOTTOMLEFT", petBar, "TOPLEFT", 0, PET_OFFSET_Y)
        petBar:EnableMouse(false)
        petIsShifted = true

        -- Reparentar y reposicionar los botones dentro de nuestro frame.
        frameClearAllPoints(PetActionButton1)
        frameSetPoint(PetActionButton1, "BOTTOMLEFT", NEB_PetHolder, "BOTTOMLEFT", 36, 2)
        for i = 2, 10 do
            local obj = _G["PetActionButton"..i]
            if obj then
                frameClearAllPoints(obj)
                frameSetPoint(obj, "LEFT", _G["PetActionButton"..(i-1)], "RIGHT", 8, 0)
            end
        end
    elseif petIsShifted then
        -- Volver los botones a la barra original de Blizzard.
        petBar:EnableMouse(true)
        petIsShifted = false
        frameClearAllPoints(PetActionButton1)
        frameSetPoint(PetActionButton1, "BOTTOMLEFT", petBar, "BOTTOMLEFT", 36, 2)
        for i = 2, 10 do
            local obj = _G["PetActionButton"..i]
            if obj then
                frameClearAllPoints(obj)
                frameSetPoint(obj, "LEFT", _G["PetActionButton"..(i-1)], "RIGHT", 8, 0)
            end
        end
    end
end

-- Hook del OnUpdate: espera a que la animación de deslizamiento TERMINE.
-- Esta es la clave que evita que la barra "se baje".
local function NEB_Pet_OnUpdate()
    if not PetActionBarFrame then return end
    if not PetActionBarFrame.completed then
        -- La barra se está deslizando → marcar que hay que mover cuando termine
        petNeedToMove = true
    else
        if petNeedToMove then
            NEB_Pet_UpdatePositions()
            petNeedToMove = false
        end
    end
end

-- Hook del SetPoint de cada botón: si Blizzard los reposiciona, re-aplicamos.
local function NEB_Pet_ButtonSetPoint()
    if isApplying then return end
    NEB_Pet_UpdatePositions()
end

local function NEB_Pet_Init()
    if NEB_PetHolder then return end
    if not PetActionBarFrame or not PetActionButton1 then return end

    NEB_PetHolder = CreateFrame("Frame", "NEB_PetHolder", UIParent)
    NEB_PetHolder:SetParent(UIParent)
    NEB_PetHolder:EnableMouse(false)
    NEB_PetHolder:SetHeight(PetActionBarFrame:GetHeight())
    NEB_PetHolder:SetWidth(PetActionBarFrame:GetWidth())
    NEB_PetHolder:SetPoint("BOTTOMLEFT", PetActionBarFrame, "TOPLEFT", 0, PET_OFFSET_Y)
    NEB_PetHolder:SetAlpha(1)
    NEB_PetHolder:Show()

    isApplying = true
    for i = 1, 10 do
        local btn = _G["PetActionButton"..i]
        if btn then
            hooksecurefunc(btn, "SetPoint", NEB_Pet_ButtonSetPoint)
            hooksecurefunc(btn, "SetAllPoints", NEB_Pet_ButtonSetPoint)
        end
    end
    isApplying = false

    -- Esperar el fin de la animación de deslizamiento (clave anti-bug)
    if type(PetActionBarFrame_OnUpdate) == "function" then
        hooksecurefunc("PetActionBarFrame_OnUpdate", NEB_Pet_OnUpdate)
    end
    PetActionBarFrame:HookScript("OnUpdate", NEB_Pet_OnUpdate)

    NEB_Pet_UpdatePositions()
end

function NEB:ApplyFrameOffsets()
    if isApplying then return end
    if InCombatLockdown() then
        applyPending = true
        return
    end
    isApplying = true
    local shifted = NEB_ClassBarsShifted() and true or false
    local dy = shifted and OFFSET_Y or 0
    -- Barras simples: offset del contenedor
    for _, fn in ipairs(simpleFrames) do ApplyOffsetToFrame(fn, dy) end
    isApplying = false
    applyPending = false
    -- Pet bar: método reparentado (fuera del guard isApplying para sus hooks)
    NEB_Pet_UpdatePositions()
    -- Avisar solo si cambio.
    if shifted ~= lastShiftNotified then
        lastShiftNotified = shifted
        pcall(NEB_ClassBarShiftChanged, shifted)
    end
end

function NEB:InitFrameMover()
    -- Hooks de las barras SIMPLES (shapeshift/possess/totem)
    for _, frameName in ipairs(simpleFrames) do
        local f = _G[frameName]
        if f then
            hooksecurefunc(f, "SetPoint", function()
                if isApplying then return end
                if not NEB_ClassBarsShifted() then return end
                if CTBarModOwnsFrame(frameName) then return end
                if InCombatLockdown() then applyPending = true; return end
                NEB:ApplyFrameOffsets()
            end)
        end
    end

    -- Pet bar: inicializar el método reparentado
    NEB_Pet_Init()

    -- Al poner o sacar un hechizo de un boton (o cambiar de talento) puede
    -- cambiar si la barra izquierda esta vacia: se recalcula.
    if type(NEB_ABT_SetCommand) == "function" then
        hooksecurefunc("NEB_ABT_SetCommand", function()
            if InCombatLockdown() then applyPending = true; return end
            NEB:ApplyFrameOffsets()
        end)
    end

    local delayFrame = CreateFrame("Frame")
    delayFrame:Hide(); delayFrame.elapsed = 0
    delayFrame:SetScript("OnUpdate", function(self, e)
        self.elapsed = self.elapsed + e
        if self.elapsed > 0.2 then
            NEB:RefreshAllLayout()
            NEB_Pet_UpdatePositions()
            self:Hide()
        end
    end)

    local watcher = CreateFrame("Frame")
    for _, ev in ipairs({
            "UPDATE_BONUS_ACTIONBAR",
            "PET_BAR_UPDATE", "PET_BAR_SHOW", "PET_BAR_HIDE", "UNIT_PET",
            "UPDATE_SHAPESHIFT_FORMS",
            "PLAYER_REGEN_ENABLED",
            "PLAYER_ENTERING_WORLD",
            "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE",
    }) do watcher:RegisterEvent(ev) end
    watcher:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_ENABLED" and applyPending then
            NEB:ApplyFrameOffsets()
            applyPending = false
        end
        delayFrame.elapsed = 0; delayFrame:Show()
    end)
end

-- ─────────────────────────────────────────────
-- OPTIONS PANEL — ArcaneBlue
-- ─────────────────────────────────────────────
function NEB:InitOptions()
    SLASH_NEXTRABAR1 = "/neb"
    SLASH_NEXTRABAR2 = "/nextrabars"
    SlashCmdList["NEXTRABAR"] = function(msg)
        msg = strtrim(msg or ""):lower()
        if     msg == "left on"   then NEB_Config["LeftEnabled"]  = true;  NEB:ApplyEnabled("Left");  print("|cff40ccffnExtraBars:|r Left |cff00ff00ON|r")
        elseif msg == "left off"  then NEB_Config["LeftEnabled"]  = false; NEB:ApplyEnabled("Left");  print("|cff40ccffnExtraBars:|r Left |cffff4444OFF|r")
        elseif msg == "right on"  then NEB_Config["RightEnabled"] = true;  NEB:ApplyEnabled("Right"); print("|cff40ccffnExtraBars:|r Right |cff00ff00ON|r")
        elseif msg == "right off" then NEB_Config["RightEnabled"] = false; NEB:ApplyEnabled("Right"); print("|cff40ccffnExtraBars:|r Right |cffff4444OFF|r")
        elseif msg == "reset"     then ReloadUI()
        else   NEB:ToggleOptionsFrame()
        end
    end
    self:BuildOptionsFrame()
end

function NEB:BuildOptionsFrame()
    if self.optionsFrame then return end

    -- ── Main window ──────────────────────────────────────────────────────────
    local f = CreateFrame("Frame", "NEB_OptionsFrame", UIParent)
    f:SetWidth(OPT_W); f:SetHeight(OPT_H)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true)
    f:Hide()
    SetABBackdrop(f, 16, 16, 5, AB.frameBG, AB.frameBorder)
    f:SetScript("OnMouseDown", function(self, btn)
        if btn == "LeftButton" then self:StartMoving() end
    end)
    f:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing() end)

    -- ── Title bar ────────────────────────────────────────────────────────────
    local titleBox = CreateFrame("Frame", nil, f)
    titleBox:SetPoint("TOPLEFT",  f, "TOPLEFT",  8,  10)
    titleBox:SetPoint("TOPRIGHT", f, "TOPRIGHT", -36, 10)
    titleBox:SetHeight(30)
    titleBox:SetFrameLevel(f:GetFrameLevel() + 2)
    SetABBackdrop(titleBox, 16, 14, 4, AB.titleBG, AB.titleBorder)

    local glow = titleBox:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface/Tooltips/UI-Tooltip-Border")
    glow:SetHeight(2)
    glow:SetPoint("TOPLEFT",  titleBox, "TOPLEFT",  5, -1)
    glow:SetPoint("TOPRIGHT", titleBox, "TOPRIGHT", -5, -1)
    glow:SetVertexColor(0.50, 0.85, 1.00, 0.65)

    local titleFS = titleBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleFS:SetPoint("CENTER", titleBox, "CENTER", 0, 0)
    titleFS:SetTextColor(AB.titleText[1], AB.titleText[2], AB.titleText[3])
    titleFS:SetText("nExtraBars")

    local verFS = titleBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    verFS:SetPoint("RIGHT", titleBox, "RIGHT", -6, 0)
    verFS:SetTextColor(0.55, 0.45, 0.10)
    verFS:SetText("v2.2")

    titleBox:EnableMouse(true)
    titleBox:SetScript("OnMouseDown", function() f:StartMoving() end)
    titleBox:SetScript("OnMouseUp",   function() f:StopMovingOrSizing() end)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 14)

    -- ── Layout ───────────────────────────────────────────────────────────────
    local yOff = -40   -- just below titleBox (4 + 30 + 6)
    MakeLine(f, yOff, AB.accentBright)

    -- ── LEFT BAR ─────────────────────────────────────────────────────────────
    yOff = yOff - 14
    MakeSection(f, "Left Bar", yOff)
    yOff = yOff - 20

    local leftPanel = CreateFrame("Frame", nil, f)
    leftPanel:SetPoint("TOPLEFT",  f, "TOPLEFT",  PANEL_INDENT,  yOff)
    leftPanel:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PANEL_INDENT, yOff)
    leftPanel:SetHeight(LEFT_PANEL_H)
    SetABBackdrop(leftPanel, 16, 10, 3, AB.panelBG, AB.panelBorder)

    local lpY = -PANEL_PAD_T
    self:MakeCheckbox(leftPanel, "Enable Left Bar",  CB_INDENT, lpY, "LeftEnabled",
        function(v) NEB_Config["LeftEnabled"]     = v; NEB:ApplyEnabled("Left")     end)
    lpY = lpY - CB_SPACING
    self:MakeCheckbox(leftPanel, "Lock Buttons",     CB_INDENT, lpY, "LeftLockButtons",
        function(v) NEB_Config["LeftLockButtons"] = v; NEB:ApplyLockButtons("Left") end)
    lpY = lpY - CB_SPACING
    local onlyCB = self:MakeCheckbox(leftPanel, "Raise class bars only if used", CB_INDENT, lpY, "LeftShiftOnlyIfUsed",
        function(v) NEB_Config["LeftShiftOnlyIfUsed"] = v; NEB:ApplyFrameOffsets() end)
    onlyCB:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Raise class bars only if used", 1, 1, 1)
        GameTooltip:AddLine("Stance, aura, totem and pet bars move up above the left bar only when it has at least one spell, item or macro. Turn it off to always move them up.", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    onlyCB:HookScript("OnLeave", function() GameTooltip:Hide() end)

    yOff = yOff - LEFT_PANEL_H - 16

    -- ── RIGHT BAR ────────────────────────────────────────────────────────────
    MakeLine(f, yOff, AB.accentDim)
    yOff = yOff - 14
    MakeSection(f, "Right Bar", yOff)
    yOff = yOff - 20

    local rightPanel = CreateFrame("Frame", nil, f)
    rightPanel:SetPoint("TOPLEFT",  f, "TOPLEFT",  PANEL_INDENT,  yOff)
    rightPanel:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PANEL_INDENT, yOff)
    rightPanel:SetHeight(PANEL_H)
    SetABBackdrop(rightPanel, 16, 10, 3, AB.panelBG, AB.panelBorder)

    local rpY = -PANEL_PAD_T
    self:MakeCheckbox(rightPanel, "Enable Right Bar", CB_INDENT, rpY, "RightEnabled",
        function(v) NEB_Config["RightEnabled"]     = v; NEB:ApplyEnabled("Right")     end)
    rpY = rpY - CB_SPACING
    self:MakeCheckbox(rightPanel, "Lock Buttons",     CB_INDENT, rpY, "RightLockButtons",
        function(v) NEB_Config["RightLockButtons"] = v; NEB:ApplyLockButtons("Right") end)

    -- ── Footer ───────────────────────────────────────────────────────────────
    yOff = yOff - PANEL_H - 10
    MakeLine(f, yOff, AB.accentDim)

    -- Note about Show Grid being controlled by Blizzard
    local note = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("BOTTOM", f, "BOTTOM", 0, 28)
    note:SetWidth(OPT_W - 32)
    note:SetWordWrap(true)
    note:SetJustifyH("CENTER")
    note:SetTextColor(0.28, 0.58, 0.85)
    note:SetText("Empty button visibility:\nInterface > Action Bars > |cffffff88Always Show Action Bars|r")

    local footer = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    footer:SetPoint("BOTTOM", f, "BOTTOM", 0, 8)
    footer:SetWidth(OPT_W - 32)
    footer:SetWordWrap(true)
    footer:SetJustifyH("CENTER")
    footer:SetTextColor(AB.footer[1], AB.footer[2], AB.footer[3])
    footer:SetText("|cffffff55/neb left on|r · |cffffff55/neb left off|r\n"..
                   "|cffffff55/neb right on|r · |cffffff55/neb right off|r")

    self.optionsFrame = f

    -- ── Blizzard Interface panel entry ────────────────────────────────────────
    local bp = CreateFrame("Frame", "NEB_BlizzOptions", UIParent)
    bp.name  = "nExtraBars"
    local bt = bp:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    bt:SetPoint("TOPLEFT", 16, -16)
    bt:SetTextColor(1.0, 0.82, 0.05)
    bt:SetText("nExtraBars")
    local bs = bp:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    bs:SetPoint("TOPLEFT", bt, "BOTTOMLEFT", 0, -8)
    bs:SetText("Type |cffffff00/neb|r for options.\n\n"..
               "|cffffff00/neb left on|r / |cffffff00off|r\n"..
               "|cffffff00/neb right on|r / |cffffff00off|r\n"..
               "|cffffff00/neb reset|r  (reloads UI)\n\n"..
               "|cff5599ffEmpty slot visibility|r is controlled by\n"..
               "Interface > Action Bars > |cff5599ffAlways Show Action Bars|r.")
    InterfaceOptions_AddCategory(bp)
end

-- ─────────────────────────────────────────────
-- Checkbox factory
-- ─────────────────────────────────────────────
function NEB:MakeCheckbox(parent, label, x, y, configKey, onChange)
    local hl = parent:CreateTexture(nil, "BACKGROUND")
    hl:SetTexture("Interface/Tooltips/UI-Tooltip-Background")
    hl:SetPoint("TOPLEFT",  parent, "TOPLEFT",  x - 2, y + 2)
    hl:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4,    y + 2)
    hl:SetHeight(CB_SPACING - 4)
    hl:SetVertexColor(AB.cbHover[1], AB.cbHover[2], AB.cbHover[3], 0)

    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cb:SetWidth(22); cb:SetHeight(22)

    local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    fs:SetText(label)
    fs:SetTextColor(AB.cbText[1], AB.cbText[2], AB.cbText[3])

    cb:SetChecked(NEB_Config[configKey] and true or false)
    cb:SetScript("OnEnter", function()
        hl:SetVertexColor(AB.cbHover[1], AB.cbHover[2], AB.cbHover[3], AB.cbHover[4])
        fs:SetTextColor(1, 1, 1)
    end)
    cb:SetScript("OnLeave", function()
        hl:SetVertexColor(AB.cbHover[1], AB.cbHover[2], AB.cbHover[3], 0)
        fs:SetTextColor(AB.cbText[1], AB.cbText[2], AB.cbText[3])
    end)
    cb:SetScript("OnClick", function(self)
        local val = self:GetChecked() and true or false
        if onChange then onChange(val) end
        PlaySound(val and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
    end)

    if not self.checkboxes then self.checkboxes = {} end
    self.checkboxes[configKey] = cb
    return cb
end

function NEB:ToggleOptionsFrame()
    if not self.optionsFrame then return end
    if self.optionsFrame:IsShown() then
        self.optionsFrame:Hide()
    else
        if self.checkboxes then
            for key, cb in pairs(self.checkboxes) do
                cb:SetChecked(NEB_Config[key] and true or false)
            end
        end
        self.optionsFrame:Show()
    end
end

-- ─────────────────────────────────────────────
-- Lorti UI Integration (Nidhaus_UnitFrames)
-- Auto-styles NEB buttons to match NUF's Lorti
-- action bar skin when the module is active.
-- ─────────────────────────────────────────────

local LORTI_TEX = {
    normal     = "Interface\\AddOns\\Nidhaus_UnitFrames\\Modules2\\Lorti UI\\media\\gloss",
    flash      = "Interface\\AddOns\\Nidhaus_UnitFrames\\Modules2\\Lorti UI\\media\\flash",
    hover      = "Interface\\AddOns\\Nidhaus_UnitFrames\\Modules2\\Lorti UI\\media\\hover",
    pushed     = "Interface\\AddOns\\Nidhaus_UnitFrames\\Modules2\\Lorti UI\\media\\pushed",
    checked    = "Interface\\AddOns\\Nidhaus_UnitFrames\\Modules2\\Lorti UI\\media\\checked",
    buttonback = "Interface\\AddOns\\Nidhaus_UnitFrames\\Modules2\\Lorti UI\\media\\button_background",
    shadow     = "Interface\\AddOns\\Nidhaus_UnitFrames\\Modules2\\Lorti UI\\media\\outer_shadow",
}
local LORTI_FONT     = "Fonts\\FRIZQT__.TTF"
local LORTI_NT_COLOR = {0, 0, 0, 0.9}
local LORTI_BG_CLR   = {0.3, 0.3, 0.3, 0.7}
local LORTI_SH_CLR   = {0, 0, 0, 0.9}
local LORTI_INSET    = 5

local lortiBackdrop = {
    bgFile   = "",
    edgeFile = LORTI_TEX.shadow,
    tile     = false,
    tileSize = 32,
    edgeSize = LORTI_INSET,
    insets   = {left = LORTI_INSET, right = LORTI_INSET, top = LORTI_INSET, bottom = LORTI_INSET},
}

local function NEB_IsLortiAvailable()
    if not IsAddOnLoaded("Nidhaus_UnitFrames") then return false end
    local db = NidhausUnitFramesDB
    if not db or not db.Modules then return false end
    return (db.Modules.LortiUI == true)
end

local function NEB_LortiApplyBG(bu)
    if bu._nebLortiBG then return end
    local bg = CreateFrame("Frame", nil, bu)
    bg:SetPoint("TOPLEFT", bu, "TOPLEFT", -4, 4)
    bg:SetPoint("BOTTOMRIGHT", bu, "BOTTOMRIGHT", 4, -4)
    bg:SetFrameLevel(math.max(bu:GetFrameLevel() - 1, 0))

    local t = bg:CreateTexture(nil, "BACKGROUND", -8)
    t:SetTexture(LORTI_TEX.buttonback)
    t:SetAllPoints(bu)
    t:SetVertexColor(LORTI_BG_CLR[1], LORTI_BG_CLR[2], LORTI_BG_CLR[3], LORTI_BG_CLR[4])

    bg:SetBackdrop(lortiBackdrop)
    bg:SetBackdropBorderColor(LORTI_SH_CLR[1], LORTI_SH_CLR[2], LORTI_SH_CLR[3], LORTI_SH_CLR[4])
    bu._nebLortiBG = bg
end

local function NEB_LortiStyleButton(bu)
    if bu._nebLortiStyled then return end
    local name = bu:GetName()

    local ic = _G[name.."Icon"]
    local co = _G[name.."Count"]
    local bo = _G[name.."Border"]
    local ho = _G[name.."HotKey"]
    local cd = _G[name.."Cooldown"]
    local na = _G[name.."Name"]
    local fl = _G[name.."Flash"]

    -- Hide green border
    if bo then bo:Hide() end

    -- Replacement textures
    if fl then fl:SetTexture(LORTI_TEX.flash) end
    bu:SetHighlightTexture(LORTI_TEX.hover)
    bu:SetPushedTexture(LORTI_TEX.pushed)
    bu:SetCheckedTexture(LORTI_TEX.checked)

    -- Icon crop (inset 2px from each edge)
    if ic then
        ic:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        ic:ClearAllPoints()
        ic:SetPoint("TOPLEFT", bu, "TOPLEFT", 2, -2)
        ic:SetPoint("BOTTOMRIGHT", bu, "BOTTOMRIGHT", -2, 2)
    end

    -- Cooldown inset
    if cd then
        cd:ClearAllPoints()
        cd:SetPoint("TOPLEFT", bu, "TOPLEFT", 0, 0)
        cd:SetPoint("BOTTOMRIGHT", bu, "BOTTOMRIGHT", 0, 0)
    end

    -- Font styling
    if ho then ho:SetFont(LORTI_FONT, 12, "OUTLINE") end
    if na then na:SetFont(LORTI_FONT, 11, "OUTLINE") end
    if co then co:SetFont(LORTI_FONT, 12, "OUTLINE") end

    -- Background & shadow
    NEB_LortiApplyBG(bu)

    bu._nebLortiStyled = true
end

-- Post-hook: re-apply gloss normal texture after NEB updates its own textures
local function NEB_LortiPostUpdateTexture(self)
    if not self._nebLortiStyled then return end
    local name = self:GetName()
    local ic = _G[name.."Icon"]

    -- Only apply gloss if the button has content (icon visible)
    if ic and ic:IsShown() then
        self:SetNormalTexture(LORTI_TEX.normal)
        local nt = _G[name.."NormalTexture"]
        if nt then
            nt:SetAllPoints(self)
            nt:SetVertexColor(LORTI_NT_COLOR[1], LORTI_NT_COLOR[2], LORTI_NT_COLOR[3], LORTI_NT_COLOR[4])
        end
        -- Re-crop icon (SetNormalTexture can disturb child anchors)
        ic:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    else
        -- Empty slot: apply gloss with subdued alpha
        self:SetNormalTexture(LORTI_TEX.normal)
        local nt = _G[name.."NormalTexture"]
        if nt then
            nt:SetAllPoints(self)
            nt:SetVertexColor(LORTI_NT_COLOR[1], LORTI_NT_COLOR[2], LORTI_NT_COLOR[3], 0.35)
        end
    end
end

function NEB:InitLortiIntegration()
    if not NEB_IsLortiAvailable() then return end

    -- Style all existing buttons
    for _, bu in ipairs(NEB_ABTFrame.buttons) do
        NEB_LortiStyleButton(bu)
    end

    -- Hook texture updates to re-apply gloss after every NEB_ABT_UpdateTexture call
    hooksecurefunc("NEB_ABT_UpdateTexture", NEB_LortiPostUpdateTexture)

    -- Also hook NEB_ABT_Update for full refresh coverage
    hooksecurefunc("NEB_ABT_Update", function(self)
        if self._nebLortiStyled then NEB_LortiPostUpdateTexture(self) end
    end)

    -- FIX: Hook UpdateUsable to prevent NormalTexture flash.
    -- UpdateUsable sets normalTexture:SetVertexColor(1,1,1) which turns the
    -- Lorti gloss bright white. Re-apply the dark vertex color after it runs.
    hooksecurefunc("NEB_ABT_UpdateUsable", function(self)
        if not self._nebLortiStyled then return end
        local nt = _G[self:GetName().."NormalTexture"]
        if nt then
            nt:SetVertexColor(LORTI_NT_COLOR[1], LORTI_NT_COLOR[2], LORTI_NT_COLOR[3], LORTI_NT_COLOR[4])
        end
    end)
end

-- ─────────────────────────────────────────────
-- Login message
-- ─────────────────────────────────────────────
local loginMsg = CreateFrame("Frame")
loginMsg:RegisterEvent("PLAYER_LOGIN")
loginMsg:SetScript("OnEvent", function()
    print("|cff40ccffnExtraBars|r loaded. Type |cffffff00/neb|r for options.")
end)