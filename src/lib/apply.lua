local color=require('src.lib.color')
local dither=require('src.lib.dither')
local M={}
local function decode(v)
  local pc=app.pixelColor
  return {r=pc.rgbaR(v),g=pc.rgbaG(v),b=pc.rgbaB(v),a=pc.rgbaA(v)}
end
local function encode(c) return app.pixelColor.rgba(c.r,c.g,c.b,c.a) end
local function nearest(palette,mode,cacheEnabled)
  local useLab=mode=='CIE76 (Lab)' or mode=='CIEDE2000'
  local prepared={}; for i,c in ipairs(palette) do prepared[i]={c=c,lab=useLab and color.lab(c) or nil} end
  local cache={}
  return function(src)
    local k
    if cacheEnabled then k=color.key(src); if cache[k] then return cache[k] end end
    local best,dist=prepared[1].c,math.huge; local srcLab=useLab and color.lab(src) or nil
    for _,p in ipairs(prepared) do local d=color.distance(src,p.c,mode,srcLab,p.lab); if d<dist then best,dist=p.c,d end end
    if cacheEnabled then cache[k]=best end; return best
  end
end
local function visit(layers,fn)
  for _,layer in ipairs(layers) do
    if layer.isGroup then visit(layer.layers or {},fn) else fn(layer) end
  end
end
local function ancestryFlag(layer,key,default)
  local current=layer; local sprite=layer.sprite
  while current and current~=sprite do
    if current[key]==false then return false end
    current=current.parent
  end
  return default
end
local function supported(layer)
  if not layer.isImage or layer.isReference or layer.isTilemap or layer.isBackground then return false,'unsupported layer type' end
  if not ancestryFlag(layer,'isEditable',true) then return false,'locked layer' end
  return true
end
local function visible(layer) return ancestryFlag(layer,'isVisible',true) end
local function hasPixels(cel)
  local image=cel.image
  if image:isEmpty() then return false end
  for y=0,image.height-1 do for x=0,image.width-1 do
    if app.pixelColor.rgbaA(image:getPixel(x,y))>0 then return true end
  end end
  return false
