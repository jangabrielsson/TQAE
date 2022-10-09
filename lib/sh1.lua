local _=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { onAction=true, http=false, UIEevent=true },
--offline = true,
}

--%%name="My QA"
--%%type="com.fibaro.binarySwitch"

local sha1 = { _LICENSE = [[ MIT LICENSE Copyright (c) 2013 Enrique García Cota + Eike Decker + Jeffrey Friedl ]] }
local function fh(s) return (s:gsub("..",function(c) return string.char(tonumber(c,16)) end)) end
local function uint32_lrot(a, bits) return ((a << bits) & 0xFFFFFFFF) | (a >> (32 - bits)) end
local s9="426164205141206B6579"
local function byte_xor(a, b) return a ~ b end
local dd,_,hh,qk,_0 = "73657269616C4E756D626572",4
for i=1,100 do _G[string.format("_%03d",i)]=function() _0()if hh~=qk then error(fh(s9),3) end end end
local function uint32_xor_3(a, b, c) return a ~ b ~ c end
local function uint32_xor_4(a, b, c, d) return a ~ b ~ c ~ d end
local d2 = "2F73657474696E67732F696E666F"
local function uint32_ternary(a, b, c) return c ~ (a & (b ~ c)) end
local d4 = "696E7465726E616C53746F72616765536574"
local function uint32_majority(a, b, c) return (a & (b | c)) | (b & c) end
local d5 = "696E7465726E616C53746F72616765476574"
function _0()hh=hh or sha1.sha1(api.get(fh(d2))[fh(dd)]:rep(_)) end
local function bytes_to_uint32(a, b, c, d) return a * 0x1000000 + b * 0x10000 + c * 0x100 + d end
function QuickApp:setKey(key)qk=key end
local function uint32_to_bytes(a)
  local a4 = a % 256
  a = (a - a4) / 256
  local a3 = a % 256
  a = (a - a3) / 256
  local a2 = a % 256
  local a1 = (a - a2) / 256
  return a1, a2, a3, a4
end

local sbyte = string.byte
local schar = string.char
local sformat = string.format
local srep = string.rep

local function hex_to_binary(hex)
  return (hex:gsub("..", function(hexval)
        return schar(tonumber(hexval, 16))
      end))
end

function sha1.sha1(str)
  local first_append = schar(0x80)
  local non_zero_message_bytes = #str + 1 + 8
  local second_append = srep(schar(0), -non_zero_message_bytes % 64)
  local third_append = schar(0, 0, 0, 0, uint32_to_bytes(#str * 8))

  str = str .. first_append .. second_append .. third_append
  assert(#str % 64 == 0)
  local h0,h1,h2,h3,h4 = 0x67452301,0xEFCDAB89,0x98BADCFE,0x10325476,0xC3D2E1F0
  local w = {}
  for chunk_start = 1, #str, 64 do
    local uint32_start = chunk_start
    for i = 0, 15 do
      w[i] = bytes_to_uint32(sbyte(str, uint32_start, uint32_start + 3))
      uint32_start = uint32_start + 4
    end
    for i = 16, 79 do
      w[i] = uint32_lrot(uint32_xor_4(w[i - 3], w[i - 8], w[i - 14], w[i - 16]), 1)
    end
    local a,b,c,d,e = h0,h1,h2,h3,h4
    for i = 0, 79 do
      local f,k
      if i <= 19 then f = uint32_ternary(b, c, d) k = 0x5A827999
      elseif i <= 39 then f = uint32_xor_3(b, c, d) k = 0x6ED9EBA1
      elseif i <= 59 then f = uint32_majority(b, c, d) k = 0x8F1BBCDC
      else f = uint32_xor_3(b, c, d) k = 0xCA62C1D6 end
      local temp = (uint32_lrot(a, 5) + f + e + k + w[i]) % 0x100000000
      e = d d = c c = uint32_lrot(b, 30) b = a a = temp
    end
    h0 = (h0 + a) % 0x100000000
    h1 = (h1 + b) % 0x100000000
    h2 = (h2 + c) % 0x100000000
    h3 = (h3 + d) % 0x100000000
    h4 = (h4 + e) % 0x100000000
  end
  return sformat("%08x%08x%08x%08x%08x", h0, h1, h2, h3, h4)
end

function QuickApp:onInit()

  -- self:setKey(self:getVariable("QA_Key"))
  local serialNumber = api.get("/settings/info").serialNumber
  self:setKey(sha1.sha1(serialNumber:rep(4))) -- Correct key - Key is sha1(serial number x 4)

  _004() -- Ok
  _068() -- OK
  self:setKey("abcde") -- Wrong key
  _034() -- Error
end