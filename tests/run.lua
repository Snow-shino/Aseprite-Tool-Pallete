-- Batch acceptance tests for Aseprite 1.3+. Run from repository root:
-- Aseprite.exe --batch --script tests/run.lua
package.path='./?.lua;./?/init.lua;'..package.path
local color=require('src.lib.color')
local quantize=require('src.lib.quantize')
local palette=require('src.lib.palette')
local dither=require('src.lib.dither')
local apply=require('src.lib.apply')
local presets=require('src.lib.presets')
local function eq(a,b,msg) assert(a==b,(msg or 'mismatch')..': '..tostring(a)..' ~= '..tostring(b)) end
local function near(a,b,eps,msg) assert(math.abs(a-b)<=eps,(msg or 'outside tolerance')..': '..a..' ~= '..b) end

-- CIE Lab reference values (D65, 2 degree observer).
local black=color.lab{r=0,g=0,b=0}; near(black.l,0,0.01,'black L'); near(black.a,0,0.01,'black a'); near(black.b,0,0.01,'black b')
local white=color.lab{r=255,g=255,b=255}; near(white.l,100,0.02,'white L'); near(white.a,0,0.02,'white a'); near(white.b,0,0.02,'white b')
local red=color.lab{r=255,g=0,b=0}; near(red.l,53.2408,0.03,'red L'); near(red.a,80.0925,0.03,'red a'); near(red.b,67.2032,0.03,'red b')
eq(color.distance({r=5,g=6,b=7},{r=5,g=6,b=7},'CIE76 (Lab)'),0,'identical color distance')
local de=color.ciede2000({l=50,a=2.6772,b=-79.7751},{l=50,a=0,b=-82.7485}); near(de,2.0425,0.0002,'CIEDE2000 reference pair')