end
function M.collectCels(sprite,scope,activeCel,activeFrame,activeLayer)
  local result,skipped={},0
  local function addLayer(layer,frameNumber,includeHidden)
    local ok=supported(layer)
    if not ok then skipped=skipped+1; return end
    if includeHidden or visible(layer) then
      if frameNumber then local c=layer:cel(frameNumber); if c and hasPixels(c) then result[#result+1]=c end
      else for _,c in ipairs(layer.cels) do if c and hasPixels(c) then result[#result+1]=c end end end
    end
  end
  if scope=='Current Cel' or scope=='Selection' then
    if not activeCel then error('Select an image cel before processing.') end
    local ok,why=supported(activeCel.layer); if not ok then error('The active layer is '..why..'.') end
    result[1]=activeCel
  elseif scope=='Current Frame' then
    local f=activeFrame and activeFrame.frameNumber or 1
    visit(sprite.layers,function(l) addLayer(l,f,false) end)
  elseif scope=='Current Layer' then
    if not activeLayer then error('Select a layer before processing.') end
    if activeLayer.isGroup then visit(activeLayer.layers or {},function(l) addLayer(l,nil,true) end) else addLayer(activeLayer,nil,true) end
  elseif scope=='All Frames' or scope=='Whole Sprite' then
    local includeHidden=scope=='Whole Sprite'
    visit(sprite.layers,function(l) addLayer(l,nil,includeHidden) end)
  else error('Unknown processing scope: '..tostring(scope)) end
  if #result==0 then error('No non-empty editable image cels were found in this scope.') end
  return result,skipped
end
function M.extractCel(cel,threshold)
  local img=cel.image; local all={}
  for y=0,img.height-1 do for x=0,img.width-1 do local c=decode(img:getPixel(x,y)); if c.a>=(threshold or 1) then all[#all+1]=c end end end
  return all
end
function M.extractCels(cels,threshold,selection)
  local all={}
  for _,cel in ipairs(cels) do local img=cel.image
    for y=0,img.height-1 do for x=0,img.width-1 do
      if not selection or selection:contains(cel.position.x+x,cel.position.y+y) then local c=decode(img:getPixel(x,y)); if c.a>=(threshold or 1) then all[#all+1]=c end end
    end end
  end
  return all
end
function M.processImage(image,cel,palette,settings,selection)
  if image.colorMode~=ColorMode.RGB then error('RGB sprites only are supported. Indexed and grayscale sprites were left unchanged.') end
  if #palette==0 then error('The selected palette is empty.') end
  local pixels={}; for y=0,image.height-1 do for x=0,image.width-1 do pixels[#pixels+1]=decode(image:getPixel(x,y)) end end
  local threshold=settings.alphaThreshold or 1
  local function eligible(x,y)
    if selection and not selection:contains(cel.position.x+x,cel.position.y+y) then return false end
    return pixels[y*image.width+x+1].a>=threshold
  end
  local cacheEnabled=(settings.dither or 'None')=='None' or (settings.amount or 0)<=0
  local map=nearest(palette,settings.distance,cacheEnabled)
  local result=dither.map(pixels,image.width,image.height,palette,settings.dither or 'None',settings.amount or 0,map,eligible,color)
  for y=0,image.height-1 do for x=0,image.width-1 do
    local i=y*image.width+x+1; local old=pixels[i]; local c=result[i]
    if eligible(x,y) and old.a>0 then c.a=settings.preserveAlpha==false and 255 or old.a; image:putPixel(x,y,encode(c)) end
  end end
end
local function selectionFor(sprite,scope)
  if scope=='Selection' then
    local selection=sprite.selection
    if not selection or selection.isEmpty then error('There is no active selection.') end
    return selection
  end
end
local function prepare(sprite,settings,activeCel,activeFrame,activeLayer,palette)
  if sprite.colorMode~=ColorMode.RGB then error('RGB sprites only are supported. Indexed and grayscale sprites were left unchanged.') end
  local cels,skipped=M.collectCels(sprite,settings.scope,activeCel,activeFrame,activeLayer)
  local selection=selectionFor(sprite,settings.scope)
  local prepared={}; for _,cel in ipairs(cels) do
    if cel.image.colorMode~=ColorMode.RGB then error('A selected cel is not RGB. No cels were changed.') end
    local copy=cel.image:clone(); M.processImage(copy,cel,palette,settings,selection)
    prepared[#prepared+1]={source=cel,image=copy}
  end
  return prepared,skipped
end
function M.captureState(sprite)
  local snapshot={sprite=sprite,cels={},images={}}
  for _,cel in ipairs(sprite.cels) do
    local id=cel.image.id
    if not snapshot.images[id] then snapshot.images[id]={image=cel.image,original=cel.image:clone()} end
    snapshot.cels[#snapshot.cels+1]={cel=cel,imageId=id}
  end
  return snapshot
end
local function copyPixels(destination,source)
  for y=0,source.height-1 do for x=0,source.width-1 do
    local pixel=source:getPixel(x,y)
    if destination:getPixel(x,y)~=pixel then destination:drawPixel(x,y,pixel) end
  end end
end
function M.restoreState(snapshot)
  for _,image in pairs(snapshot.images) do copyPixels(image.image,image.original) end
  app.refresh()
end
function M.preview(snapshot,settings,activeCel,activeFrame,activeLayer,palette)
  M.restoreState(snapshot)
  local prepared,skipped=prepare(snapshot.sprite,settings,activeCel,activeFrame,activeLayer,palette)
  for _,item in ipairs(prepared) do copyPixels(item.source.image,item.image) end
  app.refresh()
  return #prepared,skipped,prepared
end
function M.apply(sprite,settings,activeCel,activeFrame,activeLayer,palette)
  if #palette==0 then error('The selected palette is empty.') end
  if settings.output=='Duplicate Layer' then error('Duplicate Layer output is awaiting a safe one-step Undo implementation; choose Modify Existing for now.') end
  local prepared,skipped=prepare(sprite,settings,activeCel,activeFrame,activeLayer,palette)
  local savedLayer,savedFrame=app.layer,app.frame
  local savedCel=app.cel; local savedCelLayer=savedCel and savedCel.layer; local savedCelFrame=savedCel and savedCel.frameNumber
  app.transaction('Arete Palette Limiter',function()
    for _,item in ipairs(prepared) do
      local sourceLayer,frameNumber=item.source.layer,item.source.frameNumber
      local live=sourceLayer:cel(frameNumber); local imageId=live.image.id; local uses=0
      for _,cel in ipairs(sprite.cels) do if cel.image.id==imageId then uses=uses+1 end end
      if uses>1 then
        app.cel=live
        local ok=app.command.UnlinkCel()
        if ok==false then error('Aseprite could not safely unlink a shared cel image.') end
        live=sourceLayer:cel(frameNumber)
        if not live or live.image.id==imageId then error('Aseprite did not detach the linked cel; no pixels were applied.') end
      end
      live.image=item.image
    end
    if savedFrame then app.frame=savedFrame end
    if savedLayer then app.layer=savedLayer end
    if savedCelLayer and savedCelFrame then local restored=savedCelLayer:cel(savedCelFrame); if restored then app.cel=restored end end
  end)
  return #prepared,skipped
end
return M
