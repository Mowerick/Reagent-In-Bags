-- The reagent slot buttons (standard container item buttons we feed by hand).
local _, ns = ...
local C = ns.Const

local Slots = {}
ns.Slots = Slots

local buttons = {}

-- Glow/highlight textures the template otherwise leaves on until hovered.
local OVERLAYS = { "NewItemTexture", "BattlepayItemTexture", "ItemContextOverlay", "flash" }

local function ClearOverlays(btn, slot)
  pcall(function()
    for _, key in ipairs(OVERLAYS) do
      if btn[key] then btn[key]:Hide() end
    end
    if btn.flashAnim then btn.flashAnim:Stop() end
    if btn.newitemglowAnim then btn.newitemglowAnim:Stop() end
    if btn.UnlockHighlight then btn:UnlockHighlight() end
    if C_NewItems and C_NewItems.RemoveNewItem then C_NewItems.RemoveNewItem(C.BAG, slot) end
  end)
end

local function ShowItem(btn, info)
  SetItemButtonTexture(btn, info.iconFileID)
  SetItemButtonCount(btn, info.stackCount)
  SetItemButtonDesaturated(btn, info.isLocked)
  if SetItemButtonQuality then SetItemButtonQuality(btn, info.quality, info.hyperlink) end
  btn.emptyBackground:Hide()
  if btn.SetMatchesSearch then
    btn:SetMatchesSearch(not info.isFiltered)
  elseif btn.searchOverlay then
    btn.searchOverlay:SetShown(info.isFiltered and true or false)
  end
end

local function ShowEmpty(btn)
  SetItemButtonTexture(btn, nil)
  SetItemButtonCount(btn, 0)
  SetItemButtonDesaturated(btn, false)
  if SetItemButtonQuality then SetItemButtonQuality(btn, nil) end
  btn.emptyBackground:Show()
  if btn.SetMatchesSearch then btn:SetMatchesSearch(true) end
end

--- Updates one button from the current bag contents.
function Slots.Refresh(btn)
  local slot = btn:GetID()
  local info = C_Container.GetContainerItemInfo(C.BAG, slot)

  if info then
    ShowItem(btn, info)
  else
    ShowEmpty(btn)
  end
  ClearOverlays(btn, slot)

  local cooldown = btn.Cooldown or btn.cooldown or _G[btn:GetName() .. "Cooldown"]
  if cooldown then
    local start, duration, enable = C_Container.GetContainerItemCooldown(C.BAG, slot)
    CooldownFrame_Set(cooldown, start or 0, duration or 0, enable)
  end
end

--- Returns (creating on first use) the button for slot i.
function Slots.Get(i)
  local btn = buttons[i]
  if btn then return btn end

  local panel = ns.Panel.Get()
  btn = CreateFrame("ItemButton", "ReagentInBagsButton" .. i, panel, "ContainerFrameItemButtonTemplate")
  btn:SetSize(C.SLOT_SIZE, C.SLOT_SIZE)
  btn:SetID(i)
  btn:SetFrameLevel(panel:GetFrameLevel() + 5)
  if btn.SetBagID then btn:SetBagID(C.BAG) end

  -- Empty-slot background (the template doesn't draw one for us).
  local empty = btn:CreateTexture(nil, "BACKGROUND")
  empty:SetAllPoints()
  if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("bags-item-slot64") then
    empty:SetAtlas("bags-item-slot64")
  else
    empty:SetColorTexture(0, 0, 0, 0.5)
  end
  btn.emptyBackground = empty

  buttons[i] = btn
  return btn
end

--- Hides every button after the first n.
function Slots.HideFrom(n)
  for i = n + 1, #buttons do
    buttons[i]:Hide()
  end
end

--- Refreshes all visible buttons (only while the panel is shown).
function Slots.RefreshAll()
  local panel = ns.Panel.Get()
  if not panel or not panel:IsShown() then return end
  for _, btn in ipairs(buttons) do
    if btn:IsShown() then Slots.Refresh(btn) end
  end
end
