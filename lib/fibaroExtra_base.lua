_MODULES = _MODULES or {} -- Global
_MODULES.base={ author = "jan@gabrielsson.com", version = '0.4', init = function()
    fibaro.FIBARO_EXTRA = "v0.959"
    fibaro.debugFlags  = fibaro.debugFlags or { modules=false }
    fibaro.utils = {}
    _MODULES.base._inited=true
    local debugFlags = fibaro.debugFlags
    
    function fibaro.printf(fmt,...) print(string.format(fmt,...)) end
    fibaro.printf("fibaroExtra %s, ©%s",fibaro.FIBARO_EXTRA,"jan@gabrielsson.com")
    function fibaro.protectFun(fun,f,level)
      return function(...)
        local stat,res = pcall(fun,...)
        if not stat then
          res = res:gsub("fibaroExtra.lua:%d+:","").."("..f..")"
          error(res,level) 
        else return res end
      end
    end
    function fibaro.utils.asserts(cond, ...)
      if not cond then error("assertion failed!: " .. string.format(...), 2) end
    end

    local function copy(obj)
      if type(obj) == 'table' then
        local res = {} for k,v in pairs(obj) do res[k] = copy(v) end
        return res
      else return obj end
    end

    local function equal(e1,e2)
      if e1==e2 then return true
      else
        if type(e1) ~= 'table' or type(e2) ~= 'table' then return false
        else
          for k1,v1 in pairs(e1) do if e2[k1] == nil or not equal(v1,e2[k1]) then return false end end
          for k2,_  in pairs(e2) do if e1[k2] == nil then return false end end
          return true
        end
      end
    end

    if not table.maxn then 
      function table.maxn(tbl) local c=0 for _ in pairs(tbl) do c=c+1 end return c end
    end

    function table.member(k,tab) for i,v in ipairs(tab) do if equal(v,k) then return i end end return false end
    function table.map(f,l,s) s = s or 1; local r,m={},table.maxn(l) for i=s,m do r[#r+1] = f(l[i]) end return r end
    function table.mapf(f,l,s) s = s or 1; local e=true for i=s,table.maxn(l) do e = f(l[i]) end return e end
    function table.delete(k,tab) local i = table.member(tab,k); if i then table.remove(tab,i) return i end end
    table.equal,table.copy = equal,copy

    local old_tostring = tostring
    fibaro._orgToString = old_tostring
    if hc3_emulator then
      function tostring(obj)
        if type(obj)=='table' and not hc3_emulator.getmetatable(obj) then
          if obj.__tostring then return obj.__tostring(obj) 
          elseif debugFlags.json then return json.encodeFast and json.encodeFast(obj) or json.encode(obj)  end
        end
        return old_tostring(obj)
      end
    else
      function tostring(obj)
        if type(obj)=='table' then
          if obj.__tostring then return obj.__tostring(obj) 
          elseif debugFlags.json then return json.encodeFast and json.encodeFast(obj) or json.encode(obj)  end
        end
        return old_tostring(obj)
      end
    end

    local _init,_onInit = QuickApp.__init

    local function initQA(selfv)
      local dev = __fibaro_get_device(selfv.id)
      if not dev.enabled then
        if fibaro.__disabled then pcall(fibaro.__disabled,selfv) end
        selfv:debug("QA ",selfv.name," disabled")
        return 
      end
      for m,_ in pairs(_MODULES or {}) do fibaro.loadModule(m) end
      selfv.config = {}
      for _,v in ipairs(dev.properties.quickAppVariables or {}) do
        if v.value ~= "" then selfv.config[v.name] = v.value end
      end
      quickApp = selfv
      if _onInit then _onInit(selfv) end
    end

    function QuickApp.__init(self,...) -- We hijack the __init methods so we can control users :onInit() method
      _onInit = self.onInit
      self.onInit = initQA
      _init(self,...)
    end

    function fibaro.loadModule(name)
      local m = _MODULES[name]
      assert(m,"Module "..tostring(name).." doesn't exist")
      if not m._inited then m._inited=true m.init() 
        if fibaro.debugFlags.modules then fibaro.printf("Loaded %s, v%s, ©%s",name,m.version,m.author) end 
      end
    end
  end
} -- Base
if not _MODULES.base._inited then _MODULES.base.init() end

