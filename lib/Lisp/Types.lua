local Exception = Lisp.Exception

local typeTab = {
  ['number'] = function() return 'Number' end,
  ['table'] = function(o) return o.__ltyp or 'Table' end,
  ['string'] = function() return 'String' end,
  ['boolean'] = function() return 'Bool' end,
}
local function isLType(o) return type(o)=='table' and o.__ltyp or nil end
Lisp.isLType = isLType
local function LType(o) return typeTab[type(o)](o) end
Lisp.LType = LType

class 'Expr'
Expr.__ltyp='Expr'
function Expr:__init() end
function Expr:isAtom() return false end
function Expr:isNumber() return false end
function Expr:isString() return false end
function Expr:isFree() return false end
function Expr:isLocal() return false end
function Expr:isCons() return false end
function Expr:isConst() return false end
function Expr:eval() Exception.Eval(self) end
function Expr:isTailRec(curr) return false end
function Expr:isMacro(curr) return false end
function Expr:funset(env, e) 
  Exception.Eval("Trying to funset",self)
end
function Expr:funBinding(env) 
  local expr = self:eval(env)
  if expr.apply then return expr 
  else Exception.Eval("No fun",self) end
end

class 'Atom'(Expr)
Atom.__ltyp='Atom'
function Atom:__init(str,val) 
  self.name = str:upper()
  self.val= val==nil and Lisp.NIL or val
end
function Atom:eval() return self.val end
function Atom:isAtom() return true end
function Atom:set(env, expr) self.val = expr return expr end
function Atom:funset(env, expr)
		self.fun = expr
		return expr
end
function Atom:isMacro() 
		return self.fun and self.fun:isMacro();
end
function Atom:funBinding(env)		
  return self.fun or Exception.Eval("Undefined fun",self);
end
function Atom:__tostring() return self.name end
function Atom:intern()
  local name,symbols = self.name,Lisp.symbols
  if symbols[name] then return symbols[name] 
  else
    symbols[name]=self
    return self
  end
end

class 'Const'(Expr)
Const.__ltyp='Const'
function Const:__init(val) 
  self.val= val
end
function Const:eval() return self.val end
function Const:isConst() return true end
function Const:__tostring() return "'"..tostring(self.val) end

class 'Cons'(Expr)
Cons.__ltyp='Cons'
function Cons:__init(car,cdr) 
  self.car,self.cdr = car or Lisp.NIL,cdr or Lisp.NIL
end
function Cons:isCons() return true end
local function isCons(x) return isLType(x)=='Cons' end

local function stringRest(e,buff)
  buff[#buff+1]=tostring(e.car)
  if isCons(e.cdr) then stringRest(e.cdr,buff)
  elseif e.cdr==Lisp.NIL then --
  else 
    buff[#buff+1] = "."
    buff[#buff+1] = tostring(e.cdr)
  end
end
function Cons:iter()
  local c = self
  return function ()
    if c:isCons() then
      local v = c.car
      c = c.cdr
      return v
    end
  end
end
function Cons:__tostring()
  local buff = {}
  stringRest(self,buff)
  return "("..table.concat(buff," ")..")"
end

function string:isString() return true end
function string:eval() return self end
