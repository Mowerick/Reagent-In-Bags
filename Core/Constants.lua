---@diagnostic disable: undefined-global
local _, ns = ...

ns.Const = {
  -- Bag index of the reagent bag.
  BAG = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5,

  -- Slot grid.
  SLOT_SIZE = 37,
  SPACING = 5,
  PAD = 6,

  -- Panel geometry.
  HEADER = 18, -- room for the "Reagent Bag" title above the slots
  FOOTER = 16, -- room for the "Bag" title under the slots
  SIDE = 1, -- inset of the panel from the bag window's left/right edge; SIDE + PAD is where the first slot starts and must match the bag grid (7)
  BOTTOM_INSET = 28, -- bottom placement: distance above the window bottom (money bar + border)
  TRIM = 16, -- top placement: the bag already leaves this gap under the search box
  TOP_FALLBACK = 68, -- top placement: window top to just under the search box

  GOLD = { 1, 0.82, 0 },

  DB_VERSION = 3,
  DEFAULTS = {
    color = { 0.15, 0.75, 0.65 },
    style = "blizzard", -- "blizzard" | "tinted"
    showTitles = true,
    bottom = false, -- experimental: panel below the item grid instead of under the search box
  },
}
