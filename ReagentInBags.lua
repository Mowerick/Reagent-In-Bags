-- Reagent In Bags
-- Adds the reagent bag slots inside the combined backpack window (the window
-- grows to make room) and suppresses the separate reagent bag window, so the
-- normal bag key opens everything in one place. Colour/style: /rbag.

local BAG = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5
local SIZE, SPACING, PAD, HEADER = 37, 5, 6, 18
local FOOTER = 16       -- room for the "Bags" title under the reagent slots
local SIDE = 6          -- inset of the panel from the bag window's left/right edge
local BOTTOM_INSET = 28 -- panel sits this far above the window bottom (money bar + border)
local TRIM = 16         -- the bag already leaves a gap under the search box; don't add that part twice
local TOP_FALLBACK = 68 -- distance from the window top to just under the search box

local DEFAULTS = { color = { 0.15, 0.75, 0.65 }, style = "blizzard", showTitles = true } -- style: "tinted" | "blizzard"
local DB

local section, chrome
local buttons = {}

local function Combined()
  return _G.ContainerFrameCombinedBags
end

---------------------------------------------------------------------------
-- Styling
---------------------------------------------------------------------------

local function ApplyStyle()
  if not section then return end
  local r, g, b = DB.color[1], DB.color[2], DB.color[3]

  if DB.style == "blizzard" then
    -- No background of our own: the bag window's art shows through; the colour
    -- is only a faint wash on top of it.
    section:SetBackdropColor(0, 0, 0, 0)
    section:SetBackdropBorderColor(0, 0, 0, 0)
    section.title:SetTextColor(1, 0.82, 0)
    section.title2:SetTextColor(1, 0.82, 0)
    section.line:Hide()
  else
    if chrome then chrome:Hide() end
    section.line:Hide()
    section:SetBackdropColor(r * 0.25, g * 0.25, b * 0.25, 0.92)
    section:SetBackdropBorderColor(r, g, b, 1)
    section.title:SetTextColor(math.min(1, r + 0.25), math.min(1, g + 0.25), math.min(1, b + 0.25))
    section.title2:SetTextColor(1, 0.82, 0)
  end
end

local function Notify()
  if _G.ReagentInBagsOptions and _G.ReagentInBagsOptions.Refresh then _G.ReagentInBagsOptions.Refresh() end
end

local function SetColor(r, g, b)
  DB.color = { r, g, b }
  ApplyStyle()
  Notify()
end

local function SetStyle(style)
  DB.style = style
  ApplyStyle()
  Notify()
end

local RelayoutNow -- set once Layout exists
local function SetShowTitles(v)
  DB.showTitles = v and true or false
  if RelayoutNow then RelayoutNow() end
  Notify()
end

---------------------------------------------------------------------------
-- Slot buttons
---------------------------------------------------------------------------

local OVERLAYS = { "NewItemTexture", "BattlepayItemTexture", "ItemContextOverlay", "flash" }

local function RefreshButton(btn)
  local slot = btn:GetID()
  local info = C_Container.GetContainerItemInfo(BAG, slot)

  if info then
    SetItemButtonTexture(btn, info.iconFileID)
    SetItemButtonCount(btn, info.stackCount)
    SetItemButtonDesaturated(btn, info.isLocked)
    if SetItemButtonQuality then
      SetItemButtonQuality(btn, info.quality, info.hyperlink)
    end
    btn.rbEmpty:Hide()
    if btn.SetMatchesSearch then
      btn:SetMatchesSearch(not info.isFiltered)
    elseif btn.searchOverlay then
      btn.searchOverlay:SetShown(info.isFiltered and true or false)
    end
  else
    SetItemButtonTexture(btn, nil)
    SetItemButtonCount(btn, 0)
    SetItemButtonDesaturated(btn, false)
    if SetItemButtonQuality then SetItemButtonQuality(btn, nil) end
    btn.rbEmpty:Show()
    if btn.SetMatchesSearch then btn:SetMatchesSearch(true) end
  end

  -- Clear the new-item / highlight glow that the template otherwise leaves on
  -- until the slot is hovered.
  pcall(function()
    for _, key in ipairs(OVERLAYS) do
      if btn[key] then btn[key]:Hide() end
    end
    if btn.flashAnim then btn.flashAnim:Stop() end
    if btn.newitemglowAnim then btn.newitemglowAnim:Stop() end
    if btn.UnlockHighlight then btn:UnlockHighlight() end
    if C_NewItems and C_NewItems.RemoveNewItem then C_NewItems.RemoveNewItem(BAG, slot) end
  end)

  local cd = btn.Cooldown or btn.cooldown or _G[btn:GetName() .. "Cooldown"]
  if cd then
    local start, duration, enable = C_Container.GetContainerItemCooldown(BAG, slot)
    CooldownFrame_Set(cd, start or 0, duration or 0, enable)
  end
