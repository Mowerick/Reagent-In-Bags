-- Entry point: wires the modules together once the player is in the world.
local _, ns = ...

local REFRESH_EVENTS = {
  "BAG_UPDATE",
  "BAG_UPDATE_COOLDOWN",
  "ITEM_LOCK_CHANGED",
  "INVENTORY_SEARCH_UPDATE",
}
-- The reagent bag may have been equipped/removed: size and slot count can change.
local RELAYOUT_EVENTS = { "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED" }

local frame = CreateFrame("Frame")

local function OnLogin()
  ns.Config.Init()
  ns.Layout.SetTopMode(not ns.db.bottom)
  ns.Options.Register()

  local combined = ns.Util.GetCombinedBags()
  if not combined then return end

  ns.Panel.Create(combined)
  ns.Config.Subscribe(ns.Panel.ApplyStyle)
  ns.Config.Subscribe(function()
    ns.Layout.SetTopMode(not ns.db.bottom)
    ns.Layout.Relayout()
  end)
  ns.BagHooks.Install(combined)

  for _, event in ipairs(REFRESH_EVENTS) do
    frame:RegisterEvent(event)
  end
  for _, event in ipairs(RELAYOUT_EVENTS) do
    frame:RegisterEvent(event)
  end
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_LOGIN" then
    self:UnregisterEvent("PLAYER_LOGIN")
    OnLogin()
  elseif tContains(RELAYOUT_EVENTS, event) then
    ns.Layout.Relayout()
  else
    ns.Slots.RefreshAll()
  end
end)
