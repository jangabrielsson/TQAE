--"""Color util methods."""
--from __future__ import annotations

--import colorsys
--import math
--from typing import NamedTuple

--import attr

local COLORS 
local Gamut
local color_name_to_rgb
local color_RGB_to_xy_brightness
local color_xy_brightness_to_RGB
local color_hsb_to_RGB
local color_RGB_to_hsv
local color_RGB_to_hs
local color_hsv_to_RGB
local color_hs_to_RGB
local color_xy_to_hs
local color_hs_to_xy
local color_rgb_to_rgbw
local color_rgbw_to_rgb
local get_closest_point_to_point
local check_point_in_lamps_reach
local check_valid_gamut
local get_light_gamut

local function RGBColor(r,g,b) 
  if g==nil and b==nil then
    if type(r)=='string' and COLORS[r] then
      local rgb = COLORS[r]
      return {r=rgb.r,g=rgb.g,b=rgb.b}
    else error("Bad RGB color") end
  else
    return {r=r,g=g,b=b}
  end
end

--# Official CSS3 colors from w3.org:
--# https://www.w3.org/TR/2010/PR-css3-color-20101028/#html4
--# names do not have spaces in them so that we can compare against
--# requests more easily (by removing spaces from the requests as well).
--# This lets "dark seagreen" and "dark sea green" both match the same
--# color "darkseagreen".
COLORS = {
  ['aliceblue']= RGBColor(240, 248, 255),
  ['antiquewhite']= RGBColor(250, 235, 215),
  ['aqua']= RGBColor(0, 255, 255),
  ['aquamarine']= RGBColor(127, 255, 212),
  ['azure']= RGBColor(240, 255, 255),
  ['beige']= RGBColor(245, 245, 220),
  ['bisque']= RGBColor(255, 228, 196),
  ['black']= RGBColor(0, 0, 0),
  ['blanchedalmond']= RGBColor(255, 235, 205),
  ['blue']= RGBColor(0, 0, 255),
  ['blueviolet']= RGBColor(138, 43, 226),
  ['brown']= RGBColor(165, 42, 42),
  ['burlywood']= RGBColor(222, 184, 135),
  ['cadetblue']= RGBColor(95, 158, 160),
  ['chartreuse']= RGBColor(127, 255, 0),
  ['chocolate']= RGBColor(210, 105, 30),
  ['coral']= RGBColor(255, 127, 80),
  ['cornflowerblue']= RGBColor(100, 149, 237),
  ['cornsilk']= RGBColor(255, 248, 220),
  ['crimson']= RGBColor(220, 20, 60),
  ['cyan']= RGBColor(0, 255, 255),
  ['darkblue']= RGBColor(0, 0, 139),
  ['darkcyan']= RGBColor(0, 139, 139),
  ['darkgoldenrod']= RGBColor(184, 134, 11),
  ['darkgray']= RGBColor(169, 169, 169),
  ['darkgreen']= RGBColor(0, 100, 0),
  ['darkgrey']= RGBColor(169, 169, 169),
  ['darkkhaki']= RGBColor(189, 183, 107),
  ['darkmagenta']= RGBColor(139, 0, 139),
  ['darkolivegreen']= RGBColor(85, 107, 47),
  ['darkorange']= RGBColor(255, 140, 0),
  ['darkorchid']= RGBColor(153, 50, 204),
  ['darkred']= RGBColor(139, 0, 0),
  ['darksalmon']= RGBColor(233, 150, 122),
  ['darkseagreen']= RGBColor(143, 188, 143),
  ['darkslateblue']= RGBColor(72, 61, 139),
  ['darkslategray']= RGBColor(47, 79, 79),
  ['darkslategrey']= RGBColor(47, 79, 79),
  ['darkturquoise']= RGBColor(0, 206, 209),
  ['darkviolet']= RGBColor(148, 0, 211),
  ['deeppink']= RGBColor(255, 20, 147),
  ['deepskyblue']= RGBColor(0, 191, 255),
  ['dimgray']= RGBColor(105, 105, 105),
  ['dimgrey']= RGBColor(105, 105, 105),
  ['dodgerblue']= RGBColor(30, 144, 255),
  ['firebrick']= RGBColor(178, 34, 34),
  ['floralwhite']= RGBColor(255, 250, 240),
  ['forestgreen']= RGBColor(34, 139, 34),
  ['fuchsia']= RGBColor(255, 0, 255),
  ['gainsboro']= RGBColor(220, 220, 220),
  ['ghostwhite']= RGBColor(248, 248, 255),
  ['gold']= RGBColor(255, 215, 0),
  ['goldenrod']= RGBColor(218, 165, 32),
  ['gray']= RGBColor(128, 128, 128),
  ['green']= RGBColor(0, 128, 0),
  ['greenyellow']= RGBColor(173, 255, 47),
  ['grey']= RGBColor(128, 128, 128),
  ['honeydew']= RGBColor(240, 255, 240),
  ['hotpink']= RGBColor(255, 105, 180),
  ['indianred']= RGBColor(205, 92, 92),
  ['indigo']= RGBColor(75, 0, 130),
  ['ivory']= RGBColor(255, 255, 240),
  ['khaki']= RGBColor(240, 230, 140),
  ['lavender']= RGBColor(230, 230, 250),
  ['lavenderblush']= RGBColor(255, 240, 245),
  ['lawngreen']= RGBColor(124, 252, 0),
  ['lemonchiffon']= RGBColor(255, 250, 205),
  ['lightblue']= RGBColor(173, 216, 230),
  ['lightcoral']= RGBColor(240, 128, 128),
  ['lightcyan']= RGBColor(224, 255, 255),
  ['lightgoldenrodyellow']= RGBColor(250, 250, 210),
  ['lightgray']= RGBColor(211, 211, 211),
  ['lightgreen']= RGBColor(144, 238, 144),
  ['lightgrey']= RGBColor(211, 211, 211),
  ['lightpink']= RGBColor(255, 182, 193),
  ['lightsalmon']= RGBColor(255, 160, 122),
  ['lightseagreen']= RGBColor(32, 178, 170),
  ['lightskyblue']= RGBColor(135, 206, 250),
  ['lightslategray']= RGBColor(119, 136, 153),
  ['lightslategrey']= RGBColor(119, 136, 153),
  ['lightsteelblue']= RGBColor(176, 196, 222),
  ['lightyellow']= RGBColor(255, 255, 224),
  ['lime']= RGBColor(0, 255, 0),
  ['limegreen']= RGBColor(50, 205, 50),
  ['linen']= RGBColor(250, 240, 230),
  ['magenta']= RGBColor(255, 0, 255),
  ['maroon']= RGBColor(128, 0, 0),
  ['mediumaquamarine']= RGBColor(102, 205, 170),
  ['mediumblue']= RGBColor(0, 0, 205),
  ['mediumorchid']= RGBColor(186, 85, 211),
  ['mediumpurple']= RGBColor(147, 112, 219),
  ['mediumseagreen']= RGBColor(60, 179, 113),
  ['mediumslateblue']= RGBColor(123, 104, 238),
  ['mediumspringgreen']= RGBColor(0, 250, 154),
  ['mediumturquoise']= RGBColor(72, 209, 204),
  ['mediumvioletred']= RGBColor(199, 21, 133),
  ['midnightblue']= RGBColor(25, 25, 112),
  ['mintcream']= RGBColor(245, 255, 250),
  ['mistyrose']= RGBColor(255, 228, 225),
  ['moccasin']= RGBColor(255, 228, 181),
  ['navajowhite']= RGBColor(255, 222, 173),
  ['navy']= RGBColor(0, 0, 128),
  ['navyblue']= RGBColor(0, 0, 128),
  ['oldlace']= RGBColor(253, 245, 230),
  ['olive']= RGBColor(128, 128, 0),
  ['olivedrab']= RGBColor(107, 142, 35),
  ['orange']= RGBColor(255, 165, 0),
  ['orangered']= RGBColor(255, 69, 0),
  ['orchid']= RGBColor(218, 112, 214),
  ['palegoldenrod']= RGBColor(238, 232, 170),
  ['palegreen']= RGBColor(152, 251, 152),
  ['paleturquoise']= RGBColor(175, 238, 238),
  ['palevioletred']= RGBColor(219, 112, 147),
  ['papayawhip']= RGBColor(255, 239, 213),
  ['peachpuff']= RGBColor(255, 218, 185),
  ['peru']= RGBColor(205, 133, 63),
  ['pink']= RGBColor(255, 192, 203),
  ['plum']= RGBColor(221, 160, 221),
  ['powderblue']= RGBColor(176, 224, 230),
  ['purple']= RGBColor(128, 0, 128),
  ['red']= RGBColor(255, 0, 0),
  ['rosybrown']= RGBColor(188, 143, 143),
  ['royalblue']= RGBColor(65, 105, 225),
  ['saddlebrown']= RGBColor(139, 69, 19),
  ['salmon']= RGBColor(250, 128, 114),
  ['sandybrown']= RGBColor(244, 164, 96),
  ['seagreen']= RGBColor(46, 139, 87),
  ['seashell']= RGBColor(255, 245, 238),
  ['sienna']= RGBColor(160, 82, 45),
  ['silver']= RGBColor(192, 192, 192),
  ['skyblue']= RGBColor(135, 206, 235),
  ['slateblue']= RGBColor(106, 90, 205),
  ['slategray']= RGBColor(112, 128, 144),
  ['slategrey']= RGBColor(112, 128, 144),
  ['snow']= RGBColor(255, 250, 250),
  ['springgreen']= RGBColor(0, 255, 127),
  ['steelblue']= RGBColor(70, 130, 180),
  ['tan']= RGBColor(210, 180, 140),
  ['teal']= RGBColor(0, 128, 128),
  ['thistle']= RGBColor(216, 191, 216),
  ['tomato']= RGBColor(255, 99, 71),
  ['turquoise']= RGBColor(64, 224, 208),
  ['violet']= RGBColor(238, 130, 238),
  ['wheat']= RGBColor(245, 222, 179),
  ['white']= RGBColor(255, 255, 255),
  ['whitesmoke']= RGBColor(245, 245, 245),
  ['yellow']= RGBColor(255, 255, 0),
  ['yellowgreen']= RGBColor(154, 205, 50),
}