end

local function GetButton(i)
  local btn = buttons[i]
  if btn then return btn end

  btn = CreateFrame("ItemButton", "ReagentInBagsButton" .. i, section, "ContainerFrameItemButtonTemplate")
  btn:SetSize(SIZE, SIZE)
  btn:SetID(i)
  btn:SetFrameLevel(section:GetFrameLevel() + 5)
  if btn.SetBagID then btn:SetBagID(BAG) end

  -- Empty-slot background (the template doesn't draw one for us).
  local empty = btn:CreateTexture(nil, "BACKGROUND")
  empty:SetAllPoints()
  if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("bags-item-slot64") then
    empty:SetAtlas("bags-item-slot64")
  else
    empty:SetColorTexture(0, 0, 0, 0.5)
  end
  btn.rbEmpty = empty

  buttons[i] = btn
  return btn
end

---------------------------------------------------------------------------
-- Layout: the bag window itself grows to make room for the reagent slots
---------------------------------------------------------------------------

-- Fallback placement (only used if the bag's item buttons can't be found): the
-- bag grid is anchored to the bottom of the window, so extra height opens up at
-- the top and the panel goes right under the search box.
local function TopOffset(combined)
  local box = _G.BagItemSearchBox or combined.SearchBox
  if box and box.GetBottom and combined.GetTop then
    local top, bottom = combined:GetTop(), box:GetBottom()
    if top and bottom and top > bottom then return (top - bottom) + 4 end
  end
  return TOP_FALLBACK
end

local applying = false -- true while we resize the window ourselves
local blizzHeight = 0 -- the height Blizzard wants for the window
local extra = 0       -- height we add on top for the reagent panel
local topMode = false -- true = fallback placement under the search box

-- Moving Blizzard's item buttons up by `extra` frees the strip above the money
-- bar for the reagent panel. Blizzard re-anchors the buttons whenever it lays
-- the grid out, so we detect that (probe) and re-apply.
local itemDy, probe, probeY = 0, nil, nil

local function CollectItemButtons(combined)
  local list = {}
  for _, c in ipairs({ combined:GetChildren() }) do
    if c ~= section and c.SetMatchesSearch and c.GetNumPoints then list[#list + 1] = c end
  end
  return list
end

local function BottomPointY(btn, combined)
  for i = 1, btn:GetNumPoints() do
    local point, rel, _, _, y = btn:GetPoint(i)
    if rel == combined and point:find("BOTTOM") then return y end
  end
end

local function ShiftButton(btn, combined, dy)
  local pts = {}
  for i = 1, btn:GetNumPoints() do pts[i] = { btn:GetPoint(i) } end
  local touched = false
  btn:ClearAllPoints()
  for _, p in ipairs(pts) do
    local y = p[5]
    if p[2] == combined and p[1]:find("BOTTOM") then y = y + dy; touched = true end
    btn:SetPoint(p[1], p[2], p[3], p[4], y)
  end
  return touched
end

-- Returns false if we wanted a shift but found no buttons to shift.
local function SetItemShift(combined, want)
  local cur = probe and BottomPointY(probe, combined)
  local still = cur and probeY and math.abs(cur - probeY) < 0.01 -- layout untouched since our shift
  local delta = want - (still and itemDy or 0)
  if still and delta == 0 then return true end
  if delta == 0 then itemDy, probe, probeY = 0, nil, nil return true end

  probe = nil
  for _, b in ipairs(CollectItemButtons(combined)) do
    if ShiftButton(b, combined, delta) and not probe then probe = b end
  end
  if probe then
    probeY = BottomPointY(probe, combined)
    itemDy = want
    if want == 0 then probe, probeY = nil, nil end
    return true
  end
  itemDy, probeY = 0, nil
  return want == 0
end

local function Layout(blizzH)
  local combined = Combined()
  if not section or not combined then return end

  local n = C_Container.GetContainerNumSlots(BAG) or 0
  if n == 0 or not combined:IsShown() then
    section:Hide()
    SetItemShift(combined, 0)
    if extra > 0 then
      extra = 0
      applying = true
      combined:SetHeight(blizzHeight)
      applying = false
    end
    return
  end

  blizzHeight = blizzH or (combined:GetHeight() - extra)

  local inner = combined:GetWidth() - 2 * SIDE
  local cols = math.floor((inner - 2 * PAD + SPACING) / (SIZE + SPACING))
  cols = math.max(1, math.min(cols, n))
  local rows = math.ceil(n / cols)
  local hdr = DB.showTitles and HEADER or 0
  local ftr = DB.showTitles and FOOTER or 0
  section.title:SetShown(DB.showTitles)
  section.title2:SetShown(DB.showTitles)
  local height = hdr + 2 * PAD + rows * SIZE + (rows - 1) * SPACING + ftr

  extra = topMode and math.max(0, height - TRIM) or height
  applying = true
  combined:SetHeight(blizzHeight + extra)
  applying = false

  section:ClearAllPoints()
  if topMode then
    local top = TopOffset(combined)
    section:SetPoint("TOPLEFT", combined, "TOPLEFT", SIDE, -top)
    section:SetPoint("TOPRIGHT", combined, "TOPRIGHT", -SIDE, -top)
  else
    section:SetPoint("BOTTOMLEFT", combined, "BOTTOMLEFT", SIDE, BOTTOM_INSET)
    section:SetPoint("BOTTOMRIGHT", combined, "BOTTOMRIGHT", -SIDE, BOTTOM_INSET)
  end
  section:SetHeight(height)
  SetItemShift(combined, topMode and 0 or extra)

  for i = 1, n do
    local btn = GetButton(i)
    local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
    btn:ClearAllPoints()
    btn:SetPoint("TOPLEFT", section, "TOPLEFT",
      PAD + col * (SIZE + SPACING), -(hdr + PAD + row * (SIZE + SPACING)))
    btn:Show()
    RefreshButton(btn)
  end
  for i = n + 1, #buttons do buttons[i]:Hide() end

  section:Show()
end

RelayoutNow = function()
  local c = Combined()
  if c and c:IsShown() then Layout() end
end

-- Runs every frame while the bag is open: Blizzard can resize the window or
-- re-anchor the item buttons at any time.
local missed = 0
local function OnCombinedUpdate(self)
  if extra == 0 or not section or not section:IsShown() then return end
  local h = self:GetHeight()
  if math.abs(h - (blizzHeight + extra)) >= 0.5 then
    Layout(h) -- Blizzard resized the window: re-add our extra height
    return
  end
  if not topMode then
    if SetItemShift(self, extra) then
      missed = 0
    else
      missed = missed + 1
      if missed > 30 then -- no item buttons to move: use the fallback placement
        topMode = true
        Layout()
      end
    end
  end
end

local function RefreshAll()
  if not section or not section:IsShown() then return end
  for _, btn in ipairs(buttons) do
    if btn:IsShown() then RefreshButton(btn) end
  end
end

---------------------------------------------------------------------------
-- Suppress the separate reagent bag window
---------------------------------------------------------------------------

local function ForEachContainerFrame(fn)
  local list = _G.ContainerFrameContainer and _G.ContainerFrameContainer.ContainerFrames
  if list then
    for _, f in ipairs(list) do fn(f) end
  else
    for i = 1, 13 do
      local f = _G["ContainerFrame" .. i]
      if f then fn(f) end
    end
  end
end

local function HideSeparateReagentFrame()
  local combined = Combined()
  if not combined or not combined:IsShown() then return end
  ForEachContainerFrame(function(f)
    if f ~= combined and f:IsShown() then
      local id = f.GetBagID and f:GetBagID() or f:GetID()
      if id == BAG then f:Hide() end
    end
  end)
end

local function Sweep()
  HideSeparateReagentFrame()
  Layout()
end

-- Run immediately (so the window never renders unextended), and once more next
-- frame in case Blizzard finishes setting up after our hook runs.
local function DeferredSweep()
  Sweep()
  C_Timer.After(0, Sweep)
end

---------------------------------------------------------------------------
-- Options panel
---------------------------------------------------------------------------

local category

local function OpenPicker()
  local c = DB.color
  local function onChange()
    local r, g, b = ColorPickerFrame:GetColorRGB()
    SetColor(r, g, b)
  end
  local function onCancel(prev)
    prev = prev or ColorPickerFrame.previousValues
    if prev then SetColor(prev.r or prev[1], prev.g or prev[2], prev.b or prev[3]) end
  end

  if ColorPickerFrame.SetupColorPickerAndShow then
    ColorPickerFrame:SetupColorPickerAndShow({
      r = c[1], g = c[2], b = c[3], hasOpacity = false,
      swatchFunc = onChange, cancelFunc = onCancel,
    })
  else
    ColorPickerFrame.hasOpacity = false
    ColorPickerFrame.func = onChange
    ColorPickerFrame.cancelFunc = onCancel
    ColorPickerFrame.previousValues = { r = c[1], g = c[2], b = c[3] }
    ColorPickerFrame:SetColorRGB(c[1], c[2], c[3])
    ColorPickerFrame:Hide()
    ColorPickerFrame:Show()
  end
end

local function BuildOptions()
  local panel = CreateFrame("Frame", "ReagentInBagsOptions")
  panel.name = "Reagent In Bags"

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("Reagent In Bags")

  local colorLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  colorLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -24)
  colorLabel:SetText("Panel colour")

  local swatch = CreateFrame("Button", nil, panel)
  swatch:SetSize(28, 28)
  swatch:SetPoint("LEFT", colorLabel, "RIGHT", 16, 0)
  local swatchBorder = swatch:CreateTexture(nil, "BACKGROUND")
  swatchBorder:SetPoint("TOPLEFT", -2, 2)
  swatchBorder:SetPoint("BOTTOMRIGHT", 2, -2)
  swatchBorder:SetColorTexture(1, 1, 1, 1)
  local swatchTex = swatch:CreateTexture(nil, "ARTWORK")
  swatchTex:SetAllPoints()
  swatch:SetScript("OnClick", OpenPicker)

  local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  hint:SetPoint("LEFT", swatch, "RIGHT", 12, 0)
  hint:SetText("Click to choose a colour")

  local styleLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  styleLabel:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 0, -36)
  styleLabel:SetText("Style")

  local function MakeRadio(text, style, anchorTo, yOff)
    local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, yOff)
    local label = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    label:SetText(text)
    cb:SetScript("OnClick", function() SetStyle(style) end)
    return cb
  end
  local radioBlizzard = MakeRadio("Blizzard style (uses the bag window's own look, colour setting is ignored)", "blizzard", styleLabel, -6)
  local radioTinted = MakeRadio("Tinted panel (solid colour with a coloured border)", "tinted", radioBlizzard, 0)

  local titlesCB = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  titlesCB:SetPoint("TOPLEFT", radioTinted, "BOTTOMLEFT", 0, -16)
  local titlesLabel = titlesCB:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  titlesLabel:SetPoint("LEFT", titlesCB, "RIGHT", 4, 0)
  titlesLabel:SetText("Show titles (\"Reagent Bag\" / \"Bags\")")
  titlesCB:SetScript("OnClick", function(self) SetShowTitles(self:GetChecked()) end)

  local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  reset:SetSize(120, 24)
  reset:SetPoint("TOPLEFT", titlesCB, "BOTTOMLEFT", 0, -20)
  reset:SetText("Reset")
  reset:SetScript("OnClick", function()
    DB.color = { unpack(DEFAULTS.color) }
    SetShowTitles(DEFAULTS.showTitles)
    SetStyle(DEFAULTS.style)
  end)

  function panel.Refresh()
    swatchTex:SetColorTexture(DB.color[1], DB.color[2], DB.color[3], 1)
    radioBlizzard:SetChecked(DB.style ~= "tinted")
    radioTinted:SetChecked(DB.style == "tinted")
    titlesCB:SetChecked(DB.showTitles)
  end
  panel:SetScript("OnShow", panel.Refresh)
  panel.Refresh()

  if Settings and Settings.RegisterCanvasLayoutCategory then
    category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
