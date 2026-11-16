-- `/rbag debug`: prints how the bag frame is built, for bug reports.
local _, ns = ...

local Debug = {}
ns.Debug = Debug

local PREFIX = "|cff26bfa6RIB|r"
local MAX_ITEMS_SHOWN = 8
local MAX_FRAMES_SHOWN = 12

local function Say(...)
  print(PREFIX, ...)
end

local function DescribePoint(frame, index, combined)
  local point, relativeTo, relativePoint, x, y = frame:GetPoint(index)
  local name = "nil"
  if relativeTo then
    name = (relativeTo.GetName and relativeTo:GetName()) or (relativeTo == combined and "<combined>") or tostring(relativeTo)
  end
  return string.format("%s -> %s %s (%.1f, %.1f)", tostring(point), name, tostring(relativePoint), x or 0, y or 0)
end

local function ListFrameFields(combined)
  local keys = {}
  for key, value in pairs(combined) do
    if type(key) == "string" and type(value) == "table" and value.GetObjectType then
      keys[#keys + 1] = key .. "(" .. value:GetObjectType() .. ")"
    end
  end
  table.sort(keys)
  Say("frame fields:", table.concat(keys, ", "))
end

local function ListItemButtons(combined, children, panel)
  local shown = 0
  for _, child in ipairs(children) do
    if child ~= panel and shown < MAX_ITEMS_SHOWN and (child.SetMatchesSearch or child.GetBagID) then
      shown = shown + 1
      local parent = child:GetParent()
      Say(string.format(
        "  item-like %s [%s] parent=%s points=%d",
        tostring(child:GetName()),
        child:GetObjectType(),
        tostring(parent == combined and "combined" or (parent and parent:GetName())),
        child:GetNumPoints()
      ))
      for i = 1, child:GetNumPoints() do
        Say("     " .. DescribePoint(child, i, combined))
      end
    end
  end
  return shown
end

function Debug.Run()
  local combined = ns.Util.GetCombinedBags()
  if not combined then
    Say("no ContainerFrameCombinedBags")
    return
  end
  local panel = ns.Panel.Get()

  Say(string.format("combined: %.0fx%.0f, level %d, strata %s", combined:GetWidth(), combined:GetHeight(), combined:GetFrameLevel(), combined:GetFrameStrata()))
  Say("anchor:", DescribePoint(combined, 1, combined))
  ListFrameFields(combined)

  local children = { combined:GetChildren() }
  Say("children:", #children)
  if ListItemButtons(combined, children, panel) == 0 then
    Say("no item buttons among direct children; sub-frames:")
    for i, child in ipairs(children) do
      if i <= MAX_FRAMES_SHOWN then
        Say(string.format("  %s [%s] children=%d", tostring(child:GetName() or child:GetDebugName()), child:GetObjectType(), child:GetNumChildren()))
      end
    end
  end

  local state = ns.Layout.GetState()
  Say(string.format(
    "height now %.1f, blizzHeight %.1f, extra %.1f, panel shown %s",
    combined:GetHeight(), state.blizzHeight, state.extra, tostring(panel and panel:IsShown())
  ))
  Say("mode:", state.topMode and "top (stable)" or "bottom (experimental)", "extra:", state.extra, "itemOffset:", state.itemOffset)
end
