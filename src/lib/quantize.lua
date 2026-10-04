-- Deterministic weighted median-cut quantizer.
local M={}
local function channel(c,k) return k==1 and c.r or (k==2 and c.g or c.b) end
local function boxStats(items)
  local lo={255,255,255}; local hi={0,0,0}; local weight=0
  for _,it in ipairs(items) do weight=weight+it.n; for k=1,3 do local v=channel(it.c,k); if v<lo[k] then lo[k]=v end; if v>hi[k] then hi[k]=v end end end
  local ch=1; if hi[2]-lo[2]>hi[ch]-lo[ch] then ch=2 end; if hi[3]-lo[3]>hi[ch]-lo[ch] then ch=3 end
  return {items=items,lo=lo,hi=hi,channel=ch,weight=weight,range=hi[ch]-lo[ch]}
end
local function average(box)
  local r,g,b,n=0,0,0,0
  for _,it in ipairs(box.items) do r=r+it.c.r*it.n; g=g+it.c.g*it.n; b=b+it.c.b*it.n; n=n+it.n end
  return {r=math.floor(r/n+0.5),g=math.floor(g/n+0.5),b=math.floor(b/n+0.5),a=255}
end
function M.medianCut(histogram,target)
  local colors={}; for _,it in pairs(histogram) do if it.n>0 then colors[#colors+1]=it end end
  table.sort(colors,function(a,b) return a.c.r==b.c.r and (a.c.g==b.c.g and a.c.b<b.c.b or a.c.g<b.c.g) or a.c.r<b.c.r end)
  if #colors==0 then return {} end
  target=math.max(1,math.min(math.floor(target or 16),#colors))
  local boxes={boxStats(colors)}
  while #boxes<target do
    local best=0; local score=-1
    for i,box in ipairs(boxes) do local s=box.range*box.weight; if #box.items>1 and s>score then best=i; score=s end end
    if best==0 then break end
    local box=table.remove(boxes,best); local k=box.channel
    table.sort(box.items,function(a,b) local av,bv=channel(a.c,k),channel(b.c,k); if av~=bv then return av<bv end; if a.c.r~=b.c.r then return a.c.r<b.c.r end; if a.c.g~=b.c.g then return a.c.g<b.c.g end; return a.c.b<b.c.b end)
    local half=box.weight/2; local sum,cut=0,1
    for i,it in ipairs(box.items) do sum=sum+it.n; if sum>=half then cut=i; break end end
    if cut>=#box.items then cut=#box.items-1 end
    local left,right={},{}; for i,it in ipairs(box.items) do (i<=cut and left or right)[#(i<=cut and left or right)+1]=it end
    boxes[#boxes+1]=boxStats(left); boxes[#boxes+1]=boxStats(right)
  end
  local out={}; for _,box in ipairs(boxes) do out[#out+1]=average(box) end
  return out
end
function M.kMeans(histogram,seeds,iterations)
  if #seeds<2 then return seeds end
  local items={}; for _,it in pairs(histogram) do if it.n>0 then items[#items+1]=it end end
  table.sort(items,function(a,b) if a.c.r~=b.c.r then return a.c.r<b.c.r end; if a.c.g~=b.c.g then return a.c.g<b.c.g end; return a.c.b<b.c.b end)
  local centers={}; for i,c in ipairs(seeds) do centers[i]={r=c.r,g=c.g,b=c.b} end
  iterations=math.max(1,math.min(20,math.floor(iterations or 8)))
  for _=1,iterations do
    local sums={}; for i=1,#centers do sums[i]={r=0,g=0,b=0,n=0} end
    for _,it in ipairs(items) do
      local best,bestD=1,math.huge
      for i,c in ipairs(centers) do local dr,dg,db=it.c.r-c.r,it.c.g-c.g,it.c.b-c.b; local d=dr*dr+dg*dg+db*db; if d<bestD then best,bestD=i,d end end
      local s=sums[best]; s.r=s.r+it.c.r*it.n; s.g=s.g+it.c.g*it.n; s.b=s.b+it.c.b*it.n; s.n=s.n+it.n
    end
    local changed=false
    for i,s in ipairs(sums) do if s.n>0 then local nextC={r=math.floor(s.r/s.n+0.5),g=math.floor(s.g/s.n+0.5),b=math.floor(s.b/s.n+0.5)}; if nextC.r~=centers[i].r or nextC.g~=centers[i].g or nextC.b~=centers[i].b then changed=true end; centers[i]=nextC end end
    if not changed then break end
  end
  local out,seen={},{}
  for _,c in ipairs(centers) do local k=c.r..':'..c.g..':'..c.b; if not seen[k] then seen[k]=true; out[#out+1]={r=c.r,g=c.g,b=c.b,a=255} end end
  return out
end
return M
