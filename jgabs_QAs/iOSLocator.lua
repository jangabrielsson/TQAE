_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { 
    onAction=true, http=false, UIEevent=true 
  },
}

--%%name = "iOSLocator" 
--%%quickVars = {['HomeVar'] = 'iOSHome',['UserLocVars'] = 'Bob:BobLoc,Ann:AnnLoc,Tim:TimLoc,Alice:AliceLoc',['LocationsVar'] = 'iOSLocInfo',['HomeName'] = 'Home',['AwayName'] = 'Away',}
--%%u1={label='version', text=''}
--%%u2={label='home', text=''}
--%%u3={label='user', text=''}

--FILE:lib/fibaroExtra.lua,fibaroExtra;
---------------------- Setup users -----------------------------
local version = "V0.2"
local USERS = {      -- Fill in with iOS credentials
  {name='Bob',   device='iPhone', home=true, icloud={user="XXXX1", pwd=".."}},
  {name='Ann',   device='iPhone', home=true, icloud={user="XXXX2", pwd=".."}},
  {name='Tim',   device='iPhone', home=true, icloud={user="XXXX3", pwd=".."}},
  {name='Alice', device='iPhone', home=false,icloud={user="XXXX4", pwd=".."}},  -- Family member not living at home (not counted in "all at home")
}

--[[
'User' is username - should be without spaces and strange characters (used in global variable name)
'home' is true if user is part of people that live at home - used to decide if all at home etc.
'device' is name of iDevice, matches so "iPhone" mathes 'Jan's iPhone'.
icloud.user is icloud username
icloud.pwd = is icloud password

Ex.
local USERS={
  {name='User1', home=true, device='iPhone', icloud={user='x2@y.com', pwd='xizzy1'}}, 
  {name='User2', home=true, device='iPhone', icloud={user='x1@y.com', pwd='xizzy2'}}, 
}

quickAppVariables:
'HomeName' = name of place that is home
'HomeVar' = name of global where home status is stored
'UserLocVars' = Name of global variables for users. 
     Ex: 'Jan:JanLoc,Daniela:DaniLoc' 
     creates fibaro global 'JanLoc' where the latest place for user Jan is stored
'LocationsVar' = Name of variable where all location info is stored
--]]

------------------------------------------------------------------
if hc3_emulator then -- for debugging
  USERS={
    {name='Jan', id = 2, device='iPhone', home=true, icloud=hc3_emulator.EM.cfg.icloud.jan},
    {name='Daniela', device='iPhone', home=false, icloud=hc3_emulator.EM.cfg.icloud.daniela},
    {name='Max', device='iPhone', home=false, icloud=hc3_emulator.EM.cfg.icloud.max},
    {name='Tim', device='iPhone',home=true,  icloud=hc3_emulator.EM.cfg.icloud.tim},
  }
end
---------------------------------------------------------------------

local format = string.format
local HOME,LOCATIONS=nil,{}
local EVENTS,post = nil,nil 
local MYHOME,MYAWAY
local HomeVar = nil
local LocationsVar = nil
local UserLocVars = nil
local Users = {}
local numberOfHomeUsers = 0
local whereIsUser = {}
local HTTP, pollingextra
USERS = USERS or {}
utils = fibaro.utils

-- debug flags for various subsystems...
local _debugFlags = { post=true  }
--Test

INTERVAL = 90 -- check every 90s
local devicePattern = "iPhone"
local extrapolling = 4000

local function distance(lat1, lon1, lat2, lon2)
  local dlat = math.rad(lat2-lat1)
  local dlon = math.rad(lon2-lon1)
  local sin_dlat = math.sin(dlat/2)
  local sin_dlon = math.sin(dlon/2)
  local a = sin_dlat * sin_dlat + math.cos(math.rad(lat1)) * math.cos(math.rad(lat2)) * sin_dlon * sin_dlon
  local c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
  local d = 6378 * c
  return d
end

