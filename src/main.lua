-- Arete Palette Limiter
-- Initial bootstrap. Codex should evolve this into the full extension.

local function noSpriteAlert()
  if app.sprite == nil then
    app.alert("Open a sprite before using Arete Palette Limiter.")
    return true
  end
  return false
end

local function showDialog()
  if noSpriteAlert() then return end

  local dlg = Dialog{
    title="Arete Palette Limiter",
    resizeable=true
  }

  dlg:combobox{
    id="paletteSource",
    label="Palette:",
    option="Current Sprite Palette",
    options={
      "Current Sprite Palette",
      "Generate From Artwork"
    }
  }

  dlg:slider{
    id="targetColors",
    label="Colors:",
    min=2,
    max=256,
    value=16
  }

  dlg:combobox{
    id="distance",
    label="Distance:",
    option="CIE76 (Lab)",
    options={
      "CIE76 (Lab)",
      "Weighted RGB",
      "RGB Euclidean"
    }
  }

  dlg:combobox{
    id="dither",
    label="Dither:",
    option="None",
    options={
      "None",
      "Bayer 2x2",
      "Bayer 4x4",
      "Bayer 8x8",
      "Floyd-Steinberg",
      "Atkinson"
    }
  }

  dlg:slider{
    id="ditherAmount",
    label="Dither Amount:",
    min=0,
    max=100,
    value=100
  }

  dlg:check{
    id="preserveAlpha",
    label="Alpha:",
    text="Preserve transparency",
    selected=true
  }

  dlg:check{
    id="duplicateLayer",
    label="Output:",
    text="Duplicate layer before apply",
    selected=true
  }

  dlg:separator{text="Scope"}

  dlg:combobox{
    id="scope",
    option="Current Cel",
    options={
      "Current Cel",
      "Selection",
      "Current Frame",
      "Current Layer",
      "All Frames",
      "Whole Sprite"
    }
  }

  dlg:separator()

  dlg:button{
    id="preview",
    text="Preview",
    onclick=function()
      app.alert("Preview pipeline is scaffolded; implement in src/ui.lua + src/lib/apply.lua.")
    end
  }

  dlg:button{
    id="apply",
    text="Apply",
    focus=true,
    onclick=function()
      app.alert("Apply pipeline is scaffolded; implement algorithms before enabling destructive output.")
    end
  }

  dlg:button{id="cancel", text="Close"}

  dlg:show{wait=false, autoscrollbars=true}
end

showDialog()
