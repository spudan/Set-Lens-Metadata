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
prefs.cameraPresets = prefs.cameraPresets or {}

local function runDialog()
  LrTasks.startAsyncTask(function()
    LrFunctionContext.callWithContext("SetLensMetadata", function(context)
      local f = LrView.osFactory()
      local bind = LrBinding.makePropertyTable(context)

      local catalog = LrApplication.activeCatalog()
      local selected = catalog:getTargetPhotos()

      if #selected == 0 then
        LrDialogs.message("No Photos Selected", "Please select at least one photo.", "warning")
        return
      end

      local firstPhoto = selected[1]

      -- EXIF auslesen
      local cameraModel = firstPhoto:getFormattedMetadata("cameraModel") or ""
      local lensFromExif = firstPhoto:getFormattedMetadata("lens") or ""
      local focalFromExif = firstPhoto:getFormattedMetadata("focalLength") or ""
      local rawFNumber = firstPhoto:getFormattedMetadata("aperture") or ""

      local focalOnly = focalFromExif:match("^(%d+)") or ""
      local fnumberFromExif = rawFNumber:match("([%d,%.]+)") or ""
      fnumberFromExif = fnumberFromExif:gsub(",", ".")

      local hasMetadata = (lensFromExif and lensFromExif ~= "")
        or (focalOnly and focalOnly ~= "")
        or (fnumberFromExif and fnumberFromExif ~= "")

      local preset = nil
      if hasMetadata and lensFromExif and prefs.presets[lensFromExif] then
        preset = prefs.presets[lensFromExif]
      end

      bind["lens"] = hasMetadata and lensFromExif or ""
      bind["focal"] = hasMetadata and (focalOnly ~= "" and focalOnly or (preset and preset.focal or "")) or ""
      bind["fnumber"] = hasMetadata and (fnumberFromExif ~= "" and fnumberFromExif or (preset and preset.fnumber or "")) or ""
      bind["aperture"] = hasMetadata and (preset and preset.aperture or "") or ""
      bind["serial"] = hasMetadata and (preset and preset.serial or "") or ""
      bind["focal35"] = (preset and preset.focal35) or ""
      bind["focal35Manual"] = (preset and preset.focal35Manual) or false

      bind["selectedPreset"] = nil

      bind:addObserver("selectedPreset", function(propertyTable, key, value)
        local selected = value
        if selected and prefs.presets[selected] then
          local p = prefs.presets[selected]
          bind.lens = p.lens or ""
          bind.focal = p.focal or ""
          bind.aperture = p.aperture or ""
          bind.fnumber = p.fnumber or ""
          bind.serial = p.serial or ""
          bind.focal35Manual = p.focal35Manual or false

          local crop = tonumber(bind.cameraCrop) or 1.0
          local focal = tonumber(bind.focal)
          local shouldCalculate = not bind.focal35Manual or not p.focal35 or p.focal35 == ""
          if shouldCalculate and focal then
            bind.focal35 = tostring(math.floor(focal * crop + 0.5))
          else
            bind.focal35 = p.focal35 or ""
          end
        end
      end)

      bind["cameraName"] = cameraModel
      bind["cameraCrop"] = prefs.cameraPresets[cameraModel] and tostring(prefs.cameraPresets[cameraModel]) or "1.0"
      bind["selectedCameraPreset"] = nil
      bind["cameraPresetNames"] = {}
      bind["cropInfo"] = ""

      local function updatePresetNames()
        local names = {}
        for name, _ in pairs(prefs.presets) do
          table.insert(names, name)
        end
        table.sort(names)
        bind["presetNames"] = names
      end

      local function updateCameraPresetNames()
        local names = {}
        for name, _ in pairs(prefs.cameraPresets) do
          table.insert(names, name)
        end
        table.sort(names)
        bind["cameraPresetNames"] = names
      end

      local function updateCropInfo()
        local crop = tonumber(bind.cameraCrop) or 1.0
        local focal = tonumber(bind.focal)
        if not bind.focal35Manual and focal then
          bind.focal35 = tostring(math.floor(focal * crop + 0.5))
        end
      end

      updatePresetNames()
      updateCameraPresetNames()
      updateCropInfo()

      bind:addObserver("cameraCrop", updateCropInfo)
      bind:addObserver("focal", updateCropInfo)
      bind:addObserver("focal35Manual", updateCropInfo)
      bind:addObserver("focal", function() end)

      if #selected > 1 then
	  LrDialogs.message(
	    "Note: Multiple images selected",
	    "The displayed values are from the first selected image. They may differ for the other images.",
	    "info"
	  )
	end

      local contents = f:column {
        spacing = f:control_spacing(),
        bind_to_object = bind,

        f:row {
          f:popup_menu {
            items = LrView.bind("presetNames"),
            value = LrView.bind("selectedPreset"),
            width = 300,
            title = "Load Lens:",
          },
          f:push_button {
            title = "Delete Preset",
            action = function()
              local selected = bind.selectedPreset
              if selected and prefs.presets[selected] then
                prefs.presets[selected] = nil
                bind.selectedPreset = nil
                updatePresetNames()
              end
            end
          },
        },

        f:row { f:static_text { title = "Lens:", width = 100 }, f:edit_field { value = LrView.bind("lens"), width_in_chars = 30 } },
        f:row { f:static_text { title = "Focal Length:", width = 100 }, f:edit_field { value = LrView.bind("focal"), width_in_chars = 10, immediate = true } },
        f:row { f:static_text { title = "Max Aperture:", width = 100 }, f:edit_field { value = LrView.bind("aperture"), width_in_chars = 10 } },
        f:row { f:static_text { title = "FNumber:", width = 100 }, f:edit_field { value = LrView.bind("fnumber"), width_in_chars = 10 } },
        f:row { f:static_text { title = "Serial Number:", width = 100 }, f:edit_field { value = LrView.bind("serial"), width_in_chars = 20 } },

        f:row {
          f:push_button {
            title = "Save as Lens Preset",
            action = function()
              if bind.lens == "" then return end
              prefs.presets[bind.lens] = {
                lens = bind.lens,
                focal = bind.focal,
                aperture = bind.aperture,
                fnumber = bind.fnumber,
                serial = bind.serial,
                focal35 = bind.focal35,
                focal35Manual = bind.focal35Manual
              }
              bind.selectedPreset = bind.lens
              updatePresetNames()
            end
          }
        },

        f:spacer { height = 20 },

        f:row {
		  f:static_text { title = "Only relevant for Crop-Sensor Cameras or Special Lenses", fill_horizontal = 1 },
		},
		
		f:row {
          f:static_text { title = "Camera:", width = 100 },
          f:edit_field {
            value = LrView.bind("cameraName"),
            width_in_chars = 30,
            enabled = false,
          },
        },

        f:row {
          f:static_text { title = "Crop Factor:", width = 100 },
          f:edit_field { value = LrView.bind("cameraCrop"), width_in_chars = 6, immediate = true }
        },

        f:row {
          f:static_text { title = "Focal Length (35mm equivalent):", width = 200 },
          f:edit_field {
            value = LrView.bind("focal35"),
            width_in_chars = 8,
            enabled = LrView.bind("focal35Manual")
          },
          f:checkbox { title = "Set manually", value = LrView.bind("focal35Manual") },
        },
      }

      local result = LrDialogs.presentModalDialog {
        title = "Set Lens Metadata",
        contents = contents,
      }

      if result == "ok" then
        local function isNumber(v) return v:match("^%d+%.?%d*$") ~= nil end
        local function isInteger(v) return v:match("^%d+$") ~= nil end

        local camName = bind.cameraName
        local camCrop = tonumber(bind.cameraCrop)
        if camName ~= "" and camCrop and camCrop > 0 then
          prefs.cameraPresets[camName] = camCrop
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

        local focal35 = bind.focal35Manual and bind.focal35 or (tonumber(bind.focal) and math.floor(tonumber(bind.focal) * (tonumber(bind.cameraCrop) or 1.0) + 0.5))

        ExifToolCommand.writeMetadataBatch(
          selected,
          bind.lens,
          bind.focal,
          bind.aperture,
          bind.fnumber,
          bind.serial,
          focal35
        )
      end
    end)
  end)
end

runDialog()
