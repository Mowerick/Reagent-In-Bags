local _, ns = ...

ns.Util = {}

--- The combined backpack frame (nil if the client has none).
function ns.Util.GetCombinedBags()
  return _G.ContainerFrameCombinedBags
end

--- Calls fn for every separate container frame.
function ns.Util.ForEachContainerFrame(fn)
  local list = _G.ContainerFrameContainer and _G.ContainerFrameContainer.ContainerFrames
  if list then
    for _, frame in ipairs(list) do
      fn(frame)
    end
  else
    for i = 1, 13 do
      local frame = _G["ContainerFrame" .. i]
      if frame then fn(frame) end
    end
  end
end