function getIOSDeviceNextStage(nextStage,user,headers,pollingextra)
  pollingextra = pollingextra or 0
  HTTP:request("https://"..nextStage.."/fmipservice/device/"..user.icloud.user.."/initClient",{
      options = { headers = headers, data = '', checkCertificate = false, method = 'POST', timeout = 20000 },
      error = function(status)
        quickApp:tracef("Error getting NextStage data:%s",status or "<unknown error>")
      end,
      success = function(status)
        local stat,res = pcall(function()
            if (status.status==200) then			
              if (pollingextra==0) then
                local output = json.decode(status.data)
                post({type='deviceMap', user=user, data=output.content, _sh=true})
                return
              else
                quickApp:tracef("Waiting for NextStage extra polling")
                setTimeout(function() getIOSDeviceNextStage(nextStage,user,headers,0) end, extrapolling)
                return
              end
            end
            quickApp:tracef("Bad response from NextStage:%s",json.encode(status) )	
          end)
        if not stat then quickApp:errorf("Crash NextStage:%s",res )	end
      end})
end

EVENTS = {}

function EVENTS.setupLocations()
  LOCATIONS = api.get("/panels/location")
  for _,l in ipairs(LOCATIONS) do
    if l.home then HOME = l end
  end
  quickApp:tracef("Home set to '%s'",HOME.name)
  post({type='setupLocations'},2*60*1000) -- check locations every 2min
end

local function getLocationId(name)
  for _,l in ipairs(LOCATIONS) do
    if l.name == name then return l.id end
  end
end

