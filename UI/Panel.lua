-- The reagent panel frame: a child of the combined bag window that holds the
-- title(s) and the reagent slot buttons.
local _, ns = ...
local C = ns.Const

local Panel = {}
ns.Panel = Panel

local frame

-- The styled background is its own child frame so it can stop short of the
-- "Bag" title below the slots, which sits on the bag window's own background.
local function Background()
  return frame.background
end

function Panel.Get()
  return frame
end

--- Applies the configured style and title visibility.
function Panel.ApplyStyle()
  if not frame then return end
  local db = ns.db
  local r, g, b = db.color[1], db.color[2], db.color[3]

  if db.style == "blizzard" then
    -- No background of our own: the bag window's art shows through.
    Background():SetBackdropColor(0, 0, 0, 0)
    Background():SetBackdropBorderColor(0, 0, 0, 0)
    frame.title:SetTextColor(unpack(C.GOLD))
  else
    Background():SetBackdropColor(r * 0.25, g * 0.25, b * 0.25, 0.92)
    Background():SetBackdropBorderColor(r, g, b, 1)
    frame.title:SetTextColor(math.min(1, r + 0.25), math.min(1, g + 0.25), math.min(1, b + 0.25))
  end
  frame.bagsTitle:SetTextColor(unpack(C.GOLD))

  frame.title:SetShown(db.showTitles)
  frame.bagsTitle:SetShown(db.showTitles)
end

--- Sets the height of the styled background (the panel minus the "Bag" title strip).
function Panel.SetBackgroundHeight(height)
  frame.background:SetHeight(height)
end

--- Creates the panel as a child of the combined bag window.
function Panel.Create(combined)
  -- Child of the bag window: moves, scales and hides together with it.
  frame = CreateFrame("Frame", "ReagentInBagsFrame", combined)
  frame:SetID(C.BAG)
  frame:SetFrameLevel(combined:GetFrameLevel() + 20) -- above the bag's own item buttons
  frame:Hide()

  frame.background = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  frame.background:SetPoint("TOPLEFT")
  frame.background:SetPoint("TOPRIGHT")
  frame.background:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
  })
  frame.background:SetFrameLevel(frame:GetFrameLevel())

  frame.bagsTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.bagsTitle:SetPoint("BOTTOMLEFT", C.PAD + 2, 2)
  frame.bagsTitle:SetText("Bag")

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.title:SetPoint("TOPLEFT", C.PAD + 2, -C.PAD)
  frame.title:SetText(REAGENT_BAG or "Reagent Bag")

  Panel.ApplyStyle()
  return frame
end
