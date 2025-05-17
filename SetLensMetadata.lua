local LrDialogs = import 'LrDialogs'
local LrTasks = import 'LrTasks'
local LrView = import 'LrView'
local LrBinding = import 'LrBinding'
local LrPrefs = import 'LrPrefs'
local LrApplication = import 'LrApplication'
local LrFunctionContext = import 'LrFunctionContext'

local ExifToolCommand = require 'ExifToolCommand'

local prefs = LrPrefs.prefsForPlugin()
prefs.presets = prefs.presets or {}

local function runDialog()
  LrFunctionContext.callWithContext("SetLensMetadata", function(context)
    local f = LrView.osFactory()
    local bind = LrBinding.makePropertyTable(context)

    local function updatePresetNames()
      local names = {}
      for name, _ in pairs(prefs.presets) do
        table.insert(names, name)
      end
      table.sort(names)
      bind["presetNames"] = names
    end

    bind["lens"] = prefs.lastLens or ""
    bind["focal"] = prefs.lastFocal or ""
    bind["aperture"] = prefs.lastAperture or ""
    bind["fnumber"] = prefs.lastFNumber or ""
    bind["serial"] = prefs.lastSerial or ""
    bind["selectedPreset"] = nil

    updatePresetNames()

    local contents = f:column {
      spacing = f:control_spacing(),
      bind_to_object = bind,

      f:row {
        f:popup_menu {
          items = LrView.bind("presetNames"),
          value = LrView.bind("selectedPreset"),
          width = 300,
          title = "Load Preset:",
        },
        f:push_button {
          title = "Load",
          action = function()
            local selected = bind.selectedPreset
            if selected and prefs.presets[selected] then
              local preset = prefs.presets[selected]
              bind["lens"] = preset.lens or ""
              bind["focal"] = preset.focal or ""
              bind["aperture"] = preset.aperture or ""
              bind["fnumber"] = preset.fnumber or ""
              bind["serial"] = preset.serial or ""
            else
              LrDialogs.message("Invalid Preset", "Please select a valid saved preset.", "warning")
            end
          end
        },
        f:push_button {
          title = "Delete Preset",
          action = function()
            if bind.selectedPreset and prefs.presets[bind.selectedPreset] then
              local confirmed = LrDialogs.confirm("Delete Preset?", "Are you sure you want to delete this preset?", "Delete", "Cancel")
              if confirmed == "ok" then
                prefs.presets[bind.selectedPreset] = nil
                bind.selectedPreset = nil
                updatePresetNames()
              end
            end
          end
        },
      },

      f:row {
        f:static_text { title = "Lens:", width = 100 },
        f:edit_field { value = LrView.bind("lens"), width_in_chars = 30 },
      },
      f:row {
        f:static_text { title = "Focal Length:", width = 100 },
        f:edit_field { value = LrView.bind("focal"), width_in_chars = 10 },
      },
      f:row {
        f:static_text { title = "Max Aperture:", width = 100 },
        f:edit_field { value = LrView.bind("aperture"), width_in_chars = 10 },
      },
      f:row {
        f:static_text { title = "FNumber:", width = 100 },
        f:edit_field { value = LrView.bind("fnumber"), width_in_chars = 10 },
      },
      f:row {
        f:static_text { title = "Serial Number:", width = 100 },
        f:edit_field { value = LrView.bind("serial"), width_in_chars = 20 },
      },

      f:row {
        f:push_button {
          title = "Save as Preset",
          action = function()
            if bind.lens == "" then
              LrDialogs.message("No Lens Provided", "Please enter a lens name.", "warning")
              return
            end

            prefs.presets[bind.lens] = {
              lens = bind.lens,
              focal = bind.focal,
              aperture = bind.aperture,
              fnumber = bind.fnumber,
              serial = bind.serial
            }
            bind.selectedPreset = bind.lens
            updatePresetNames()
            LrDialogs.message("Saved", "Preset \"" .. bind.lens .. "\" has been saved.")
          end
        },
      }
    }

    local result = LrDialogs.presentModalDialog {
      title = "Set Lens Metadata",
      contents = contents,
    }

    if result == "ok" then
      local function isNumber(value)
        return string.match(value, "^%d+%.?%d*$") ~= nil
      end

      local function isInteger(value)
        return string.match(value, "^%d+$") ~= nil
      end

      if bind.focal ~= "" and not isInteger(bind.focal) then
        LrDialogs.message("Invalid Focal Length", "Please enter a whole number.", "warning")
        return
      end

      if bind.aperture ~= "" and not isNumber(bind.aperture) then
        LrDialogs.message("Invalid Max Aperture", "Please enter a number like x.y.", "warning")
        return
      end

      if bind.fnumber ~= "" and not isNumber(bind.fnumber) then
        LrDialogs.message("Invalid FNumber", "Please enter a number like x.y.", "warning")
        return
      end

      prefs.lastLens = bind.lens
      prefs.lastFocal = bind.focal
      prefs.lastAperture = bind.aperture
      prefs.lastFNumber = bind.fnumber
      prefs.lastSerial = bind.serial

      local catalog = LrApplication.activeCatalog()
      local selected = catalog:getTargetPhotos()

      if #selected == 0 then
        LrDialogs.message("No Photos Selected", "Please select at least one photo.", "warning")
        return
      end

      ExifToolCommand.writeMetadataBatch(
        selected,
        bind.lens,
        bind.focal,
        bind.aperture,
        bind.fnumber,
        bind.serial
      )
    end
  end)
end

runDialog()
