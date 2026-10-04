local M={}
local b2={{0,2},{3,1}}
local b4={{0,8,2,10},{12,4,14,6},{3,11,1,9},{15,7,13,5}}
local b8={}; for y=1,8 do b8[y]={}; for x=1,8 do
  local v=b4[(y-1)%4+1][(x-1)%4+1]*4
  if y>4 then v=v+2 end; if (x-1)%4>=2 then v=v+1 end; b8[y][x]=v
end end
local matrices={['Bayer 2x2']=b2,['Bayer 4x4']=b4,['Bayer 8x8']=b8}
function M.ordered(c,palette,mode,amount,x,y,color)
  if amount<=0 or not matrices[mode] then return nil end
  local mat=matrices[mode]; local n=#mat; local threshold=((mat[y%n+1][x%n+1]+0.5)/(n*n)-0.5)*(amount/100)*96
  return {r=color.clamp(c.r+threshold),g=color.clamp(c.g+threshold),b=color.clamp(c.b+threshold),a=c.a}
end
function M.map(pixels,w,h,palette,mode,amount,matcher,eligible,colorUtil)
  local out={}; for i,c in ipairs(pixels) do out[i]=c end
  if amount<=0 or (mode~='Floyd-Steinberg' and mode~='Atkinson') then
    for y=0,h-1 do for x=0,w-1 do local i=y*w+x+1; if not eligible or eligible(x,y) then local c=out[i]; local adjusted=M.ordered(c,palette,mode,amount,x,y,colorUtil); out[i]=matcher(adjusted or c) end end end
    return out
  end
  local buf={}; for i,c in ipairs(pixels) do buf[i]={r=c.r,g=c.g,b=c.b,a=c.a} end
  local fs={{1,0,7/16},{-1,1,3/16},{0,1,5/16},{1,1,1/16}}
  local at={{1,0,1/8},{2,0,1/8},{-1,1,1/8},{0,1,1/8},{1,1,1/8},{0,2,1/8}}
  local weights=mode=='Atkinson' and at or fs; local scale=amount/100
  for y=0,h-1 do for x=0,w-1 do local i=y*w+x+1; local c=buf[i]
    if (not eligible or eligible(x,y)) and c.a>0 then local mapped=matcher(c); out[i]=mapped
      for _,d in ipairs(weights) do local nx,ny=x+d[1],y+d[2]; if nx>=0 and nx<w and ny<h then local ni=ny*w+nx+1; local target=buf[ni]
        if (not eligible or eligible(nx,ny)) and target.a>0 then local factor=d[3]*scale; target.r=colorUtil.clamp(target.r+(c.r-mapped.r)*factor); target.g=colorUtil.clamp(target.g+(c.g-mapped.g)*factor); target.b=colorUtil.clamp(target.b+(c.b-mapped.b)*factor) end
      end end
    else out[i]=c end
  end end
  return out
end
return M
