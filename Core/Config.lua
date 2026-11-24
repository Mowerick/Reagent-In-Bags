-- Saved settings. Changes go through the setters so every interested module
-- (panel styling, layout, options UI) gets notified in one place.
local _, ns = ...
local C = ns.Const

local Config = {}
ns.Config = Config

local listeners = {}

local function Fire()
  for _, fn in ipairs(listeners) do
    fn()
  end
end

--- Registers fn to be called after any setting changed.
function Config.Subscribe(fn)
  listeners[#listeners + 1] = fn
end

local function CopyColor(color)
  return { color[1], color[2], color[3] }
end

--- Loads/migrates the saved variables into ns.db. Call once at PLAYER_LOGIN.
function Config.Init()
  ReagentInBagsDB = ReagentInBagsDB or {}
  local db = ReagentInBagsDB

  if type(db.color) ~= "table" then db.color = CopyColor(C.DEFAULTS.color) end
  if db.version ~= C.DB_VERSION then
    db.style = C.DEFAULTS.style -- layout changed: start from the default look
    db.version = C.DB_VERSION
  end
  if db.style ~= "tinted" then db.style = "blizzard" end
  if db.showTitles == nil then db.showTitles = C.DEFAULTS.showTitles end
  if db.align ~= "left" then db.align = "right" end
  db.bottom = db.bottom == true

  ns.db = db
end

function Config.SetColor(r, g, b)
  ns.db.color = { r, g, b }
  Fire()
end

function Config.SetStyle(style)
  ns.db.style = style
  Fire()
end

function Config.SetShowTitles(show)
  ns.db.showTitles = show and true or false
  Fire()
end

function Config.SetAlign(align)
  ns.db.align = align == "left" and "left" or "right"
  Fire()
end

function Config.SetBottomPlacement(bottom)
  ns.db.bottom = bottom and true or false
  Fire()
end

function Config.ResetAppearance()
  local db = ns.db
  db.color = CopyColor(C.DEFAULTS.color)
  db.style = C.DEFAULTS.style
  db.showTitles = C.DEFAULTS.showTitles
  db.align = C.DEFAULTS.align
  Fire()
end