end

local function OpenOptions()
  if category and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(category.GetID and category:GetID() or category.ID)
  elseif InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(_G.ReagentInBagsOptions)
    InterfaceOptionsFrame_OpenToCategory(_G.ReagentInBagsOptions)
  end
end

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_LOGIN" then
    ReagentInBagsDB = ReagentInBagsDB or {}
    DB = ReagentInBagsDB
    if type(DB.color) ~= "table" then DB.color = { unpack(DEFAULTS.color) } end
    if DB.version ~= 3 then DB.style = "blizzard"; DB.version = 3 end -- new in-window layout: start from the default look
    if DB.style ~= "tinted" then DB.style = "blizzard" end
    if DB.showTitles == nil then DB.showTitles = true end

    topMode = not DB.bottom -- bottom placement is experimental: /rbag bottom
    BuildOptions()

    local combined = Combined()
    if not combined then return end

    -- Child of the bag window: moves, scales and hides together with it.
    section = CreateFrame("Frame", "ReagentInBagsFrame", combined, "BackdropTemplate")
    section:SetID(BAG)
    section:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
    })
    section:SetFrameLevel(combined:GetFrameLevel() + 20) -- above the bag's own item buttons
    section:Hide()

    section.line = section:CreateTexture(nil, "ARTWORK")
    section.line:SetHeight(1)
    section.line:SetPoint("TOPLEFT", 0, 0)
    section.line:SetPoint("TOPRIGHT", 0, 0)

    section.title2 = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    section.title2:SetPoint("BOTTOMLEFT", PAD + 2, 2)
    section.title2:SetText("Bags")

    section.title = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    section.title:SetPoint("TOPLEFT", PAD + 2, -PAD)
    section.title:SetText(REAGENT_BAG or "Reagent Bag")
    ApplyStyle()

    combined:HookScript("OnShow", DeferredSweep)
    combined:HookScript("OnHide", function() Layout() end)
    -- Blizzard can (re)size the window at any point; verify every frame while open.
    combined:HookScript("OnUpdate", OnCombinedUpdate)
    -- Also react the instant Blizzard resizes the window (no one-frame lag).
    local function OnResizeCall()
      if not applying then OnCombinedUpdate(combined) end
    end
    hooksecurefunc(combined, "SetHeight", OnResizeCall)
    hooksecurefunc(combined, "SetSize", OnResizeCall)

    ForEachContainerFrame(function(f2)
      if f2 ~= combined then f2:HookScript("OnShow", DeferredSweep) end
    end)
    for _, name in ipairs({ "OpenBag", "ToggleBag", "ToggleAllBags", "OpenAllBags", "ToggleBackpack" }) do
      if _G[name] then hooksecurefunc(name, DeferredSweep) end
    end

    self:RegisterEvent("BAG_UPDATE")
    self:RegisterEvent("BAG_UPDATE_DELAYED")
    self:RegisterEvent("BAG_UPDATE_COOLDOWN")
    self:RegisterEvent("ITEM_LOCK_CHANGED")
    self:RegisterEvent("INVENTORY_SEARCH_UPDATE")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    self:UnregisterEvent("PLAYER_LOGIN")
  elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYER_EQUIPMENT_CHANGED" then
    -- bag size may have changed (reagent bag equipped/removed)
    if Combined() and Combined():IsShown() then Layout() end
  else
    RefreshAll()
  end
