local _, ns = ...

SLASH_REAGENTINBAGS1 = "/rbag"

local function SetPlacement(placement)
  ns.Config.SetBottomPlacement(placement == "bottom")
  print("|cff26bfa6ReagentInBags|r: panel placement = " .. placement)
end

SlashCmdList.REAGENTINBAGS = function(message)
  local command = (message or ""):lower()
  if command == "debug" then
    ns.Debug.Run()
  elseif command == "bottom" or command == "top" then
    SetPlacement(command)
  else
    ns.Options.Open()
  end
end
