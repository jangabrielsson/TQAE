function makeTokenizer()

  local patterns = {}
  local nopers = {['jmp']=true,}--['return']=true}
  
  local function token(pattern, createFn)
    table.insert(patterns, function ()
        local _, len, res, group = string.find(source, "^(" .. pattern .. ")")
        if len then
          if createFn then
            local tokenv = createFn(group or res)
            tokenv.from, tokenv.to = cursor, cursor+len
            table.insert(tokens, tokenv)
          end
          source = string.sub(source, len+1)
          cursor = cursor + len
          return true
        end
      end)
  end

  local function toTimeDate(str)
    local t,y,m,d,h,min,s=os.date("*t"),str:match("(%d?%d?%d?%d?)/?(%d+)/(%d+)/(%d%d):(%d%d):?(%d?%d?)")
    return os.time{year=y~="" and y or t.year,month=m,day=d,hour=h,min=min,sec=s~="" and s or 0}
  end

  local SW={['(']='lpar',['{']='lcur',['[']='lbra',['||']='lor'}
  token("[%s%c]+")
--2019/3/30/20:30
  token("%d?%d?%d?%d?/?%d+/%d+/%d%d:%d%d:?%d?%d?",function (t) return {type="number", value=toTimeDate(t)} end)
  token("%d%d:%d%d:?%d?%d?",function (t) return {type="number", value=toTime(t)} end)
  token("%d+:%d+",function (_) error('Bad time constant') end)
  token("[t+n][/]", function (op) return {type="operator", value=op} end)
  token("#[A-Za-z_][%w_%-]*", function (w) return {type="event", value=w} end)
  token("[_a-zA-Z\xC3\xA5\xA4\xB6\x85\x84\x96][_0-9a-zA-Z\xC3\xA5\xA4\xB6\x85\x84\x96]*", function (w) return {type=nopers[w] and 'operator' or "name", value=w} end)
  token("%d+%.%d+", function (d) return {type="number", value=tonumber(d)} end)
  token("%d+", function (d) return {type="number", value=tonumber(d)} end)
  token('"([^"]*)"', function (s) return {type="string", value=s} end)
  token("'([^']*)'", function (s) return {type="string", value=s} end)
  token("%-%-.-\n")
  token("%-%-.*")  
  token("===",function (op) return {type="operator", value=op} end)    
  token("%.%.%.",function (op) return {type="operator", value=op} end)
  token("[@%$=<>!+%.%-*&|/%^~;:][%$+@=<>&|;:%.]?", function (op) return {type="operator", value=op} end)
  token("[{}%(%),%[%]#%%]", function (op) return {type="operator", value=op} end)


  local function dispatch() for _,m in ipairs(patterns) do if m() then return true end end end

  local function tokenize(src)
    source, tokens, cursor = src, {}, 0
    while #source>0 and dispatch() do end
    if #source > 0 then print("tokenizer failed at " .. source) end
    return tokens
  end

  return tokenize
end