-- Deterministic reduction, threshold filtering, and no needless colors.
local pixels={{r=0,g=0,b=0,a=255},{r=10,g=0,b=0,a=255},{r=255,g=255,b=255,a=255},{r=7,g=8,b=9,a=0}}
local g1=palette.generate(pixels,2,1); local g2=palette.generate(pixels,2,1)
eq(#g1,2,'requested median-cut count'); eq(json.encode(g1),json.encode(g2),'deterministic palette')
eq(#palette.generate({pixels[1],pixels[1],pixels[4]},16,1),1,'fewer colors than target')
local hist=palette.histogram(pixels,1); eq(hist['7:8:9'],nil,'transparent color excluded')
local k1=palette.generate(pixels,2,1,'Median Cut + K-Means'); local k2=palette.generate(pixels,2,1,'Median Cut + K-Means')
eq(json.encode(k1),json.encode(k2),'k-means deterministic'); eq(#k1,2,'k-means preserves target count')

-- Dither modes are deterministic, stay in bounds, and never diffuse through transparent pixels.
local dest={{r=0,g=0,b=0,a=255},{r=255,g=255,b=255,a=255}}
local matcher=function(c) return c.r<128 and dest[1] or dest[2] end
-- Exercise pure deterministic palette remapping (including transparent sentinel preservation).
local src={{r=0,g=0,b=0,a=255},{r=255,g=255,b=255,a=255},{r=100,g=100,b=100,a=255}}
local m1=dither.map(src,3,1,dest,'Bayer 4x4',100,matcher,nil,color)
local m2=dither.map(src,3,1,dest,'Bayer 4x4',100,matcher,nil,color)
eq(json.encode(m1),json.encode(m2),'ordered dither deterministic')
local none=dither.map(src,3,1,dest,'Floyd-Steinberg',0,matcher,nil,color)
local plain=dither.map(src,3,1,dest,'None',100,matcher,nil,color)
eq(json.encode(none),json.encode(plain),'zero dither equals no dither')
local bayer8a=dither.map(src,3,1,dest,'Bayer 8x8',75,matcher,nil,color)
local bayer8b=dither.map(src,3,1,dest,'Bayer 8x8',75,matcher,nil,color)
eq(json.encode(bayer8a),json.encode(bayer8b),'8x8 ordered dither deterministic')
local transparentSrc={{r=255,g=0,b=0,a=0},{r=100,g=100,b=100,a=255}}
local noLeak=dither.map(transparentSrc,2,1,dest,'Floyd-Steinberg',100,matcher,nil,color)
local isolated=dither.map({transparentSrc[2]},1,1,dest,'Floyd-Steinberg',100,matcher,nil,color)
eq(noLeak[2].r,isolated[1].r,'transparent pixel does not seed diffusion')

-- Aseprite integration: pixel colors, scopes, linked-cel detachment, duplication, and undo.
local sprite=Sprite(4,1,ColorMode.RGB); local layer=sprite:newLayer(); layer.name='Artwork'
local image=Image(4,1,ColorMode.RGB)
image:putPixel(0,0,app.pixelColor.rgba(255,0,0,255)); image:putPixel(1,0,app.pixelColor.rgba(0,0,255,255))
image:putPixel(2,0,app.pixelColor.rgba(0,255,0,255)); image:putPixel(3,0,app.pixelColor.rgba(12,34,56,0))
local cel1=sprite:newCel(layer,1,image,Point(0,0)); sprite:newFrame(1); local cel2=sprite:newCel(layer,2,cel1.image,Point(0,0))
app.range.layers={layer}; app.range.frames={1,2}; app.command.LinkCels(); app.range:clear()
cel1=layer:cel(1); cel2=layer:cel(2)
eq(cel1.image.id,cel2.image.id,'fixture uses linked cels')
local blackPalette={{r=0,g=0,b=0,a=255}}
local settings={distance='RGB Euclidean',dither='None',amount=100,preserveAlpha=true,alphaThreshold=1,scope='Current Cel',output='Modify Existing'}
eq(cel1.image:getPixel(0,0),app.pixelColor.rgba(255,0,0,255),'source fixture')
local linkedSnapshot=apply.captureState(sprite); local linkedUndo=sprite.undoHistory.undoSteps
apply.preview(linkedSnapshot,settings,cel1,sprite.frames[1],layer,blackPalette)
eq(cel1.image:getPixel(0,0),app.pixelColor.rgba(0,0,0,255),'linked cel preview appears on sprite')
eq(cel1.image.id,cel2.image.id,'live preview preserves linked image identity')
eq(sprite.undoHistory.undoSteps,linkedUndo,'linked live preview leaves undo history unchanged')
apply.restoreState(linkedSnapshot)
eq(cel1.image:getPixel(0,0),app.pixelColor.rgba(255,0,0,255),'linked live preview restores source pixels')
eq(cel1.image.id,cel2.image.id,'live preview restoration preserves links')
local undoBefore=sprite.undoHistory.undoSteps
local count=apply.apply(sprite,settings,cel1,sprite.frames[1],layer,blackPalette); eq(count,1,'current cel scope count')
cel1=layer:cel(1); cel2=layer:cel(2)
eq(cel1.image:getPixel(0,0),app.pixelColor.rgba(0,0,0,255),'nearest black mapping')
eq(cel1.image:getPixel(3,0),app.pixelColor.rgba(12,34,56,0),'transparent bytes preserved')
eq(cel2.image:getPixel(0,0),app.pixelColor.rgba(255,0,0,255),'linked frame not modified')
assert(cel1.image.id~=cel2.image.id,'selected linked cel detaches from other frame')
eq(sprite.undoHistory.undoSteps,undoBefore+1,'one transaction step')
app.undo(); cel1=layer:cel(1); cel2=layer:cel(2); eq(cel1.image:getPixel(0,0),app.pixelColor.rgba(255,0,0,255),'undo restores source')
eq(cel1.image.id,cel2.image.id,'undo restores linked-cel relation')

-- Selection touches only selected coordinates.
sprite.selection:select(Rectangle(1,0,1,1)); settings.scope='Selection'
apply.apply(sprite,settings,cel1,sprite.frames[1],layer,blackPalette)
eq(cel1.image:getPixel(0,0),app.pixelColor.rgba(255,0,0,255),'selection leaves outside unchanged')
eq(cel1.image:getPixel(1,0),app.pixelColor.rgba(0,0,0,255),'selection processes inside')
app.undo(); sprite.selection:deselect()

-- Frame and layer scopes select only their documented cels.
settings.scope='Current Frame'
local frameCount=apply.apply(sprite,settings,cel1,sprite.frames[1],layer,blackPalette); eq(frameCount,1,'current frame scope count')
eq(cel2.image:getPixel(0,0),app.pixelColor.rgba(255,0,0,255),'current frame leaves other frame unchanged'); app.undo()
settings.scope='Current Layer'
local layerCount=apply.apply(sprite,settings,cel1,sprite.frames[1],layer,blackPalette); eq(layerCount,2,'current layer scope count'); app.undo()

-- All Frames processing groups edits in one transaction and safely detaches linked images.
settings.scope='All Frames'; settings.output='Modify Existing'
local before1=cel1.image:getPixel(0,0); local before2=cel2.image:getPixel(0,0)
local originalWidth,originalHeight=sprite.width,sprite.height
local multiBefore=sprite.undoHistory.undoSteps
local count,skipped=apply.apply(sprite,settings,cel1,sprite.frames[1],layer,blackPalette)
eq(count,2,'all frames cels processed'); eq(skipped,0,'no unsupported layers skipped')
eq(cel1.image:getPixel(0,0),app.pixelColor.rgba(0,0,0,255),'frame one processed')
eq(cel2.image:getPixel(0,0),app.pixelColor.rgba(0,0,0,255),'linked frame processed independently')
eq(sprite.width,originalWidth,'canvas width unchanged'); eq(sprite.height,originalHeight,'canvas height unchanged')
eq(sprite.undoHistory.undoSteps,multiBefore+1,'multi-cel transaction is one step')
app.undo(); eq(cel1.image:getPixel(0,0),before1,'multi-frame undo restores frame one'); eq(cel2.image:getPixel(0,0),before2,'multi-frame undo restores frame two')

-- Hidden image layers participate only in Whole Sprite; locked layers are always skipped.
local hidden=sprite:newLayer(); hidden.name='Hidden'; hidden.isVisible=false
local hiddenImage=Image(1,1,ColorMode.RGB); hiddenImage:putPixel(0,0,app.pixelColor.rgba(50,60,70,255)); sprite:newCel(hidden,1,hiddenImage,Point(0,0))
local locked=sprite:newLayer(); locked.name='Locked'; locked.isEditable=false
local lockedImage=Image(1,1,ColorMode.RGB); lockedImage:putPixel(0,0,app.pixelColor.rgba(80,90,100,255)); sprite:newCel(locked,1,lockedImage,Point(0,0))
settings.scope='Current Frame'; local visibleCount,visibleSkipped=apply.apply(sprite,settings,cel1,sprite.frames[1],layer,blackPalette); eq(visibleCount,1,'current frame ignores hidden/locked'); app.undo()
settings.scope='Whole Sprite'; local wholeCount,wholeSkipped=apply.apply(sprite,settings,cel1,sprite.frames[1],layer,blackPalette); eq(wholeCount,3,'whole sprite includes hidden layer'); eq(wholeSkipped,1,'whole sprite skips locked layer'); app.undo()

-- Unsafe duplicate output is rejected without creating partial layers/history.
settings.output='Duplicate Layer'
local layersBefore,celsBefore,historyBefore=#sprite.layers,#sprite.cels,sprite.undoHistory.undoSteps
local duplicateOk=pcall(function() apply.apply(sprite,settings,cel1,sprite.frames[1],layer,blackPalette) end)
eq(duplicateOk,false,'unsafe duplicate output rejected')
eq(#sprite.layers,layersBefore,'rejected duplication creates no layer'); eq(#sprite.cels,celsBefore,'rejected duplication creates no cels'); eq(sprite.undoHistory.undoSteps,historyBefore,'rejected duplication adds no history')

-- Pixels below the alpha threshold remain byte-identical.
local faint=Image(1,1,ColorMode.RGB); faint:putPixel(0,0,app.pixelColor.rgba(255,0,0,3))
local faintCel={image=faint,position=Point(0,0)}; settings.alphaThreshold=4; settings.output='Modify Existing'
apply.processImage(faint,faintCel,blackPalette,settings,nil); eq(faint:getPixel(0,0),app.pixelColor.rgba(255,0,0,3),'below-threshold alpha pixel is preserved')

-- Live preview always starts from the captured original and never creates undo history.
local liveSprite=Sprite(1,1,ColorMode.RGB); local liveLayer=liveSprite:newLayer(); local liveImage=Image(1,1,ColorMode.RGB)
liveImage:putPixel(0,0,app.pixelColor.rgba(100,100,100,255)); local liveCel=liveSprite:newCel(liveLayer,1,liveImage,Point(0,0))
local liveState=apply.captureState(liveSprite); local liveUndo=liveSprite.undoHistory.undoSteps; local liveRedo=liveSprite.undoHistory.redoSteps
local liveSettings={distance='RGB Euclidean',dither='None',amount=0,preserveAlpha=true,alphaThreshold=1,scope='Current Cel',output='Modify Existing'}
apply.preview(liveState,liveSettings,liveCel,liveSprite.frames[1],liveLayer,{{r=200,g=200,b=200,a=255}})
eq(liveCel.image:getPixel(0,0),app.pixelColor.rgba(200,200,200,255),'first live preview applied')
local _,_,secondPreview=apply.preview(liveState,liveSettings,liveCel,liveSprite.frames[1],liveLayer,{{r=0,g=0,b=0,a=255},{r=200,g=200,b=200,a=255}})
eq(secondPreview[1].image:getPixel(0,0),app.pixelColor.rgba(0,0,0,255),'second preview starts from original pixels')
eq(liveCel.image:getPixel(0,0),app.pixelColor.rgba(0,0,0,255),'sprite preview does not accumulate prior result')
eq(liveSprite.undoHistory.undoSteps,liveUndo,'live preview does not add undo history')
eq(liveSprite.undoHistory.redoSteps,liveRedo,'live preview does not alter redo history')
apply.restoreState(liveState); eq(liveCel.image:getPixel(0,0),app.pixelColor.rgba(100,100,100,255),'restore returns exact source pixel')
assert(liveCel.image:isEqual(liveState.images[liveCel.image.id].original),'cancel snapshot restores byte-identical image')
eq(liveSprite.undoHistory.undoSteps,liveUndo,'restore does not add undo history')
eq(liveSprite.undoHistory.redoSteps,liveRedo,'restore does not alter redo history')
apply.preview(liveState,liveSettings,liveCel,liveSprite.frames[1],liveLayer,{{r=0,g=0,b=0,a=255},{r=200,g=200,b=200,a=255}})
apply.restoreState(liveState)
apply.apply(liveSprite,liveSettings,liveCel,liveSprite.frames[1],liveLayer,{{r=0,g=0,b=0,a=255},{r=200,g=200,b=200,a=255}})
eq(liveSprite.undoHistory.undoSteps,liveUndo+1,'apply after preview is one undo step')
eq(liveCel.image:getPixel(0,0),app.pixelColor.rgba(0,0,0,255),'apply commits preview result')
app.undo(); eq(liveCel.image:getPixel(0,0),app.pixelColor.rgba(100,100,100,255),'one undo restores original after preview apply')

-- Preview image computation uses a detached clone and leaves the source byte-identical.
settings.scope='Current Cel'; settings.output='Modify Existing'
local originalPixel=cel1.image:getPixel(0,0); local originalCels=#sprite.cels
local preview=cel1.image:clone(); apply.processImage(preview,cel1,blackPalette,settings,nil)
eq(cel1.image:getPixel(0,0),originalPixel,'preview leaves original image unchanged')
eq(#sprite.cels,originalCels,'preview adds no original cels')
eq(preview.width,sprite.width,'preview dimensions unchanged')

-- Invalid modes are rejected safely.
local indexed=Sprite(1,1,ColorMode.INDEXED)
local ok=pcall(function() apply.processImage(Image(1,1,ColorMode.INDEXED),{position=Point(0,0)},blackPalette,settings) end)
eq(ok,false,'indexed processing rejected')
assert(type(presets.names())=='table','preset listing API available')
local presetName='__AreteAcceptanceTemporary__'
presets.save(presetName,{source='Generate From Artwork',settings={distance='CIE76 (Lab)',dither='Atkinson',amount=50,alphaThreshold=8,preserveAlpha=true,scope='All Frames',output='Modify Existing',colors=16},palette={{r=20,g=30,b=40,a=255}}})
local saved=presets.get(presetName); eq(saved.source,'Generate From Artwork','preset source persists'); eq(saved.settings.amount,50,'preset settings persist'); eq(saved.palette[1].r,20,'preset palette persists')
eq(saved.settings.distance,'CIE76 (Lab)','preset distance persists'); eq(saved.settings.dither,'Atkinson','preset dither persists')
presets.save(presetName,{source='Generate From Artwork',settings={distance='CIEDE2000',quantize='Median Cut + K-Means',dither='Atkinson',amount=50,alphaThreshold=8,preserveAlpha=true,scope='All Frames',output='Modify Existing',colors=16},palette={{r=20,g=30,b=40,a=255}}})
saved=presets.get(presetName); eq(saved.settings.distance,'CIEDE2000','preset overwrite updates distance'); eq(saved.settings.quantize,'Median Cut + K-Means','preset quantizer persists')
eq(presets.get(presetName).palette[1].b,40,'palette survives subsequent serialization'); presets.delete(presetName); eq(presets.get(presetName),nil,'preset deletion')
-- Empty active frames report a useful error; all-frame scope still ignores them.
sprite:newEmptyFrame(3)
settings.scope='Current Frame'
local emptyFrameOk=pcall(function() apply.apply(sprite,settings,nil,sprite.frames[3],layer,blackPalette) end)
eq(emptyFrameOk,false,'empty current frame is rejected without mutation')
settings.scope='All Frames'
local nonEmptyCount=apply.apply(sprite,settings,cel1,sprite.frames[1],layer,blackPalette); eq(nonEmptyCount,2,'all frames ignores empty frames'); app.undo()

require('src.ui')
dofile('src/main.lua')
local registeredCommand
init({newCommand=function(_,command) registeredCommand=command end})
eq(registeredCommand.id,'AretePaletteLimiter','native command id')
eq(registeredCommand.title,'Arete Palette Limiter','native command title')
eq(registeredCommand.group,'sprite_crop','native Sprite menu group')
assert(registeredCommand.onenabled(),'command enabled with an open sprite')
assert(type(registeredCommand.onclick)=='function','command launches limiter dialog')
local installedCommand=app.command.AretePaletteLimiter
if installedCommand then
  assert(installedCommand.enabled==(app.sprite~=nil),'installed command enablement follows sprite availability')
  local dispatched=pcall(function() installedCommand() end)
  assert(dispatched,'installed command dispatches through Aseprite')
end
