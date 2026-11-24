-- Moves Blizzard's own item buttons up so the strip above the money bar is free
-- for the reagent panel ("bottom" placement).
--
-- Blizzard lays the combined grid out with AnchorUtil.GridLayout: every item
-- button gets a single BOTTOMRIGHT anchor relative to the window's MoneyFrame
-- (ContainerFrameCombinedBagsMixin:GetInitialItemAnchor). We add our offset to
-- that anchor's y. Blizzard resets the anchors whenever it lays the grid out
-- again (UpdateItemLayout, which BagHooks hooks to re-apply us instantly).
--
-- Each button remembers the y we gave it and Blizzard's original y, so a pass
-- is idempotent: a button whose anchor still has our y is left alone, any other
-- button is treated as freshly laid out by Blizzard. One shifted button serves
-- as a cheap probe for the every-frame check.
local _, ns = ...

local ItemShift = {}
ns.ItemShift = ItemShift

local EPSILON = 0.01

local offset = 0 -- shift currently applied to the buttons
local probe -- one shifted button, checked every frame
local shifted = setmetatable({}, { __mode = "k" }) -- button -> { y = our y, base = Blizzard's y }

local function IsGridAnchor(combined, point, relativeTo)
  return (relativeTo == combined.MoneyFrame or relativeTo == combined) and point and point:find("BOTTOM") ~= nil
end

-- Index and y of the anchor Blizzard's grid layout gave the button.
local function GridAnchor(btn, combined)
  for i = 1, btn:GetNumPoints() do
    local point, relativeTo, _, _, y = btn:GetPoint(i)
    if IsGridAnchor(combined, point, relativeTo) then return i, y end
  end
end

local function SetAnchorY(btn, index, y)
  local points = {}
  for i = 1, btn:GetNumPoints() do
    points[i] = { btn:GetPoint(i) }
  end
  points[index][5] = y
  btn:ClearAllPoints()
  for _, p in ipairs(points) do
    btn:SetPoint(p[1], p[2], p[3], p[4], p[5])
  end
end

local function ItemButtons(combined)
  local panel = ns.Panel.Get()
  local list = {}
  for _, child in ipairs({ combined:GetChildren() }) do
    if child ~= panel and child.SetMatchesSearch and child.GetNumPoints then list[#list + 1] = child end
  end
  return list
end

local function ProbeIntact(combined)
  local rec = probe and shifted[probe]
  if not rec then return false end
  local _, y = GridAnchor(probe, combined)
  return y ~= nil and math.abs(y - rec.y) < EPSILON
end

function ItemShift.GetOffset()
  return offset
end

--- Makes the item buttons sit `want` above Blizzard's own position.
--- `force` skips the cheap probe check (use right after Blizzard re-laid out).
--- Returns false if a shift was wanted but there were no buttons to move.
function ItemShift.Set(combined, want, force)
  if not force then
    if want == 0 and offset == 0 then return true end
    if want == offset and ProbeIntact(combined) then return true end
  end

  local found = false
  probe = nil
  for _, btn in ipairs(ItemButtons(combined)) do
    local index, y = GridAnchor(btn, combined)
    if index then
      found = true
      local rec = shifted[btn]
      local base = (rec and math.abs(y - rec.y) < EPSILON) and rec.base or y
      local target = base + want
      if math.abs(target - y) >= EPSILON then SetAnchorY(btn, index, target) end

      if want == 0 then
        shifted[btn] = nil
      else
        if rec then
          rec.y, rec.base = target, base
        else
          shifted[btn] = { y = target, base = base }
        end
        if not probe or (btn:IsShown() and not probe:IsShown()) then probe = btn end
      end
    end
  end

  offset = found and want or 0
  return found or want == 0
end