function XYPoint(x,y) return {x=x,y=y} end
function Gamut(R,G,B) return {red=R,green=G,blue=B} end

-- LivingColors Iris, Bloom, Aura, LightStrips
local GamutA = Gamut(XYPoint(0.704, 0.296),XYPoint(0.2151, 0.7106),XYPoint(0.138, 0.08))
-- Hue A19 bulbs
local GamutB = Gamut(XYPoint(0.675, 0.322),XYPoint(0.4091, 0.518),XYPoint(0.167, 0.04))
-- Hue BR30, A19 (Gen 3), Hue Go, LightStrips plus
local GamutC = Gamut(XYPoint(0.692, 0.308),XYPoint(0.17, 0.7),XYPoint(0.153, 0.048))
local GamutD = Gamut(XYPoint(1.0, 0),XYPoint(0.0, 1.0),XYPoint(0.0, 0.0))

-- Gets the correct color gamut for the provided model id.
-- Docs: https://developers.meethue.com/develop/hue-api/supported-devices/
local GamutMap = {
  LST001=GamutA, LLC005=GamutA, LLC006=GamutA, LLC007=GamutA, LLC010=GamutA, LLC011=GamutA, LLC012=GamutA, LLC013=GamutA, LLC014=GamutA,
  LCT001=GamutB, LCT007=GamutB, LCT002=GamutB, LCT003=GamutB, LLM001=GamutB,
  LCT010=GamutC, LCT011=GamutC, LCT012=GamutC, LCT014=GamutC, LCT015=GamutC, LCT016=GamutC, LLC020=GamutC, LST002=GamutC,
  A=GamutA,B=GamutB,C=GamutC
}
function get_light_gamut(modelId) return GamutMap[modelId] or GamutD end

