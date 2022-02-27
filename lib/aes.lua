---------------------------------------- pure LUA AES Lib for HC3 QuickApps -----------------------------------------
aeslib = {
  _VERSION     = "0.2",
  _DESCRIPTION = "pura LUA AES LIB",
  _URL         = "http://quickapps.info",
  _LICENSE     = [[
      (c) tinman/Intuitech
  ]]
}

--------------------------------------------------------------------------------
-- USAGE:
-- call aeslib.decryptString or aeslib.encryptString
-- there is additional padding and aestil lib inside, check QA example
--------------------------------------------------------------------------------
-- Decrypt strings
-- key - byte array with key
-- string - string to decrypt
-- modefunction - ciphermode.decryptECB,ciphermode.decryptCBC,ciphermode.decryptOFB,ciphermode.decryptCFB,ciphermode.decryptCTR
-- iv - optional iv for modefunction
function aeslib.decryptString(key, data, modeFunction, iv)
    return ciphermode.decryptString(key, data, modeFunction, iv)
end

-- Encrypt strings
-- key - byte array with key
-- string - string to encrypt
-- modefunction - ciphermode.encryptECB,ciphermode.encryptCBC,ciphermode.encryptOFB,ciphermode.encryptCFB,ciphermode.encryptCTR)
-- iv - optional iv for modefunction
function aeslib.encryptString(key, data, modeFunction, iv)
    return ciphermode.encryptString(key, data, modeFunction, iv)
end

--------------------------------------------------------------------------------
-- small extra -> padding lib : PKCS#7, ANSI X9.23, ISO7816-4, ZERO and SPACE 
--------------------------------------------------------------------------------

padding = {
  _VERSION     = "lua-resty-nettle.padding.lua v1.5 - 2020-04-01",
  _LICENSE     = [[
  Copyright (c) 2014 - 2020, Aapo Talvensaari
  All rights reserved.
  
  Redistribution and use in source and binary forms, with or without modification,
  are permitted provided that the following conditions are met:
  
  * Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.
  
  * Redistributions in binary form must reproduce the above copyright notice, this
  list of conditions and the following disclaimer in the documentation and/or
  other materials provided with the distribution.
  
  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
  ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
  ]]
}

function padding.padPKCS7(data, blocksize, optional)
  blocksize = blocksize or 16
  if type(blocksize) ~= "number" then
    return nil, "invalid block size data type"
  end
  if blocksize < 1 or blocksize > 256 then
    return nil, "invalid block size"
  end
  local ps = blocksize - #data % blocksize
  if optional and ps == blocksize then return data end
  return data .. string.rep(string.char(ps), ps)
end

function padding.unpadPKCS7(data, blocksize)
  blocksize = blocksize or 16
  if type(blocksize) ~= "number" then
    return nil, "invalid block size data type"
  end
  if blocksize < 1 or blocksize > 256 then
    return nil, "invalid block size"
  end
  local len = #data
  if len % blocksize ~= 0 then
    return nil, "data length is not a multiple of the block size"
  end
  local chr = string.sub(data, -1)
  local rem = string.byte(chr)
  if rem > 0 and rem <= blocksize then
    local chk = string.sub(data, -rem)
    if chk == string.rep(chr, rem) then
      return string.sub(data, 1, len - rem)
    end
  end
  return data
end

function padding.padANSIX923(data, blocksize, optional)
  blocksize = blocksize or 16
  if type(blocksize) ~= "number" then
    return nil, "invalid block size data type"
  end
  if blocksize < 1 or blocksize > 256 then
    return nil, "invalid block size"
  end
  local ps = blocksize - #data % blocksize
  if optional and ps == blocksize then return data end
  return data .. string.rep("\0", ps - 1) .. string.char(ps)
end

function padding.unpadANSIX923(data, blocksize)
  blocksize = blocksize or 16
  if type(blocksize) ~= "number" then
    return nil, "invalid block size data type"
  end
  if blocksize < 1 or blocksize > 256 then
    return nil, "invalid block size"
  end
  local len = #data
  if len % blocksize ~= 0 then
    return nil, "data length is not a multiple of the block size"
  end
  local chr = string.sub(data, -1)
  local rem = string.byte(chr)
  if rem > 0 and rem <= blocksize then
    local chk = string.sub(data, -rem)
    if chk == string.rep("\0", rem - 1) .. chr then
      return string.sub(data, 1, len - rem)
    end
  end
  return data
end

function padding.padZERO(data, blocksize, optional)
  blocksize = blocksize or 16
  if type(blocksize) ~= "number" then
    return nil, "invalid block size data type"
  end
  if blocksize < 1 or blocksize > 256 then
    return nil, "invalid block size"
  end
  local ps = blocksize - #data % blocksize
  if optional and ps == blocksize then return data end
  return data .. string.rep("\0", ps)
end

function padding.unpadZERO(data, blocksize)
  blocksize = blocksize or 16
  if type(blocksize) ~= "number" then
    return nil, "invalid block size data type"
  end
  if blocksize < 1 or blocksize > 256 then
    return nil, "invalid block size"
  end
  local len = #data
  if len % blocksize ~= 0 then
    return nil, "data length is not a multiple of the block size"
  end
  data = string.gsub(data, "%z+$", "")
  local rem = len - #data
  if rem < 0 or rem > blocksize then
    return nil, "data has invalid padding"
  end
  return data
