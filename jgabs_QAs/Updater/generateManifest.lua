_=loadfile and loadfile("TQAE.lua"){
  debug = { onAction=true, http=false, UIEevent=true },
  copas=true,
}

--%%name="Generator"
--%%type="com.fibaro.binarySwitch"
--%%fullLUA=true

local EM = hc3_emulator.EM

local function resolve(str,vars)
  for v,sub in pairs(vars) do str=str:gsub("%$"..v,sub) end
  return str
end

local function generateVersion(vs,ctx)
  local v = {}
  for k,e in pairs(vs) do v[k]=e end  -- Copy values from vs to v
  local files,vars,info = v.files,v.vars

  for k,v in pairs(ctx.vars) do if not vars[k] then vars[k]=v end end

  local mainfile,filePrefix,baseFile
  if v.mainfile then
    filePrefix,baseFile = v.mainfile:match("$(.-)/(.*)")
    mainfile = v.mainfile
  end

  local function loadinfo() 
    if info then return info end
    local url = resolve(mainfile,vars)
    local res,stat,headers = EM.httpRequest({
        method="GET", url=url, checkCertificate = false, timeout = 15000})
    info = EM._createQA({code=res,file=baseFile}) 
  end

  if files=='generate' then
    loadinfo()
    v.files = {}
    for n,f in pairs(info.fileMap) do v.files[n]="$"..filePrefix.."/"..f.fname end
  end

  if v.viewLayout=="generate" then
    loadinfo()
    if next(info.UI)~= nil then
      EM.UI.transformUI(info.UI)
      v.viewLayout = json.encode(EM.UI.mkViewLayout(info.UI))
      v.uiCallbacks = json.encode(EM.UI.uiStruct2uiCallbacks(info.UI))
    else v.viewLayout = nil end
  end

  if v.interfaces=="generate" then loadinfo() v.interfaces = info.interfaces end
  v.version = math.floor(v.version*1000+0.5)/1000
  
  return v
end

local function generateAppEntry(id,e)
  local entry,ctx = {}
  entry.name=e.name
  entry.type=e.type
  entry.versions = {}
  ctx = { versions = entry.versions, vars = e.vars or {} }
  for _,s in ipairs(e.versions) do entry.versions[#entry.versions+1]=generateVersion(s,ctx) end
  return entry
end

local sortKeys = {
  'name','type','version','vars','descr','files','keep','quickAppVariables','viewLayout','uiCallbacks','configXml',
  'interfaces','properties','view', 'actions','created','modified','sortOrder'
}
local sortOrder={}
for i,s in ipairs(sortKeys) do sortOrder[s]="\n"..string.char(i+64).." "..s end
local function keyCompare(a,b)
  local av,bv = sortOrder[a] or a, sortOrder[b] or b
  return av < bv
end

function QuickApp:onInit()
  self:debug(self.name, self.id)
  EM.cfg.noFileError = true
  local file = io.open("jgabs_QAs/Updater/MANIFEST.lua","r+")
  local data,res = file:read("*all") file:close()
  data,res = load(data,nil,"t",_G)
  if data then data = data() else print(res) end

  local out = {}
  for id,e in pairs(data) do out[id]=generateAppEntry(id,e) end
  print("\n"..EM.utilities.encodeFormated(out,keyCompare))
  
  file = io.open("jgabs_QAs/Updater/MANIFEST.json","w+")
  local res = { date=os.date("%x %X"), updates = out }
  file:write(EM.utilities.encodeFormated(res,keyCompare))
  file:close()
end

OldEventRunner = [[
{
   "uiCallbacks": [
      {
        "callback": "debugTriggerClicked",
        "eventType": "onReleased",
        "name": "debugTrigger"
      },
      {
        "callback": "debugPostClicked",
        "eventType": "onReleased",
        "name": "debugPost"
      },
      {
        "callback": "debugRuleClicked",
        "eventType": "onReleased",
        "name": "debugRule"
      }
    ],
   "viewLayout": {
      "$jason": {
        "body": {
          "header": {
            "style": {
              "height": "0"
            },
            "title": "quickApp_device_53"
          },
          "sections": {
            "items": [
              {
                "components": [
                  {
                    "name": "ERname",
                    "style": {
                      "weight": "1.2"
                    },
                    "text": "...",
                    "type": "label"
                  },
                  {
                    "style": {
                      "weight": "0.5"
                    },
                    "type": "space"
                  }
                ],
                "style": {
                  "weight": "1.2"
                },
                "type": "vertical"
              },
              {
                "components": [
                  {
                    "name": "debugTrigger",
                    "style": {
                      "weight": "1.2"
                    },
                    "text": "Triggers:ON",
                    "type": "button"
                  },
                  {
                    "style": {
                      "weight": "0.5"
                    },
                    "type": "space"
                  }
                ],
                "style": {
                  "weight": "1.2"
                },
                "type": "vertical"
              },
              {
                "components": [
                  {
                    "name": "debugPost",
                    "style": {
                      "weight": "1.2"
                    },
                    "text": "Post:ON",
                    "type": "button"
                  },
                  {
                    "style": {
                      "weight": "0.5"
                    },
                    "type": "space"
                  }
                ],
                "style": {
                  "weight": "1.2"
                },
                "type": "vertical"
              },
              {
                "components": [
                  {
                    "name": "debugRule",
                    "style": {
                      "weight": "1.2"
                    },
                    "text": "Rules:ON",
                    "type": "button"
                  },
                  {
                    "style": {
                      "weight": "0.5"
                    },
                    "type": "space"
                  }
                ],
                "style": {
                  "weight": "1.2"
                },
                "type": "vertical"
              }
            ]
          }
        },
        "head": {
          "title": "quickApp_device_53"
        }
      }
    }
}
  ]]

--OldEventRunner = json.decode(OldEventRunner)
--print(json.encode(OldEventRunner.uiCallbacks))
--print()
--print(json.encode(OldEventRunner.viewLayout))
--_=0