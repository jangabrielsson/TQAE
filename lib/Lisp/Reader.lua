if require then require("modules/class") end

local Lisp = { atoms = {}, types = {} }

function LispException(fmt,...)
  error(string.format(fmt,...))
end
function LispReaderException(msg,line)
  error(string.format("Line %s: %s",line,msg))
end

function Lisp:log(level,fmt,...)
  print(string.format(fmt,...))
end

class 'Expr'
function Expr:__init() end
function Expr:isAtom() return false end
function Expr:isNumber() return false end
function Expr:isString() return false end
function Expr:isCons() return false end
function Expr:eval() LispException("Eval:%s",self) end

class 'Atom'(Expr)
function Atom:__init(str,val) 
  self.type='ATOM'
  self.name = str:upper()
  self.val= val==nil and Lisp.NIL or val
end
function Atom:eval() return self.val end
function Atom:isAtom() return true end
function Atom:__tostring() return self.name end
function Atom:intern()
  local name,atoms = self.name,Lisp.atoms
  if atoms[name] then return atoms[name] 
  else
    atoms[name]=self
    return self
  end
end

class 'Number'(Expr)
function Number:__init(val) 
  self.type='NUMBER'
  self.val= tonumber(val) or 0
end
function Number:eval() return self end
function Number:isNumber() return true end
function Number:__tostring() return tostring(self.val) end

class 'String'(Expr)
function Number:__init(val) 
  self.type='STRING'
  self.val= tostring(val) or 0
end
function String:eval() return self end
function String:isString() return true end
function String:__tostring() return self.val end

class 'Cons'(Expr)
function Cons:__init(car,cdr) 
  self.type='CONS'
  self.car,self.cdr = car or Lisp.NIL,cdr or Lisp.NIL