function color_name_to_rgb(color_name) -- -> RGBColor:
  local rgb = COLORS[color_name:gsub(" ", ""):lower()]
  assert("Unknown color")
  return rgb.r,rgb.g,rgb.b
end

local  RGB_MAX = 255
local  HUE_MAX = 360
local  SV_MAX = 100
local function _normalizeAngle (degrees) return (degrees % 360 + 360) % 360 end
local function round(x,n) local f = 10^(n or 0); return math.floor(x*f + 0.5)/f end

local colorsys = {}
function colorsys.hsv_to_rgb(h, s, v)

  h = _normalizeAngle(h)
  h = (h == HUE_MAX) and 1 or (h % HUE_MAX / (1.0*HUE_MAX) * 6)
  s = (s == SV_MAX) and 1 or (s % SV_MAX / (1.0*SV_MAX))
  v = (v == SV_MAX) and 1 or (v % SV_MAX / (1.0*SV_MAX))

  local i = math.floor(h)
  local f = h - i
  local p = v * (1 - s)
  local q = v * (1 - f * s)
  local t = v * (1 - (1 - f) * s)
  local mod = i % 6
  local r = ({v, q, p, p, t, v})[mod+1]
  local g = ({t, v, v, q, p, p})[mod+1]
  local b = ({p, p, t, v, v, q})[mod+1]

  return r,g,b

end

function colorsys.rgb_to_hsv(r, g, b)

  --It converts [0,255] format, to [0,1]
  r = (r == RGB_MAX) and 1 or (r % RGB_MAX / (1.0*RGB_MAX))
  g = (g == RGB_MAX) and 1 or (g % RGB_MAX / (1.0*RGB_MAX))
  b = (b == RGB_MAX) and 1 or (b % RGB_MAX / (1.0*RGB_MAX))

  local max = math.max(r, g, b)
  local min = math.min(r, g, b)
  local h, s, v = max,max,max

  local d = max - min

  s = max == 0 and 0 or d / max

  if (max == min) then
    h = 0 -- achromatic
  else
    if max == r then
      h = (g - b) / d + (g < b and 6 or 0)
    elseif max == g then
      h = (b - r) / d + 2
    elseif max == b then
      h = (r - g) / d + 4
    end
    h = h / 6
  end

  return h,s,v
end

function color_RGB_to_xy(iR, iG, iB, Gamut) --iR: int, iG: int, iB: int, Gamut: GamutType | None = None -> tuple[float, float]:
--Convert from RGB color to XY color.
  local x,y = color_RGB_to_xy_brightness(iR, iG, iB, Gamut)
  return x,y
