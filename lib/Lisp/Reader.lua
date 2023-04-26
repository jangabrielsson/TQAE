local Exception = Lisp.Exception

local singleTokens = {
  ["("] = 'TT_LPAR',
  [")"] = 'TT_RPAR',
  ["+"] = 'TT_ATOM',
  ["%"] = 'TT_ATOM',
  ["/"] = 'TT_ATOM',
  ["'"] = 'TT_QUOTE',
  ["`"] = 'TT_BACKQUOTE',
  ["@"] = 'TT_AT',
  ["#"] = 'TT_HASH',
  ["-"] = 'TT_ATOM',
  ["<"] = 'TT_ATOM',
  [">"] = 'TT_ATOM',
  [","] = 'TT_COMMA',
  ["."] = 'TT_DOT',
  ["{"] = 'TT_LCB',
  ["}"] = 'TT_RCB',
  ["="] = 'TT_EQ',
}

local tokens = {
  {s = "^(%-?%d+%.%d+)", f= function (d) return 'TT_NUMBER',tonumber(d) end },
  {s = "^(\n)", f= function (l) return 'TT_NEWLINE',true end },
  {s = "^(%-?%d+)", f = function (d) return 'TT_NUMBER',tonumber(d) end },
  {s = '^(%b"")', f = function (s) s=s:gsub("(\\n)","\n") return 'TT_STRING',s:sub(2,-2) end },
  {s = '^([&:_%a%*]+[%w_%-%*]*)', f = function (a) return 'TT_ATOM',a end },
  {s = "^([%{%}%(%%).%+%%/%\\'%`@#%-<>,=])", f = function(s) return singleTokens[s],s end},
}
local function Tokenizer(str)
  local self = { val = nil, lastToken=nil, line=1, pbFlag = false }    
  function self:nextToken()
    if self.pbFlag then 
      self.pbFlag = false
      return self.lastToken
    end
    while true do
      str = str:match("^[ \t]*(.*)")
      if str=="" then return 'TT_EOF' end
      local c = str:sub(1,1)
      if c=='\n' then self.line=self.line+1 str=str:sub(2)
      elseif c==';' then str = str:match(";.-(\n.*)") str=str or ""
      else break end
    end
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
  TT_EOF    = function(st) Exception.Reader("Read beyond EOF", st:lineNo()) end,
  TT_NUMBER = function(st) return st.val end,
  TT_STRING = function(st) return st.val end,
  TT_ATOM   = function(st) return Atom(st.val):intern() end,
  TT_QUOTE  = function(st,p) return Cons(Lisp.QUOTE, Cons(p:parse(st), Lisp.NIL)) end,
  TT_HASH   = function(st,p) -- Hack
    local Expr e = p:parse(st).cdr.car
    if e:isAtom() then e = Cons(Lisp.QUOTE, Cons(e, Lisp.NIL)) end
    return Cons(Lisp.FUNCTION, Cons(e, Lisp.NIL))
  end,
  TT_BACKQUOTE = function(st,p) return Cons(Atom("BACKQUOTE"):intern(),Cons(p:parse(st),Lisp.NIL)) end,
  TT_COMMA     = function(st,p) 
    local n = st:nextToken();
    if n == 'TT_DOT' then
      return  Cons(Lisp['*BACK-COMMA-DOT*'],Cons(p:parse(st),Lisp.NIL))
    elseif n == 'TT_AT' then
      return Cons(Lisp['*BACK-COMMA-AT*'],Cons(p:parse(st),Lisp.NIL))
    else 
      st:pushBack();
      return Cons(Lisp['*BACK-COMMA*'],Cons(p:parse(st),Lisp.NIL))
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
            Exception.Reader("Missing ')'", st:lineNo())
          else
            return l
          end
        elseif tk == 'TT_EOF' then
          Exception.Reader("Malformed list!", st:lineNo())
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
    Exception.Reader("Missing ')'", st:lineNo())
  end,
  TT_DEFAULT = function(st) 
    return Atom(st.val):intern()
  end
}

function Lisp.Reader(str)
  local st = Tokenizer(str) 
  local self = { st = st, line = 1 }
  local function parse(st) -- -> Expr
    local pf = parseFuns[st:nextToken()] or parseFuns['TT_DEFAULT']
    return pf(st,self)
  end
  function self:parse()
    local stat,res = pcall(function()
        if st:nextToken() == 'TT_EOF' then
          return Lisp.EOF
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