function EVENTS.location_upd(ev)
  local user = ev.user
  local loc = ev.result.location
  local batt = ev.result.battery
  local dist = ev.result.distance
  local device = ev.result.device

  if not loc then return end
  local res={}
  for _,v in ipairs(LOCATIONS) do
    local d = distance(loc.latitude,loc.longitude,v.latitude,v.longitude)
    res[#res+1]={hit=100*d < v.radius, dist=d,isHome=v.name==(HOME and HOME.name or ""),loc=v}
  end
  table.sort(res,function(a,b) return 
      (a.hit and not b.hit) or (a.hit and b.hit and a.isHome) or (not(a.hit and b.hit) and a.dist <= b.dist) 
    end)
  if res[1] then
    local v = res[1]
    if v.hit then 
      post({type='checkPresence', user=user, device=device, place=v.loc.name, dist=dist, battery=batt, _sh=true})
    else
      post({
          type='checkPresence', user=user, device=device, 
          place=MYAWAY, nearest={place=v.loc.name,dist=v.dist}, dist=dist, battery=batt, _sh=true
        })
    end
  end
end

local function isUserDevice(user,dev)
  local ds = type(user.device)=='table' and user.device or {user.device}
  for _,d in ipairs(ds) do if dev:match(d) then return true end end
  return false
end

function EVENTS.deviceMap(ev)
  local user = ev.user
  local dm = ev.data
  if dm ==nil then return end
  -- Get the list of all iDevices in the iCloud account
  local result = {}
  if HOME then
    for _,value in pairs(dm) do
      local loc = value.location
      if isUserDevice(user,value.name) and loc and type(loc) == 'table' then
        local d = distance(loc.latitude,loc.longitude,HOME.latitude,HOME.longitude)
        result[#result+1] = {device=value.name, time=loc.timeStamp, distance=d, location=loc, battery=value.batteryLevel}
      end
    end
  end
  for _,r in ipairs(result) do
    post({type='location_upd', user=user, result=r,_sh=true})
  end
end

function EVENTS.getIOSdevices(ev) --, user='$user', name = '$name', pwd='$pwd'},
  local user = ev.user
  pollingextra = ev.polling or 0

  HTTP = net.HTTPClient()

  local headers = {
    ["Authorization"]=utils.basicAuthorization(user.icloud.user,user.icloud.pwd), 
    ["Content-Type"] = "application/json; charset=utf-8",
    ["X-Apple-Find-Api-Ver"] = "2.0",
    ["X-Apple-Authscheme"] = "UserIdGuest",
    ["X-Apple-Realm-Support"] = "1.0",
    ["User-agent"] = "Find iPhone/1.3 MeKit (iPad: iPhone OS/4.2.1)",
    ["X-Client-Name"]= "iPad",
    ["X-Client-UUID"]= "0cf3dc501ff812adb0b202baed4f37274b210853",
    ["Accept-Language"]= "en-us",
    ["Connection"]= "keep-alive"}

  HTTP:request("https://fmipmobile.icloud.com/fmipservice/device/"..user.icloud.user.."/initClient",{
      options = {
        headers = headers,
        data = '',
        checkCertificate = false,
        method = 'POST', 
        timeout = 20000
      },
      error = function(status) 
        post({type='error', msg=format("Failed calling FindMyiPhone service for %s (%s)",user.name,status)})
      end,
      success = function(status)
        local stat,res = pcall(function()
            if (status.status==330) then
              local nextStage="fmipmobile.icloud.com"  
              for k,ns in pairs(status.headers) do 
                if string.lower(k)=="x-apple-mme-host" then 
                  nextStage=ns; break  
                end
              end
              quickApp:tracef("NextStage:%s",nextStage)
              getIOSDeviceNextStage(nextStage,user,headers,pollingextra)
            elseif (status.status==200) then
              post({type='deviceMap', user=user, data=json.decode(status.data).content, _sh=true})
            else
              post({type='error', msg=format("Access denied for %s :%s",user.name,json.encode(status))})
            end
          end)
        if not stat then quickApp:errorf("Crash getIOSdevices:%s",res ) end
      end
    })
end

local function checkAllAtHome()
  local away,home=0,0
  for user,u in pairs(whereIsUser) do 
    if Users[user].home then
      if u.place~=HOME.name then away=away+1 else home=home+1 end 
    end
  end
  return home==numberOfHomeUsers,away==numberOfHomeUsers,home>0
end

function EVENTS.checkPresence(ev)
  local name = ev.user.name
  local place = ev.place
  local battery = ev.battery
  local device = ev.device

  -- ptrace("User:%s, device:%s, place:%s, battery:%f",name,device,place,battery)

  if whereIsUser[name]~=nil then whereIsUser[name].battery=ev.battery end

  if whereIsUser[name]==nil or whereIsUser[name].place ~= place then  -- user at new place
    if Users[name].id then
      local id,lid = Users[name].id,getLocationId(place)
      if whereIsUser[name]==nil then
        if place ~= MYAWAY and lid then
          fibaro.postGeofenceEvent(id,lid,"enter")
        end
      else
        local oldLid = getLocationId(whereIsUser[name].place)
        if oldLid then
          fibaro.postGeofenceEvent(id,oldLid,"leave")
        end
        if place ~= MYAWAY then
          fibaro.postGeofenceEvent(id,lid,"enter")
        end
      end
    end

    whereIsUser[name] = {
      home = place == HOME.name,
      name=name, device=device, place=place, dist=ev.dist, battery=battery, nearest=ev.nearest
    }
    --local ename = "iOS_location_"..name
    --api.put("/customEvents/"..ename,{name=ename,userDescription=whereIsUser[name]})
    --if true or not hc3_emulator then fibaro.emitCustomEvent(ename) end
    if UserLocVars[name] then
      fibaro.setGlobalVariable(UserLocVars[name],place)
    end
    quickApp:tracef("User %s at %s (%.2f km from home)", name,place == HOME.name and MYHOME or place,ev.dist)
    if place==MYAWAY then 
      quickApp:tracef("Nearest:%s, (%f km)",ev.nearest.place,ev.nearest.dist) 
    end
    fibaro.setGlobalVariable(LocationsVar,json.encode(whereIsUser))
    quickApp:setView("user","text","User %s at %s",name,place)
  end

  if not HOME then return end

  local allAtHome,allAway,atHome = checkAllAtHome()

  if allAtHome then
    quickApp:tracef("All at home")
    fibaro.setGlobalVariable(HomeVar,"all_home")
    quickApp:setView("home","text","Home status: All at home")
    --if not hc3_emulator then fibaro.emitCustomEvent("iOS_all_at_home") end
  elseif allAway then
    quickApp:tracef("All away")
    fibaro.setGlobalVariable(HomeVar,"all_away")
    quickApp:setView("home","text","Home status: All away")
    --if not hc3_emulator then fibaro.emitCustomEvent("iOS_all_away") end
  elseif atHome then
    fibaro.setGlobalVariable(HomeVar,"some_home")
    quickApp:setView("home","text","Home status: Some at home")
  else
    fibaro.setGlobalVariable(HomeVar,"unknown")
    quickApp:setView("home","text","Home status: Unknown")
  end
end

function EVENTS.poll(ev)
  local index = ev.index
  local user = USERS[(index % #USERS)+1]
  post({type='getIOSdevices', user=user})
  post({type='poll',index=index+1,_sh=true},math.ceil(INTERVAL/#USERS)) -- INTERVAL=60 => check every minute
end

function EVENTS.error(ev)
  quickApp:errorf("Error %s",json.encode(ev))
end

local function getVar(name,dflt)
  local v = quickApp:getVariable(name)
  if v == nil or v == "" then return dflt else return v end
end

function EVENTS.start(ev)
  --local a,b = api.post("/customEvents",{name='iOS_all_at_home',userDescription=""})
  --a,b = api.post("/customEvents",{name='iOS_all_away',userDescription=""})

  HomeVar = getVar('HomeVar','iOSHome')
  fibaro.createGlobalVariable(HomeVar,"unknown")
  quickApp:tracef("Global variable for home status: %s",HomeVar)
  local _UserLocVars = getVar('UserLocVars','')
  LocationsVar = getVar('LocationsVar','iOSLocations')
  fibaro.createGlobalVariable(LocationsVar,"{}")
  quickApp:tracef("Global variable for all location status: %s",LocationsVar)
  MYHOME = getVar('HomeName','Home')
  MYAWAY = getVar('AwayName','away')

  UserLocVars = {}
  _UserLocVars = string.split(_UserLocVars,",")
  for _,n in ipairs(_UserLocVars) do
    local name,var = n:match("(.-):(.*)")
    if name and name~="" then UserLocVars[name]=var end
  end

  for n,v in pairs(UserLocVars) do
    quickApp:tracef("Global variable for user: '%s' is '%s'",n,v)
    fibaro.createGlobalVariable(v,"unknown")
  end
  quickApp:tracef("Name of home place: '%s'",MYHOME)
  quickApp:tracef("Name of AWAY place: '%s'",MYAWAY)

  for _,u in ipairs(USERS) do 
    u.device = u.device or devicePattern
    Users[u.name]=u
    if u.home then numberOfHomeUsers=numberOfHomeUsers+1 end

    --a,b = api.post("/customEvents",{name="iOS_location_"..u.name,userDescription=""})
  end
  post({type='setupLocations'})
  post({type='poll',index=1,_sh=true})
end

function post(ev,t)
  if _debugFlags.post and not ev._sh then quickApp:debugf("Event:%s %s",ev.type,ev.user and ev.user.name or "") end
  if EVENTS[ev.type] then setTimeout(function() EVENTS[ev.type](ev) end,1000*(t or 0)) end
end

function QuickApp:onInit()
  fibaro.updateFibaroExtra()
  quickApp:tracef("iOSLocator, deviceId:%s",self.id)
  self:setView("version","text","iOSLocator, %s (Users:%d)",version,#USERS)
  self:setView("home","text","Home status: Unknown")
  self:setView("users","text","")
  post({type='start'})
end