end

--Taken from:
--https://github.com/PhilipsHue/PhilipsHueSDK-iOS-OSX/blob/00187a3/ApplicationDesignNotes/RGB%20to%20xy%20Color%20conversion.md
--License: Code is given as is. Use at your own risk and discretion.

function color_RGB_to_xy_brightness(iR, iG, iB, Gamut) --iR: int, iG: int, iB: int, Gamut: GamutType | None = None -> tuple[float, float, int]:
--Convert from RGB color to XY color.
  if iR + iG + iB == 0 then return 0.0, 0.0, 0 end

  local R = iR / 255.0
  local B = iB / 255.0
  local G = iG / 255.0

  --Gamma correction
  R = (R > 0.04045) and ((R + 0.055) / (1.0 + 0.055))^2.4 or (R / 12.92)
  G = (G > 0.04045) and ((G + 0.055) / (1.0 + 0.055))^2.4 or (G / 12.92)
  B = (B > 0.04045) and ((B + 0.055) / (1.0 + 0.055))^2.4 or (B / 12.92)

  --Wide RGB D65 conversion formula
  local X = R * 0.664511 + G * 0.154324 + B * 0.162028
  local Y = R * 0.283881 + G * 0.668433 + B * 0.047685
  local Z = R * 0.000088 + G * 0.072310 + B * 0.986039

  --Convert XYZ to xy
  local x = X / (X + Y + Z)
  local y = Y / (X + Y + Z)

  --Brightness
  if Y > 1 then Y = 1 end 
  local brightness = round(Y * 255.0)

  --Check if the given xy value is within the color-reach of the lamp.
  if Gamut then
    local in_reach = check_point_in_lamps_reach(x, y, Gamut)
    if not in_reach then
      x,y = get_closest_point_to_point(x, y, Gamut)
    end
  end

  return round(x, 3), round(y, 3), brightness
end

function color_xy_to_RGB(vX, vY, Gamut) --vX: float, vY: float, Gamut: GamutType | None = None -> tuple[int, int, int]:
--Convert from XY to a normalized RGB
  return color_xy_brightness_to_RGB(vX, vY, 255, Gamut)
end

--Converted to Python from Obj-C, original source from:
--https://github.com/PhilipsHue/PhilipsHueSDK-iOS-OSX/blob/00187a3/ApplicationDesignNotes/RGB%20to%20xy%20Color%20conversion.md
function color_xy_brightness_to_RGB(vX, vY, ibrightness, Gamut) --vX: float, vY: float, ibrightness: int, Gamut: GamutType | None = None -> tuple[int, int, int]:
--Convert from XYZ to RGB.
  if Gamut and not check_point_in_lamps_reach(vX, vY, Gamut) then
    vX,vY = get_closest_point_to_point(vX, vY, Gamut)
  end

  local brightness = ibrightness / 255.0
  if brightness == 0.0 then
    return 0, 0, 0
  end

  local Y = brightness

  if vY == 0.0 then
    vY = vY+ 0.00000000001
  end

  local X = (Y / vY) * vX
  local Z = (Y / vY) * (1 - vX - vY)

  --Convert to RGB using Wide RGB D65 conversion.
  local r = X * 1.656492 - Y * 0.354851 - Z * 0.255038
  local g = -X * 0.707196 + Y * 1.655397 + Z * 0.036152
  local b = X * 0.051713 - Y * 0.121364 + Z * 1.011530

  --Apply reverse gamma correction.
  r = (r <= 0.0031308) and (12.92 * r) or ((1.0 + 0.055) * r^(1.0 / 2.4) - 0.055)
  g = (g <= 0.0031308) and (12.92 * g) or ((1.0 + 0.055) * g^(1.0 / 2.4) - 0.055)
  b = (b <= 0.0031308) and (12.92 * b) or ((1.0 + 0.055) * b^(1.0 / 2.4) - 0.055)


  --Bring all negative components to zero.
  r, g, b = math.max(0, r), math.max(0,g), math.max(0,b) 

  --If one component is greater than 1, weight components by that value.
  local max_component = math.max(r, g, b)
  if max_component > 1 then
    r, g, b = r/max_component, g/max_component, b/max_component 
  end

  return math.floor(r*255), math.floor(g*255), math.floor(b*255) 
end

