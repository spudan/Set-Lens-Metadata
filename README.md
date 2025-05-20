# Set Lens Metadata Plugin for Adobe Lightroom Classic

**Set Lens Metadata** is a lightweight and user-friendly plugin for **Adobe Lightroom Classic**, designed to help photographers manually add or correct lens information in metadata — especially for **vintage lenses**, **manual focus lenses**, or **third-party lenses** that don’t write EXIF data.

This plugin leverages the power of **ExifTool** to write metadata directly into XMP sidecar files, while also reading what it can directly from Lightroom. It’s ideal for photographers who use manual lenses with adapters on mirrorless or DSLR cameras.

---

## ✨ Features

- Add or update lens metadata via ExifTool
- Automatically reads available metadata (e.g. lens, focal length, aperture) from Lightroom
- Supports lens presets to fill in missing values (e.g. serial number, max aperture)
- Maintains user-defined **camera crop factor list** (e.g. APS-C, MFT)
- Automatically calculates and writes **35mm equivalent focal length**
- All data written to XMP sidecar files
- Smart autofill: if no useful metadata is found, fields remain empty
- Works with multiple selected images

---

## ⚠ Disclaimer

Use at your own risk.  
I'm not a professional developer, just a photographer who needed a tool like this and couldn't find one – so I built it myself. Feel free to contribute or suggest improvements!

---

## 📦 Installation

1. **Download or clone this repository** into your Lightroom plugins folder.
2. **Download [ExifTool](https://exiftool.org/)** (required):
   - Windows: place `exiftool(-k).exe` as `resources/exiftool.exe`
   - macOS/Linux: install via package manager or manually; adjust path in `ExifToolCommand.lua` if needed
3. **Enable the plugin** in Lightroom:
   - Go to `File > Plug-in Manager`
   - Click `Add` and select the plugin folder
   - Enable it

---

## 🛠️ Usage Instructions

### 1. Save Metadata to XMP
Before using the plugin, make sure metadata is saved to XMP sidecar files:
- Select your RAW images
- Press `Ctrl+S` (or `Cmd+S` on Mac)

### 2. Use the Plugin
- Select one or more photos in the Library module
- Go to `Library > Plug-in Extras > Set Lens...`
- The plugin will:
  - Read available metadata from Lightroom
  - Fill in missing values from presets (if available)
  - Display 35mm equivalent focal length if crop factor is known

You can:
- Edit values manually
- Save presets for lenses
- Define crop factors for your cameras

Click **OK** to apply.

### 3. Reload Metadata
After running the plugin:
- Select the modified photos again
- Choose `Metadata > Read Metadata from Files` in Lightroom

---

## 🧰 Technical Notes

- Plugin writes to the `.xmp` files using ExifTool
- Lightroom’s own metadata is read where available (no ExifTool read required)
- Existing XMP metadata is overwritten in-place
- `FocalLengthIn35mmFormat` is calculated and written if crop factor is available
- If no usable metadata is found, all fields remain blank
- Camera crop factors are stored per model name
- Tested on Windows (macOS should work with correct ExifTool path)

---

## 📄 License

This project is licensed under the MIT License.  
ExifTool is a separate tool with its own license – see [exiftool.org](https://exiftool.org/) for details.
