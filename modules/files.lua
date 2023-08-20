local EM,FB = ...

local json,LOG,DEBUG = FB.json,EM.LOG,EM.DEBUG
local copy,cfg = EM.utilities.copy,EM.cfg

LOG.register("files","Log filesystem events")

local CRC16Lookup = {
  0x0000,0x1021,0x2042,0x3063,0x4084,0x50a5,0x60c6,0x70e7,0x8108,0x9129,0xa14a,0xb16b,0xc18c,0xd1ad,0xe1ce,0xf1ef,
  0x1231,0x0210,0x3273,0x2252,0x52b5,0x4294,0x72f7,0x62d6,0x9339,0x8318,0xb37b,0xa35a,0xd3bd,0xc39c,0xf3ff,0xe3de,
  0x2462,0x3443,0x0420,0x1401,0x64e6,0x74c7,0x44a4,0x5485,0xa56a,0xb54b,0x8528,0x9509,0xe5ee,0xf5cf,0xc5ac,0xd58d,
  0x3653,0x2672,0x1611,0x0630,0x76d7,0x66f6,0x5695,0x46b4,0xb75b,0xa77a,0x9719,0x8738,0xf7df,0xe7fe,0xd79d,0xc7bc,
  0x48c4,0x58e5,0x6886,0x78a7,0x0840,0x1861,0x2802,0x3823,0xc9cc,0xd9ed,0xe98e,0xf9af,0x8948,0x9969,0xa90a,0xb92b,
  0x5af5,0x4ad4,0x7ab7,0x6a96,0x1a71,0x0a50,0x3a33,0x2a12,0xdbfd,0xcbdc,0xfbbf,0xeb9e,0x9b79,0x8b58,0xbb3b,0xab1a,
  0x6ca6,0x7c87,0x4ce4,0x5cc5,0x2c22,0x3c03,0x0c60,0x1c41,0xedae,0xfd8f,0xcdec,0xddcd,0xad2a,0xbd0b,0x8d68,0x9d49,
  0x7e97,0x6eb6,0x5ed5,0x4ef4,0x3e13,0x2e32,0x1e51,0x0e70,0xff9f,0xefbe,0xdfdd,0xcffc,0xbf1b,0xaf3a,0x9f59,0x8f78,
  0x9188,0x81a9,0xb1ca,0xa1eb,0xd10c,0xc12d,0xf14e,0xe16f,0x1080,0x00a1,0x30c2,0x20e3,0x5004,0x4025,0x7046,0x6067,
  0x83b9,0x9398,0xa3fb,0xb3da,0xc33d,0xd31c,0xe37f,0xf35e,0x02b1,0x1290,0x22f3,0x32d2,0x4235,0x5214,0x6277,0x7256,
  0xb5ea,0xa5cb,0x95a8,0x8589,0xf56e,0xe54f,0xd52c,0xc50d,0x34e2,0x24c3,0x14a0,0x0481,0x7466,0x6447,0x5424,0x4405,
  0xa7db,0xb7fa,0x8799,0x97b8,0xe75f,0xf77e,0xc71d,0xd73c,0x26d3,0x36f2,0x0691,0x16b0,0x6657,0x7676,0x4615,0x5634,
  0xd94c,0xc96d,0xf90e,0xe92f,0x99c8,0x89e9,0xb98a,0xa9ab,0x5844,0x4865,0x7806,0x6827,0x18c0,0x08e1,0x3882,0x28a3,
  0xcb7d,0xdb5c,0xeb3f,0xfb1e,0x8bf9,0x9bd8,0xabbb,0xbb9a,0x4a75,0x5a54,0x6a37,0x7a16,0x0af1,0x1ad0,0x2ab3,0x3a92,
  0xfd2e,0xed0f,0xdd6c,0xcd4d,0xbdaa,0xad8b,0x9de8,0x8dc9,0x7c26,0x6c07,0x5c64,0x4c45,0x3ca2,0x2c83,0x1ce0,0x0cc1,
  0xef1f,0xff3e,0xcf5d,0xdf7c,0xaf9b,0xbfba,0x8fd9,0x9ff8,0x6e17,0x7e36,0x4e55,0x5e74,0x2e93,0x3eb2,0x0ed1,0x1ef0
}

