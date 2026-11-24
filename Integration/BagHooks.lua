-- Hooks into Blizzard's bag code: keeps the reagent panel in sync with the
-- combined bag window and hides the separate reagent bag window.
local _, ns = ...
local C = ns.Const

local BagHooks = {}
ns.BagHooks = BagHooks

local OPEN_FUNCTIONS = { "OpenBag", "ToggleBag", "ToggleAllBags", "OpenAllBags", "ToggleBackpack" }

local function HideSeparateReagentFrame()
  local combined = ns.Util.GetCombinedBags()
  if not combined or not combined:IsShown() then return end

  ns.Util.ForEachContainerFrame(function(frame)
    if frame ~= combined and frame:IsShown() then
      local bagID = frame.GetBagID and frame:GetBagID() or frame:GetID()
      if bagID == C.BAG then frame:Hide() end
    end
  end)
end

local function Sweep()
  HideSeparateReagentFrame()
  ns.Layout.Run()
end

-- Run immediately (so the window never renders unextended), and once more next
-- frame in case Blizzard finishes setting up after our hook runs.
local function DeferredSweep()
  Sweep()
  C_Timer.After(0, Sweep)
end

-- True for the rest of the frame in which the combined window was hidden.
local hiddenThisFrame = false

local function ClearHidden()
  hiddenThisFrame = false
end

local function OnCombinedHide()
  hiddenThisFrame = true
  C_Timer.After(0, ClearHidden)
  ns.Layout.Run()
end

-- ToggleAllBags (the "Open All Bags" binding, Shift+B) closes every open bag and
-- then counts them: if fewer were open than should be, it reopens everything
-- instead of closing. It expects the reagent bag to be open in its own window,
-- which we hide, so it always counts one short and reopens the bags. Seen from
-- here: the combined window was hidden and is shown again within the same call.
-- Finish the close Blizzard meant to do (the same bags OpenAllBagsInternal opened).
local function FinishToggleClose()
  local combined = ns.Util.GetCombinedBags()
  if not (hiddenThisFrame and combined and combined:IsShown()) then return end
  CloseBackpack()
  CloseBag(C.BAG)
end

--- Installs all hooks. Call once, after the panel exists.
function BagHooks.Install(combined)
  combined:HookScript("OnShow", DeferredSweep)
  combined:HookScript("OnHide", OnCombinedHide)
  -- Blizzard can (re)size the window at any point: verify every frame while open,
  -- and also the instant it calls SetHeight/SetSize (no one-frame lag).
  combined:HookScript("OnUpdate", ns.Layout.Verify)
  hooksecurefunc(combined, "SetHeight", function() ns.Layout.OnResizeCall(combined) end)
  hooksecurefunc(combined, "SetSize", function() ns.Layout.OnResizeCall(combined) end)
  -- Blizzard re-anchors every item button to its MoneyFrame here (bags opened,
  -- tracked currency changed, gamepad mode toggled): re-apply the bottom shift
  -- before the frame renders.
  if combined.UpdateItemLayout then
    hooksecurefunc(combined, "UpdateItemLayout", function() ns.Layout.OnItemLayout(combined) end)
  end

  ns.Util.ForEachContainerFrame(function(frame)
    if frame ~= combined then frame:HookScript("OnShow", DeferredSweep) end
  end)
  for _, name in ipairs(OPEN_FUNCTIONS) do
    if _G[name] then hooksecurefunc(name, DeferredSweep) end
  end
  if ToggleAllBags and CloseBackpack and CloseBag then
    hooksecurefunc("ToggleAllBags", FinishToggleClose)
  end
end
