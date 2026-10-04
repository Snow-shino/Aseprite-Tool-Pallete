local palette=require('src.lib.palette')
local apply=require('src.lib.apply')
local presets=require('src.lib.presets')
local M={}
local SOURCES={'Current Sprite Palette','Generate From Artwork','Saved Preset'}
local DISTANCES={'CIE76 (Lab)','CIEDE2000','Weighted RGB','RGB Euclidean'}
local DITHERS={'None','Bayer 2x2','Bayer 4x4','Bayer 8x8','Floyd-Steinberg','Atkinson'}
local SCOPES={'Current Cel','Selection','Current Frame','Current Layer','All Frames','Whole Sprite'}
local OUTPUTS={'Modify Existing'}
local QUANTIZERS={'Median Cut','Median Cut + K-Means'}
local function renderFit(image,maxW,maxH)
  if not image then return nil end
  local scale=math.min(maxW/image.width,maxH/image.height,1)
  local w,h=math.max(1,math.floor(image.width*scale)),math.max(1,math.floor(image.height*scale))
  local out=Image(w,h,ColorMode.RGB)
  for y=0,h-1 do for x=0,w-1 do out:putPixel(x,y,image:getPixel(math.min(image.width-1,math.floor(x/scale)),math.min(image.height-1,math.floor(y/scale)))) end end
  return out
