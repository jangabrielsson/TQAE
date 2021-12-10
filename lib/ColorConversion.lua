--[[
Library for RGB / CIE1931 "x, y" coversion.
Based on Philips implementation guidance:
http://www.developers.meethue.com/documentation/color-conversions-rgb-xy
Copyright (c) 2016 Benjamin Knight / MIT License.
--]]

local __version__ = '0.5.1'

-- Represents a CIE 1931 XY coordinate pair.
local function XYPoint(x,y) return {x=x, y=y} end

-- LivingColors Iris, Bloom, Aura, LightStrips
local GamutA = {
  XYPoint(0.704, 0.296),
  XYPoint(0.2151, 0.7106),
  XYPoint(0.138, 0.08),
}

-- Hue A19 bulbs
local GamutB = {
  XYPoint(0.675, 0.322),
  XYPoint(0.4091, 0.518),
  XYPoint(0.167, 0.04),
}

-- Hue BR30, A19 (Gen 3), Hue Go, LightStrips plus
local GamutC = {
  XYPoint(0.692, 0.308),
  XYPoint(0.17, 0.7),
  XYPoint(0.153, 0.048),
}

local GamutD = { 
  XYPoint(1.0, 0),
  XYPoint(0.0, 1.0),
  XYPoint(0.0, 0.0)
} 

local Gamut = { A = GamutA, B = GamutB, C = GamutC, D = GamutD }

local get_distance_between_two_points
local function member(e,l) for _,x in ipairs(l) do if e==x then return true end end end

local function get_light_gamut(modelId)
-- Gets the correct color gamut for the provided model id.
-- Docs: https://developers.meethue.com/develop/hue-api/supported-devices/
--
  if member(modelId,{'LST001', 'LLC005', 'LLC006', 'LLC007', 'LLC010', 'LLC011', 'LLC012', 'LLC013', 'LLC014'}) then
    return GamutA
  elseif member(modelId,{'LCT001', 'LCT007', 'LCT002', 'LCT003', 'LLM001'}) then
    return GamutB
  elseif member(modelId,{'LCT010', 'LCT011', 'LCT012', 'LCT014', 'LCT015', 'LCT016', 'LLC020', 'LST002'}) then
    return GamutC
  end
end

local function ColorHelper(gamut)
  local self = {}
  gamut = gamut or "B"
  gamut = Gamut[gamut]

  self.Red = gamut[1]
  self.Lime = gamut[2]
  self.Blue = gamut[3]

  local function cross_product(p1, p2)
-- Returns the cross product of two XYPoints.
    return (p1.x * p2.y - p1.y * p2.x)
  end

  local function check_point_in_lamps_reach(p)
-- Check if the provided XYPoint can be recreated by a Hue lamp.
    local v1 = XYPoint(self.Lime.x - self.Red.x, self.Lime.y - self.Red.y)
    local v2 = XYPoint(self.Blue.x - self.Red.x, self.Blue.y - self.Red.y)

    local q = XYPoint(p.x - self.Red.x, p.y - self.Red.y)
    local s = cross_product(q, v2) / cross_product(v1, v2)
    local t = cross_product(v1, q) / cross_product(v1, v2)

    return (s >= 0.0) and (t >= 0.0) and (s + t <= 1.0)
  end

  local function get_closest_point_to_line(A, B, P)
-- Find the closest point on a line. This point will be reproducible by a Hue lamp
    local AP = XYPoint(P.x - A.x, P.y - A.y)
    local AB = XYPoint(B.x - A.x, B.y - A.y)
    local ab2 = AB.x * AB.x + AB.y * AB.y
    local ap_ab = AP.x * AB.x + AP.y * AB.y
    local t = ap_ab / ab2

    if t < 0.0 then
      t = 0.0
    elseif t > 1.0 then
      t = 1.0
    end

    return XYPoint(A.x + AB.x * t, A.y + AB.y * t)
  end

  local function get_closest_point_to_point(xy_point)
-- Color is unreproducible, find the closest point on each line in the CIE 1931 'triangle'.
    local pAB = get_closest_point_to_line(self.Red, self.Lime, xy_point)
    local pAC = get_closest_point_to_line(self.Blue, self.Red, xy_point)
    local pBC = get_closest_point_to_line(self.Lime, self.Blue, xy_point)

    -- Get the distances per point and see which point is closer to our Point.
    local dAB = get_distance_between_two_points(xy_point, pAB)
    local dAC = get_distance_between_two_points(xy_point, pAC)
    local dBC = get_distance_between_two_points(xy_point, pBC)

    local lowest = dAB
    local closest_point = pAB

    if (dAC < lowest) then
      lowest = dAC
      closest_point = pAC
    end

    if (dBC < lowest) then
      lowest = dBC
      closest_point = pBC
    end

    -- Change the xy value to a value which is within the reach of the lamp.
    local cx = closest_point.x
    local cy = closest_point.y

    return XYPoint(cx, cy)
  end

  function get_distance_between_two_points(one, two)
