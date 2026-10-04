-- Pure color math. Colors are {r=0..255,g=0..255,b=0..255,a=0..255}.
local M = {}
local function linear(v) v=v/255; if v<=0.04045 then return v/12.92 end; return ((v+0.055)/1.055)^2.4 end
function M.lab(c)
  local r,g,b=linear(c.r),linear(c.g),linear(c.b)
  local x=(r*0.4124564+g*0.3575761+b*0.1804375)/0.95047
  local y=(r*0.2126729+g*0.7151522+b*0.0721750)
  local z=(r*0.0193339+g*0.1191920+b*0.9503041)/1.08883
  local function f(t) if t>0.008856451679 then return t^(1/3) end; return 7.787037*t+16/116 end
  x,y,z=f(x),f(y),f(z)
  return {l=116*y-16,a=500*(x-y),b=200*(y-z)}
end
function M.distance(a,b,mode,alab,blab)
  local r,g,bl=a.r-b.r,a.g-b.g,a.b-b.b
  if mode=="Weighted RGB" then return 0.299*r*r+0.587*g*g+0.114*bl*bl end
  if mode=="RGB Euclidean" then return r*r+g*g+bl*bl end
  alab=alab or M.lab(a); blab=blab or M.lab(b)
  if mode=='CIEDE2000' then return M.ciede2000(alab,blab) end
  local dl,da,db=alab.l-blab.l,alab.a-blab.a,alab.b-blab.b
  return dl*dl+da*da+db*db
end
local function atan2(y,x)
  if math.atan2 then return math.atan2(y,x) end
  if x>0 then return math.atan(y/x) elseif x<0 and y>=0 then return math.atan(y/x)+math.pi
  elseif x<0 then return math.atan(y/x)-math.pi elseif y>0 then return math.pi/2
  elseif y<0 then return -math.pi/2 else return 0 end
end
local function cosd(x) return math.cos(x*math.pi/180) end
local function sind(x) return math.sin(x*math.pi/180) end
local function hue(a,b)
  if a==0 and b==0 then return 0 end
  local h=atan2(b,a)*180/math.pi; return h<0 and h+360 or h
end
function M.ciede2000(one,two)
  local l1,a1,b1=one.l,one.a,one.b; local l2,a2,b2=two.l,two.a,two.b
  local c1,c2=math.sqrt(a1*a1+b1*b1),math.sqrt(a2*a2+b2*b2); local cbar=(c1+c2)/2
  local cbar7=cbar^7; local g=0.5*(1-math.sqrt(cbar7/(cbar7+25^7)))
  local ap1,ap2=(1+g)*a1,(1+g)*a2; local cp1,cp2=math.sqrt(ap1*ap1+b1*b1),math.sqrt(ap2*ap2+b2*b2)
  local hp1,hp2=hue(ap1,b1),hue(ap2,b2)
  local dl=l2-l1; local dc=cp2-cp1; local dh=0
  if cp1*cp2~=0 then
    local delta=hp2-hp1
    if math.abs(delta)<=180 then dh=delta elseif delta>180 then dh=delta-360 else dh=delta+360 end
  end
  local dH=2*math.sqrt(cp1*cp2)*sind(dh/2); local lbar=(l1+l2)/2; local cpbar=(cp1+cp2)/2
  local hbar
  if cp1*cp2==0 then hbar=hp1+hp2
  elseif math.abs(hp1-hp2)<=180 then hbar=(hp1+hp2)/2
  elseif hp1+hp2<360 then hbar=(hp1+hp2+360)/2 else hbar=(hp1+hp2-360)/2 end
  local t=1-0.17*cosd(hbar-30)+0.24*cosd(2*hbar)+0.32*cosd(3*hbar+6)-0.20*cosd(4*hbar-63)
  local lm=lbar-50; local sl=1+0.015*lm*lm/math.sqrt(20+lm*lm); local sc=1+0.045*cpbar; local sh=1+0.015*cpbar*t
  local dtheta=30*math.exp(-((hbar-275)/25)^2); local cp7=cpbar^7; local rc=2*math.sqrt(cp7/(cp7+25^7)); local rt=-sind(2*dtheta)*rc
  local x,y,z=dl/sl,dc/sc,dH/sh
  return math.sqrt(x*x+y*y+z*z+rt*y*z)
end
function M.key(c) return c.r..":"..c.g..":"..c.b end
function M.clamp(v) if v<0 then return 0 elseif v>255 then return 255 else return math.floor(v+0.5) end end
return M
