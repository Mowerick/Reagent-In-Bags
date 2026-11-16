-- Sizes the combined bag window and positions the reagent panel and its slots.
--
-- The window grows by the panel's height. Blizzard resizes the window itself
-- (and re-anchors its item buttons) at times we can't predict, so Layout is
-- re-run whenever that happens.
local _, ns = ...
local C = ns.Const

local Layout = {}
ns.Layout = Layout

local MISSED_LIMIT = 30 -- frames without item buttons before falling back to top placement

local state = {
  applying = false, -- true while we resize the window ourselves
  blizzHeight = 0, -- the height Blizzard wants for the window
  extra = 0, -- height we add on top for the reagent panel
  topMode = true, -- true = panel under the search box, false = below the item grid
  missed = 0, -- consecutive frames bottom placement found no item buttons
}

local function SetWindowHeight(combined, height)
  state.applying = true
  combined:SetHeight(height)
  state.applying = false
end

-- Distance from the window top to just under the search box.
local function TopOffset(combined)
  local box = _G.BagItemSearchBox or combined.SearchBox
  if box and box.GetBottom and combined.GetTop then
    local top, bottom = combined:GetTop(), box:GetBottom()
    if top and bottom and top > bottom then return (top - bottom) + 4 end
  end
  return C.TOP_FALLBACK
end

local function AnchorPanel(panel, combined)
  panel:ClearAllPoints()
  if state.topMode then
    local top = TopOffset(combined)
    panel:SetPoint("TOPLEFT", combined, "TOPLEFT", C.SIDE, -top)
    panel:SetPoint("TOPRIGHT", combined, "TOPRIGHT", -C.SIDE, -top)
  else
    panel:SetPoint("BOTTOMLEFT", combined, "BOTTOMLEFT", C.SIDE, C.BOTTOM_INSET)
    panel:SetPoint("BOTTOMRIGHT", combined, "BOTTOMRIGHT", -C.SIDE, C.BOTTOM_INSET)
  end
end

local function PlaceSlots(panel, slotCount, columns, headerHeight)
  for i = 1, slotCount do
    local btn = ns.Slots.Get(i)
    local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
    btn:ClearAllPoints()
    btn:SetPoint(
      "TOPLEFT",
      panel,
      "TOPLEFT",
      C.PAD + col * (C.SLOT_SIZE + C.SPACING),
      -(headerHeight + C.PAD + row * (C.SLOT_SIZE + C.SPACING))
    )
    btn:Show()
    ns.Slots.Refresh(btn)
  end
  ns.Slots.HideFrom(slotCount)
end

local function Collapse(panel, combined)
  panel:Hide()
  ns.ItemShift.Set(combined, 0)
  if state.extra > 0 then
    state.extra = 0
    SetWindowHeight(combined, state.blizzHeight)
  end
end

--- Lays everything out. `blizzHeight` is the height Blizzard just set, if known.
function Layout.Run(blizzHeight)
  local combined = ns.Util.GetCombinedBags()
  local panel = ns.Panel.Get()
  if not panel or not combined then return end

  local slotCount = C_Container.GetContainerNumSlots(C.BAG) or 0
  if slotCount == 0 or not combined:IsShown() then
    Collapse(panel, combined)
    return
  end

  state.blizzHeight = blizzHeight or (combined:GetHeight() - state.extra)

  local innerWidth = combined:GetWidth() - 2 * C.SIDE
  local columns = math.floor((innerWidth - 2 * C.PAD + C.SPACING) / (C.SLOT_SIZE + C.SPACING))
  columns = math.max(1, math.min(columns, slotCount))
  local rows = math.ceil(slotCount / columns)

  local showTitles = ns.db.showTitles
  local headerHeight = showTitles and C.HEADER or 0
  local footerHeight = showTitles and C.FOOTER or 0
  local height = headerHeight + 2 * C.PAD + rows * C.SLOT_SIZE + (rows - 1) * C.SPACING + footerHeight

  state.extra = state.topMode and math.max(0, height - C.TRIM) or height
  SetWindowHeight(combined, state.blizzHeight + state.extra)

  AnchorPanel(panel, combined)
  panel:SetHeight(height)
  ns.Panel.SetBackgroundHeight(height - footerHeight)
  ns.ItemShift.Set(combined, state.topMode and 0 or state.extra)
  PlaceSlots(panel, slotCount, columns, headerHeight)

  panel:Show()
end

--- Lays out again, but only while the bag window is open.
function Layout.Relayout()
  local combined = ns.Util.GetCombinedBags()
  if combined and combined:IsShown() then Layout.Run() end
end

--- true = panel under the search box (stable); false = below the item grid (experimental).
function Layout.SetTopMode(top)
  state.topMode = top and true or false
  state.missed = 0
end

--- Read-only snapshot for the debug command.
function Layout.GetState()
  return {
    blizzHeight = state.blizzHeight,
    extra = state.extra,
    topMode = state.topMode,
    itemOffset = ns.ItemShift.GetOffset(),
  }
end

--- Checks the window every frame (and on every resize call) while it is open.
function Layout.Verify(combined)
  local panel = ns.Panel.Get()
  if state.extra == 0 or not panel or not panel:IsShown() then return end

  local height = combined:GetHeight()
  if math.abs(height - (state.blizzHeight + state.extra)) >= 0.5 then
    Layout.Run(height) -- Blizzard resized the window: re-add our extra height
    return
  end

  if state.topMode then return end
  if ns.ItemShift.Set(combined, state.extra) then
    state.missed = 0
    return
  end
  state.missed = state.missed + 1
  if state.missed > MISSED_LIMIT then -- no item buttons to move: use the stable placement
    state.topMode = true
    Layout.Run()
  end
end

--- Called from the resize hooks; ignores resizes we made ourselves.
function Layout.OnResizeCall(combined)
  if not state.applying then Layout.Verify(combined) end
end
