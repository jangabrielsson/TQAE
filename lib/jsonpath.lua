if not json then dofile("lib/json.lua") end

--[[
Paths:

Expression	        Description
----------------------------------------------------------------
$	                 -The root object or array.
.property	         -Selects the specified property in a parent object.
['property']	     -Selects the specified property in a parent object. Be sure to put single quotes around the property name.
                   Tip: Use this notation if the property name contains special characters such as spaces, or begins with a character other
                   than A..Za..z_.

[n]	               -Selects the n-th element from an array. Indexes are 0-based.
[index1,index2,…]	 -Selects array elements with the specified indexes. Returns a list.
..property	       -Recursive descent: Searches for the specified property name recursively and returns an array of all values with this
                   property name. Always returns a list, even if just one property is found.
*	                 -Wildcard selects all elements in an object or an array, regardless of their names or indexes. For example, address.* means
                   all properties of the address object, and book[*] means all items of the book array.

[start:end]        -Selects array elements from the start index and up to, but not including, end index. If end is omitted, selects all elements
[start:]	         from start until the end of the array. Returns a list.


[:n]	             -Selects the first n elements of the array. Returns a list.
[-n:]	             -Selects the last n elements of the array. Returns a list.
[?(expression)]	   -Filter expression. Selects all elements in an object or array that match the specified filter. Returns a list.
[(expression)]	   -Script expressions can be used instead of explicit property names or indexes. An example is [(@.length-1)] which selects the
                   last item in an array. Here, length refers to the length of the current array rather than a JSON field named length.
@	                 -Used in filter expressions to refer to the current node being processed.

Filters/expression:

Operator           Description
-------------------------------------------------------------
==	               -Equals to. String values must be enclosed in single quotes (not double quotes): [?(@.color=='red')].
!=	               -Not equal to. String values must be enclosed in single quotes: [?(@.color!='red')].
>,>=,<,<=	          -Comparision, strings or numbers
=~	               -Matches a Lua regular expression. For example, [?(@.description =~ /cat.*/i)] matches items whose description starts
                    with cat (case-insensitive).
!	                 -Used to negate a filter: [?(!@.isbn)] matches items that do not have the isbn property.
&&	               -Logical AND, used to combine multiple filter expressions:
                    [?(@.category=='fiction' && @.price < 10)]
||	               -Logical OR, used to combine multiple filter expressions:
                    [?(@.category=='fiction' || @.price < 10)]
in	               -Checks if the left-side value is present in the right-side list. Similar to the SQL IN operator. String comparison is
                    case-sensitive.
                    [?(@.size in ['M', 'L'])]
                    [?('S' in @.sizes)]
nin	                -Opposite of in. Checks that the left-side value is not present in the right-side list. String comparison is case-sensitive.
                    [?(@.size nin ['M', 'L'])]
                    [?('S' nin @.sizes)]
subsetof	          -Checks if the left-side array is a subset of the right-side array. The actual order of array items does not matter. String
                     comparison is case-sensitive. An empty left-side array always matches.
                    For example:
                    [?(@.sizes subsetof ['M', 'L'])] – matches if sizes is ['M'] or ['L'] or ['L', 'M'] but does not match if the array has any
                    other elements.
                    [?(['M', 'L'] subsetof @.sizes)] – matches if sizes contains at least 'M' and 'L'.
contains	          -Checks if a string contains the specified substring (case-sensitive), or an array contains the specified element.
                    [?(@.name contains 'Alex')]
                    [?(@.numbers contains 7)]
                    [?('ABCDEF' contains @.character)]
size	              -Checks if an array or string has the specified length.
                    [?(@.name size 4)]
empty true	        -Matches an empty array or string.
                    [?(@.name empty true)]
empty false	        -Matches a non-empty array or string.
                    [?(@.name empty false)]
--]]
local testData =
{
  store = {
    book = {
      {
        category = "reference",
        author = "Nigel Rees",
        title = "Sayings of the Century",
        price = 8.95
      },
      {
        category = "fiction",
        author = "Evelyn Waugh",
        title = "Sword of Honour",
        price = 12.99
      },
      {
        category = "fiction",
        author = "Herman Melville",
        title = "Moby Dick",
        isbn = "0-553-21311-3",
        price = 8.99
      },
      {
        category = "fiction",
        author = "J. R. R. Tolkien",
        title = "The Lord of the Rings",
        isbn = "0-395-19395-8",
        price = 22.99
      }
    },
    bicycle = {
      color = "red",
      price = 19.95
    }
  }
}