local function base64encode(data)
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

local function getSize(b)
  local buf = {}
  for i=1,8 do buf[i]=b:byte(16+i) end
  local width = (buf[1] << 24) + (buf[2] << 16) + (buf[3] << 8) + (buf[4] << 0)
  local height = (buf[5] << 24) + (buf[6] << 16) + (buf[7] << 8) + (buf[8] << 0);
  return width,height
end

local function crc16(bytes)
  local crc = 0
  for i=1,#bytes do
    local b = string.byte(bytes,i,i)
    crc = ((crc<<8) & 0xffff) ~ CRC16Lookup[(((crc>>8)~b) & 0xff) + 1]
  end
  return tonumber(crc)
end

local function readFile(file,err) 
  local f = io.open(file); assert(f or EM.cfg.noFileError,"No such file:"..file) 
  if f then local c = f:read("*all"); f:close() return c end
end

local firstTemp = true 
local function createTemp(name,content) -- Storing code fragments on disk will help debugging. TBD
  if firstTemp then DEBUG("files","sys","Using %s for temporary files",EM.cfg.temp) firstTemp=false end
  local crc = crc16(content)
  local fname = EM.cfg.temp..name.."_"..crc..".lua" 
  local f,res; f = io.open(fname,"r") 
  if f then -- If it exists, don't store it again
    content = f:read("*all")
    f:close() 
    return fname,content 
  end 
  f,res = io.open(fname,"w+")
  if not f then LOG.error("Warning - couldn't create temp files in %s - %s",EM.cfg.temp,res) return 
  else DEBUG("files","sys","Created temp file %s",fname) end
  f:write(content) 
  f:close()
  return fname,content
end

