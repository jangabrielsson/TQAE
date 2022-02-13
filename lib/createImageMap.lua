local outputFile = "test/map/imageFile.lua"
local rows = 2
local code

lfs = require('lfs')

local function getFiles(path)
  local res={}
  for file in lfs.dir(path) do
    if file ~= "." and file ~= ".." and file:match("%.png") then
      res[#res+1]=path..file
    end
  end
  return res
end

local function base64encode(data)
  local bC='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  return ((data:gsub('.', function(x) 
          local r,b='',x:byte() for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
          return r;
        end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return bC:sub(c+1,c+1)
      end)..({ '', '==', '=' })[#data%3+1])
end

local function getSize(b)
  local buf = {}
  for i=1,8 do buf[i]=b:byte(16+i) end
  local width = (buf[1] << 24) + (buf[2] << 16) + (buf[3] << 8) + (buf[4] << 0)
  local height = (buf[5] << 24) + (buf[6] << 16) + (buf[7] << 8) + (buf[8] << 0);
  return width,height
end

local function dump(fo,i,tag,name)
  local f = io.open(name,"rb")
  local data = f:read("*all")
  f:close()
  local b,width,height = base64encode(data),getSize(data)
  print(string.format("%s, width:%s, height:%s",name,width,height))
  fo:write(string.format("k%s_%s = {im='%s',width=%s,hight=%s},\n",tag,i,b,width,height))
end

code = [[
class 'ImageMap'
local width

function ImageMap:__init(width)
   width=width
   self.rows = rows
   self.map = {}
   self.tiles = {}
   for k,p in pairs(images) do
     local tag,i = k:match("k(%w+)_(%d+)")
     i=tonumber(i)
     self.tiles[tag] = self.tiles[tag] or {}
     self.tiles[tag][i]=p
   end
   local s=nil
   for tag,p in pairs(self.tiles) do
      if s == nil then s=#p
      elseif s~=#p then error("Rows must have same number of columns") end
      for _,e in ipairs(p) do e.tag=tag end
   end
   self.columns = s//rows
   if not(self.tiles['base'] or self.tiles['0']) then error("Missing 'base' or '0' tiles") end
   local base = self.tiles['base'] and "base" or "0"
   local w = 0
   for _,e in ipairs(self.tiles[base]) do w=w+e.width end
   print(w)
   self.scale=width/w
   self:setTag(base)
end

local function createBuff()
    local  self,res = {},{}
    self.res=res
    function self.add(str) res[#res+1]=str end
    function self.pr(f,...) res[#res+1]=string.format(f,...) end
    function self.render() return table.concat(res) end
    return self
end

function ImageMap:render()
   local b = createBuff()
   b.add("<div>")
   for i=1,#self.map do
     b.pr('<img src="data:image/png;base64,%s" crossorigin="anonymous" width="%s" height="%s" align="left"  border="1">',
     self.map[i].im,
     math.floor(self.scale*self.map[i].width),
     math.floor(self.scale*self.map[i].hight))
   end
   table.insert(b.res,self.columns+2,"</br>")
   b.add("</div>")
   return b.render()
end

function ImageMap:getSize() return self.rows,self.columns end

function ImageMap:setTile(row,col,tag)
    assert(row>0 and row <= self.rows and col>0 and col <= self.columns,"map index out of range")
    assert(self.tiles[tag],"Unknown map tag")
   self.map[(row-1)*self.rows+col] = self.tiles[tag][(row-1)*self.rows+col]
end

function ImageMap:getTile(row,col)
    assert(row>0 and row <= self.rows and col>0 and col <= self.columns,"map index out of range")
    return self.map[(row-1)*self.rows+col]
end

function ImageMap:setTag(tag)
    assert(self.tiles[tag],"Unknown map tag")
    for i=1,#self.tiles[tag] do 
      self.map[i] = self.tiles[tag][i]
    end
end
]]

local fo = io.open(outputFile,"w")
fo:write("local rows="..rows.."\n")
fo:write("local images={\n")
for _,p in ipairs(getFiles(outputFile:match("(.*/)"))) do
  local i,tag = p:match("(%d+)_(%w+)%.png")
  if i then dump(fo,i,tag,p)
  else print("Unknown file ",p) end
end
fo:write("\n}\n")
fo:write(code)
fo:close()
