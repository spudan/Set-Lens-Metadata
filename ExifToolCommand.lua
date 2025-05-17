local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'
local LrDialogs = import 'LrDialogs'
local LrTasks = import 'LrTasks'
local LrFunctionContext = import 'LrFunctionContext'

local pluginPath = LrPathUtils.child(_PLUGIN.path, "resources")
local exiftoolPath = LrPathUtils.child(pluginPath, "exiftool.exe")

local ExifToolCommand = {}

local function findXMPPath(photoPath)
  local folder = LrPathUtils.parent(photoPath)
  local baseName = LrPathUtils.removeExtension(LrPathUtils.leafName(photoPath))
  local xmp1 = LrPathUtils.child(folder, baseName .. ".xmp")
  local xmp2 = LrPathUtils.child(folder, baseName:gsub("^_", "") .. ".xmp")
  if LrFileUtils.exists(xmp1) then return xmp1 end
  if LrFileUtils.exists(xmp2) then return xmp2 end
  return nil
end

function ExifToolCommand.writeMetadataBatch(photoList, lensName, focalLength, aperture, fnumber, serial)
  LrTasks.startAsyncTask(function()
    local missing = {}
    local valid = {}

    for _, photo in ipairs(photoList) do
      local path = photo:getRawMetadata("path")
      local xmp = findXMPPath(path)
      if xmp then
        table.insert(valid, { raw = path, xmp = xmp })
      else
        table.insert(missing, path)
      end
    end

    if #missing > 0 then
      local msg = "No XMP file was found for the following files:\n\n"
      for _, path in ipairs(missing) do
        msg = msg .. "- " .. LrPathUtils.leafName(path) .. "\n"
      end
      msg = msg .. "\nPlease open the images in Lightroom and press Ctrl+S to save metadata."

      LrFunctionContext.callWithContext("missingXMPDialog", function()
        LrDialogs.message("Missing XMP Files", msg, "warning")
      end)

      return
    end

    local failed = {}

    for _, entry in ipairs(valid) do
      local command = string.format(
        '%s -m -P -overwrite_original_in_place ' ..
        '-Lens="%s" -LensModel="%s" -LensType="%s" ' ..
        '-FocalLength="%s" -MaxApertureValue="%s" -FNumber="%s" -LensSerialNumber="%s" ' ..
        '"%s"',
        exiftoolPath,
        lensName, lensName, lensName,
        focalLength, aperture, fnumber, serial,
        entry.xmp
      )

      local result = LrTasks.execute(command)
      if result ~= 0 then
        table.insert(failed, entry.xmp)
      end
    end

    LrFunctionContext.callWithContext("resultDialog", function()
      if #failed > 0 then
        local msg = "ExifTool could not modify the XMP file for the following files:\n\n"
        for _, xmp in ipairs(failed) do
          msg = msg .. "- " .. LrPathUtils.leafName(xmp) .. "\n"
        end
        LrDialogs.message("ExifTool Error", msg, "critical")
      else
        LrDialogs.message("Done", "Metadata successfully written. Please reload metadata in Lightroom.", "info")
      end
    end)
  end)
end

return ExifToolCommand
