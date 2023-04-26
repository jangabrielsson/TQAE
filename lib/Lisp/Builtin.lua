local Exception, NIL, isLType, LType, evalt, debug
local format = string.format 

Lisp.inits[#Lisp.inits+1] = function(lisp)
  Exception =lisp.Exception
  isLType, evalt, NIL, T = lisp.isLType, lisp.evalt, lisp.NIL, Lisp.T
  LType = lisp.LType
  debug = Lisp.debug
end 

local fmt,unpack = string.format,table.unpack

class 'Builtin'(Expr)
function Builtin:__init(name,fun) 
  self.fun = fun
  self.name = name
end

function Builtin:__tostring() 
  return "<" .. self.name .. ">"
end

function Builtin:eval(env)
  return self
end

function Builtin:apply(env, params) 
  local args = {}
  for _,e in ipairs(params) do args[#args+1]=evalt(e,env) end
  return self:apply2(env,args)
end

local function traceCall(call, args) if call then call[1]:trace(args) end end
local function traceStr(call, args) return call and call[1]:traceStr(args) or "" end

function Builtin:apply2(env, args)
  if debug.tracebuiltin then traceCall(env:lookup('_call'),args) end
  local stat, res = pcall(self.fun,env,unpack(args))
  if not stat then
    local str = traceStr(env:lookup('_call'),args)
    Exception.Eval(res,env:lookup('_call')[1])
  else return res end
end

local function define(name,fun)
  Atom(name):intern().fun=Builtin(name,fun)
end

define("car",function(env,a) assert(isLType(a)=='Cons',"Not a cons") return a.car end)
define("cdr",function(env,a) assert(isLType(a)=='Cons',"Not a cons") return a.cdr end)
define("cons",function(env,a,b) return Cons(a,b) end)
define("+",function(env,a,b) return a+b end)
define("-",function(env,a,b) return b==nil and -a or a-b end)
define("*",function(env,a,b) return a*b end)
define("/",function(env,a,b) return a/b end)
define("%",function(env,a,b) return a % b end)
define("eq",function(env,a,b) return a==b and T or NIL end)
define(">",function(env,a,b) return a>b and T or NIL end)
define(">=",function(env,a,b) return a>=b and T or NIL end)
define("<",function(env,a,b) return a<b and T or NIL end)
define("<=",function(env,a,b) return a<=b and T or NIL end)
define("concat",function(env,a,b) return tostring(a)..tostring(b) end)
define("function",function(env,a) return a:funBinding(env) end)
define("funset",function(env,a,b) a:funset(env,b) return a:funBinding(env) end)
define("rplaca",function(env,a,b) a.car=b return a end)
define("rplacd",function(env,a,b) a.cdr=b return a end)
define("apply",function(env,a,b)
    local e = a:funBinding(env)  -- Macro expands?
    local args = Lisp.listToArr(b)
    return e:apply2(env,args)
  end)
define("funcall",function(env,a,...)
    local e = a:funBinding(env)  -- Macro expands?
    return e:apply2(env,{...})
  end)
define("eval",function(env,a)
    local cexpr = Lisp.compile(a);
    return cexpr:run()
  end)
local gensymCount=0
define("gensym",function(env)
    gensymCount=gensymCount+1
    return Atom("<G:"..gensymCount..">")
  end)
define("atom",function(env,a) 
    local l=LType(a) 
    return (l == 'Atom' or l == 'String' or l=='Number') and T or NIL end 
  )
  define("numberp",function(env,a)  return tonumber(a) and T or NIL end )
  define("consp",function(env,a)  return isLType(a) == 'Cons' and T or NIL end )
  define("print",function(env,a)
      io.write(tostring(a))
      return T
    end)
  define("flush",function(env,a)
      return NIL
    end)
  define("throw",function(env,tag,value)
      Exception.User(tag,value)
    end)
  define("error",function(env,err)
      Exception.Error(tostring(err))
    end)
  define("strformat",function(env,...)
      local a = {...}
      for i=1,#a do a[i]=isLType(a[i]) and tostring(a[i]) or a[i] end
      if #a==1 then return a[1] else return format(table.unpack(a)) end	
    end)
  define("read",function(env)
      local line = io.read("*line")
      return Lisp.Reader(line):parse()
    end)
  define("readfile",function(env,a)
      Lisp:loadFile(tostring(a))
      return Lisp.NIL
    end)

  define("clock",function(env) return os.clock() end)