local deviceTemplates,sortedDeviceTemplates
local function getDeviceResources()
  if deviceTemplates == nil then 
    local f = io.open(EM.cfg.modPath.."devices.json")
    if f then deviceTemplates=FB.json.decode(f:read("*all")) f:close() else deviceTemplates={} end
    local r = {} for n,d in pairs(deviceTemplates) do r[#r+1]={n,d} end
    table.sort(r,function(a,b) return a[1] < b[1] end)
    sortedDeviceTemplates=r
  end
  return deviceTemplates,sortedDeviceTemplates
end

local function mergeUI(info)
  local ui,res = {},{}
  for k,v in pairs(info) do local i = k:match("u(%d+)$") if i then ui[#ui+1]={tonumber(i),v} end end
  table.sort(ui,function(a,b) return a[1] < b[1] end)
  for _,u in ipairs(ui) do res[#res+1]=u[2] info[u[1]]=nil end
  info.UI = res
end

local function matchContinousLines(str,pattern1,pattern2,collector)
  local state = 0
  str:gsub("(.-)[\n\r]+",function(line)
      local m = {line:match(pattern1)}
      if  #m > 0 then
        if state < 2 and line:match(pattern2) then collector(table.unpack(m)) state=1 end
      elseif state==1 then state = 2 end
    end)
end

local function imageInclude(image,fn,name)
  assert(image,"Missing IMAGE file:"..tostring(fn))
  local w,h = getSize(image)
  assert(image,"Missing IMAGE size:"..tostring(fn))
  -- fn = fn:gsub("[%/%\\%s%c]","_"):match("(.+)[%.%$]")
  return string.format([[
    _IMAGES['%s']={data='%s',w=%s,h=%s}
    ]],name,"data:image/png;base64,"..base64encode(image),w,h)
end

local function loadSource(code,fileName) -- Load code and resolve info and --FILE directives
  local files = {}
  assert(code,"Missing code for "..tostring(fileName))
  matchContinousLines(code,[[%-%-%s*FILE:%s*(.-)%s*,%s*(.-);]],[[%-%-FILE:%s*(.-)%s*,%s*(.-);]],
    function(file,name)
      file = file:gsub("/",EM.cfg.pathSeparator)
      files[#files+1]={name=name,type='lua',isOpen=false,content=readFile(file,EM.cfg.noFileError),isMain=false,fname=file}
      return ""
    end)
  table.insert(files,{name="main",type='lua',isOpen=false,content=code,isMain=true,fname=fileName})
  local images = {"_IMAGES = _IMAGES or {}"}
  matchContinousLines(code,[[%-%-%s*IMAGE:%s*(.-)%s*,%s*(.-);]],[[%-%-IMAGE:%s*(.-)%s*,%s*(.-);]],
    function(file,name)
      file = file:gsub("/",EM.cfg.pathSeparator)
      images[#images+1]=imageInclude(readFile(file,EM.cfg.noFileError),file,name)
      return ""
    end)
  if #images > 1 then
    files[#files+1] = {name="IMAGES64B",type='lua',isOpen=false,content=table.concat(images,"\n"),isMain=false,fname="IMAGES64B"}
  end

  local info = code:match("%-%-%[%[QAemu(.-)%-%-%]%]")
  if info==nil or info=="" then
    local il = {}
    matchContinousLines(code,"%-%-%s*%%%%(.-)$","%-%-%%%%(.-)$",function(l) il[#il+1]=l end)
    info=table.concat(il,",")
  end
  if info then 
    local icode,res = load("return {"..info.."}",nil,nil,{EM=EM,FB=FB,G=_G})
    if not icode then error(res) end
    info,res = icode()
    if res then error(res) end
  end
  mergeUI(info)
  if info and info.uiFrom then
    if cfg.offline then
      LOG.warn("Can't have both offline and uiFrom - ignoring uiFrom")
    else 
      local d = FB.api.get("/devices/"..info.uiFrom)
      if d then
        info.UI = EM.UI.view2UI(d.properties.viewLayout,d.properties.uiCallbacks)
      end
    end
  end
  return files,(info or {})
end

local function loadLua(fileName) return loadSource(readFile(fileName),fileName) end
local function findFirstCodeLine(code,name)  -- Try to find first code line
  local n,first,init = 1
  for line in string.gmatch(code,"([^\r\n]*\r?\n?)") do
    if not (line=="" or line:match("^[%-%s]+")) then 
      if not first then first = n end
    end
    if line:match("%s*QuickApp%s*:%s*onInit%s*%(") then
      if not init then init = n end
    end
    n=n+1
  end
  return first or 1,init
end

local function loadFQA(fqa,args)  -- Load FQA
  local files,main = {}
  for _,f in ipairs(fqa.files) do
    local fname,content = createTemp(f.name,f.content)
    if fname==nil then fname=f.name..crc16(f.content) content = f.content end -- Create temp files for fqa files, easier to debug
    f.content = content
    if f.isMain then f.fname=fname main=f
    else files[#files+1] = {name=f.name,content=f.content,type='lua',isOpen=false,isMain=f.isMain,fname=fname} end
    local first,init = findFirstCodeLine(f.content,f.name)
    if args.breakOnLoad then EM.mobdebug.setbreakpoint(fname,first) end
    if args.breakOnInit and init then EM.mobdebug.setbreakpoint(fname,init) end
  end
  table.insert(files,{name=main.name,content=main.content,type='lua',isOpen=false,isMain=true,fname=main.fname})
  return files,{name=fqa.name,type=fqa.type,properties=fqa.initialProperties}
end

local function loadFile(code,file,args)
  if file and not code then
    if file:match("%.fqa$") then return loadFQA(json.decode(readFile(file)),args)
    elseif file:match("%.lua$") then return loadLua(file,args)
    else error("No such file:"..file) end
  elseif type(code)=='table' then  -- fqa table
    return loadFQA(code,args)
  elseif code then
    local fname = file or createTemp("main",code) or "main"..crc16(code) -- Create temp file for string code easier to debug
    return loadSource(code,fname)
  end
end

local function packageFQA(D)
  local dev = D.dev
  local files = {}
  for _,f in ipairs(D.files or {}) do local f2=copy(f) f2.fname=nil files[#files+1]=f2 end
  local fqa = {
    name = dev.name,
    type = dev.type,
    apiVersion="1.2",
    initialInterfaces = dev.interfaces,
    initialProperties = {
      apiVersion="1.2",
      viewLayout=dev.properties.viewLayout,
      uiCallbacks = dev.properties.uiCallbacks,
      quickAppVariables = dev.properties.quickAppVariables,
      typeTemplateInitialized=true,
    },
    files = files
  }
  return fqa
end

local function saveFQA(D)
  local fqa = packageFQA(D)
  local save = D.name..".fqa"
  local stat,res = pcall(function()
      local f = io.open(save,"w+")
      assert(f,"Can't open file "..save)
      f:write((json.encode(fqa)))
      f:close()
    end)
  if not stat then LOG.error("saving .fqa - %s",res) 
  else LOG.sys("Saved %s",save) end
end

local function uploadFQA(D)
  local fqa = packageFQA(D)
  local dev = D.dev
  local res,err = FB.api.post("/quickApp/",fqa)
  if not res then LOG.error("uploading .fqa '%s' - %s",dev.name,err) 
  else LOG.sys("Uploaded '%s', deviceId:%s",res.name,res.id) end
end

local function patchQA(_,client,ref,_,opts)
  local device,QA = opts.deviceId,opts.QAid
  local fs,fileMap = {},EM.Devices[opts.QAid].fileMap
  for k,v in pairs(opts) do 
    if k ~= "deviceId" and k ~= "QAid" then 
      fs[#fs+1]=v 
    end 
  end
  local files = FB.api.get("/quickApp/"..device.."/files","remote") or {}
  local files2 = {}
  for _,f in ipairs(files) do
    files2[f.name]=f
    if not fileMap[f.name] then
      local _,code = FB.api.delete("/quickApp/"..device.."/files/"..f.name,"remote")
      if code > 204 then LOG.error("Failed deleting file '%s' for QA:%s",f,device) end
      DEBUG("files","sys","Deleting file '%s' for QA:'%s'",f.name,device)
    end
  end
  for _,f in ipairs(fs) do
    if files2[f] then --Exists
      local fs = {isMain=false,type='lua',isOpen=false,name=f,content=fileMap[f].content}
      local _,code = FB.api.put("/quickApp/"..device.."/files/"..f,fs,"remote")
      if code > 204 then LOG.error("Failed updating file '%s' for QA:%s",f,device) end
      DEBUG("files","sys","Updating file '%s' for QA:%s",f,device)
    else -- New
      local fs = {isMain=false,type='lua',isOpen=false,name=f,content=fileMap[f].content}
      local _,code = FB.api.post("/quickApp/"..device.."/files",fs,"remote")
      if code > 204 then LOG.error("Failed creating file '%s' for QA:%s",f,device) end
      DEBUG("files","sys","Creating file '%s' for QA:%s",f,device)
    end
  end
  client:send("HTTP/1.1 302 Found\nLocation: "..(ref or "").."\n\n")
  return true
end

EM.EMEvents('start',function(_) 
    EM.addPath("GET/TQAE/updateQA",patchQA)
  end)

EM.loadFile, EM.saveFQA, EM.uploadFQA, EM.packageFQA = loadFile, saveFQA, uploadFQA, packageFQA
EM.getDeviceResources = getDeviceResources