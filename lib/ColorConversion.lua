local function parseInt(x) return math.floor(x) end
local function parseFloat(f) return f end

local GamutRanges = {
  A = { red = {0.704, 0.296}, green = {0.2151, 0.7106}, blue = {0.138, 0.08} },
  B = { red = {0.675, 0.322}, green = {0.409, 0.518},   blue = {0.167, 0.04} },
  C = { red = {0.692, 0.308}, green = {0.17, 0.7},      blue = {0.153, 0.048} },
  D = { red = {1.0, 0},       green = {0.0, 1.0},       blue = {0.0, 0.0} } 
}

local function xyIsInGamutRange(xy, gamut)
  gamut = GamutRanges[gamut] or GamutRanges.C
  if xy[1] then
    xy = { x = xy[1], y = xy[2] }
  end

  local v0 = {gamut.blue[1] - gamut.red[1], gamut.blue[2] - gamut.red[2]}
  local v1 = {gamut.green[1] - gamut.red[1], gamut.green[2] - gamut.red[2]}
  local v2 = {xy.x - gamut.red[1], xy.y - gamut.red[2]}

  local dot00 = (v0[1] * v0[1]) + (v0[2] * v0[2])
  local dot01 = (v0[1] * v1[1]) + (v0[2] * v1[2])
  local dot02 = (v0[1] * v2[1]) + (v0[2] * v2[2])
  local dot11 = (v1[1] * v1[1]) + (v1[2] * v1[2])
  local dot12 = (v1[1] * v2[1]) + (v1[2] * v2[2])

  local invDenom = 1 / (dot00 * dot11 - dot01 * dot01)

  local u = (dot11 * dot02 - dot01 * dot12) * invDenom
  local v = (dot00 * dot12 - dot01 * dot02) * invDenom

  return ((u >= 0) and (v >= 0) and (u + v < 1));
end

local function getClosestColor(xy, gamut)

  local function getLineDistance(pointA,pointB)
    return math.sqrt(math.pow(pointB.x - pointA.x,2), math.pow(pointB.y - pointA.y,2))
  end

  local function getClosestPoint(xy, pointA, pointB) 
    local xy2a = {xy.x - pointA.x, xy.y - pointA.y}
    local a2b = {pointB.x - pointA.x, pointB.y - pointA.y}
    local a2bSqr = math.pow(a2b[1],2) + math.pow(a2b[2],2)
    local xy2a_dot_a2b = xy2a[1] * a2b[1] + xy2a[2] * a2b[2]
    local t = xy2a_dot_a2b /a2bSqr

    return { x = pointA.x + a2b[1] * t, y = pointA.y + a2b[2] * t }
  end

  local greenBlue = {
    a = { x = gamut.green[1], y = gamut.green[2] },
    b = { x = gamut.blue[1],  y = gamut.blue[2] }
  }
  local greenRed = {
    a = { x = gamut.green[1], y = gamut.green[2] },
    b = { x = gamut.red[1],   y = gamut.red[2] }
  }
  local blueRed = {
    a = { x = gamut.red[1],   y = gamut.red[2] },
    b = { x = gamut.blue[1],  y = gamut.blue[2] }
  }

  local closestColorPoints = {
    greenBlue = getClosestPoint(xy,greenBlue.a,greenBlue.b),
    greenRed = getClosestPoint(xy,greenRed.a,greenRed.b),
    blueRed = getClosestPoint(xy,blueRed.a,blueRed.b)
  }

  local distance = {
    greenBlue = getLineDistance(xy,closestColorPoints.greenBlue),
    greenRed = getLineDistance(xy,closestColorPoints.greenRed),
    blueRed = getLineDistance(xy,closestColorPoints.blueRed)
  };

  local closestDistance,closestColor
  for p,_ in pairs(distance) do
    if closestDistance == nil then
      closestDistance = distance[p]
      closestColor = p
    end
    if closestDistance > distance[p] then
      closestDistance = distance[p]
      closestColor = p
    end
  end
  return  closestColorPoints[closestColor]
end

local function rgb2xy(red, green, blue, gamut)
  local function getGammaCorrectedValue(value)
    return (value > 0.04045) and math.pow((value + 0.055) / (1.0 + 0.055), 2.4) or (value / 12.92)
  end
  local colorGamut = GamutRanges[gamut]

  red = getGammaCorrectedValue(parseFloat(red / 255))
  green = getGammaCorrectedValue(parseFloat(green / 255))
  blue = getGammaCorrectedValue(parseFloat(blue / 255))

  local x = red * 0.649926 + green * 0.103455 + blue * 0.197109
  local y = red * 0.234327 + green * 0.743075 + blue * 0.022598
  local z = red * 0.0000000 + green * 0.053077 + blue * 1.035763

  local xy = { x = x / (x + y + z), y = y / (x + y + z) }

  if not xyIsInGamutRange(xy, colorGamut) then
    xy = getClosestColor(xy, colorGamut)
  end

  return xy;