-- Returns the distance between two XYPoints.
    local dx = one.x - two.x
    local dy = one.y - two.y
    return math.sqrt(dx * dx + dy * dy)
  end

  local function get_xy_point_from_rgb(red_i, green_i, blue_i)
-- Returns an XYPoint object containing the closest available CIE 1931 x, y coordinates based on the RGB input values

    local red = red_i / 255.0
    local green = green_i / 255.0
    local blue = blue_i / 255.0

    local r = (red > 0.04045) and ((red + 0.055) / (1.0 + 0.055))^2.4 or (red / 12.92)
    local g = (green > 0.04045) and ((green + 0.055) / (1.0 + 0.055))^2.4 or (green / 12.92)
    local b = (blue > 0.04045) and ((blue + 0.055) / (1.0 + 0.055))^2.4 or (blue / 12.92)

    local X = r * 0.664511 + g * 0.154324 + b * 0.162028
    local Y = r * 0.283881 + g * 0.668433 + b * 0.047685
    local Z = r * 0.000088 + g * 0.072310 + b * 0.986039

    local cx = X / (X + Y + Z)
    local cy = Y / (X + Y + Z)

    -- Check if the given XY value is within the colourreach of our lamps.
    local xy_point = XYPoint(cx, cy)
    local in_reach = check_point_in_lamps_reach(xy_point)

    if not in_reach then
      xy_point = get_closest_point_to_point(xy_point)
    end

    return xy_point
  end

  local function get_rgb_from_xy_and_brightness(x, y, bri)
    bri=bri or 1.0
-- Inverse of `get_xy_point_from_rgb`. Returns (r, g, b) for given x, y values.
-- Implementation of the instructions found on the Philips Hue iOS SDK docs: http://goo.gl/kWKXKl

-- The xy to color conversion is almost the same, but in reverse order.
-- Check if the xy value is within the color gamut of the lamp.
-- If not continue with step 2, otherwise step 3.
-- We do this to calculate the most accurate color the given light can actually do.
    local xy_point = XYPoint(x, y)

    if not check_point_in_lamps_reach(xy_point) then
      -- Calculate the closest point on the color gamut triangle
      -- and use that as xy value See step 6 of color to xy.
      xy_point = get_closest_point_to_point(xy_point)
    end

    -- Calculate XYZ values Convert using the following formulas:
    local Y = bri
    local X = (Y / xy_point.y) * xy_point.x
    local Z = (Y / xy_point.y) * (1 - xy_point.x - xy_point.y)

    -- Convert to RGB using Wide RGB D65 conversion
    local r = X * 1.656492 - Y * 0.354851 - Z * 0.255038
    local g = -X * 0.707196 + Y * 1.655397 + Z * 0.036152
    local b = X * 0.051713 - Y * 0.121364 + Z * 1.011530

    -- Apply reverse gamma correction
--  r, g, b = map(
--    lambda x: (12.92 * x) if (x <= 0.0031308) else ((1.0 + 0.055) * pow(x, (1.0 / 2.4)) - 0.055),
--    [r, g, b]
--  )
    r = (r <= 0.0031308) and (12.92 * r) or ((1.0 + 0.055) * r^(1.0 / 2.4) - 0.055)
    g = (g <= 0.0031308) and (12.92 * g) or ((1.0 + 0.055) * g^(1.0 / 2.4) - 0.055)
    b = (b <= 0.0031308) and (12.92 * b) or ((1.0 + 0.055) * b^(1.0 / 2.4) - 0.055)

    -- Bring all negative components to zero
    r, g, b = r < 0 and 0 or r, g < 0 and 0 or g, b < 0 and 0 or b

    -- If one component is greater than 1, weight components by that value.
    local max_component = math.max(r, g, b)
    if max_component > 1 then
      r, g, b = r / max_component, g / max_component, b / max_component
    end

    r, g, b = math.floor(r*255),math.floor(g*255),math.floor(b*255) 

    -- Convert the RGB values to your color object The rgb values from the above formulas are between 0.0 and 1.0.
    return r, g, b
  end

  self.rgb2xy =  get_xy_point_from_rgb -- (r,g,b) -- 0-255,0-255,0-255
  self.xyb2rgb = get_rgb_from_xy_and_brightness  -- (x,y,bri) -- 0-1.0,0-1.0,0-1.0
  self.getGamutFromModel = get_light_gamut -- (modelId)
  return self
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

--- xyb2rgb(x,y,b) => { r=r, g=g, b=b }
--- rgb2xy(r,g,b,gamut) => { x=x, y=y }
fibaro = fibaro or {}
fibaro.colorConverter = { 
  xy = ColorHelper,   --
--  xyb2rgb=xyb2rgb, 
--  rgb2xy=rgb2xy,
  hsb2rgb = hsb2rgb,
  rgb2hsb = rgb2hsb
}
