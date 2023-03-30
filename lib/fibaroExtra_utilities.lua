_MODULES = _MODULES or {} -- Global
_MODULES.utilities={ author = "jan@gabrielsson.com", version = '0.4', init = function()
    local _,utils,format = fibaro.debugFlags,fibaro.utils,string.format

    local _,copy = table.member,table.copy

    function table.copyShallow(t)
      if type(t)=='table' then
        local r={}; for k,v in pairs(t) do r[k]=v end 
        return r 
      else return t end
    end

    function table.mapAnd(f,l,s) s = s or 1; local e=true for i=s,table.maxn(l) do e = f(l[i]) if not e then return false end end return e end 
    function table.mapOr(f,l,s) s = s or 1; for i=s,table.maxn(l) do local e = f(l[i]) if e then return e end end return false end
    function table.reduce(f,l) local r = {}; for _,e in ipairs(l) do if f(e) then r[#r+1]=e end end; return r end
    function table.mapk(f,l) local r={}; for k,v in pairs(l) do r[k]=f(v) end; return r end
    function table.mapkv(f,l) local r={}; for k,v in pairs(l) do k,v=f(k,v) if k then r[k]=v end end; return r end
    function table.mapkl(f,l) local r={} for i,j in pairs(l) do r[#r+1]=f(i,j) end return r end
    function table.size(l) local n=0; for _,_ in pairs(l) do n=n+1 end return n end 

    function table.keyMerge(t1,t2)
      local res = copy(t1)
      for k,v in pairs(t2) do if t1[k]==nil then t1[k]=v end end
      return res
    end

    function table.keyIntersect(t1,t2)
      local res = {}
      for k,v in pairs(t1) do if t2[k] then res[k]=v end end
      return res
    end

    function table.zip(fun,a,b,c,d) 
      local res = {}
      for i=1,math.max(#a,#b) do res[#res+1] = fun(a[i],b[i],c and c[i],d and d[i]) end
      return res
    end

    for _,m in ipairs({"equal","copy","shallowCopy","member","delete","map","mapf","mapAnd","mapOr","reduce",
        "mapk","mapkv","size","keyMerge","keyIntersect","zip"}) do 
      utils[m]=table[m] 
    end

    function utils.gensym(s) return (s or "G")..fibaro._orgToString({}):match("%s(.*)") end

    function urlencode(str) -- very useful
      if str then
        str = str:gsub("\n", "\r\n")
        str = str:gsub("([^%w %-%_%.%~])", function(c)
            return ("%%%02X"):format(string.byte(c))
          end)
        str = str:gsub(" ", "%%20")
      end
      return str	
    end

    do
      local sortKeys = {"type","device","deviceID","value","oldValue","val","key","arg","event","events","msg","res"}
      local sortOrder={}
      for i,s in ipairs(sortKeys) do sortOrder[s]="\n"..string.char(i+64).." "..s end
      local function keyCompare(a,b)
        local av,bv = sortOrder[a] or a, sortOrder[b] or b
        return av < bv
      end

      -- our own json encode, as we don't have 'pure' json structs, and sorts keys in order (i.e. "stable" output)
      local function prettyJsonFlat(e0) 
        local res,seen = {},{}
        local function pretty(e)
          local t = type(e)
          if t == 'string' then res[#res+1] = '"' res[#res+1] = e res[#res+1] = '"'
          elseif t == 'number' then res[#res+1] = e
          elseif t == 'boolean' or t == 'function' or t=='thread' or t=='userdata' then res[#res+1] = tostring(e)
          elseif t == 'table' then
            if next(e)==nil then res[#res+1]='{}'
            elseif seen[e] then res[#res+1]="..rec.."
            elseif e[1] or #e>0 then
              seen[e]=true
              res[#res+1] = "[" pretty(e[1])
              for i=2,#e do res[#res+1] = "," pretty(e[i]) end
              res[#res+1] = "]"
            else
              seen[e]=true
              if e._var_  then res[#res+1] = format('"%s"',e._str) return end
              local k = {} for key,_ in pairs(e) do k[#k+1] = tostring(key) end
              table.sort(k,keyCompare)
              if #k == 0 then res[#res+1] = "[]" return end
              res[#res+1] = '{'; res[#res+1] = '"' res[#res+1] = k[1]; res[#res+1] = '":' t = k[1] pretty(e[t])
              for i=2,#k do
                res[#res+1] = ',"' res[#res+1] = k[i]; res[#res+1] = '":' t = k[i] pretty(e[t])
              end
              res[#res+1] = '}'
            end
          elseif e == nil then res[#res+1]='null'
          else error("bad json expr:"..tostring(e)) end
        end
        pretty(e0)
        return table.concat(res)
      end
      json.encodeFast = prettyJsonFlat
    end

    do -- Used for print device table structs - sortorder for device structs
      local sortKeys = {
        'id','name','roomID','type','baseType','enabled','visible','isPlugin','parentId','viewXml','configXml',
        'interfaces','properties','view', 'actions','created','modified','sortOrder'
      }
      local sortOrder={}
      for i,s in ipairs(sortKeys) do sortOrder[s]="\n"..string.char(i+64).." "..s end
      local function keyCompare(a,b)
        local av,bv = sortOrder[a] or a, sortOrder[b] or b
        return av < bv
      end

      local function prettyJsonStruct(t0)
        local res = {}
        local function isArray(t) return type(t)=='table' and t[1] end
        local function isEmpty(t) return type(t)=='table' and next(t)==nil end
        local function printf(tab,fmt,...) res[#res+1] = string.rep(' ',tab)..format(fmt,...) end
        local function pretty(tab,t,key)
          if type(t)=='table' then
            if isEmpty(t) then printf(0,"[]") return end
            if isArray(t) then
              printf(key and tab or 0,"[\n")
              for i,k in ipairs(t) do
                local _ = pretty(tab+1,k,true)
                if i ~= #t then printf(0,',') end
                printf(tab+1,'\n')
              end
              printf(tab,"]")
              return true
            end
            local r = {}
            for k,_ in pairs(t) do r[#r+1]=k end
            table.sort(r,keyCompare)
            printf(key and tab or 0,"{\n")
            for i,k in ipairs(r) do
              printf(tab+1,'"%s":',k)
              local _ =  pretty(tab+1,t[k])
              if i ~= #r then printf(0,',') end
              printf(tab+1,'\n')
            end
            printf(tab,"}")
            return true
          elseif type(t)=='number' then
            printf(key and tab or 0,"%s",t)
          elseif type(t)=='boolean' then
            printf(key and tab or 0,"%s",t and 'true' or 'false')
          elseif type(t)=='string' then
            printf(key and tab or 0,'"%s"',t:gsub('(%")','\\"'))
          end
        end
        pretty(0,t0,true)
        return table.concat(res,"")
      end
      json.encodeFormated = prettyJsonStruct
    end

    function utils.printBuffer(pre) 
      local self2,buff = {},pre and {pre} or {}
      function self2.printf(_,fmt,...) buff[#buff+1]=format(fmt,...) end --ignore 212/self
      function self2.add(_,str) buff[#buff+1]=tostring(str) end
      function self2.trim(_,n) for _=1,#buff-n do table.remove(buff,#buff) end end
      self2.buffer = buff
      function self2.tostring(_,space) return table.concat(buff,space) end
      return self2
    end

    function utils.basicAuthorization(user,password) return "Basic "..utils.base64encode(user..":"..password) end
    function utils.base64encode(data)
      __assert_type(data,"string")
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

    function fibaro.sequence(...)
      local args,i,ref = {...},1,{}
      local function stepper()
        if i <= #args then
          local arg = args[i]
          i=i+1
          if type(arg)=='number' then 
            ref[1]=setTimeout(stepper,arg)
          elseif type(arg)=='table' and type(arg[1])=='function' then
            pcall(table.unpack(arg))
            ref[1]=setTimeout(stepper,0)
          end
        end
      end
      ref[1]=setTimeout(stepper,0)
      return ref
    end

    function fibaro.stopSequence(ref) clearTimeout(ref[1]) end

  end
} -- Utilities

