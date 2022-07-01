--[[
TQAE - Tiny QuickApp emulator for the Fibaro Home Center 3
Copyright (c) 2021 Jan Gabrielsson
Email: jan@gabrielsson.com
MIT License

Class support, mimicking LuaBind's class implementation

--]]
local setmetatable = hc3_emulator.setmetatable
local rawset = hc3_emulator.rawset
local rawget = hc3_emulator.rawget

--[[
local metas = {}
for _,m in ipairs({
    "__add","__sub","__mul","__div","__mod","__pow","__unm","__idiv","__band","__bor",
    "__bxor","__bnot","__shl","__shr","__concat","__len","__eq","__lt","__le","__call",
    "__tostring"
    }) do
  metas[m]=true
end

function property(get,set)
  assert(type(get)=='function' and type(set)=="function","Property need function set and get")
  return {['%CLASSPROP%']=true, get=get, set=set}
end

local function trapIndex(props,cmt,obj)
  function cmt.__index(_,key)
    if props[key] then return props[key].get(obj) else return rawget(obj,key) end
  end
  function cmt.__newindex(_,key,val)
    if props[key] then return props[key].set(obj,val) else return rawset(obj,key,val) end
  end
end

function class(name)    -- Version that tries to avoid __index & __newindex to make debugging easier
  local cl,mt,cmt,props,parent= {['_TYPE']='userdata'},{},{},{}  -- We still try to be Luabind class compatible
  function cl.__copyObject(clo,obj)
    for k,v in pairs(clo) do if metas[k] then cmt[k]=v else obj[k]=v end end
    return obj,cmt
  end
  function mt.__call(tab,...)        -- Instantiation  <name>(...)
    local obj,cmt = tab.__copyObject(tab,tab.__obj or {}) tab.__obj = nil
    if not tab.__init then error("Class "..name.." missing initialiser") end
    tab.__init(obj,...)
    local trapF = false
    for k,v in pairs(obj) do
      if type(v)=='table' and v['%CLASSPROP%'] then obj[k],props[k]=nil,v; trapF = true end
    end
    if trapF then trapIndex(props,cmt,obj) end
    local str = "Object "..name..":"..tostring(obj):match("%s(.*)")
    if obj.__tostring then cmt.__tostring = obj.__tostring end
    setmetatable(obj,cmt)
    obj._CLASS=name
    return obj
  end
  function mt:__tostring() local _=self return "class "..name end
  setmetatable(cl,mt)
  _ENV[name] = cl
  return function(p) -- Class creation -- class <name>
    parent = p 
    if parent then parent.__copyObject(parent,cl) end
  end 
end
--]]
local class2 = {}
local classes = {}
local isofclass = {}

local fmt = string.format
local function assertf(test,fm,...) if not test then error(fmt(fm,...),2) end end

-- create a constructor table
local function constructortbl(metatable)
  local ct = {}
  setmetatable(ct, {
      __index=metatable,
      __newindex=metatable,
      --     __metatable=metatable,
      __call=function(self, ...)
        return self.new(...)
      end,
      __tostring=function(self) return "class "..self.__typename end
    })
  return ct
end

local function isClass(c)
  return type(c)=='table' and classes[c.__typename or ""]
end

function property(get,set)
  assert(type(get)=='function' and type(set)=="function","Property need function set and get")
  return {['%CLASSPROP%']=true, get=get, set=set}
end

local function trapIndex(props,clss,obj)
  function clss.__index(_,key)
    if props[key] then return props[key].get(obj) 
    else
      local v = rawget(obj,key)
      if v~=nil then 
        return v 
      else 
        local mt = getmetatable(obj) 
        if mt then return mt[key] else return nil end
      end
    end
  end
  function clss.__newindex(_,key,val)
    if props[key] then return props[key].set(obj,val) else return rawset(obj,key,val) end
  end
end

class2.new = function(name, parent)
  local class = { __typename = name }
  local _str = fmt("object[%s:%%s]",name)

  assertf(not classes[name], "class <%s> already exists", name)

  class.__index = class
  class.__tostring = function(obj) return fmt(_str,obj.___id) end

  class.__factory =
  function()
    local self = {}
    self.___id = tostring(self):match("x(.*)") or "99"
    setmetatable(self, class)
    return self
  end

  class.new =
  function(...)
    local self = class.__factory()
    assertf(self.__init,"Missing initializer for %s",name)
    self:__init(...)
    local trapF,props = false,{}
    for k,v in pairs(self) do
      if type(v)=='table' and v['%CLASSPROP%'] then self[k],props[k]=nil,v; trapF = true end
    end
    if trapF then trapIndex(props,class,self) end
    return self
  end

  classes[name] = class
  isofclass[name] = {[name]=true}

  if parent then
    assertf(isClass(parent), "parent class does not exist for class %s", name)
    local parentname = parent.__typename

    _G[name] = constructortbl(class)
    setmetatable(class, classes[parentname])
    --print('setmetatable',name,_str,parent)
  else
    _G[name] =  constructortbl(class)
    --print(name,_str)
  end
  return _G[name]
end

class2.factory = function(name)
  assert(classes[name], string.format('unknown class <%s>', name))
  return class[name].__factory()
end

class2.metatable = function(name)
  return classes[name]
end

-- allow class() instead of class.new()
setmetatable(class2, { 
    __call = function(self, ...)
      return self.new(...)
    end
  })

-------------------------------------

local metas = {
  "__add","__sub","__mul","__div","__mod","__pow","__unm","__idiv","__band","__bor",
  "__bxor","__bnot","__shl","__shr","__concat","__len","__eq","__lt","__le","__call",
  "__tostring"
}
function class(name)
  class2(name)
  return function(parent)
    assertf(parent,"Missing parent for %s",name)
    setmetatable(classes[name],classes[parent.__typename])
    local c,p = _G[name],classes[parent.__typename]
    for _,k in ipairs(metas) do
      if p[k] and rawget(c,k)==nil then 
        c[k]=p[k] 
      end
    end
  end
end