end

function padding.padISO7816_4(data, blocksize, optional)
  blocksize = blocksize or 16
  if type(blocksize) ~= "number" then
    return nil, "invalid block size data type"
  end
  if blocksize < 1 or blocksize > 256 then
    return nil, "invalid block size"
  end
  local ps = blocksize - #data % blocksize
  if optional and ps == blocksize then return data end
  return data .. "\x80" .. string.rep("\0", ps - 1)
end

function padding.unpadISO7816_4(data, blocksize)
  blocksize = blocksize or 16
  if type(blocksize) ~= "number" then
    return nil, "invalid block size data type"
  end
  if blocksize < 1 or blocksize > 256 then
    return nil, "invalid block size"
  end
  local len = #data
  if len % blocksize ~= 0 then
    return nil, "data length is not a multiple of the block size"
  end
  local d = string.gsub(data, "%z+$", "")
  if string.sub(d, -1) == "\x80" then
    return string.sub(d, 1, #d - 1)
  end
  return data
end

function padding.padSPACE(data, blocksize, optional)
  blocksize = blocksize or 16
  if type(blocksize) ~= "number" then
    return nil, "invalid block size data type"
  end
  if blocksize < 1 or blocksize > 256 then
    return nil, "invalid block size"
  end
  local ps = blocksize - #data % blocksize
  if optional and ps == blocksize then return data end
  return data .. string.rep(" ", ps)
end

function padding.unpadSPACE(data, blocksize)
  blocksize = blocksize or 16
  if type(blocksize) ~= "number" then
    return nil, "invalid block size data type"
  end
  if blocksize < 1 or blocksize > 256 then
    return nil, "invalid block size"
  end
  local len = #data
  if len % blocksize ~= 0 then
    return nil, "data length is not a multiple of the block size"
  end
  data = string.gsub(data, " +$", "")
  local rem = len - #data
  if rem < 0 or rem > blocksize then
    return nil, "data has invalid padding"
  end
  return data
end

function padding.toHex(data)
    local inputHexTab = {}
    for c in data:gmatch(".") do
        table.insert(inputHexTab, string.format("%02x", c:byte()))
    end
    return table.concat(inputHexTab, "")
end

function padding.fromHex(data)
    return data:gsub(
        "%x%x",
        function(c)
            return c.char(tonumber(c, 16))
        end
    )
end

--------------------------------------------------------------------------------
-- aes part of aeslib
--------------------------------------------------------------------------------

aesutil = {
  _VERSION     = "util.lua 0.2",
  _LICENSE     = [[
    aeslua: Lua AES implementation
    Copyright (c) 2006,2007 Matthias Hilbig

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU Lesser Public License as published by the
    Free Software Foundation; either version 2.1 of the License, or (at your
    option) any later version.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser Public License for more details.

    A copy of the terms and conditions of the license can be found in
    License.txt or online at

    http://www.gnu.org/copyleft/lesser.html

    To obtain a copy, write to the Free Software Foundation, Inc.,
    59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

    Author
    Matthias Hilbig
    http://homepages.upb.de/hilbig/aeslua/
    hilbig@upb.de 
  ]]
}

--
-- calculate the parity of one byte
--
function aesutil.byteParity(byte)
    byte = bit32.bxor(byte, bit32.rshift(byte, 4));
    byte = bit32.bxor(byte, bit32.rshift(byte, 2));
    byte = bit32.bxor(byte, bit32.rshift(byte, 1));
    return bit32.band(byte, 1);
end

-- 
-- get byte at position index
--
function aesutil.getByte(number, index)
    if (index == 0) then
        return bit32.band(number,0xff);
    else
        return bit32.band(bit32.rshift(number, index*8),0xff);
    end
end

--
-- put number into int at position index
--
function aesutil.putByte(number, index)
    if (index == 0) then
        return bit32.band(number,0xff);
    else
        return bit32.lshift(bit32.band(number,0xff),index*8);
    end
end

--
-- convert byte array to int array
--
function aesutil.bytesToInts(bytes, start, n)
    local ints = {};
    for i = 0, n - 1 do
        ints[i] = aesutil.putByte(bytes[start + (i*4)    ], 3)
                + aesutil.putByte(bytes[start + (i*4) + 1], 2) 
                + aesutil.putByte(bytes[start + (i*4) + 2], 1)    
                + aesutil.putByte(bytes[start + (i*4) + 3], 0);
    end
    return ints;
end

--
-- convert int array to byte array
--
function aesutil.intsToBytes(ints, output, outputOffset, n)
    n = n or #ints;
    for i = 0, n do
        for j = 0,3 do
            output[outputOffset + i*4 + (3 - j)] = aesutil.getByte(ints[i], j);
        end
    end
    return output;
end

--
-- convert bytes to hexString
--
function aesutil.bytesToHex(bytes)
    local hexBytes = "";
    for i,byte in ipairs(bytes) do 
        hexBytes = hexBytes .. string.format("%02x ", byte);
    end
    return hexBytes;
end

--
-- convert data to hex string
--
function aesutil.toHexString(data)
    local type = type(data);
    if (type == "number") then
        return string.format("%08x",data);
    elseif (type == "table") then
        return aesutil.bytesToHex(data);
    elseif (type == "string") then
        local bytes = {string.byte(data, 1, #data)}; 
        return aesutil.bytesToHex(bytes);
    else
        return data;
    end
end

function aesutil.xorIV(data, iv)
    for i = 1,16 do
        data[i] = bit32.bxor(data[i], iv[i]);
    end 
end

function aesutil.increment(data)
    local i = 16
    while true do
        local value = data[i] + 1
        if value >= 256 then
            data[i] = value - 256
            i = (i - 2) % 16 + 1
        else
            data[i] = value
            break
        end
    end
end

--------------------------------------------------------------------------------

aeslibgf = {
  _VERSION     = "gf.lua 0.2",
  _LICENSE     = [[
    aeslua: Lua AES implementation
    Copyright (c) 2006,2007 Matthias Hilbig

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU Lesser Public License as published by the
    Free Software Foundation; either version 2.1 of the License, or (at your
    option) any later version.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser Public License for more details.

    A copy of the terms and conditions of the license can be found in
    License.txt or online at

    http://www.gnu.org/copyleft/lesser.html

    To obtain a copy, write to the Free Software Foundation, Inc.,
    59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

    Author
    Matthias Hilbig
    http://homepages.upb.de/hilbig/aeslua/
    hilbig@upb.de 
  ]]
}

-- gf data of gf
aeslibgf.n = 0x100;
aeslibgf.ord = 0xff;
aeslibgf.irrPolynom = 0x11b;
aeslibgf.exp = {};
aeslibgf.log = {};

--
-- add two polynoms (its simply xor)
--
function aeslibgf.add(operand1, operand2) 
    return bit32.bxor(operand1,operand2);
end

-- 
-- subtract two polynoms (same as addition)
--
function aeslibgf.sub(operand1, operand2) 
    return bit32.bxor(operand1,operand2);
end

--
-- inverts element a^(-1) = g^(order - log(a))
--
function aeslibgf.invert(operand)
    -- special case for 1 
    if (operand == 1) then
        return 1;
    end;
    -- normal invert
    local exponent = aeslibgf.ord - aeslibgf.log[operand];
    return aeslibgf.exp[exponent];
end

--
-- multiply two elements using a logarithm table
-- a*b = g^(log(a)+log(b))
--
function aeslibgf.mul(operand1, operand2)
    if (operand1 == 0 or operand2 == 0) then
        return 0;
    end
    
    local exponent = aeslibgf.log[operand1] + aeslibgf.log[operand2];
    if (exponent >= aeslibgf.ord) then
        exponent = exponent - aeslibgf.ord;
    end
    return  aeslibgf.exp[exponent];
end

--
-- divide two elements
-- a/b = g^(log(a)-log(b))
--
function aeslibgf.div(operand1, operand2)
    if (operand1 == 0)  then
        return 0;
    end
    -- TODO: exception if operand2 == 0
    local exponent = aeslibgf.log[operand1] - aeslibgf.log[operand2];
    if (exponent < 0) then
        exponent = exponent + aeslibgf.ord;
    end
    return aeslibgf.exp[exponent];
end

--
-- print logarithmic table
--
function aeslibgf.printLog()
    for i = 1, aeslibgf.n do
        print("log(", i-1, ")=", aeslibgf.log[i-1]);
    end
end

--
-- print exponentiation table
--
function aeslibgf.printExp()
    for i = 1, aeslibgf.n do
        print("exp(", i-1, ")=", aeslibgf.exp[i-1]);
    end
end

--
-- calculate logarithmic and exponentiation table
--
function aeslibgf.initMulTable()
    local a = 1;
    for i = 0,aeslibgf.ord-1 do
        aeslibgf.exp[i] = a;
        aeslibgf.log[a] = i;
        -- multiply with generator x+1 -> left shift + 1    
        a = bit32.bxor(bit32.lshift(a, 1), a);
        -- if a gets larger than order, reduce modulo irreducible polynom
        if a > aeslibgf.ord then
            a = aeslibgf.sub(a, aeslibgf.irrPolynom);
        end
    end
end

aeslibgf.initMulTable();

--------------------------------------------------------------------------------

aeslibbuffer = {
  _VERSION     = "buffer.lua 0.2",
  _LICENSE     = [[
    aeslua: Lua AES implementation
    Copyright (c) 2006,2007 Matthias Hilbig

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU Lesser Public License as published by the
    Free Software Foundation; either version 2.1 of the License, or (at your
    option) any later version.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser Public License for more details.

    A copy of the terms and conditions of the license can be found in
    License.txt or online at

    http://www.gnu.org/copyleft/lesser.html

    To obtain a copy, write to the Free Software Foundation, Inc.,
    59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

    Author
    Matthias Hilbig
    http://homepages.upb.de/hilbig/aeslua/
    hilbig@upb.de 
  ]]
}

function aeslibbuffer.new()
  return {};
end

function aeslibbuffer.addString(stack, s)
  table.insert(stack, s)
  for i = #stack - 1, 1, -1 do
    if #stack[i] > #stack[i+1] then 
        break;
    end
    stack[i] = stack[i] .. table.remove(stack);
  end
end

function aeslibbuffer.toString(stack)
  for i = #stack - 1, 1, -1 do
    stack[i] = stack[i] .. table.remove(stack);
  end
  return stack[1];
end

--------------------------------------------------------------------------------

aes = {
  _VERSION     = "aes.lua 0.2",
  _LICENSE     = [[
    aeslua: Lua AES implementation
    Copyright (c) 2006,2007 Matthias Hilbig

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU Lesser Public License as published by the
    Free Software Foundation; either version 2.1 of the License, or (at your
    option) any later version.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser Public License for more details.

    A copy of the terms and conditions of the license can be found in
    License.txt or online at

    http://www.gnu.org/copyleft/lesser.html

    To obtain a copy, write to the Free Software Foundation, Inc.,
    59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

    Author
    Matthias Hilbig
    http://homepages.upb.de/hilbig/aeslua/
    hilbig@upb.de 
  ]]
}

-- some constants
aes.ROUNDS = "rounds";
aes.KEY_TYPE = "type";
aes.ENCRYPTION_KEY=1;
aes.DECRYPTION_KEY=2;

-- aes SBOX
aes.SBox = {};
aes.iSBox = {};

-- aes tables
aes.table0 = {};
aes.table1 = {};
aes.table2 = {};
aes.table3 = {};

aes.tableInv0 = {};
aes.tableInv1 = {};
aes.tableInv2 = {};
aes.tableInv3 = {};

-- round constants
aes.rCon = {0x01000000, 
            0x02000000, 
            0x04000000, 
            0x08000000, 
            0x10000000, 
            0x20000000, 
            0x40000000, 
            0x80000000, 
            0x1b000000, 
            0x36000000,
            0x6c000000,
            0xd8000000,
            0xab000000,
            0x4d000000,
            0x9a000000,
            0x2f000000};

--
-- affine transformation for calculating the S-Box of AES
--
function aes.affinMap(byte)
    mask = 0xf8;
    result = 0;
    for i = 1,8 do
        result = bit32.lshift(result,1);
        parity = aesutil.byteParity(bit32.band(byte,mask)); 
        result = result + parity
        -- simulate roll
        lastbit = bit32.band(mask, 1);
        mask = bit32.band(bit32.rshift(mask, 1),0xff);
        if (lastbit ~= 0) then
            mask = bit32.bor(mask, 0x80);
        else
            mask = bit32.band(mask, 0x7f);
        end
    end
    return bit32.bxor(result, 0x63);
end

--
-- calculate S-Box and inverse S-Box of AES
-- apply affine transformation to inverse in finite field 2^8 
--
function aes.calcSBox() 
    for i = 0, 255 do
    if (i ~= 0) then
        inverse = aeslibgf.invert(i);
    else
        inverse = i;
    end
        mapped = aes.affinMap(inverse);                 
        aes.SBox[i] = mapped;
        aes.iSBox[mapped] = i;
    end
end

--
-- Calculate round tables
-- round tables are used to calculate shiftRow, MixColumn and SubBytes 
-- with 4 table lookups and 4 xor operations.
--
function aes.calcRoundTables()
    for x = 0,255 do
        byte = aes.SBox[x];
        aes.table0[x] = aesutil.putByte(aeslibgf.mul(0x03, byte), 0)
                          + aesutil.putByte(             byte , 1)
                          + aesutil.putByte(             byte , 2)
                          + aesutil.putByte(aeslibgf.mul(0x02, byte), 3);
        aes.table1[x] = aesutil.putByte(             byte , 0)
                          + aesutil.putByte(             byte , 1)
                          + aesutil.putByte(aeslibgf.mul(0x02, byte), 2)
                          + aesutil.putByte(aeslibgf.mul(0x03, byte), 3);
        aes.table2[x] = aesutil.putByte(             byte , 0)
                          + aesutil.putByte(aeslibgf.mul(0x02, byte), 1)
                          + aesutil.putByte(aeslibgf.mul(0x03, byte), 2)
                          + aesutil.putByte(             byte , 3);
        aes.table3[x] = aesutil.putByte(aeslibgf.mul(0x02, byte), 0)
                          + aesutil.putByte(aeslibgf.mul(0x03, byte), 1)
                          + aesutil.putByte(             byte , 2)
                          + aesutil.putByte(             byte , 3);
    end
end

--
-- Calculate inverse round tables
-- does the inverse of the normal roundtables for the equivalent 
-- decryption algorithm.
--
function aes.calcInvRoundTables()
    for x = 0,255 do
        byte = aes.iSBox[x];
        aes.tableInv0[x] = aesutil.putByte(aeslibgf.mul(0x0b, byte), 0)
                             + aesutil.putByte(aeslibgf.mul(0x0d, byte), 1)
                             + aesutil.putByte(aeslibgf.mul(0x09, byte), 2)
                             + aesutil.putByte(aeslibgf.mul(0x0e, byte), 3);
        aes.tableInv1[x] = aesutil.putByte(aeslibgf.mul(0x0d, byte), 0)
                             + aesutil.putByte(aeslibgf.mul(0x09, byte), 1)
                             + aesutil.putByte(aeslibgf.mul(0x0e, byte), 2)
                             + aesutil.putByte(aeslibgf.mul(0x0b, byte), 3);
        aes.tableInv2[x] = aesutil.putByte(aeslibgf.mul(0x09, byte), 0)
                             + aesutil.putByte(aeslibgf.mul(0x0e, byte), 1)
                             + aesutil.putByte(aeslibgf.mul(0x0b, byte), 2)
                             + aesutil.putByte(aeslibgf.mul(0x0d, byte), 3);
        aes.tableInv3[x] = aesutil.putByte(aeslibgf.mul(0x0e, byte), 0)
                             + aesutil.putByte(aeslibgf.mul(0x0b, byte), 1)
                             + aesutil.putByte(aeslibgf.mul(0x0d, byte), 2)
                             + aesutil.putByte(aeslibgf.mul(0x09, byte), 3);
    end
end

--
-- rotate word: 0xaabbccdd gets 0xbbccddaa
-- used for key schedule
--
function aes.rotWord(word)
    local tmp = bit32.band(word,0xff000000);
    return (bit32.lshift(word,8) + bit32.rshift(tmp,24)) ;
end

--
-- replace all bytes in a word with the SBox.
-- used for key schedule
--
function aes.subWord(word)
    return aesutil.putByte(aes.SBox[aesutil.getByte(word,0)],0) 
         + aesutil.putByte(aes.SBox[aesutil.getByte(word,1)],1) 
         + aesutil.putByte(aes.SBox[aesutil.getByte(word,2)],2)
         + aesutil.putByte(aes.SBox[aesutil.getByte(word,3)],3);
end

--
-- generate key schedule for aes encryption
--
-- returns table with all round keys and
-- the necessary number of rounds saved in [aes.ROUNDS]
--
function aes.expandEncryptionKey(key)
    local keySchedule = {};
    local keyWords = math.floor(#key / 4);
    if ((keyWords ~= 4 and keyWords ~= 6 and keyWords ~= 8) or (keyWords * 4 ~= #key)) then
        print("Invalid key size: ", keyWords);
        return nil;
    end
    keySchedule[aes.ROUNDS] = keyWords + 6;
    keySchedule[aes.KEY_TYPE] = aes.ENCRYPTION_KEY;
    for i = 0,keyWords - 1 do
        keySchedule[i] = aesutil.putByte(key[i*4+1], 3) 
                       + aesutil.putByte(key[i*4+2], 2)
                       + aesutil.putByte(key[i*4+3], 1)
                       + aesutil.putByte(key[i*4+4], 0);  
    end
    for i = keyWords, (keySchedule[aes.ROUNDS] + 1)*4 - 1 do
        local tmp = keySchedule[i-1];
        if ( i % keyWords == 0) then
            tmp = aes.rotWord(tmp);
            tmp = aes.subWord(tmp);
            
            local index = math.floor(i/keyWords);
            tmp = bit32.bxor(tmp,aes.rCon[index]);
        elseif (keyWords > 6 and i % keyWords == 4) then
            tmp = aes.subWord(tmp);
        end
        keySchedule[i] = bit32.bxor(keySchedule[(i-keyWords)],tmp);
    end
    return keySchedule;
end

--
-- Inverse mix column
-- used for key schedule of decryption key
--
function aes.invMixColumnOld(word)
    local b0 = aesutil.getByte(word,3);
    local b1 = aesutil.getByte(word,2);
    local b2 = aesutil.getByte(word,1);
    local b3 = aesutil.getByte(word,0);
    return aesutil.putByte(aeslibgf.add(aeslibgf.add(aeslibgf.add(aeslibgf.mul(0x0b, b1), 
                                             aeslibgf.mul(0x0d, b2)), 
                                             aeslibgf.mul(0x09, b3)), 
                                             aeslibgf.mul(0x0e, b0)),3)
         + aesutil.putByte(aeslibgf.add(aeslibgf.add(aeslibgf.add(aeslibgf.mul(0x0b, b2), 
                                             aeslibgf.mul(0x0d, b3)), 
                                             aeslibgf.mul(0x09, b0)), 
                                             aeslibgf.mul(0x0e, b1)),2)
         + aesutil.putByte(aeslibgf.add(aeslibgf.add(aeslibgf.add(aeslibgf.mul(0x0b, b3), 
                                             aeslibgf.mul(0x0d, b0)), 
                                             aeslibgf.mul(0x09, b1)), 
                                             aeslibgf.mul(0x0e, b2)),1)
         + aesutil.putByte(aeslibgf.add(aeslibgf.add(aeslibgf.add(aeslibgf.mul(0x0b, b0), 
                                             aeslibgf.mul(0x0d, b1)), 
                                             aeslibgf.mul(0x09, b2)), 
                                             aeslibgf.mul(0x0e, b3)),0);
end

-- 
-- Optimized inverse mix column
-- look at http://fp.gladman.plus.com/cryptography_technology/rijndael/aes.spec.311.pdf
-- TODO: make it work
--
function aes.invMixColumn(word)
    local b0 = aesutil.getByte(word,3);
    local b1 = aesutil.getByte(word,2);
    local b2 = aesutil.getByte(word,1);
    local b3 = aesutil.getByte(word,0);
    local t = bit32.bxor(b3,b2);
    local u = bit32.bxor(b1,b0);
    local v = bit32.bxor(t,u);
    v = bit32.bxor(v,aeslibgf.mul(0x08,v));
    w = bit32.bxor(v,aeslibgf.mul(0x04, bit32.bxor(b2,b0)));
    v = bit32.bxor(v,aeslibgf.mul(0x04, bit32.bxor(b3,b1)));
    return aesutil.putByte( bit32.bxor(bit32.bxor(b3,v), aeslibgf.mul(0x02, bit32.bxor(b0,b3))), 0)
         + aesutil.putByte( bit32.bxor(bit32.bxor(b2,w), aeslibgf.mul(0x02, t              )), 1)
         + aesutil.putByte( bit32.bxor(bit32.bxor(b1,v), aeslibgf.mul(0x02, bit32.bxor(b0,b3))), 2)
         + aesutil.putByte( bit32.bxor(bit32.bxor(b0,w), aeslibgf.mul(0x02, u              )), 3);
end

--
-- generate key schedule for aes decryption
--
-- uses key schedule for aes encryption and transforms each
-- key by inverse mix column. 
--
function aes.expandDecryptionKey(key)
    local keySchedule = aes.expandEncryptionKey(key);
    if (keySchedule == nil) then
        return nil;
    end
    keySchedule[aes.KEY_TYPE] = aes.DECRYPTION_KEY;    
    for i = 4, (keySchedule[aes.ROUNDS] + 1)*4 - 5 do
        keySchedule[i] = aes.invMixColumnOld(keySchedule[i]);
    end
    return keySchedule;
end

--
-- xor round key to state
--
function aes.addRoundKey(state, key, round)
    for i = 0, 3 do
        state[i] = bit32.bxor(state[i], key[round*4+i]);
    end
end

--
-- do encryption round (ShiftRow, SubBytes, MixColumn together)
--
function aes.doRound(origState, dstState)
    dstState[0] =  bit32.bxor(bit32.bxor(bit32.bxor(
                aes.table0[aesutil.getByte(origState[0],3)],
                aes.table1[aesutil.getByte(origState[1],2)]),
                aes.table2[aesutil.getByte(origState[2],1)]),
                aes.table3[aesutil.getByte(origState[3],0)]);

    dstState[1] =  bit32.bxor(bit32.bxor(bit32.bxor(
                aes.table0[aesutil.getByte(origState[1],3)],
                aes.table1[aesutil.getByte(origState[2],2)]),
                aes.table2[aesutil.getByte(origState[3],1)]),
                aes.table3[aesutil.getByte(origState[0],0)]);
    
    dstState[2] =  bit32.bxor(bit32.bxor(bit32.bxor(
                aes.table0[aesutil.getByte(origState[2],3)],
                aes.table1[aesutil.getByte(origState[3],2)]),
                aes.table2[aesutil.getByte(origState[0],1)]),
                aes.table3[aesutil.getByte(origState[1],0)]);
    
    dstState[3] =  bit32.bxor(bit32.bxor(bit32.bxor(
                aes.table0[aesutil.getByte(origState[3],3)],
                aes.table1[aesutil.getByte(origState[0],2)]),
                aes.table2[aesutil.getByte(origState[1],1)]),
                aes.table3[aesutil.getByte(origState[2],0)]);
end

--
-- do last encryption round (ShiftRow and SubBytes)
--
function aes.doLastRound(origState, dstState)
    dstState[0] = aesutil.putByte(aes.SBox[aesutil.getByte(origState[0],3)], 3)
                + aesutil.putByte(aes.SBox[aesutil.getByte(origState[1],2)], 2)
                + aesutil.putByte(aes.SBox[aesutil.getByte(origState[2],1)], 1)
                + aesutil.putByte(aes.SBox[aesutil.getByte(origState[3],0)], 0);

    dstState[1] = aesutil.putByte(aes.SBox[aesutil.getByte(origState[1],3)], 3)
                + aesutil.putByte(aes.SBox[aesutil.getByte(origState[2],2)], 2)
                + aesutil.putByte(aes.SBox[aesutil.getByte(origState[3],1)], 1)
                + aesutil.putByte(aes.SBox[aesutil.getByte(origState[0],0)], 0);

    dstState[2] = aesutil.putByte(aes.SBox[aesutil.getByte(origState[2],3)], 3)
                + aesutil.putByte(aes.SBox[aesutil.getByte(origState[3],2)], 2)
                + aesutil.putByte(aes.SBox[aesutil.getByte(origState[0],1)], 1)
                + aesutil.putByte(aes.SBox[aesutil.getByte(origState[1],0)], 0);

    dstState[3] = aesutil.putByte(aes.SBox[aesutil.getByte(origState[3],3)], 3)
                + aesutil.putByte(aes.SBox[aesutil.getByte(origState[0],2)], 2)
                + aesutil.putByte(aes.SBox[aesutil.getByte(origState[1],1)], 1)
                + aesutil.putByte(aes.SBox[aesutil.getByte(origState[2],0)], 0);
end

--
-- do decryption round 
--
function aes.doInvRound(origState, dstState)
    dstState[0] =  bit32.bxor(bit32.bxor(bit32.bxor(
                aes.tableInv0[aesutil.getByte(origState[0],3)],
                aes.tableInv1[aesutil.getByte(origState[3],2)]),
                aes.tableInv2[aesutil.getByte(origState[2],1)]),
                aes.tableInv3[aesutil.getByte(origState[1],0)]);

    dstState[1] =  bit32.bxor(bit32.bxor(bit32.bxor(
                aes.tableInv0[aesutil.getByte(origState[1],3)],
                aes.tableInv1[aesutil.getByte(origState[0],2)]),
                aes.tableInv2[aesutil.getByte(origState[3],1)]),
                aes.tableInv3[aesutil.getByte(origState[2],0)]);
    
    dstState[2] =  bit32.bxor(bit32.bxor(bit32.bxor(
                aes.tableInv0[aesutil.getByte(origState[2],3)],
                aes.tableInv1[aesutil.getByte(origState[1],2)]),
                aes.tableInv2[aesutil.getByte(origState[0],1)]),
                aes.tableInv3[aesutil.getByte(origState[3],0)]);
    
    dstState[3] =  bit32.bxor(bit32.bxor(bit32.bxor(
                aes.tableInv0[aesutil.getByte(origState[3],3)],
                aes.tableInv1[aesutil.getByte(origState[2],2)]),
                aes.tableInv2[aesutil.getByte(origState[1],1)]),
                aes.tableInv3[aesutil.getByte(origState[0],0)]);
end

--
-- do last decryption round
--
function aes.doInvLastRound(origState, dstState)
    dstState[0] = aesutil.putByte(aes.iSBox[aesutil.getByte(origState[0],3)], 3)
                + aesutil.putByte(aes.iSBox[aesutil.getByte(origState[3],2)], 2)
                + aesutil.putByte(aes.iSBox[aesutil.getByte(origState[2],1)], 1)
                + aesutil.putByte(aes.iSBox[aesutil.getByte(origState[1],0)], 0);

    dstState[1] = aesutil.putByte(aes.iSBox[aesutil.getByte(origState[1],3)], 3)
                + aesutil.putByte(aes.iSBox[aesutil.getByte(origState[0],2)], 2)
                + aesutil.putByte(aes.iSBox[aesutil.getByte(origState[3],1)], 1)
                + aesutil.putByte(aes.iSBox[aesutil.getByte(origState[2],0)], 0);

    dstState[2] = aesutil.putByte(aes.iSBox[aesutil.getByte(origState[2],3)], 3)
                + aesutil.putByte(aes.iSBox[aesutil.getByte(origState[1],2)], 2)
                + aesutil.putByte(aes.iSBox[aesutil.getByte(origState[0],1)], 1)
                + aesutil.putByte(aes.iSBox[aesutil.getByte(origState[3],0)], 0);

    dstState[3] = aesutil.putByte(aes.iSBox[aesutil.getByte(origState[3],3)], 3)
                + aesutil.putByte(aes.iSBox[aesutil.getByte(origState[2],2)], 2)
                + aesutil.putByte(aes.iSBox[aesutil.getByte(origState[1],1)], 1)
                + aesutil.putByte(aes.iSBox[aesutil.getByte(origState[0],0)], 0);
end

--
-- encrypts 16 Bytes
-- key           encryption key schedule
-- input         array with input data
-- inputOffset   start index for input
-- output        array for encrypted data
-- outputOffset  start index for output
--
function aes.encrypt(key, input, inputOffset, output, outputOffset) 
    --default parameters
    inputOffset = inputOffset or 1;
    output = output or {};
    outputOffset = outputOffset or 1;
    local state = {};
    local tmpState = {};
    if (key[aes.KEY_TYPE] ~= aes.ENCRYPTION_KEY) then
        print("No encryption key: ", key[aes.KEY_TYPE]);
        return;
    end
    state = aesutil.bytesToInts(input, inputOffset, 4);
    aes.addRoundKey(state, key, 0);
    local round = 1;
    while (round < key[aes.ROUNDS] - 1) do
        -- do a double round to save temporary assignments
        aes.doRound(state, tmpState);
        aes.addRoundKey(tmpState, key, round);
        round = round + 1;
        aes.doRound(tmpState, state);
        aes.addRoundKey(state, key, round);
        round = round + 1;
    end
    aes.doRound(state, tmpState);
    aes.addRoundKey(tmpState, key, round);
    round = round +1;
    aes.doLastRound(tmpState, state);
    aes.addRoundKey(state, key, round);
    return aesutil.intsToBytes(state, output, outputOffset);
end

--
-- decrypt 16 bytes
-- key           decryption key schedule
-- input         array with input data
-- inputOffset   start index for input
-- output        array for decrypted data
-- outputOffset  start index for output
---
function aes.decrypt(key, input, inputOffset, output, outputOffset) 
    -- default arguments
    inputOffset = inputOffset or 1;
    output = output or {};
    outputOffset = outputOffset or 1;
    local state = {};
    local tmpState = {};
    if (key[aes.KEY_TYPE] ~= aes.DECRYPTION_KEY) then
        print("No decryption key: ", key[aes.KEY_TYPE]);
        return;
    end
    state = aesutil.bytesToInts(input, inputOffset, 4);
    aes.addRoundKey(state, key, key[aes.ROUNDS]);
    local round = key[aes.ROUNDS] - 1;
    while (round > 2) do
        -- do a double round to save temporary assignments
        aes.doInvRound(state, tmpState);
        aes.addRoundKey(tmpState, key, round);
        round = round - 1;

        aes.doInvRound(tmpState, state);
        aes.addRoundKey(state, key, round);
        round = round - 1;
    end
    aes.doInvRound(state, tmpState);
    aes.addRoundKey(tmpState, key, round);
    round = round - 1;
    aes.doInvLastRound(tmpState, state);
    aes.addRoundKey(state, key, round);
    return aesutil.intsToBytes(state, output, outputOffset);
end

-- calculate all tables when loading this file
aes.calcSBox();
aes.calcRoundTables();
aes.calcInvRoundTables();

--------------------------------------------------------------------------------

ciphermode = {
  _VERSION     = "ciphermode.lua 0.2",
  _LICENSE     = [[
    aeslua: Lua AES implementation
    Copyright (c) 2006,2007 Matthias Hilbig

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU Lesser Public License as published by the
    Free Software Foundation; either version 2.1 of the License, or (at your
    option) any later version.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser Public License for more details.

    A copy of the terms and conditions of the license can be found in
    License.txt or online at

    http://www.gnu.org/copyleft/lesser.html

    To obtain a copy, write to the Free Software Foundation, Inc.,
    59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

    Author
    Matthias Hilbig
    http://homepages.upb.de/hilbig/aeslua/
    hilbig@upb.de 
  ]]
}

--
-- Encrypt strings
-- key - byte array with key
-- string - string to encrypt
-- modefunction - function for cipher mode to use
-- iv - optional iv for modefunction
--
function ciphermode.encryptString(key, data, modeFunction, iv)
    if iv then
        local ivCopy = {}
        for i = 1, 16 do ivCopy[i] = iv[i] end
        iv = ivCopy
    else
        iv = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
    end
    local keySched = aes.expandEncryptionKey(key)
    local encryptedData = aeslibbuffer.new()
    for i = 1, #data/16 do
        local offset = (i-1)*16 + 1
        local byteData = {string.byte(data,offset,offset +15)}
        iv = modeFunction(keySched, byteData, iv)
        aeslibbuffer.addString(encryptedData, string.char(unpack(byteData)))
    end
    return aeslibbuffer.toString(encryptedData)
end

--
-- the following 4 functions can be used as 
-- modefunction for encryptString
--
function ciphermode.encryptECB(keySched, byteData, iv) 
    aes.encrypt(keySched, byteData, 1, byteData, 1)
end

-- Cipher block chaining mode encrypt function
function ciphermode.encryptCBC(keySched, byteData, iv)
    aesutil.xorIV(byteData, iv)
    aes.encrypt(keySched, byteData, 1, byteData, 1)
    return byteData
end

-- Output feedback mode encrypt function
function ciphermode.encryptOFB(keySched, byteData, iv)
    aes.encrypt(keySched, iv, 1, iv, 1)
    aesutil.xorIV(byteData, iv)
    return iv
end

-- Cipher feedback mode encrypt function
function ciphermode.encryptCFB(keySched, byteData, iv) 
    aes.encrypt(keySched, iv, 1, iv, 1)
    aesutil.xorIV(byteData, iv)
    return byteData       
end

function ciphermode.encryptCTR(keySched, byteData, iv)
    local nextIV = {}
    for j = 1, 16 do nextIV[j] = iv[j] end
    aes.encrypt(keySched, iv, 1, iv, 1)
    aesutil.xorIV(byteData, iv)
    aesutil.increment(nextIV)
    return nextIV
end

--
-- Decrypt strings
-- key - byte array with key
-- string - string to decrypt
-- modefunction - function for cipher mode to use
-- iv - optional iv for modefunction
--
function ciphermode.decryptString(key, data, modeFunction, iv)
    if iv then
        local ivCopy = {}
        for i = 1, 16 do ivCopy[i] = iv[i] end
        iv = ivCopy
    else
        iv = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
    end
    local keySched
    if (modeFunction == ciphermode.decryptOFB or modeFunction == ciphermode.decryptCFB or modeFunction == ciphermode.decryptCTR) then
        keySched = aes.expandEncryptionKey(key)
    else
        keySched = aes.expandDecryptionKey(key)
    end
    local decryptedData = aeslibbuffer.new()
    for i = 1, #data/16 do
        local offset = (i-1)*16 + 1
        local byteData = {string.byte(data,offset,offset +15)}
        iv = modeFunction(keySched, byteData, iv)
        aeslibbuffer.addString(decryptedData, string.char(unpack(byteData)))
    end
    return aeslibbuffer.toString(decryptedData)
end

--
-- the following 4 functions can be used as 
-- modefunction for decryptString
--
function ciphermode.decryptECB(keySched, byteData, iv)
    aes.decrypt(keySched, byteData, 1, byteData, 1)
    return iv
end

-- Cipher block chaining mode decrypt function
function ciphermode.decryptCBC(keySched, byteData, iv)
    local nextIV = {}
    for j = 1, 16 do nextIV[j] = byteData[j] end
    aes.decrypt(keySched, byteData, 1, byteData, 1)
    aesutil.xorIV(byteData, iv)
    return nextIV
end

-- Output feedback mode decrypt function
function ciphermode.decryptOFB(keySched, byteData, iv)
    aes.encrypt(keySched, iv, 1, iv, 1)
    aesutil.xorIV(byteData, iv)
    return iv
end

-- Cipher feedback mode decrypt function
function ciphermode.decryptCFB(keySched, byteData, iv)
    local nextIV = {}
    for j = 1, 16 do nextIV[j] = byteData[j] end
    aes.encrypt(keySched, iv, 1, iv, 1)
    aesutil.xorIV(byteData, iv)
    return nextIV
end

ciphermode.decryptCTR = ciphermode.encryptCTR

--------------------------------------------- end of lib --------------------------------------------- 