end

local function xyb2rgb(x,y,bri)
  local function getReversedGammaCorrectedValue(value)
    return value <= 0.0031308 and 12.92 * value or (1.0 + 0.055) * math.pow(value, (1.0 / 2.4)) - 0.055
  end

  local xy = { x = x, y = y }

  local z = 1.0 - xy.x - xy.y
  local Y = bri / 255
  local X = (Y / xy.y) * xy.x
  local Z = (Y / xy.y) * z
  local r = X * 1.656492 - Y * 0.354851 - Z * 0.255038
  local g = -X * 0.707196 + Y * 1.655397 + Z * 0.036152
  local b =  X * 0.051713 - Y * 0.121364 + Z * 1.011530

  r = getReversedGammaCorrectedValue(r)
  g = getReversedGammaCorrectedValue(g)
  b = getReversedGammaCorrectedValue(b)

  local red = parseInt(r * 255) > 255 and 255 or parseInt(r * 255)
  local green = parseInt(g * 255) > 255 and 255 or parseInt(g * 255)
  local blue = parseInt(b * 255) > 255 and 255 or parseInt(b * 255)

  return {r = math.abs(red), g = math.abs(green), b = math.abs(blue)}
end

local function round(x) return math.floor(x+0.5) end

local function hsb2rgb(hue,saturation,brightness) --0-65535,0-255,0-255
  if saturation == 0 then return {r=brightness, g=brightness, b=brightness} end
  hue        = 360*hue/65535
  saturation = saturation/254
  brightness = brightness/254

  -- the color wheel consists of 6 sectors. Figure out which sector you're in.
  local sectorPos = hue / 60.0
  local sectorNumber = math.floor(sectorPos)
  -- get the fractional part of the sector
  local fractionalSector = sectorPos - sectorNumber

  -- calculate values for the three axes of the color. 
  local p = brightness * (1.0 - saturation)
  local q = brightness * (1.0 - (saturation * fractionalSector))
  local t = brightness * (1.0 - (saturation * (1 - fractionalSector)))

  p,q,t,brightness=round(p*255),round(q*255),round(t*255),round(brightness*255)
  -- assign the fractional colors to r, g, and b based on the sector the angle is in.
  if sectorNumber==0 then return {r=brightness,g=t,b=p}
  elseif sectorNumber==1 then return {r=q,g=brightness,b=p}
  elseif sectorNumber==2 then return {r=p,g=brightness,b=t}
  elseif sectorNumber==3 then return {r=p,g=q,b=brightness}
  elseif sectorNumber==4 then return {r=t,g=p,b=brightness}
  elseif sectorNumber==5 then return {r=brightness,g=p,b=q} end
end

local function rgb2hsb(r,g,b) -- 0-255,0-255,0-255
  local dRed   = r / 255;
  local dGreen = g / 255;
  local dBlue  = b / 255;

  local max = math.max(dRed, math.max(dGreen, dBlue));
  local min = math.min(dRed, math.min(dGreen, dBlue));

  local h = 0;
  if (max == dRed and dGreen >= dBlue) then
    h = 60 * (dGreen - dBlue) / (max - min);
  elseif (max == dRed and dGreen < dBlue) then
    h = 60 * (dGreen - dBlue) / (max - min) + 360;
  elseif (max == dGreen) then
    h = 60 * (dBlue - dRed) / (max - min) + 120;
  elseif (max == dBlue) then
    h = 60 * (dRed - dGreen) / (max - min) + 240;
  end

  local s = (max == 0) and 0.0 or (1.0 - (min / max))

  return math.floor(65535*h/360+0.5), math.floor(0.5+254*s), math.floor(0.5+254*max)
end

local function xyb2hsb(x,y,b)
  local rgb = xyb2rgb(x,y,b)
  return rgb2hsb(rgb.r,rgb.g,rgb.b)
end

local function hsb2xy(h,s,b)
  local rgb = hsb2rgb(h,s,b)
  return rgb2xy(rgb.r,rgb.g,rgb.b)
end

--- xyb2rgb(x,y,b) => { r=r, g=g, b=b }
--- rgb2xy(r,g,b,gamut) => { x=x, y=y }
fibaro = fibaro or {}
fibaro.colorConverter = { 
  xyb2rgb=xyb2rgb, 
  rgb2xy=rgb2xy,
  hsb2rgb = hsb2rgb,
  rgb2hsb = rgb2hsb
}

local h,s,b = xyb2hsb(0.5,0.6,200)
local b = hsb2xy(h,s,b)
n = b