end)

local function PointInfo(f, i)
  local point, rel, relPoint, x, y = f:GetPoint(i)
  local relName = rel and (rel.GetName and rel:GetName() or (rel == Combined() and "<combined>") or tostring(rel)) or "nil"
  return string.format("%s -> %s %s (%.1f, %.1f)", tostring(point), relName, tostring(relPoint), x or 0, y or 0)
end

local function Debug()
  local c = Combined()
  if not c then print("RIB: no ContainerFrameCombinedBags") return end
  local p = function(...) print("|cff26bfa6RIB|r", ...) end
  p(string.format("combined: %.0fx%.0f, level %d, strata %s", c:GetWidth(), c:GetHeight(), c:GetFrameLevel(), c:GetFrameStrata()))
  p("anchor:", PointInfo(c, 1))
  local keys = {}
  for k, v in pairs(c) do
    if type(v) == "table" and type(k) == "string" and v.GetObjectType then keys[#keys + 1] = k .. "(" .. v:GetObjectType() .. ")" end
  end
  table.sort(keys)
  p("frame fields:", table.concat(keys, ", "))
  local children = { c:GetChildren() }
  p("children:", #children)
  local shown = 0
  for _, ch in ipairs(children) do
    if ch ~= section and shown < 8 and (ch.SetMatchesSearch or ch.GetBagID) then
      shown = shown + 1
      p(string.format("  item-like %s [%s] parent=%s points=%d", tostring(ch:GetName()), ch:GetObjectType(),
        tostring(ch:GetParent() == c and "combined" or (ch:GetParent() and ch:GetParent():GetName())), ch:GetNumPoints()))
      for i = 1, ch:GetNumPoints() do p("     " .. PointInfo(ch, i)) end
    end
  end
  if shown == 0 then
    p("no item buttons among direct children; sub-frames:")
    for i, ch in ipairs(children) do
      if i <= 12 then p(string.format("  %s [%s] children=%d", tostring(ch:GetName() or ch:GetDebugName()), ch:GetObjectType(), ch:GetNumChildren())) end
    end
  end
  p(string.format("height now %.1f, blizzHeight %.1f, extra %.1f, section shown %s", c:GetHeight(), blizzHeight, extra, tostring(section and section:IsShown())))
  p("mode:", topMode and "top (stable)" or "bottom (experimental)", "extra:", extra, "itemDy:", itemDy)
end

SLASH_REAGENTINBAGS1 = "/rbag"
SlashCmdList.REAGENTINBAGS = function(msg)
  msg = (msg or ""):lower()
  if msg == "debug" then
    Debug()
  elseif msg == "bottom" or msg == "top" then
    DB.bottom = (msg == "bottom")
    topMode = not DB.bottom
    missed = 0
    print("|cff26bfa6ReagentInBags|r: panel placement = " .. msg .. " (close and reopen the bags)")
    local c = Combined()
    if c and c:IsShown() then Layout() end
  else
    OpenOptions()
  end
end

-- Addon compartment (the addon menu next to the minimap): click opens the options.
function ReagentInBags_OnAddonCompartmentClick()
  OpenOptions()
end

function ReagentInBags_OnAddonCompartmentEnter(_, menuButtonFrame)
  GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_LEFT")
  GameTooltip:SetText("Reagent In Bags")
  GameTooltip:AddLine("Click to open the settings.", 1, 1, 1)
  GameTooltip:Show()
end

function ReagentInBags_OnAddonCompartmentLeave()
  GameTooltip:Hide()
end
