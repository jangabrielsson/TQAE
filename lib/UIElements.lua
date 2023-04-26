------------------UITable ----------------
class 'UITable'
function UITable:__init(lbl,tab,qa)
  assert(type(lbl)=='string',"UITable requires string label")
  assert(type(tab)=='string',"UITable requires string table")
  self.lbl,self.qa = lbl,qa or quickApp
  self:_parse(tab)
end
function UITable:_parse(tab)
  self.frags,self.tags = {},{}
  tab=tab:match(".-(<table.->.-</table>).*")
  tab=tab:gsub("[%c%s]*(<tr.->.-</tr>)[%c%s]*",function(s) return s end)
  tab=tab:gsub("[%c%s]*(<td.->.-</td>)[%c%s]*",function(s) return s end)
  tab = tab.."{{EOF}}"
  local tags,frags,t,i = self.tags,self.frags,{},0
  tab:gsub("(.-){{(.-)}}",function(frag,tag)
      local tag2,dflt = tag:match("(.-)/(.*)")
      if tag2 then tag = tag2 else dflt = "" end
      i=i+1; frags[i]=frag; i=i+1; frags[i]=dflt; 
      if tags[tag]==nil then tags[tag]={} end
      table.insert(tags[tag],i)
    end)
end
function UITable:set(tag,txt,...)
  tag = tostring(tag)
  local is,args = self.tags[tag],{...}
  if not is then fibaro.warning(__TAG,"Unknown tag ",tag) return end
  if #args>0 then txt = string.format(txt,...) end
  for _,i in ipairs(is) do self.frags[i] = txt end
end
function UITable:update()
  local str = table.concat(self.frags)
  self.qa:updateView(self.lbl,'text',str)
end

------------------------- UIMatrix ----------------------------
class 'UIMatrix'(UITable)
function UIMatrix:__init(args)
  self.colLabels = args.columns or {'mon','tue','wed','thu','fri','sat','sun'}
  UITable.__init(self,args.label,"<table></table>",args.qa)
  local cal = args.data or {}
  self.tags2 = {}
  local c = {}
  for _,d in ipairs(self.colLabels) do
    c[d]={}
    for t,evs in pairs(cal[d] or {}) do
      c[d][t] = evs
    end
  end
  self.cal = c
  self:_adjustTable()
  self:_sync()
end
local function member(e,l) for i,v in ipairs(l) do if e==v then return i end end end
function UIMatrix:colName(lbl) return lbl:sub(1,1):upper()..lbl:sub(2) end
function UIMatrix:renderEntry(entry) return json.encode(entry):sub(2,-2) end -- table of entries
function UIMatrix:set(t,str) self.tags2[t]=str; UITable.set(self,t,str) end
function UIMatrix:addEntry(d,t,val,op)
  op = op==nil and true or op
  local d0 = self.cal[d]
  local evs = d0[t] or {}
  d0[t] = evs
  local exist = member(val,evs)
  if op and not exist then 
    evs[#evs+1]=val
    self:_adjustTable()
    self:_set(d,t,evs)
  elseif (not op) and exist then
    table.remove(evs,exist)
    if #evs>0 then self:_set(d,t,evs) else d0[t]=nil end
    self:_adjustTable()
  end
end
function UIMatrix:clearEntry(d,t,val) self:addEntry(d,t,val,false) end
function UIMatrix:update() self:_sync() UITable.update(self) end 

function UIMatrix:_makeTable(n,tn)
  self.rows = n
  local t,fmt = {},string.format
  local function out(s,...) t[#t+1]=fmt(s,...) end
  out("<table {{tableAttr}}>")
  out("<tr {{headerAttr}}><td></td>")
  for _,d in ipairs(self.colLabels) do out("<td><font {{headerFont}}>%s</font></td>",self:colName(d)) end
  out("</tr></font>")
  for i=1,n do
    out("<tr>")
    out("<td {{fcolAttr}}><font {{fcolFont}}>%s</font></td>",tn[i])
    for _,cl in ipairs(self.colLabels) do out("<td {{itemAttr}}>{{%s%s}}</td>",cl,tn[i]) end
    out("</tr>")
  end
  out("</table>")
  UITable._parse(self,table.concat(t))
  for t,v in pairs(self.tags2) do self:set(t,v) end
end
function UIMatrix:_adjustTable()
  local ts,n = {},0
  for _,evs in pairs(self.cal) do
    for t,_ in pairs(evs) do n=n+(ts[t] and 0 or 1) ts[t]=true end
  end
  if n ~= self._rows then
    local t1 = {}
    for t2,_ in pairs(ts) do t1[#t1+1]=t2 end
    table.sort(t1)
    self:_makeTable(n,t1)
  end
end 
function UIMatrix:_sync() 
  for d,evs in pairs(self.cal) do
    for t,ev in pairs(evs) do self:_set(d,t,ev) end
  end
end
function UIMatrix:_set(d,t,val)
  local str = self:renderEntry(val)
  UITable.set(self,d..t,str) 
end



