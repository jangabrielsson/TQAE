local meta = true 
local test = false
local verify = true

if not meta then if require then require("modules/class") end
else require("lib/Lisp/class") end

Lisp = { symbols = {}, types = {}, inits = {}, debug = {} }
Lisp.verbose = true

local fmt = string.format
Lisp.Exception = {}
class 'LExcept'
function LExcept:__init(typ,msg) self.type=typ self.msg = msg end
function LExcept:__tostring() return fmt("Exception(%s) %s",self.type,self.msg) end

function Lisp.Exception.Unbound(e)       error(LExcept('unbound',fmt("%s",tostring(e)))) end
function Lisp.Exception.Compile(msg,e)   error(LExcept('compile',fmt("%s, %s",msg,e and tostring(e) or ""))) end
function Lisp.Exception.Reader(msg,line) error(LExcept('reader',msg)) end
function Lisp.Exception.Eval(msg,e)      error(LExcept('eval',fmt("%s, %s",msg,tostring(e)))) end
function Lisp.Exception.Std(fm,...)      error(LExcept('std',fmt(fm,...))) end
function Lisp.Exception.User(tag,value)  error({type='user',tag=tag,value=value}) end
function Lisp.lassert(test,fun,...) if not test then fun(...) end end

json = json or dofile("lib/Lisp/json.lua")
dofile("lib/Lisp/Types.lua")

local function defSymbol(name) Lisp[name:match("&(.*)") or name]=Atom(name):intern() end
Lisp.defSymbol = defSymbol
defSymbol('NIL') Lisp.NIL.val = Lisp.NIL
defSymbol('T') Lisp.T.val = Lisp.T

local stdSymbols = {
  'QUOTE','LET','LET*','IF','PROGN','SETQ','LAMBDA','FN','CATCH','&REST','&OPTIONAL','&KEY',
  'DEFUN','DEFMACRO','WHILE','FUNCTION',
  '*LOG-LEVEL*','*TRACE-LEVEL*','*TRACE-SILENT*',
  '*BACK-QUOTE*','*BACK-COMMA*','*BACK-COMMA-DOT*','*BACK-COMMA-AT*'
}
for _,name in ipairs(stdSymbols) do defSymbol(name) end

dofile("lib/Lisp/Reader.lua")
dofile("lib/Lisp/Statements.lua")
dofile("lib/Lisp/Compiler.lua")
dofile("lib/Lisp/Builtin.lua")
function Lisp:interceptAtom(name,fun)
  local set = Lisp[name].set
  Lisp[name].set = function(self, env, expr)
    fun(expr) return set(self, env,expr)
  end
end
local isLType,debug = Lisp.isLType,Lisp.debug
local format = string.format
local function printf(fmt,...)
  local args = {...}
  for i=1,#args do if isLType(args[i]) then args[i]=args[i]:__tostring() end end
  print(format(fmt,table.unpack(args)))
end
Lisp:interceptAtom('*LOG-LEVEL*',function(val) debug['log'] = val > 0 end)
Lisp:interceptAtom('*TRACE-LEVEL*',function(val) debug['trace'],debug['macroexpand'] = val > 0, val > 1 end)
Lisp:interceptAtom('*TRACE-SILENT*',function(val) debug['silent'] = val == Lisp.T end)

function Lisp:log(tag,fmt,...)
  if not debug.silent and debug[tag] then printf("LOG> "..fmt,...) end
end
function Lisp:trace(tag,fmt,...)
  if not debug.silent and debug[tag] then printf("TRACE> "..fmt,...) end
end

for _,initf in pairs(Lisp.inits) do initf(Lisp) end

function Lisp:eval(expr)
  if type(expr) == 'string' then 
    expr = Lisp.Reader(expr).parse()
  end
  expr = Lisp.compile(expr)
  --print("C:"..tostring(expr))
  return expr:run()
end

Lisp.EOF = '<EOF>'

function Lisp:loadFile(name)
  local f = io.open(name,"r")
  local content = f:read("*all")
  f:close()
  local r = Lisp.Reader(content)
  while true do
    local stat,res = pcall(function()
        local s = r:parse()
        if s == Lisp.EOF then return s end
        --print(s)
        printf("> %s",Lisp:eval(s))
      end)
    if not stat then
      if type(res)=='table' then
        printf("Error %s: %s",res.type,res.msg)
      else printf("Error: %s",res) end
    elseif res==Lisp.EOF then break end
  end
end

Lisp:loadFile("lib/Lisp/init.lsp")
if test then Lisp:loadFile("lib/Lisp/test.lsp") end
if verify then Lisp:loadFile("lib/Lisp/verify.lsp") end
Lisp:eval("(toploop)")