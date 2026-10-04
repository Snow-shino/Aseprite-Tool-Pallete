-- Versioned persistent preset storage (Aseprite 1.3+ json + filesystem API).
local M={}
M.VERSION=1
local function path()
  local dir=app.fs.joinPath(app.fs.userConfigPath,'AretePaletteLimiter')
  app.fs.makeAllDirectories(dir)
  return app.fs.joinPath(dir,'presets.json')
end
local function validName(name)
  return type(name)=='string' and #name>0 and #name<=64 and not name:match('^%s*$')
end
local function object(value) local t=type(value); return t=='table' or t=='userdata' end
local function normalize(data)
  if not object(data) or data.version~=M.VERSION or not object(data.presets) then return {version=M.VERSION,presets={}} end
  local out={version=M.VERSION,presets={}}
  for name,p in pairs(data.presets) do
    if validName(name) and object(p) and type(p.source)=='string' and object(p.settings) then
      local s=p.settings
      if (p.source=='Current Sprite Palette' or p.source=='Generate From Artwork') and
        (s.distance=='CIE76 (Lab)' or s.distance=='CIEDE2000' or s.distance=='Weighted RGB' or s.distance=='RGB Euclidean') and
        (s.dither=='None' or s.dither=='Bayer 2x2' or s.dither=='Bayer 4x4' or s.dither=='Bayer 8x8' or s.dither=='Floyd-Steinberg' or s.dither=='Atkinson') and
        (s.scope=='Current Cel' or s.scope=='Selection' or s.scope=='Current Frame' or s.scope=='Current Layer' or s.scope=='All Frames' or s.scope=='Whole Sprite') and
        (s.output=='Duplicate Layer' or s.output=='Modify Existing') then
        local n={source=p.source,settings={distance=s.distance,quantize=s.quantize=='Median Cut + K-Means' and s.quantize or 'Median Cut',dither=s.dither,amount=math.max(0,math.min(100,tonumber(s.amount) or 100)),alphaThreshold=math.max(1,math.min(255,tonumber(s.alphaThreshold) or 1)),preserveAlpha=s.preserveAlpha~=false,scope=s.scope,output=s.output},colors=math.max(2,math.min(256,math.floor(tonumber(s.colors) or 16)))}
        local paletteData=p.palette
        if object(paletteData) then n.palette={}; for _,c in ipairs(paletteData) do if object(c) and tonumber(c.r) and tonumber(c.g) and tonumber(c.b) then n.palette[#n.palette+1]={r=math.max(0,math.min(255,math.floor(c.r))),g=math.max(0,math.min(255,math.floor(c.g))),b=math.max(0,math.min(255,math.floor(c.b))),a=255} end end end
        out.presets[name]=n
      end
    end
  end
  return out
end
function M.load()
  local f=io.open(path(),'rb'); if not f then return {version=M.VERSION,presets={}} end
  local raw=f:read('*a'); f:close()
  local ok,result=pcall(json.decode,raw); if not ok then return {version=M.VERSION,presets={}} end
  return normalize(result)
end
local function write(data)
  local fn=path(); local tmp=fn..'.tmp'; local f,err=io.open(tmp,'wb'); if not f then error('Cannot write preset file: '..tostring(err)) end
  f:write(json.encode(data)); f:close()
  local backup=fn..'.bak'; os.remove(backup)
  local hadOriginal=app.fs.isFile(fn)
  if hadOriginal then local moved,moveErr=os.rename(fn,backup); if not moved then os.remove(tmp); error('Cannot stage existing preset file: '..tostring(moveErr)) end end
  local ok,renameErr=os.rename(tmp,fn)
  if not ok then if hadOriginal then os.rename(backup,fn) end; os.remove(tmp); error('Cannot replace preset file: '..tostring(renameErr)) end
  if hadOriginal then os.remove(backup) end
end
function M.names()
  local out={}; for name in pairs(M.load().presets) do out[#out+1]=name end; table.sort(out); return out
end
function M.get(name) return M.load().presets[name] end
function M.save(name,preset)
  if not validName(name) then error('Preset names must contain 1 to 64 non-space characters.') end
  local data=M.load(); data.presets[name]={source=preset.source,settings=preset.settings,palette=preset.palette}
  local clean=normalize({version=M.VERSION,presets={[name]=data.presets[name]}})
  if not clean.presets[name] then error('Preset settings are invalid.') end
  data.presets[name]=clean.presets[name]; write(data); return name
end
function M.delete(name)
  local data=M.load(); if not data.presets[name] then return false end; data.presets[name]=nil; write(data); return true
end
return M
