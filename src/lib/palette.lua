local quantize=require("src.lib.quantize")
local M={}
function M.fromSprite(sprite,frameNo)
  local p=sprite.palettes and sprite.palettes[1] or nil
  if not p then return {} end
  local out={}
  for i=0,#p-1 do local c=p:getColor(i); if c and c.alpha>0 then out[#out+1]={r=c.red,g=c.green,b=c.blue,a=255} end end
  return out
end
function M.histogram(pixels,threshold)
  local h={},{}
  for _,c in ipairs(pixels) do if c.a>=(threshold or 1) then local k=c.r..":"..c.g..":"..c.b; if h[k] then h[k].n=h[k].n+1 else h[k]={c={r=c.r,g=c.g,b=c.b,a=255},n=1} end end end
  return h
end
function M.generate(pixels,count,threshold,mode)
  local histogram=M.histogram(pixels,threshold); local seeds=quantize.medianCut(histogram,count)
  if mode=='Median Cut + K-Means' then return quantize.kMeans(histogram,seeds,8) end
  return seeds
end
function M.sanitize(colors)
  local out,seen={},{}
  for _,c in ipairs(colors or {}) do local r,g,b=math.floor(c.r or 0),math.floor(c.g or 0),math.floor(c.b or 0); local k=r..":"..g..":"..b
    if not seen[k] then seen[k]=true; out[#out+1]={r=r,g=g,b=b,a=255} end
  end
  return out
end
return M
