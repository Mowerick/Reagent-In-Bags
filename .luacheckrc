std = "lua51"
max_line_length = 160
codes = true

-- Saved variable and slash-command globals this addon defines.
globals = {
  "ReagentInBagsDB",
  ColorPickerFrame = { other_fields = true }, -- legacy picker API is configured by assigning fields
  "SLASH_REAGENTINBAGS1",
  "SlashCmdList",
  "ReagentInBags_OnAddonCompartmentClick",
  "ReagentInBags_OnAddonCompartmentEnter",
  "ReagentInBags_OnAddonCompartmentLeave",
}

-- WoW API used (read-only).
read_globals = {
  "Enum", "C_Container", "C_Texture", "C_NewItems", "C_Timer", "Settings",
  "CreateFrame", "hooksecurefunc", "tContains", "unpack",
  "GameTooltip", "REAGENT_BAG",
  "SetItemButtonTexture", "SetItemButtonCount", "SetItemButtonDesaturated", "SetItemButtonQuality",
  "CooldownFrame_Set", "InterfaceOptions_AddCategory", "InterfaceOptionsFrame_OpenToCategory",
  "ToggleAllBags", "CloseBackpack", "CloseBag",
}
