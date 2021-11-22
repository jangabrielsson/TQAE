
local GamutRanges = {
  gamutA = {
    red = {0.704, 0.296}, green = {0.2151, 0.7106}, blue = {0.138, 0.08}
  },
  gamutB = {
    red = {0.675, 0.322}, green = {0.409, 0.518}, blue = {0.167, 0.04}
  },
  gamutC = {
    red = {0.692, 0.308}, green = {0.17, 0.7}, blue = {0.153, 0.048}
  },
  defaultGamut = {
    red = {1.0, 0}, green = {0.0, 1.0}, blue = {0.0, 0.0}
  }
}


local function getLightColorGamutRange(gamut)
  return GamutRanges[gamut] or GamutRanges['defaultGamut']
end

local function parseFloat(f) return f end
local function parseInt(i) return math.floor(i) end

local function getClosestColor(xy, gamut)

  local function getLineDistance(pointA,pointB)
    return math.hypot(pointB.x - pointA.x, pointB.y - pointA.y)
  end

  local function getClosestPoint(xy, pointA, pointB) 
    local xy2a = {xy.x - pointA.x, xy.y - pointA.y}
    local a2b = {pointB.x - pointA.x, pointB.y - pointA.y}
    local a2bSqr = math.pow(a2b[1],2) + math.pow(a2b[2],2)
    local xy2a_dot_a2b = xy2a[1] * a2b[1] + xy2a[1] * a2b[2]
    local t = xy2a_dot_a2b /a2bSqr

    return {
      x = pointA.x + a2b[1] * t,
      y = pointA.y + a2b[2] * t
    }
  end

  local greenBlue = {
    a = {
      x = gamut.green[1],
      y = gamut.green[2]
    },
    b = {
      x = gamut.blue[1],
      y = gamut.blue[2]
    }
  }

  local greenRed = {
    a = {
      x = gamut.green[1],
      y = gamut.green[2]
    },
    b = {
      x = gamut.red[1],
      y = gamut.red[2]
    }
  }

  local blueRed = {
    a = {
      x = gamut.red[1],
      y = gamut.red[2]
    },
    b = {
      x = gamut.blue[1],
      y = gamut.blue[2]
    }
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
  }

  local closestDistance
  local closestColor

  for p,_ in pairs(distance) do
      
      if not closestDistance then
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

local function xyIsInGamutRange(xy, gamut)
  gamut = gamut or GamutRanges.gamutC

  if xy[1] then
    xy = { x = xy[1], y = xy[2]}
  end

  local v0 = {gamut.blue[1] - gamut.red[1], gamut.blue[2] - gamut.red[2]}
  local v1 = {gamut.green[1] - gamut.red[1], gamut.green[2] - gamut.red[2]}
  local v2 = {xy.x - gamut.red[1], xy.y - gamut.red[2]}

  local dot00 = (v0[1] * v0[1]) + (v0[2] * v0[2])
  local dot01 = (v0[1] * v1[1]) + (v0[2] * v1[2])
  local dot02 = (v0[1] * v2[1]) + (v0[2] * v2[2])
  local dot11 = (v1[1] * v1[1]) + (v1[2] * v1[2])
  local dot12 = (v1[1] * v2[1]) + (v1[2] * v2[2])

  local invDenom = 1.0 / (dot00 * dot11 - dot01 * dot01)

  local u = (dot11 * dot02 - dot01 * dot12) * invDenom
  local v = (dot00 * dot12 - dot01 * dot02) * invDenom

  return ((u >= 0) and (v >= 0) and (u + v < 1))
end

local function rgbToXy(red, green, blue, gamut)

  local function getGammaCorrectedValue(value)
    return (value > 0.04045) and math.pow((value + 0.055) / (1.0 + 0.055), 2.4) or (value / 12.92)
  end

  local colorGamut = GamutRanges[gamut] or GamutRanges['defaultGamut']

  red = parseFloat(red / 255.0);
  green = parseFloat(green / 255.0);
  blue = parseFloat(blue / 255.0);

  red = getGammaCorrectedValue(red);
  green = getGammaCorrectedValue(green);
  blue = getGammaCorrectedValue(blue);

  local x = red * 0.649926 + green * 0.103455 + blue * 0.197109;
  local y = red * 0.234327 + green * 0.743075 + blue * 0.022598;
  local z = red * 0.0000000 + green * 0.053077 + blue * 1.035763;

  local xy = {
    x = x / (x + y + z),
    y = y / (x + y + z)
  }

  if not xyIsInGamutRange(xy, colorGamut) then
    xy = getClosestColor(xy,colorGamut)
  end

  return xy;
end

local function xyBriToRgb(x,y,bri) 

  function getReversedGammaCorrectedValue(value)
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

  red = math.abs(red)
  green = math.abs(green)
  blue = math.abs(blue)

  return {r = red, g = green, b = blue}
end

a = xyBriToRgb(0.5,0.7,255)
print(a)
b = rgbToXy(a.r, a.g, a.b, gamut)
print(b)