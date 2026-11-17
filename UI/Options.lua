-- Settings panel (Settings > AddOns > Reagent In Bags) and the colour picker.
local _, ns = ...

local Options = {}
ns.Options = Options

local category
local panelFrame

local function OpenColorPicker()
  local color = ns.db.color

  local function onChange()
    ns.Config.SetColor(ColorPickerFrame:GetColorRGB())
  end
  local function onCancel(previous)
    previous = previous or ColorPickerFrame.previousValues
    if previous then
      ns.Config.SetColor(previous.r or previous[1], previous.g or previous[2], previous.b or previous[3])
    end
  end

  if ColorPickerFrame.SetupColorPickerAndShow then
    ColorPickerFrame:SetupColorPickerAndShow({
      r = color[1],
      g = color[2],
      b = color[3],
      hasOpacity = false,
      swatchFunc = onChange,
      cancelFunc = onCancel,
    })
  else -- older client API
    ColorPickerFrame.hasOpacity = false
    ColorPickerFrame.func = onChange
    ColorPickerFrame.cancelFunc = onCancel
    ColorPickerFrame.previousValues = { r = color[1], g = color[2], b = color[3] }
    ColorPickerFrame:SetColorRGB(color[1], color[2], color[3])
    ColorPickerFrame:Hide()
    ColorPickerFrame:Show()
  end
end

local function CreateLabel(parent, template, text)
  local label = parent:CreateFontString(nil, "ARTWORK", template)
  label:SetText(text)
  return label
end

local function CreateCheckButton(parent, text, anchorTo, yOffset, onClick)
  local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  check:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, yOffset)
  local label = CreateLabel(check, "GameFontHighlight", text)
  label:SetPoint("LEFT", check, "RIGHT", 4, 0)
  check:SetScript("OnClick", onClick)
  return check
end

local function CreateColorSwatch(parent, anchorTo)
  local swatch = CreateFrame("Button", nil, parent)
  swatch:SetSize(28, 28)
  swatch:SetPoint("LEFT", anchorTo, "RIGHT", 16, 0)

  local border = swatch:CreateTexture(nil, "BACKGROUND")
  border:SetPoint("TOPLEFT", -2, 2)
  border:SetPoint("BOTTOMRIGHT", 2, -2)
  border:SetColorTexture(1, 1, 1, 1)

  swatch.color = swatch:CreateTexture(nil, "ARTWORK")
  swatch.color:SetAllPoints()
  swatch:SetScript("OnClick", OpenColorPicker)
  return swatch
end

local function Build()
  local panel = CreateFrame("Frame", "ReagentInBagsOptions")
  panel.name = "Reagent In Bags"

  local title = CreateLabel(panel, "GameFontNormalLarge", "Reagent In Bags")
  title:SetPoint("TOPLEFT", 16, -16)

  local colorLabel = CreateLabel(panel, "GameFontHighlight", "Panel colour")
  colorLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -24)
  local swatch = CreateColorSwatch(panel, colorLabel)
  local hint = CreateLabel(panel, "GameFontDisableSmall", "Click to choose a colour (Tinted style only)")
  hint:SetPoint("LEFT", swatch, "RIGHT", 12, 0)

  local styleLabel = CreateLabel(panel, "GameFontHighlight", "Style")
  styleLabel:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 0, -36)
  local blizzard = CreateCheckButton(panel, "Blizzard style (uses the bag window's own look, colour setting is ignored)", styleLabel, -6, function()
    ns.Config.SetStyle("blizzard")
  end)
  local tinted = CreateCheckButton(panel, "Tinted panel (solid colour with a coloured border)", blizzard, 0, function()
    ns.Config.SetStyle("tinted")
  end)
  local titles = CreateCheckButton(panel, 'Show titles ("Reagent Bag" / "Bag")', tinted, -16, function(self)
    ns.Config.SetShowTitles(self:GetChecked())
  end)

  local alignRight = CreateCheckButton(panel, "Align slots to the right (like the bag grid)", titles, 0, function(self)
    ns.Config.SetAlign(self:GetChecked() and "right" or "left")
  end)

  local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  reset:SetSize(120, 24)
  reset:SetPoint("TOPLEFT", alignRight, "BOTTOMLEFT", 0, -20)
  reset:SetText("Reset")
  reset:SetScript("OnClick", ns.Config.ResetAppearance)

  function panel.Refresh()
    local db = ns.db
    swatch.color:SetColorTexture(db.color[1], db.color[2], db.color[3], 1)
    blizzard:SetChecked(db.style ~= "tinted")
    tinted:SetChecked(db.style == "tinted")
    titles:SetChecked(db.showTitles)
    alignRight:SetChecked(db.align ~= "left")
  end
  panel:SetScript("OnShow", panel.Refresh)
  panel.Refresh()

  return panel
end

--- Builds the panel and registers it with the client's settings UI.
function Options.Register()
  panelFrame = Build()
  ns.Config.Subscribe(panelFrame.Refresh)

  if Settings and Settings.RegisterCanvasLayoutCategory then
    category = Settings.RegisterCanvasLayoutCategory(panelFrame, panelFrame.name)
    Settings.RegisterAddOnCategory(category)
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panelFrame)
  end
end

function Options.Open()
  if category and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(category.GetID and category:GetID() or category.ID)
  elseif InterfaceOptionsFrame_OpenToCategory and panelFrame then
    -- the classic call needs to be made twice to land on the right page
    InterfaceOptionsFrame_OpenToCategory(panelFrame)
    InterfaceOptionsFrame_OpenToCategory(panelFrame)
  end
end