function color_hsb_to_RGB(fH, fS, fB) --fH: float, fS: float, fB: float -> tuple[int, int, int]:
--Convert a hsb into its rgb representation.
  if fS == 0.0 then
    local fV = math.floor(fB * 255)
    return fV, fV, fV
  end

  local r,g,b = 0,0,0
  local h = fH / 60
  local f = h - 1.0*(math.floor(h))
  local p = fB * (1 - fS)
  local q = fB * (1 - fS * f)
  local t = fB * (1 - (fS * (1 - f)))

  if math.floor(h) == 0 then
    r = math.floor(fB * 255)
    g = math.floor(t * 255)
    b = math.floor(p * 255)
  elseif math.floor(h) == 1 then
    r = math.floor(q * 255)
    g = math.floor(fB * 255)
    b = math.floor(p * 255)
  elseif math.floor(h) == 2 then
    r = math.floor(p * 255)
    g = math.floor(fB * 255)
    b = math.floor(t * 255)
  elseif math.floor(h) == 3 then
    r = math.floor(p * 255)
    g = math.floor(q * 255)
    b = math.floor(fB * 255)
  elseif math.floor(h) == 4 then
    r = math.floor(t * 255)
    g = math.floor(p * 255)
    b = math.floor(fB * 255)
  elseif math.floor(h) == 5 then
    r = math.floor(fB * 255)
    g = math.floor(p * 255)
    b = math.floor(q * 255)
  end
  return r, g, b
end

function color_RGB_to_hsv(iR, iG, iB) --iR: float, iG: float, iB: float -> tuple[float, float, float]:
--Convert an rgb color to its hsv representation.
--  Hue is scaled 0-360
--  Sat is scaled 0-100
--  Val is scaled 0-100
--  local H,S,V = colorsys.rgb_to_hsv(iR / 255.0, iG / 255.0, iB / 255.0)
  local H,S,V = colorsys.rgb_to_hsv(iR, iG, iB)
  return round(H * 360, 3), round(S * 100, 3), round(V * 100, 3)
end

function color_RGB_to_hs(iR, iG, iB) --iR: float, iG: float, iB: float -> tuple[float, float]:
--Convert an rgb color to its hs representation.
  local h,s = color_RGB_to_hsv(iR, iG, iB)
  return h,s
end

function color_hsv_to_RGB(iH, iS, iV) --iH: float, iS: float, iV: float -> tuple[int, int, int]:
--Convert an hsv color into its rgb representation.
--  Hue is scaled 0-360
--  Sat is scaled 0-100
--  Val is scaled 0-100
  --local R,G,B = colorsys.hsv_to_rgb(iH / 360, iS / 100, iV / 100)
  local R,G,B = colorsys.hsv_to_rgb(iH, iS, iV)
  return math.floor(R * 255), math.floor(G * 255), math.floor(B * 255)
end

function color_hs_to_RGB(iH, iS) --iH: float, iS: float -> tuple[int, int, int]:
--Convert an hsv color into its rgb representation.
  return color_hsv_to_RGB(iH, iS, 100)
end

function color_xy_to_hs(vX, vY, Gamut) --vX: float, vY: float, Gamut: GamutType | None = None -> tuple[float, float]:
--Convert an xy color to its hs representation.
  local r,g,b = color_xy_to_RGB(vX, vY, Gamut)
  local h, s, _ = color_RGB_to_hsv(r,g,b)
  return h, s
end

function color_hs_to_xy(iH, iS, Gamut) --iH: float, iS: float, Gamut: GamutType | None = None -> tuple[float, float]:
--Convert an hs color to its xy representation.
  local r,g,b = color_hs_to_RGB(iH, iS)
  return color_RGB_to_xy(r,g,b, Gamut)
end

function color_hsv_to_xy_v(iH, iS, iV, Gamut) --iH: float, iS: float, Gamut: GamutType | None = None -> tuple[float, float]:
--Convert an hs color to its xy representation.
  local r,g,b = color_hsv_to_RGB(iH, iS, iV)
  local x,y,br = color_RGB_to_xy_brightness(r,g,b, Gamut)
  return x,y,round(100*br/255)
end

function color_xy_v_to_hsv(vX, vY, vV, Gamut) --vX: float, vY: float, Gamut: GamutType | None = None -> tuple[float, float]:
--Convert an xy color to its hs representation.
  local r,g,b = color_xy_brightness_to_RGB(vX, vY, round(255*vV/100), Gamut)
  return color_RGB_to_hsv(r,g,b)
end

