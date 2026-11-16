-- Entry in the addon menu next to the minimap. The functions must be globals:
-- the .toc names them (AddonCompartmentFunc / ...OnEnter / ...OnLeave).
local _, ns = ...

function ReagentInBags_OnAddonCompartmentClick()
  ns.Options.Open()
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
