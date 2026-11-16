-- Moves Blizzard's own item buttons up so the strip above the money bar is free
-- for the reagent panel ("bottom" placement; experimental).
--
-- Blizzard re-anchors the buttons whenever it lays the grid out, so one button
-- is remembered as a probe: if its anchor still has the y we set, the layout is
-- untouched; otherwise Blizzard re-laid it out and the shift must be re-applied.
local _, ns = ...

local ItemShift = {}
ns.ItemShift = ItemShift

local EPSILON = 0.01

local offset = 0 -- shift currently applied to the buttons
local probe, probeY

local function CollectItemButtons(combined)
  local panel = ns.Panel.Get()
  local list = {}
  for _, child in ipairs({ combined:GetChildren() }) do
    if child ~= panel and child.SetMatchesSearch and child.GetNumPoints then list[#list + 1] = child end
  end
  return list
end

-- y offset of the first anchor that hangs off the bottom of the combined frame.
local function BottomAnchorY(btn, combined)
  for i = 1, btn:GetNumPoints() do
    local point, relativeTo, _, _, y = btn:GetPoint(i)
    if relativeTo == combined and point:find("BOTTOM") then return y end
  end
end

-- Returns true if any anchor was moved.
local function ShiftButton(btn, combined, dy)
  local points = {}
  for i = 1, btn:GetNumPoints() do
    points[i] = { btn:GetPoint(i) }
  end

  local moved = false
  btn:ClearAllPoints()
  for _, p in ipairs(points) do
    local y = p[5]
    if p[2] == combined and p[1]:find("BOTTOM") then
      y = y + dy
      moved = true
    end
    btn:SetPoint(p[1], p[2], p[3], p[4], y)
  end
  return moved
end

function ItemShift.GetOffset()
  return offset
end

--- Makes the item buttons sit `want` above Blizzard's own position.
--- Returns false if a shift was wanted but there were no buttons to move.
function ItemShift.Set(combined, want)
  local current = probe and BottomAnchorY(probe, combined)
  local untouched = current and probeY and math.abs(current - probeY) < EPSILON
  local delta = want - (untouched and offset or 0)

  if untouched and delta == 0 then return true end
  if delta == 0 then
    offset, probe, probeY = 0, nil, nil
    return true
  end

  probe = nil
  for _, btn in ipairs(CollectItemButtons(combined)) do
    if ShiftButton(btn, combined, delta) and not probe then probe = btn end
  end

  if probe then
    probeY = BottomAnchorY(probe, combined)
    offset = want
    if want == 0 then probe, probeY = nil, nil end
    return true
  end

  offset, probeY = 0, nil
  return want == 0
end