------------ Utilities -------------------------
local function stream(tkns)
  local self, p = {}, 0
  function self.next()
    p = p + 1
    return tkns[p]
  end

  function self.match(t, err) if not self.matchif(t) then error(err, 2) end end

  function self.peek() return tkns[p + 1] end

  function self.peekm(t) return t[tkns[p + 1].type] == true end

  function self.peekif(t) return tkns[p + 1].type == t end

  function self.peek2if(t) return tkns[p + 2] and tkns[p + 2].type == t end

  function self.matchif(t) if tkns[p + 1].type == t then
      p = p + 1
      self.last = tkns[p]
      return self.last
    else return false end end

  function self.error(str) return error(str .. ":" .. tkns[p + 1].value, 2) end

  return self
end

local function stack()
  local p, st, self = 0, {}, {}
  function self.push(v)
    p = p + 1
    st[p] = v
  end

  function self.pop(n)
    n = n or 1; p = p - n; return st[p + n]
  end

  function self.popn(n, v)
    v = v or {}; if n > 0 then
      local p0 = self.pop(); self.popn(n - 1, v); v[#v + 1] = p0
    end
    return v
  end

  function self.peek(n) return st[p - (n or 0)] end

  function self.isEmpty() return p <= 0 end

  function self.size() return p end

  function self.dump() for i = 1, p do print(json.encode(st[i])) end end

  return self
end

local function output()
  local self, instr = {}, {}
  function self.add(e) instr[#instr + 1] = e end

  self.instr = instr
  return self
end

local function append(t1, t2) for _, e in ipairs(t2) do t1[#t1 + 1] = e end end

------------------ Tokenizer -------------------
local tokenMap = {
  ['['] = { t = 'LB' },
  [']'] = { t = 'RB' },
  ['('] = { t = 'LP' },
  [')'] = { t = 'RP' },
  ['*'] = { t = 'star', p = 12, n = 2 },
  ['^'] = { t = 'parent' },
  [':'] = { t = 'semi' },
  ['?'] = { t = 'question' },
  ['.'] = { t = 'dot' },
  [','] = { t = 'comma' },
  ['-'] = { t = 'op', p = 11, n = 2 },
  ['/'] = { t = 'op', p = 13, n = 2 },
  ['+'] = { t = 'op', p = 11, n = 2 },
  ['%'] = { t = 'op', p = 13, n = 2 },
  ['!'] = { t = 'op', p = 5.1, n = 1 },
  ['&&'] = { t = 'op', p = 5, n = 2 },
  ['||'] = { t = 'op', p = 4, n = 2 },
  ['>'] = { t = 'op', p = 6, n = 2 },
  ['>='] = { t = 'op', p = 6, n = 2 },
  ['<'] = { t = 'op', p = 6, n = 2 },
  ['<='] = { t = 'op', p = 6, n = 2 },
  ['=='] = { t = 'op', p = 6, n = 2 },
  ['!='] = { t = 'op', p = 6, n = 2 },                                     --['!']={t='not',p=5.1,n=1},
  ['=~'] = { t = 'op', p = 6, n = 2 },
  ['neg'] = { p = 14, n = 1 },
  ['$'] = { t = 'root' },
  ['@'] = { t = 'current_node' },
  ['in'] = { t = 'op', p = 5.1, n = 2 },
  ['nin'] = { t = 'op', p = 5.1, n = 2 },
  ['contains'] = { t = 'op', p = 5.1, n = 2 },
  ['size'] = { t = 'op', p = 5.1, n = 2 },
  ['subsetof'] = { t = 'op', p = 5.1, n = 2 },
  ['empty'] = { t = 'op', p = 5.1, n = 2 }
}

local tokens = {
  { "^(%-?[0-9]+)",                          function(t) return 'number', tonumber(t) end },
  { "^(%.%.)",                               function(t) return 'recursive_descent', t end },
  { "^([&|><=!.][&|=~.])",                   function(t)
    assert(tokenMap[t], "Illegal token:" .. t)
    return tokenMap[t].t, t
  end },
  { "^([/%[%]%(%)%*%-!:%?%^%%%+><=@%$%.,])",
                                               function(t)
      assert(tokenMap[t], "Illegal token:" .. t)
      return tokenMap[t].t, t
    end },
  { "^([a-zA-Z0-9_]+)", function(t)
    local n = tonumber(t)
    if n then return "number", n else return 'ident', t end
  end },
  { '^(%b"")', function(t) return 'str', t:sub(2, -2) end },
  { "^(%b'')", function(t) return 'str', t:sub(2, -2) end },
}

local function getToken(str)
  for _, t in ipairs(tokens) do
    local t0 = str:match(t[1])
    if t0 then return t0, t[2](t0) end
  end
  error("Unknown token " .. str)
end

local function parseTokens(str)
  local tokens = {}
  while str ~= "" do
    str = str:match("%s*(.*)")
    if str ~= "" then
      local t0, typ, t = getToken(str)
      str = str:sub(t0:len() + 1)
      tokens[#tokens + 1] = { type = typ, value = t }
    end
  end
  tokens[#tokens + 1] = { type = 'EOF' }
  return stream(tokens)
end

------------------ json grammar -------------------
local p_jsonpath
local p_relative_location
local p_relative_path
local p_bracket_expression
local p_bracket_element
local p_expression
local p_slice
local pExpr

local LA_relative_location = { dot = true, recursive_descent = true, parent = true, LB = true }
function p_jsonpath(tkns, out)
  if tkns.matchif('root') then --jsonpath = "$" [relative-location]
    out.add({ "root" })
    if tkns.peekm(LA_relative_location) then p_relative_location(tkns, out) end
  elseif tkns.matchif('current_node') then --jsonpath = / "@" [relative-location]
    out.add({ "current_node" })
    if tkns.peekm(LA_relative_location) then p_relative_location(tkns, out) end
  else
    tkns.error("Bad jsonpath")
  end
end

local LA_relative_path = { ident = true, str = true, star = true } -- star???

function p_relative_location(tkns, out)
  if tkns.matchif('dot') then -- relative-location = "." relative-path
    p_relative_path(tkns, out)
  elseif tkns.peekif('LB') then -- relative-location = bracket-expression [relative-location]
    p_bracket_expression(tkns, out)
    if tkns.peekm(LA_relative_location) then p_relative_location(tkns, out) end
  elseif tkns.matchif('recursive_descent') then
    local n = #out.instr + 1
    if tkns.peekm(LA_relative_path) then --relative-location = / ".." relative-path
      p_relative_path(tkns, out)
    elseif tkns.peekif('LB') then        --relative-location = / ".." bracket-expression [relative-location]
      p_bracket_expression(tkns, out)
      if tkns.peekm(LA_relative_location) then p_relative_location(tkns, out) end
    else
      tkns.error("Bad .. jsonpath")
    end
    out.instr[n] = { "recursive_descent", out.instr[n] }
  elseif tkns.matchif('parent') then --relative-location = / "^" [relative-location]
    out.add({ "parent" })
    if tkns.peekm(LA_relative_location) then p_relative_location(tkns, out) end
  else
    tkns.error("Bad jsonpath")
  end
end

function p_relative_path(tkns, out)
  local t = tkns.next()
  if t.type == 'ident' then  --relative-path = identifier [relative-location]
    out.add({ "ident_selector", t.value })
  elseif t.type == 'str' then --relative-path = string [relative-location]
    out.add({ "ident_selector", t.value })
  elseif t.type == 'star' then --relative-path = / "*" [relative-location]
    out.add({ "star_selector" })
  else
    tkns.error("Bad jsonpath")
  end
  if tkns.peekm(LA_relative_location) then p_relative_location(tkns, out) end
end

function p_bracket_expression(tkns, out)
  if tkns.matchif('LB') then --bracket-expression = "[" bracketed-element *bracket-expression_aux "]"
    local outs = output()
    p_bracket_element(tkns, outs)
    while tkns.matchif('comma') do --bracket-expression-aux = "," bracketed-element
      p_bracket_element(tkns, outs)
    end
    tkns.match('RB', "missing ]")
    out.add({ 'list', outs.instr })
  else
    tkns.error("Bad bracked expression")
  end
end

function p_bracket_element(tkns, out)
  local t = tkns.peek()
  if t.type == 'str' then
    tkns.next()
    out.add({ "ident_selector", t.value })                                      --bracketed-element = / string
  elseif t.type == 'ident' then
    tkns.next()
    out.add({ "ident_selector", t.value })                                      --bracketed-element = / ident
  elseif t.type == 'star' then
    tkns.next()
    out.add({ "star_selector" })                                                --bracketed-element = / "*"
  elseif t.type == 'semi' or t.type == 'number' and tkns.peek2if('semi') then   --bracketed-element = / slice
    p_slice(tkns, out)
  elseif t.type == 'number' then
    tkns.next()
    out.add({ "index_selector", t.value })                                      --bracketed-element = integer ; index
  elseif t.type == 'LP' then
    local expr = p_expression(tkns)
    out.add({ 'index_selector', expr }) --bracketed-element = / "(" expression ")"; filter expression
  elseif t.type == 'question' then
    tkns.match("question", "Missing '?' for expression")
    local expr = p_expression(tkns)
    out.add({ 'filter', expr })                        --bracketed-element = / "?" expression ; filter expression
  elseif t.type == 'root' or t.type == 'current_node' then --bracketed-element = / jsonpath
    p_jsonpath(tkns, out)
  else
    tkns.error("Bad bracketed element")
  end
end

-- slice  = [integer] ":" [integer] [ ":" [integer] ]
function p_slice(tkns, out)
  local i1, i2, i3
  if tkns.matchif('number') then
    i1 = tkns.last.value
    tkns.match('semi', "Bad slice")
  elseif tkns.matchif('semi') then
    i1 = nil
  else
    error("Bad slice")
  end
  if tkns.matchif('number') then
    i2 = tkns.last.value
  else
    i2 = nil
  end
  if tkns.matchif('semi') then
    if tkns.matchif('number') then
      i3 = tkns.last.value
    else
      i3 = nil
    end
  end
  out.add({ "slice_selector", i1, i2, i3 })
end

local gExpr = {}
function p_expression(tkns)
  tkns.match("LP", "Missing '(' for expression")
  local expr = pExpr(tkns, { [')'] = true })
  tkns.match("RP", "Missing ')' for expression")
  return expr
end

------------------ filter parser  -------------------
local function applyOp(t, st) return st.push(st.popn(tokenMap[t.value].n, { t.value })) end
local function lessp(t1, t2)
  local v1, v2 = t1.value, t2.value
  if v1 == '=' then v1 = '/' end
  return tokenMap[v1].p < tokenMap[v2].p
end

local function gArgs(inp, stop)
  local res, i = {}, 1
  while inp.peek().value ~= stop do
    assert(inp.peek().type ~= 'EOF', "Missing ')'");
    res[i] = pExpr(inp, { [stop] = true, [','] = true });
    i = i + 1;
    if inp.peek().value == ',' then inp.next() end
  end
  inp.next()
  return res
end

local constants = { ['true'] = true, ['false'] = false }
local operators = {
  ['in'] = { t = 'op', p = 5.1, n = 2 },
  ['nin'] = { t = 'op', p = 5.1, n = 2 },
  ['contains'] = { t = 'op', p = 5.1, n = 2 },
  ['size'] = { t = 'op', p = 5.1, n = 2 },
  ['subsetof'] = { t = 'op', p = 5.1, n = 2 },
  ['empty'] = { t = 'op', p = 5.1, n = 2 }
}
gExpr['LP'] = function(inp, st, ops, _, pt)
  st.push(pExpr(inp, { [')'] = true }))
  inp.next()
end
gExpr['LB'] = function(inp, st, ops, _, pt)
  local args = gArgs(inp, ']')
  st.push({ 'table', args })
end
gExpr['number'] = function(_, st, _, t, _) st.push(t.value) end
gExpr['str'] = function(_, st, _, t, _) st.push(t.value) end
gExpr['ident'] = function(inp, st, ops, t, pt)
  local v = constants[t.value]
  if v ~= nil then
    st.push(v)
    return
  end
  if tokenMap[t.value] then
    t.type = 'op'
    gExpr['op'](_, st, ops, { type = 'op', value = t.value }, pt)
    return
  end
  if inp.matchif('LP') then
    local args = gArgs(inp, ')')
    st.push({ 'funcall', t.value, args })
  else
    st.push(t.value)
  end
end
gExpr['op'] = function(_, st, ops, t, pt)
  if t.value == '-' and not (pt.type == 'ident' or pt.type == 'number' or pt.type == 'RP') then t.value = 'neg' end
  --  if t.value == '!' then t.value = 'not' end
  while ops.peek() and lessp(t, ops.peek()) do applyOp(ops.pop(), st) end
  ops.push(t)
end
gExpr['json'] = function(tkns, st, ops, t, pt)
  local out = output()
  p_jsonpath(tkns, out)
  st.push({ 'json', out.instr })
end

function pExpr(inp, stop)
  local st, ops, t, pt = stack(), stack(), { value = '<START>' }, nil
  while true do
    t, pt = inp.peek(), t
    if t.type == 'EOF' or stop and stop[t.value] then break end
    if t.type == 'current_node' then
      gExpr['json'](inp, st, ops, t, pt)
    else
      t = inp.next()
      t.type = t.type == 'star' and 'op' or t.type
      gExpr[t.type](inp, st, ops, t, pt)
    end
  end
  while not ops.isEmpty() do applyOp(ops.pop(), st) end
  local r = st.pop()
  if not st.isEmpty() then
    error("Bad expression " .. json.encode(st.pop()))
  end
  return r
end

------------------- selectors ------------------------
local run, eval

local jpi = {}
function jpi.root(_, _, root) return { root } end

function jpi.current_node(_, curr, root) return curr[1] end

function jpi.ident_selector(i, curr, _)
  local res = {}
  for _, e in ipairs(curr) do if type(e) == 'table' then res[#res + 1] = e[i[2]] end end
  return res
end

function jpi.star_selector(i, curr, _)
  local res = {}
  for _, e in ipairs(curr) do
    for _, e2 in pairs(e) do res[#res + 1] = e2 end
  end
  return res
end

function jpi.index_selector(i, curr, root)
  local res, idx = {}, i[2]
  for _, e in ipairs(curr) do
    local idx2 = eval(idx, e)
    local n = #e
    res[#res + 1] = e[idx2 < 0 and n + 1 + idx2 or idx2]
  end
  return res
end

function jpi.slice_selector(i, curr, _)
  local res, i1, i2, i3 = {}, i[2], i[3], i[4]
  i3 = i3 or 1
  for _, e in ipairs(curr) do
    local n = #e
    i1 = i1 or i3 < 0 and n or 1
    if i1 < 0 then i1 = n + 1 + i1 end
    i2 = i2 or i3 < 0 and 1 or n
    for x = i1, i2, i3 do
      res[#res + 1] = e[x]
    end
  end
  return res
end

local function apply(i, expr, curr, root)
  return jpi[i[1]](i, { expr }, root)
end

function jpi.list(i, curr, root)
  local res = {}
  for _, i2 in ipairs(i[2]) do -- [2,3]
    for _, e in ipairs(curr) do
      append(res, apply(i2, e, curr, root))
    end
  end
  return res
end

local function recurse(i, expr, curr, root, res)
  if type(expr) == 'table' then
    local r = apply(i, expr, root)
    append(res, r)
    for _, v in pairs(expr) do
      recurse(i, v, curr, root, res)
    end
  end
end
function jpi.recursive_descent(i, curr, root)
  local res = {}
  for _, e in ipairs(curr) do
    recurse(i[2], e, curr, root, res)
  end
  return res
end

local function checkIdent(res, i) if i[1] == 'json' then return res ~= nil else return res end end

function jpi.filter(i, currs, root)
  local res, f = {}, i[2]
  for _, e in pairs(currs[1]) do
    local r = checkIdent(eval(f, { e }), f)
    if r then res[#res + 1] = e end
  end
  return res
end

------------------ filter evaluator ----------------------
local function member(x, y)
  if type(y) ~= 'table' then return false end
  for _, e in ipairs(y) do if e == x then return true end end
end
local function coerce(x, y)
  local x1 = tonumber(x)
  if x1 then return x1, tonumber(y) else return tostring(x), tostring(y) end
end
local fops = {
  ['+'] = function(x, y)
    x, y = coerce(x, y)
    return x and y and x + y
  end,
  ['-'] = function(x, y)
    x, y = coerce(x, y)
    return x and y and x - y
  end,
  ['*'] = function(x, y)
    x, y = coerce(x, y)
    return x and y and x * y
  end,
  ['/'] = function(x, y)
    x, y = coerce(x, y)
    return x and y and x / y
  end,
  ['>'] = function(x, y)
    x, y = coerce(x, y)
    return x and y and x > y
  end,
  ['>='] = function(x, y)
    x, y = coerce(x, y)
    return x and y and x >= y
  end,
  ['<'] = function(x, y)
    x, y = coerce(x, y)
    return x and y and x < y
  end,
  ['<='] = function(x, y)
    x, y = coerce(x, y)
    return x and y and x <= y
  end,
  ['=='] = function(x, y) return tostring(x) == tostring(y) end,
  ['=~'] = function(x, y) return tostring(x):match(tostring(y)) end,
  ['='] = function(x, y) error("Not implemeneted") end,
  ['!='] = function(x, y) return tostring(x) ~= tostring(y) end,
  ['in'] = function(x, y) return member(x, y) or false end,
  ['nin'] = function(x, y) return not member(x, y) or false end,
  ['subsetof'] = function(x, y)
    if type(x) ~= 'table' or type(y) ~= 'table' then return false end
    local t = {}
    for _, v in ipairs(y) do t[v] = true end
    for _, v in ipairs(x) do if not t[v] then return false end end
    return true
  end,
}

local ffuns = {
  ['||'] = function(expr, data)
    local x = checkIdent(eval(expr[2], data), expr[2])
    if x then return x end
    local y = checkIdent(eval(expr[3], data), expr[2])
    if y then return y else return false end
  end,
  ['&&'] = function(expr, data)
    local x = checkIdent(eval(expr[2], data), expr[2])
    if not x then return false end
    local y = checkIdent(eval(expr[3], data), expr[2])
    if y then return y else return false end
  end,
  ['json'] = function(expr, data) return run(expr[2], data)[1] end,
  ['neg'] = function(expr, data) return -eval(expr[2], data) end,
  ['!'] = function(expr, data) return not eval(expr[2], data) end,
  ['funcall'] = function(expr, data)
    local f, args, params = expr[2], expr[3], {}
    for _, p in ipairs(args) do params[#params + 1] = eval(p, data) end
    return _G[f](table.unpack(params))
  end,
  ['table'] = function(expr, data)
    local f, args, tab = expr[2], expr[3], {}
    for _, p in ipairs(f) do tab[#tab + 1] = eval(p, data) end
    return tab
  end,
}

function eval(expr, data)
  if type(expr) == 'table' then
    local op = expr[1]
    if fops[op] then
      local x = eval(expr[2], data)
      local y = eval(expr[3], data)
      if x ~= nil and y ~= nil then return fops[op](x, y) end
    elseif ffuns[op] then
      return ffuns[op](expr, data)
    else
      return false
    end
  else
    return expr
  end
end

------------------- jsonpath ------------------------

local function parseJpath(str)
  local tkns, out = parseTokens(str), output()
  p_jsonpath(tkns, out)
  return out.instr
end

function run(instr, root)
  local currs = { root }
  for _, i in ipairs(instr) do
    currs = jpi[i[1]](i, currs, root)
  end
  return currs
end

local function jpath(jp)
  local instr = parseJpath(jp)
  return function(expr) return run(instr, expr) end
end

json.path = jpath

local function jpath2(str, expr)
  local res = jpath(str)(expr)
  print(str, "=", json.encode(res))
end

------------------------------------
-- Usage:
-- local p = jpath("$..test")
-- p({h={test=8}})

-- Test cases
--jpath2("$.foo.bar",{foo={b=9,bar=8}})
--jpath2("$.foo.bar",{foo={b=9,bar=8}})
--jpath2("$[foo].bar",{foo={b=9,bar=8}})
--jpath2("$.foo['bar','b']",{foo={b=9,bar=8}})
--jpath2("$.*",{foo={b=9,bar=8}})
--jpath2("$..b",{foo={b=9,bar={b=7}}})
--jpath2("$..[b][1]",{foo={b={7},bar={9}}})
--jpath2("$[::-1]",{"a","b","c","d"})
--jpath2("$[?(@.book > 3 || @.book==0)]",{boo=9,{book=5},{book=0},{book=3}})
--jpath2("$.store.book[*].author",testData)
--jpath2("$..author",testData)
--jpath2("$.store.*",testData)
--jpath2("$.store..price",testData)
--jpath2("$..book[2]",testData)
----jpath2("$..book[(@.length-1)]",testData)
--jpath2("$..book[-1:]",testData)
--jpath2("$..book[1,2]",testData)
--jpath2("$..book[?(@.isbn)]",testData)
--jpath2("$..book[?(@.price<10)]",testData)
--jpath2("$..*",testData)
--jpath2("$[(2+2)]",{1,2,3,4})
--jpath2("$[?(@.bar || @.foo)]",{a={foo=false}})
--jpath2("$[?('b' in @..foo)]",{a={foo={'a','b'}},foo={'c','b'}})
--jpath2("$[?(@..foo)]",{a={foo={'a','b'}},c={foo={'c','b'}} })
--jpath2("$[?(@.a)]",{a={foo={'a','b'}},c={foo={'c','b'}} })
--jpath2("$..[?(@.a>8)]",{a=9,c={a={'c','b'}} })
--jpath2("$..[?(!@.a)]",{a=9,c={a={'c'},b=7}})
--[[   -- Grammar

local grammar = [[
jsonpath = "$" [relative-location]
jsonpath = / "@" [relative-location]
relative-location = "." relative-path
relative-location = / ".." relative-path
relative-location = / ".." bracket-expression [relative-location]
relative-location = / "^" [relative-location]

relative-path = identifier [relative-location]
relative-path = string [relative-location]
relative-path = / "*" [relative-location]
bracket-expression = "[" bracketed-element *bracket-expression_aux "]"
bracket-expression-aux = "," bracketed-element

bracketed-element = integer ; index
bracketed-element = / slice
bracketed-element = / string
bracketed-element = / "*"
bracketed-element = / "?" expression ; filter expression
bracketed-element = / jsonpath

expression = single-quoted-string
expression = / json-literal ; any valid JSON value
expression = / jsonpath
expression = / unary-expression
             / binary-expression
             / regex-expression
             / paren-expression

paren-expression  = "(" expression ")"
unary-expression = "!" expression
unary-expression = "-" expression
binary-expression = expression binary-operator expression
regex-expression = expression "=~" "/" regex "/" [i]
binary-operator  = "*" / "/" / "%" / "+" / "-" / "&&" / "||" / "<" / "<=" / "==" / ">=" / ">" / "!="
;
; "regex" represents regular expression characters

function-expression = identifier function-expression-aux
function-expression-aux = no-args / one-or-more-args
no-args             = "(" ")"
one-or-more-args    = "(" one-or-more-args-aux ")"
one-or-more-args-aux = function-arg *one-or-more-args-aux-aux
one-or-more-args-aux-aux = "," function-arg
function-arg        = expression
]]