end
function Cons:isCons() return true end
local function stringRest(e,buff)
  buff[#buff+1]=tostring(e.car)
  if e.cdr:isCons() then stringRest(e.cdr,buff)
  elseif e.cdr==Lisp.NIL then --
  else 
    buff[#buff+1] = "."
    buff[#buff+1] = tostring(e.cdr)
  end
end
function Cons:__tostring()
  local buff = {'('}
  stringRest(self,buff)
  buff[#buff+1]=')'
  return table.concat(buff," ")
end

Lisp.NIL   = Atom('NIL',false):intern()
Lisp.T     = Atom('T',true):intern()
Lisp.QUOTE = Atom('QUOTE'):intern()

local singleTokens = {
  ["("] = 'TT_LPAR',
  [")"] = 'TT_RPAR',
  ["+"] = 'TT_ATOM',
  ["/"] = 'TT_ATOM',
  ["\\"] = 'TT_QUOTE',
  ["`"] = 'TT_BACKQUOTE',
  ["@"] = 'TT_AT',
  ["#"] = 'TT_HASH',
  ["-"] = 'TT_ATOM',
  ["<"] = 'TT_ATOM',
  [">"] = 'TT_ATOM',
  [","] = 'TT_COMMA',
  ["."] = 'TT_DOT',
}

local tokens = {
  {s = "^(%d+%.%d+)", f= function (d) return 'TT_NUMBER',tonumber(d) end },
  {s = "^(\n)", f= function (l,t) t.line=t.line+1; return nil,nil end },
  {s = "^(%d+)", f = function (d) return 'TT_NUMBER',tonumber(d) end },
  {s = '^(%b"")', f = function (s) return 'TT_STRING',s end },
  {s = '^([:_%a%*]+[%w_%-%*]*)', f = function (a) return 'TT_ATOM',a end },
  {s = "^([%(%%).%+%%/%\\%`@#%-<>,])", f = function(s) return singleTokens[s],s end},
}
local function Tokenizer(str)
  local self = { val = nil, lastToken=nil, line=1, pbFlag = false }    
  function self:nextToken()
    if self.pbFlag then 
      self.pbFlag = false
      return self.lastToken
    end
    str = str:match("^[ \t]*(.*)")
    for _,t in ipairs(tokens) do
      s,e,m = str:find(t.s)
      if s then
        str=str:sub(e+1)
        self.lastToken,self.val = t.f(m,self)
        if self.lastToken then return self.lastToken end
      end
    end
    self.lastToken,self.val = 'TT_UNKNOWN',str
    return self.lastToken
  end
  function self:lineNo() return self.line end 
  function self:pushBack() self.pbFlag = true end
  return self
end

local parseFuns = {
  TT_EOF    = function(st) LispReaderException("Read beyond EOF", st:lineNo()) end,
  TT_NUMBER   = function(st) return Number(st.val) end,
  TT_STRING = function(st) return String(st.val) end,
  TT_ATOM   = function(st) return Atom(st.val):intern() end,
  TT_QUOTE  = function(st,p) return Cons(Lisp.QUOTE, Cons(p:parse(st), Lisp.NIL)) end,
  TT_HASH   = function(st) -- Hack
    local Expr e = parse(st):second();
    if e:isAtom() then e = Cons(Lisp.QUOTE, e, Lisp.NIL) end
    return Cons(Lisp.FUNCTION, e, Lisp.NIL)
  end,
  TT_BACKQUOTE = function(st) return Cons(Atom("BACKQUOTE"):intern(),parse(st),Lisp.NIL) end,
  TT_COMMA     = function(st,p) 
    local n = st:nextToken();
    if n == 'TT_DOT' then
      return  Cons(Lisp.BACK_COMMA_DOT,p:parse(st),Lisp.NIL)
    elseif n == 'TT_AT' then
      return Cons(Lisp.BACK_COMMA_AT,p:parse(st),Lisp.NIL)
    else 
      st:pushBack();
      return Cons(Lisp.BACK_COMMA,p:parse(st),Lisp.NIL)
    end
  end,
  TT_LPAR   = function(st,p) 
    if st:nextToken() == 'TT_RPAR' then
      return Lisp.NIL
    else 
      st:pushBack();
      local l = Cons(p:parse(st), Lisp.NIL);
      local t = l;
      while true do
        local tk = st:nextToken()
        if tk == 'TT_RPAR' then
          return l
        elseif tk == 'TT_DOT' then
          t.cdr = p:parse(st)
          if st:nextToken() ~= 'TT_RPAR' then
            LispReaderException("Missing ')'", st:lineNo())
          else
            return l
          end
        elseif tk == 'TT_EOF' then
          LispReaderException("Malformed list!", st:lineNo())
        else
          st:pushBack();
          t.cdr = Cons(p:parse(st), Lisp.NIL);
          t = t.cdr
          -- break
        end
      end
    end
  end,
  TT_UNKNOWN = function(st) 
    Lisp:log(0,"Reader TT_UNKNOWN: %s",st.val)
    return Atom(st.val):intern()
  end,
  TT_ERROR = function(st) 
    Lisp:log(0,"Reader TT_ERROR: %s",st.val);
    LispReaderException("Missing ')'", st:lineNo())
  end,
  TT_DEFAULT = function(st) 
    return Atom(st.val):intern()
  end
}

local function Reader(str)
  local st = Tokenizer(str) 
  local self = { st = st }
  local function parse(st) -- -> Expr
    local pf = parseFuns[st:nextToken()] or parseFuns['TT_DEFAULT']
    return pf(st,self)
  end
  function self:parse()
    local stat,res = pcall(function()
        if st:nextToken() == 'TT_EOF' then
          return Lisp.NIL
        else 
          st:pushBack()
          return parse(st)
        end
      end)
    if not stat then
      error(res)
    else return res end
  end
  return self
end

local function Print(obj)
  print(tostring(obj))
end

--Print(Reader("  ()").parse())

--Print(Reader("  T").parse())

--Print(Reader("  NIL").parse())

Print(Reader([[  (d . 7)]]).parse())