end
local function colorsForShades(colors)
  local out={}; for _,c in ipairs(colors or {}) do out[#out+1]=Color{r=c.r,g=c.g,b=c.b,a=255} end; return out
end
function M.show()
  if not app.isUIAvailable then return end
  local sourceSprite=app.sprite
  if not sourceSprite then app.alert('Open a sprite before using Arete Palette Limiter.'); return end
  if sourceSprite.colorMode~=ColorMode.RGB then app.alert('Arete Palette Limiter currently supports RGB sprites. This sprite was not changed.'); return end
  if not json then app.alert('Arete Palette Limiter requires Aseprite 1.3 or later.'); return end
  local sourceCel,sourceFrame,sourceLayer=app.cel,app.frame,app.layer
  local original=apply.captureState(sourceSprite)
  local committed=false
  local timer
  local savedNames=presets.names(); if #savedNames==0 then savedNames={'(no presets saved)'} end
  local dlg=Dialog{title='Arete Palette Limiter',resizeable=false,onclose=function()
    if timer then timer:stop() end
    if not committed then apply.restoreState(original) end
  end}
  if not dlg then return end
  local previewImage,previewColors=nil,{}
  local refresh
  timer=Timer{interval=0.12,ontick=function() timer:stop(); if refresh then refresh() end end}
  local function scheduleRefresh()
    if timer.isRunning then timer:stop() end
    timer:start()
  end
  dlg:combobox{id='source',label='Palette:',options=SOURCES,option='Current Sprite Palette',onchange=scheduleRefresh}
  dlg:slider{id='colors',label='Target colors:',min=2,max=256,value=16,onchange=scheduleRefresh}
  dlg:combobox{id='quantize',label='Generate:',options=QUANTIZERS,option='Median Cut',onchange=scheduleRefresh}
  dlg:combobox{id='distance',label='Match:',options=DISTANCES,option='CIE76 (Lab)',onchange=scheduleRefresh}
  dlg:combobox{id='dither',label='Dither:',options=DITHERS,option='None',onchange=scheduleRefresh}
  dlg:slider{id='amount',label='Dither amount:',min=0,max=100,value=100,onchange=scheduleRefresh}
  dlg:slider{id='alphaThreshold',label='Alpha threshold:',min=1,max=255,value=1,onchange=scheduleRefresh}
  dlg:check{id='preserve',label='Alpha:',text='Preserve transparency',selected=true,onclick=scheduleRefresh}
  dlg:separator{text='Processing'}
  dlg:combobox{id='scope',label='Scope:',options=SCOPES,option='Current Cel',onchange=scheduleRefresh}
  dlg:combobox{id='output',label='Output:',options=OUTPUTS,option='Modify Existing'}
  dlg:separator{text='Preset'}
  dlg:combobox{id='preset',label='Saved:',options=savedNames,option=savedNames[1],onchange=function()
    local p=presets.get(dlg.data.preset)
    if p then
      local d=dlg.data; d.source='Saved Preset'; d.colors=p.colors or 16; d.quantize=p.settings.quantize or 'Median Cut'
      d.distance=p.settings.distance; d.dither=p.settings.dither; d.amount=p.settings.amount
      d.alphaThreshold=p.settings.alphaThreshold; d.preserve=p.settings.preserveAlpha; d.scope=p.settings.scope
      d.output=p.settings.output or 'Modify Existing'; dlg.data=d
    end
    scheduleRefresh()
  end}
  dlg:entry{id='presetName',label='Name:',text='My Palette Preset'}
  dlg:button{id='savePreset',text='Save Preset',onclick=function()
    local d=dlg.data; local settings={distance=d.distance,quantize=d.quantize,dither=d.dither,amount=d.amount,alphaThreshold=d.alphaThreshold,preserveAlpha=d.preserve,scope=d.scope,output=d.output,colors=d.colors}
    local source=d.source=='Saved Preset' and ((presets.get(d.preset) or {}).source or 'Current Sprite Palette') or d.source
    local colors
    if d.source=='Saved Preset' then local p=presets.get(d.preset); colors=p and p.palette or nil
    elseif source=='Generate From Artwork' then
      apply.restoreState(original)
      local ok,result=pcall(function() local cels=apply.collectCels(sourceSprite,settings.scope,sourceCel,sourceFrame,sourceLayer); return palette.generate(apply.extractCels(cels,settings.alphaThreshold,settings.scope=='Selection' and sourceSprite.selection or nil),settings.colors,settings.alphaThreshold,settings.quantize) end)
      if not ok then scheduleRefresh(); app.alert('Could not prepare palette for preset: '..tostring(result)); return end
      colors=result
    end
    local ok,err=pcall(presets.save,d.presetName,{source=source,settings=settings,palette=colors})
    if not ok then app.alert('Could not save preset: '..tostring(err)); return end
    local names=presets.names(); dlg:modify{id='preset',options=names}; local refreshed=dlg.data; refreshed.preset=d.presetName; dlg.data=refreshed
    scheduleRefresh(); app.alert('Saved preset “'..d.presetName..'”.')
  end}
  dlg:button{id='deletePreset',text='Delete Preset',onclick=function()
    local ok,removed=pcall(presets.delete,dlg.data.preset)
    if not ok then app.alert('Could not delete preset: '..tostring(removed)); return end
    if not removed then app.alert('Choose an existing preset first.'); return end
    local names=presets.names(); if #names==0 then names={'(no presets saved)'} end
    dlg:modify{id='preset',options=names}; local refreshed=dlg.data; refreshed.preset=names[1]; dlg.data=refreshed
    if refreshed.source=='Saved Preset' then refreshed.source='Current Sprite Palette'; dlg.data=refreshed end
    scheduleRefresh(); app.alert('Preset deleted.')
  end}
  dlg:separator{text='Live preview (active cel)'}
  dlg:canvas{id='previewCanvas',width=260,height=150,autoscaling=false,onpaint=function(ev)
    local gc=ev.context; gc.color=Color{r=34,g=36,b=42,a=255}; gc:fillRect(Rectangle(0,0,gc.width,gc.height))
    if previewImage then
      local img=renderFit(previewImage,gc.width-8,gc.height-38); gc:drawImage(img,4,4)
      local sw=math.max(1,math.floor((gc.width-8)/math.max(1,#previewColors)))
      for i,c in ipairs(previewColors) do local x=4+(i-1)*sw; if x<gc.width then gc.color=Color{r=c.r,g=c.g,b=c.b,a=255}; gc:fillRect(Rectangle(x,gc.height-26,math.min(sw-1,gc.width-x-4),20)) end end
    else gc.color=Color{r=225,g=225,b=225,a=255}; gc:fillText('Preparing live preview…',8,12) end
  end}
  dlg:label{id='previewStatus',label='Status:',text='Preparing preview…'}
  local function currentSettings()
    local d=dlg.data
    return {distance=d.distance,quantize=d.quantize,dither=d.dither,amount=d.amount,preserveAlpha=d.preserve,alphaThreshold=d.alphaThreshold,scope=d.scope,output=d.output,colors=d.colors}
  end
  local function selectedPalette(settings,cels)
    local d=dlg.data
    if d.source=='Saved Preset' then
      local saved=presets.get(d.preset); if not saved then error('Choose a valid saved preset.') end
      if saved.palette and #saved.palette>0 then return saved.palette end
      if saved.source=='Generate From Artwork' then return palette.generate(apply.extractCels(cels,settings.alphaThreshold,d.scope=='Selection' and sourceSprite.selection or nil),settings.colors,settings.alphaThreshold,settings.quantize) end
      return palette.sanitize(palette.fromSprite(sourceSprite))
    elseif d.source=='Generate From Artwork' then
      return palette.generate(apply.extractCels(cels,settings.alphaThreshold,d.scope=='Selection' and sourceSprite.selection or nil),settings.colors,settings.alphaThreshold,settings.quantize)
    end
    return palette.sanitize(palette.fromSprite(sourceSprite))
  end
  refresh=function()
    local ok,err=pcall(function()
      apply.restoreState(original)
      local s=currentSettings()
      local cels=apply.collectCels(sourceSprite,s.scope,sourceCel,sourceFrame,sourceLayer)
      local colors=selectedPalette(s,cels); if #colors==0 then error('No opaque colors are available in the selected palette or artwork.') end
      local count,skipped,prepared=apply.preview(original,s,sourceCel,sourceFrame,sourceLayer,colors)
      local selected
      for _,item in ipairs(prepared) do if item.source==sourceCel then selected=item; break end end
      if not selected then selected=prepared[1] end
      previewImage=selected and selected.image or nil; previewColors=colors; dlg:repaint()
      dlg:modify{id='previewStatus',text=string.format('%d cel(s) previewed%s',count,skipped>0 and ('; '..skipped..' skipped') or '')}
    end)
    if not ok then
      apply.restoreState(original); previewImage=nil; previewColors={}; dlg:repaint()
      dlg:modify{id='previewStatus',text='Preview error: '..tostring(err)}
    end
  end
  dlg:button{id='apply',text='Apply',focus=true,onclick=function()
    if timer.isRunning then timer:stop() end
    apply.restoreState(original)
    local ok,err=pcall(function()
      local s=currentSettings(); local cels=apply.collectCels(sourceSprite,s.scope,sourceCel,sourceFrame,sourceLayer)
      local colors=selectedPalette(s,cels); if #colors==0 then error('No opaque colors are available in the selected palette or artwork.') end
      local count,skipped=apply.apply(sourceSprite,s,sourceCel,sourceFrame,sourceLayer,colors)
      committed=true; app.alert(string.format('Processed %d cel(s).%s',count,skipped>0 and (' Skipped '..skipped..' unsupported or locked layer(s).') or ''))
    end)
    if not ok then
      apply.restoreState(original); dlg:modify{id='previewStatus',text='Apply error: '..tostring(err)}
      scheduleRefresh(); app.alert('Arete Palette Limiter\n'..tostring(err))
    else dlg:close() end
  end}
  dlg:button{text='Cancel',onclick=function() dlg:close() end}
  scheduleRefresh()
  dlg:show{autoscrollbars=true}
end
return M