function match_max_scale(input_colors, output_colors) --input_colors: tuple[int, ...], output_colors: tuple[float, ...] -> tuple[int, ...]:
--Match the maximum value of the output to the input.
  local max_in = math.max(table.unpack(input_colors))
  local max_out = math.max(table.unpack(output_colors))
  local factor = 0.0
  if max_out ~= 0 then
    factor = max_in / max_out
  end
  local res = {}
  for _,i in ipairs(output_colors) do res[#res+1]=math.floor(factor*i) end
  return res
end

function color_rgb_to_rgbw(r, g, b) --r: int, g: int, b: int -> tuple[int, int, int, int]:
--Convert an rgb color to an rgbw representation.
-- Calculate the white channel as the minimum of input rgb channels.
-- Subtract the white portion from the remaining rgb channels.
  local w = math.min(r, g, b)
  local rgbw = {r - w, g - w, b - w, w}

--  Match the output maximum value to the input. This ensures the full
--  channel range is used.
  return table.unpack(match_max_scale({r, g, b}, rgbw))
end

function color_rgbw_to_rgb(r, g, b, w) --r: int, g: int, b: int, w: int -> tuple[int, int, int]:
--Convert an rgbw color to an rgb representation.
--Add the white channel to the rgb channels.
  local rgb = {r + w, g + w, b + w}

  --Match the output maximum value to the input. This ensures the
  --output doesn't overflow.
  return table.unpack(match_max_scale({r, g, b, w}, rgb))
end

--[[
  def color_rgb_to_rgbww(
    r: int, g: int, b: int, min_mireds: int, max_mireds: int
    ) -> tuple[int, int, int, int, int]:
"""Convert an rgb color to an rgbww representation."""
  # Find the color temperature when both white channels have equal brightness
  mired_range = max_mireds - min_mireds
  mired_midpoint = min_mireds + mired_range / 2
  color_temp_kelvin = color_temperature_mired_to_kelvin(mired_midpoint)
  w_r, w_g, w_b = color_temperature_to_rgb(color_temp_kelvin)

  # Find the ratio of the midpoint white in the input rgb channels
  white_level = min(
    r / w_r if w_r else 0, g / w_g if w_g else 0, b / w_b if w_b else 0
  )

  # Subtract the white portion from the rgb channels.
  rgb = (r - w_r * white_level, g - w_g * white_level, b - w_b * white_level)
  rgbww = (*rgb, round(white_level * 255), round(white_level * 255))

  # Match the output maximum value to the input. This ensures the full
  # channel range is used.
  return match_max_scale((r, g, b), rgbww)  # type: ignore[return-value]


  def color_rgbww_to_rgb(
    r: int, g: int, b: int, cw: int, ww: int, min_mireds: int, max_mireds: int
    ) -> tuple[int, int, int]:
"""Convert an rgbww color to an rgb representation."""
  # Calculate color temperature of the white channels
  mired_range = max_mireds - min_mireds
  try:
  ct_ratio = ww / (cw + ww)
  except ZeroDivisionError:
  ct_ratio = 0.5
  color_temp_mired = min_mireds + ct_ratio * mired_range
  if color_temp_mired:
  color_temp_kelvin = color_temperature_mired_to_kelvin(color_temp_mired)
else:
  color_temp_kelvin = 0
  w_r, w_g, w_b = color_temperature_to_rgb(color_temp_kelvin)
  white_level = max(cw, ww) / 255

  # Add the white channels to the rgb channels.
  rgb = (r + w_r * white_level, g + w_g * white_level, b + w_b * white_level)

  # Match the output maximum value to the input. This ensures the
  # output doesn't overflow.
  return match_max_scale((r, g, b, cw, ww), rgb)  # type: ignore[return-value]


  def color_rgb_to_hex(r: int, g: int, b: int) -> str:
"""Return a RGB color from a hex color string."""
  return f"{round(r):02x}{round(g):02x}{round(b):02x}"


  def rgb_hex_to_rgb_list(hex_string: str) -> list[int]:
"""Return an RGB color value list from a hex color string."""
  return [
  int(hex_string[i : i + len(hex_string) // 3], 16)
  for i in range(0, len(hex_string), len(hex_string) // 3)
  ]


  def color_temperature_to_hs(color_temperature_kelvin: float) -> tuple[float, float]:
"""Return an hs color from a color temperature in Kelvin."""
  return color_RGB_to_hs(*color_temperature_to_rgb(color_temperature_kelvin))


  def color_temperature_to_rgb(
    color_temperature_kelvin: float,
    ) -> tuple[float, float, float]:
"""
  Return an RGB color from a color temperature in Kelvin.

  This is a rough approximation based on the formula provided by T. Helland
  http://www.tannerhelland.com/4435/convert-temperature-rgb-algorithm-code/
"""
  # range check
  if color_temperature_kelvin < 1000:
  color_temperature_kelvin = 1000
  elif color_temperature_kelvin > 40000:
  color_temperature_kelvin = 40000

  tmp_internal = color_temperature_kelvin / 100.0

  red = _get_red(tmp_internal)

  green = _get_green(tmp_internal)

  blue = _get_blue(tmp_internal)

  return red, green, blue


  def color_temperature_to_rgbww(
    temperature: int, brightness: int, min_mireds: int, max_mireds: int
    ) -> tuple[int, int, int, int, int]:
"""Convert color temperature in mireds to rgbcw."""
  mired_range = max_mireds - min_mireds
  cold = ((max_mireds - temperature) / mired_range) * brightness
  warm = brightness - cold
  return (0, 0, 0, round(cold), round(warm))


  def rgbww_to_color_temperature(
    rgbww: tuple[int, int, int, int, int], min_mireds: int, max_mireds: int
    ) -> tuple[int, int]:
"""Convert rgbcw to color temperature in mireds."""
  _, _, _, cold, warm = rgbww
  return while_levels_to_color_temperature(cold, warm, min_mireds, max_mireds)


  def while_levels_to_color_temperature(
    cold: int, warm: int, min_mireds: int, max_mireds: int
    ) -> tuple[int, int]:
"""Convert whites to color temperature in mireds."""
  brightness = warm / 255 + cold / 255
  if brightness == 0:
  return (max_mireds, 0)
  return round(
    ((cold / 255 / brightness) * (min_mireds - max_mireds)) + max_mireds
    ), min(255, round(brightness * 255))


  def _clamp(color_component: float, minimum: float = 0, maximum: float = 255) -> float:
"""
  Clamp the given color component value between the given min and max values.

  The range defined by the minimum and maximum values is inclusive, i.e. given a
  color_component of 0 and a minimum of 10, the returned value is 10.
"""
  color_component_out = max(color_component, minimum)
  return min(color_component_out, maximum)


  def _get_red(temperature: float) -> float:
"""Get the red component of the temperature in RGB space."""
  if temperature <= 66:
  return 255
  tmp_red = 329.698727446 * math.pow(temperature - 60, -0.1332047592)
  return _clamp(tmp_red)


  def _get_green(temperature: float) -> float:
"""Get the green component of the given color temp in RGB space."""
  if temperature <= 66:
  green = 99.4708025861 * math.log(temperature) - 161.1195681661
else:
  green = 288.1221695283 * math.pow(temperature - 60, -0.0755148492)
  return _clamp(green)


  def _get_blue(temperature: float) -> float:
"""Get the blue component of the given color temperature in RGB space."""
  if temperature >= 66:
  return 255
  if temperature <= 19:
  return 0
  blue = 138.5177312231 * math.log(temperature - 10) - 305.0447927307
  return _clamp(blue)


  def color_temperature_mired_to_kelvin(mired_temperature: float) -> int:
"""Convert absolute mired shift to degrees kelvin."""
  return math.floor(1000000 / mired_temperature)


  def color_temperature_kelvin_to_mired(kelvin_temperature: float) -> int:
"""Convert degrees kelvin to mired shift."""
  return math.floor(1000000 / kelvin_temperature)
--]]

--  The following 5 functions are adapted from rgbxy provided by Benjamin Knight
--  License: The MIT License (MIT), 2014.
--  https://github.com/benknight/hue-python-rgb-converter
function cross_product(p1,p2) -- p1: XYPoint, p2: XYPoint -> float:
--Calculate the cross product of two XYPoints.
  return (p1.x * p2.y - p1.y * p2.x)*1.0
end

function get_distance_between_two_points(one, two) --one: XYPoint, two: XYPoint -> float:
--Calculate the distance between two XYPoints.
  local dx = one.x - two.x
  local dy = one.y - two.y
  return math.sqrt(dx * dx + dy * dy)
end

function get_closest_point_to_line(A, B, P) --A: XYPoint, B: XYPoint, P: XYPoint -> XYPoint:
--Find the closest point from P to a line defined by A and B.
--This point will be reproducible by the lamp
--as it is on the edge of the gamut.
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

function get_closest_point_to_point(x, y, Gamut) --xy_tuple: tuple[float, float], Gamut: GamutType -> tuple[float, float]:
  --Get the closest matching color within the gamut of the light.
  --Should only be used if the supplied color is outside of the color gamut.
  local xy_point = XYPoint(x, y)

  --find the closest point on each line in the CIE 1931 'triangle'.
  local pAB = get_closest_point_to_line(Gamut.red, Gamut.green, xy_point)
  local pAC = get_closest_point_to_line(Gamut.blue, Gamut.red, xy_point)
  local pBC = get_closest_point_to_line(Gamut.green, Gamut.blue, xy_point)

  --Get the distances per point and see which point is closer to our Point.
  local dAB = get_distance_between_two_points(xy_point, pAB)
  local dAC = get_distance_between_two_points(xy_point, pAC)
  local dBC = get_distance_between_two_points(xy_point, pBC)

  local lowest = dAB
  local closest_point = pAB

  if dAC < lowest then
    lowest = dAC
    closest_point = pAC
  end

  if dBC < lowest then
    lowest = dBC
    closest_point = pBC
  end

  --Change the xy value to a value which is within the reach of the lamp.
  local cx = closest_point.x
  local cy = closest_point.y

  return cx, cy
end

function check_point_in_lamps_reach(x, y, Gamut) -- XYPoint,GamutType -> bool:
  ---Check if the provided XYPoint can be recreated by a Hue lamp.
  local v1 = XYPoint(Gamut.green.x - Gamut.red.x, Gamut.green.y - Gamut.red.y)
  local v2 = XYPoint(Gamut.blue.x - Gamut.red.x, Gamut.blue.y - Gamut.red.y)

  local q = XYPoint(x - Gamut.red.x, y - Gamut.red.y)
  local s = cross_product(q, v2) / cross_product(v1, v2)
  local t = cross_product(v1, q) / cross_product(v1, v2)

  return (s >= 0.0) and (t >= 0.0) and (s + t <= 1.0)
end

function check_valid_gamut(Gamut) -- Gamut: GamutType -> bool:
--Check if the supplied gamut is valid.
  --Check if the three points of the supplied gamut are not on the same line.
  local v1 = XYPoint(Gamut.green.x - Gamut.red.x, Gamut.green.y - Gamut.red.y)
  local v2 = XYPoint(Gamut.blue.x - Gamut.red.x, Gamut.blue.y - Gamut.red.y)
  local not_on_line = cross_product(v1, v2) > 0.0001

  --Check if all six coordinates of the gamut lie between 0 and 1.
  local red_valid =
  Gamut.red.x >= 0 and Gamut.red.x <= 1 and Gamut.red.y >= 0 and Gamut.red.y <= 1

  local green_valid =
  Gamut.green.x >= 0
  and Gamut.green.x <= 1
  and Gamut.green.y >= 0
  and Gamut.green.y <= 1

  local blue_valid =
  Gamut.blue.x >= 0
  and Gamut.blue.x <= 1
  and Gamut.blue.y >= 0
  and Gamut.blue.y <= 1

  return not_on_line and red_valid and green_valid and blue_valid
end

fibaro = fibaro or {}
fibaro.colorConversion = {
  name2rgb = color_name_to_rgb,          --> string -> r,g,b
  rgb2xyb  = color_RGB_to_xy_brightness, -- r,g,b,G -> x,y,b    0-255,0-255,2-255 -> 0-1,0-1,0-255
  rgb2xy   = color_RGB_to_xy,            -- r,g,b,G -> x,y,b    0-255,0-255       -> 0-1,0-1
  xyb2rgb  = color_xy_brightness_to_RGB, -- x,y,b,G -> r,g,b    0-1,0-1,0-255     -> 0-255,0-255,0-255
  xy2rgb   = color_xy_to_RGB,            -- x,y,G -> r,g,b      0-1,0-1           -> 0-255,0-255,0-255
  hsb2rgb  = color_hsb_to_RGB,           -- h,s,b -> r,g,b      0-1,0-1,0-1       -> 0-255,0-255,0-255  VVV
  rgb2hs   = color_RGB_to_hs,            -- r,g,b -> h,s        0-255,0-255,0-255 -> 0-360,0-100
  rgb2hsv  = color_RGB_to_hsv,           -- r,g,b -> h,s,v      0-255,0-255,0-255 -> 0-360,0-100,0-100
  hsv2rgb  = color_hsv_to_RGB,           -- h,s,v -> r,g,b      0-360,0-100,0-100 -> 0-255,0-255,0-255
  hs2rgb   = color_hs_to_RGB,            -- h,s   -> r,g,b      0-360,0-100       -> 0-255,0-255,0-255
  xy2hs    = color_xy_to_hs,             -- x,y,G -> h,s        0-1,0-1,G         -> 0-360,0-100
  hs2xy    = color_hs_to_xy,             -- h,s,G -> x,y        0-360,0-100,G           -> 0-1,0-1
  xyv2hsv   = color_xy_v_to_hsv,         -- x,y,v,G -> h,s,v    0-1,0-1,G               -> 0-360,0-100,0-100
  hsv2xyv   = color_hsv_to_xy_v,         -- h,s,v,G -> x,y,v    0-360,0-100,0-100G      -> 0-1,0-1
  rgb2rgbw = color_rgb_to_rgbw,          -- r,g,b -> r,g,b,w    0-255,0-255,0-255       -> 0-255,0-255,0-255,0-255
  rgbw2rgb = color_rgbw_to_rgb,          -- r,g,b,w -> r,g,b    0-255,0-255,0-255,0-255 -> 0-255,0-255,0-25
  gamut    = get_light_gamut             -- string -> G
}

--test=true
if test then
  local cc = fibaro.colorConversion
  r,g,b = cc.name2rgb("red")
  print(r,g,b)
  h,s = cc.rgb2hs(r,g,b)
  r,g,b = cc.hs2rgb(h,s)
  print(r,g,b)
  print("----")
  r,g,b = cc.name2rgb("green")
  print(r,g,b)
  h,s,v = cc.rgb2hsv(r,g,b)
  r,g,b = cc.hsv2rgb(h,s,v)
  print(r,g,b)
  print("----")
  r,g,b = cc.name2rgb("blue")
  print(r,g,b)
  h,s = cc.rgb2hs(r,g,b)
  r,g,b = cc.hs2rgb(h,s)
  print(r,g,b)
print("----")
  r,g,b = cc.name2rgb("blue")
  print(r,g,b)
  x,y,b = cc.rgb2xyb(r,g,b)
  print(x,y)
  r,g,b = cc.xyb2rgb(x,y,b)
  print(r,g,b)
  h,s = cc.xy2hs(x,y)
  x,y = cc.hs2xy(h,s)
  print(x,y)
end