-- luacheck: globals ignore QuickAppBase QuickApp QuickAppChild quickApp fibaro class
-- luacheck: globals ignore plugin api net netSync setTimeout clearTimeout setInterval clearInterval json
-- luacheck: globals ignore hc3_emulator __fibaro_get_device_property

---------------------- Setup users -----------------------------
local VERSION = 0.52
local SERIAL = "UPD8969654324567896"

------------------------------------------------------------------
local function preInit()
  if hc3_emulator then -- for debugging
    ACCOUNTS={
      {
        icloud = hc3_emulator.EM.cfg.icloud.jan,
        devices = {
          {name = 'Jan', deviceName='iPhone', id=2, home=true, QA="JansQA", global='JansPos'}
        }
      },
      {
        icloud = hc3_emulator.EM.cfg.icloud.daniela,
        devices = {
          {name = 'Daniela', deviceName='iPhone', id=3, home=true, global='DainielaPos'}
        }
      },
      {
        icloud = hc3_emulator.EM.cfg.icloud.tim,
        devices = {
          {name = 'Tim', deviceName='iPhone', id=99, home=false, global='TimPos'}
        }
      },
      {
        icloud = hc3_emulator.EM.cfg.icloud.max,
        devices = {{
            name = 'Max', deviceName='Apple Watch', deviceType='Apple Watch Series 6 %(GPS%)', id=44, home=false, global='MaxPos'
          }}
      },
    }
    HC3USERS = {
      {deviceName='OtherPhone', name='Lisa', id=5, home=false}
    }
    return true
  end
end
---------------------------------------------------------------------

local format = string.format
local HOME,LOCATIONS=nil,{}
local MYHOME,MYAWAY
local HomeVar = nil
local UserLocVars = nil
local Users = {}
local numberOfHomeUsers = 0
local whereIsUser = {}
local HTTP, pollingextra
ACCOUNTS = ACCOUNTS or {}
local utils = fibaro.utils
local post
local debug
local function printf(...) quickApp:debugf(...) end
enabledColor = enabledColor or "green"
disabledColor = disabledColor or "red"

local SCHEDULE_TIME = SCHEDULE_TIME or 90 -- seconds
SCHEDULE_INTERVAL = SCHEDULE_INTERVAL or false -- true=delay SCHEDULE_TIME between each account poll, false=delay SCHEDULE_TIME/#accounts between each account poll
SCHEDULE_KEEP_TOGETHER = SCHEDULE_KEEP_TOGETHER or {} -- {{'XXXX1','XXXX2'}} -- poll these accounts together - beware that it can be throttled by Apple if polled too often

local devicePattern = "iPhone"
local extrapolling  = 4000

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

function getIOSDeviceNextStage(mmeHost,mmeScope,account,headers,pollingextra)
  pollingextra = pollingextra or 0
  HTTP:request("https://"..mmeHost.."/fmipservice/device/"..(mmeScope or account.icloud.user).."/initClient",{
      options = { headers = headers, data = '', checkCertificate = false, method = 'POST', timeout = 20000 },
      error = function(status)
        account.errors = (account.errors or 0)+1
        quickApp:tracef("Error getting NextStage data:%s",status or "<unknown error>")
      end,
      success = function(status)
        local stat,res = pcall(function()
            if (status.status==200) then			
              if (pollingextra==0) then
                local output = json.decode(status.data)
                account.errors = 0
                post({type='deviceMap', account=account, data=output.content, _sh=true})
                return
              else
                quickApp:tracef("Waiting for NextStage extra polling")
                setTimeout(function() getIOSDeviceNextStage(mmeHost,mmeScope,account,headers,0) end, extrapolling)
                return
              end
            end
            account.errors = (account.errors or 0)+1
            quickApp:tracef("Bad response from NextStage:%s",json.encode(status) )	
          end)
        if not stat then account.errors = (account.errors or 0)+1; quickApp:errorf("Crash NextStage:%s",res )	end
      end})
end

local function setupEvents()
  for k,v in pairs(DEBUG or {}) do fibaro.debugFlags[k]=v end
  debug = fibaro.debugFlags 
  post = fibaro.post
  local QA = quickApp
  local id2loc,loc2id={},{}

  local function getLocations()
    id2loc,loc2id={},{}
    LOCATIONS = api.get("/panels/location")
    for _,l in ipairs(LOCATIONS or {}) do
      if l.home then 
        if HOME == nil then QA:tracef("Home set to '%s'",l.name) end
        HOME = l 
      end
      loc2id[l.name]=l.id
      id2loc[l.id]=l.name
    end
  end

  fibaro.event({type='setupLocations'},function(env)
      getLocations()
      post({type='setupLocations'},2*60*1000) -- check locations every 2min
    end)

  local function getLocationId(name) return loc2id[name] end
  local function getLocationName(id) return id2loc[id] end

  fibaro.event({type='deviceMap'},function(env)
      local account = env.event.account
      local dm = env.event.data
      if dm ==nil then return end
      -- Get the list of all iDevices in the iCloud account
      local result = {}

      if debug.listDevices and not account.listed then
        account.listed = true
        QA:debug("----------------------------------------------")
        QA:debugf("Devices for %s:",account.name)
        for _,dev in pairs(dm) do
          local ll = type(dev.location)=='table' and dev.location or {}
          local color = dev.locationEnabled and type(dev.location)=='table' and enabledColor or disabledColor
          QA:debugf("<font color=%s>Name:%s, Device type:%s, battery:%0.2f%%, Latitude:%.4f, Longitude:%.4f, Altitude:%.4f, Floor level:%s</font>",
            color,dev.name,dev.deviceDisplayName or "",tonumber(dev.batteryLevel) or 0,tonumber(ll.latitude) or 0, tonumber(ll.longitude) or 0, tonumber(ll.altitude) or 0, ll.floorLevel or 0)
        end
        QA:debug("----------------------------------------------")
      end

      for _,dev in pairs(dm) do
        for _,d in ipairs(account.devices) do
          if dev.name:match(d.deviceName) and dev.deviceDisplayName:match(d.deviceType) then
            local fullName = string.format("%s(%s)",dev.name,dev.deviceDisplayName)
            if not dev.locationEnabled and not d.known then
              d.known = true
              QA:warningf("Device %s match but is not locating - ignored",fullName)
            else
              local loc = type(dev.location)=='table' and dev.location or {}
              local res={}
              if loc.latitude then

                for _,v in ipairs(LOCATIONS) do
                  local d = distance(loc.latitude,loc.longitude,v.latitude,v.longitude)
                  res[#res+1]={hit=1000*d < v.radius, dist=d,isHome=v.name==(HOME and HOME.name or ""),loc=v}
                end
              end

              table.sort(res,function(a,b) 
                  if a.hit and not b.hit then return true elseif b.hit and not a.hit then return false end
                  if a.isHome and not b.isHome then return true elseif b.isHome and not a.isHome then return false end
                  return a.dist < b.dist
                end)

              if res[1] then
                local nearest = res[1]
                local home = distance(loc.latitude or 0,loc.longitude or 0,HOME.latitude,HOME.longitude)
                if debug.matchedDevice then QA:debugf("Matched device %s for user %s",fullName,d.name) end
                post({type='checkPresence', user=d.name, nearest=nearest, home=home, dev=dev})
              end
            end
          end
        end
      end
    end)

  fibaro.event({type='getIOSdevices'},function(env) --, user='$user', name = '$name', pwd='$pwd'},
      local account = env.event.account
      pollingextra = env.event.polling or 0

      HTTP = net.HTTPClient()

      local headers = {
        ["Authorization"]=utils.basicAuthorization(account.icloud.user,account.icloud.pwd), 
        ["Content-Type"] = "application/json; charset=utf-8",
        ["X-Apple-Find-Api-Ver"] = "3.0", 
        ["X-Apple-Authscheme"] = "UserIdGuest",
        ["X-Apple-Realm-Support"] = "1.0",
        ["User-agent"] = "FindMyiPhone/500 CFNetwork/758.4.3 Darwin/15.5.0",
--        ["X-Client-Name"]= "iPad",
--        ["X-Client-UUID"]= "0cf3dc501ff812adb0b202baed4f37274b210853",
--        ["Accept-Language"]= "en-us",
        ["Connection"]= "keep-alive"
      }

      HTTP:request("https://fmipmobile.icloud.com/fmipservice/device/"..account.icloud.user.."/initClient",{
          options = {
            headers = headers,
            data = '',
            checkCertificate = false,
            method = 'POST', 
            timeout = 20000
          },
          error = function(status) 
            account.errors = (account.errors or 0)+1
            post({type='error', msg=format("Failed calling FindMyiPhone service for %s (%s)",account.name,status)})
          end,
          success = function(status)
            local stat,res = pcall(function()
                if (status.status==330) then
                  local mmeHost,mmeScope="fmipmobile.icloud.com"  
                  for k,ns in pairs(status.headers) do 
                    if string.lower(k)=="X-apple-mme-scope" then mmeScope=ns end
                    if string.lower(k)=="x-apple-mme-host" then mmeHost=ns end
                  end
                  quickApp:tracef("NextStage:%s %s",mmeHost,mmeScope)
                  getIOSDeviceNextStage(mmeHost,mmeScope,account,headers,pollingextra)
                elseif (status.status==200) then
                  account.errors = 0
                  post({type='deviceMap', account=account, data=json.decode(status.data).content, _sh=true})
                else
                  account.errors = (account.errors or 0)+1
                  post({type='error', msg=format("Access denied for %s :%s",account.name,json.encode(status))})
                end
              end)
            if not stat then account.errors = (account.errors or 0)+1; quickApp:errorf("Crash getIOSdevices:%s",res ) end
          end
        })
    end)

  local function checkAllAtHome()
    local away,home=0,0
    for user,u in pairs(Users) do 
      if Users[user].home then
        if u.place~=MYHOME then away=away+1 else home=home+1 end 
      end
    end
    return home==numberOfHomeUsers,away==numberOfHomeUsers,home>0
  end

  fibaro.event({type='checkPresence'},function(env)
      local name = env.event.user
      local nearest = env.event.nearest
      local orgPlace = nearest.hit and nearest.loc.name or MYAWAY
      local place = nearest.hit and nearest.loc.name or MYAWAY
      local battery = env.event.dev.batteryLevel
      local device = env.event.dev.deviceDisplayName
      local dist = nearest.dist
      local homeDist = env.event.home

      -- ptrace("User:%s, device:%s, place:%s, battery:%f",name,device,place,battery)
      if place == HOME.name then place = MYHOME end
      local user = Users[name]

      user.battery=battery
      if user.child then user.child:updateProperty('batteryLevel',math.floor(battery*100+0.5)) end
      --QA:debugf("checkPresence %s %s %s",name,place,tostring(Users[name].place))
      if Users[name].place ~= place then  -- user at new place
        if Users[name].id then
          local id,lid = Users[name].id,getLocationId(orgPlace)
          if Users[name].place==nil then
            --QA:debugf("2.checkPresence %s %s %s %s",MYAWAY,tostring(lid),orgPlace)
            if place ~= MYAWAY and lid then
              fibaro.postGeofenceEvent(id,lid,"enter")
              fibaro.post({type='location2',id=id,property=lid,value="enter"})
            elseif place == MYAWAY then
              fibaro.post({type='location2',id=id,property=-1,value="leave"})
            end
          else
            local oldLid = getLocationId(Users[name].place)
            --QA:debugf("3.checkPresence %s %s",MYAWAY,tostring(oldLid))
            if oldLid then
              fibaro.postGeofenceEvent(id,oldLid,"leave")
              fibaro.post({type='location2',id=id,property=oldLid,value="leave"})
            end
            --QA:debugf("4.checkPresence %s",MYAWAY)
            if place ~= MYAWAY then
              fibaro.postGeofenceEvent(id,lid,"enter")
              fibaro.post({type='location2',id=id,property=lid,value="enter"})
            end
          end
        else 
          QA:warning("User %s doesn't have an id - ignored",name)
        end

        Users[name].isHome = place == MYHOME
        Users[name].place = place
        Users[name].dist = dist
        Users[name].homeDist = homeDist
        Users[name].nearest = nearest
      else 
        QA:debugf("User %s in same place '%s'",name,place)
      end
    end)

  fibaro.event({type='poll'},function(env)
      local index = env.event.index
      local account = ACCOUNTS[index]
      if account == nil then
        QA:warning("No accounts")
        return
      end
      if account[1] then 
        for i,a in ipairs(account) do 
          if a.errors and a.errors > 6 then
            QA:error("Too many errors from account %s, disabling",a.name)
            table.remove(a,i)
            if not next(a) then table.remove(ACCOUNT,index) end
          else
            post({type='getIOSdevices', account=a})
          end
        end
      else
        if account.errors and account.errors > 6 then
          QA:error("Too many errors from account %s, disabling",account.name)
          table.remove(ACCOUNTS,index)
        else 
          post({type='getIOSdevices', account=account})
        end
      end
      local interval = SCHEDULE_INTERVAL and SCHEDULE_TIME or math.floor((SCHEDULE_TIME / #ACCOUNTS)+0.5)
      QA:debugf("Next polling in %ss",interval)
      post({type='poll',index=(index % #ACCOUNTS)+1,_sh=true},interval) -- INTERVAL=60 => check every minute
    end)

  fibaro.event({type='error'},function(env)
      quickApp:errorf("Error %s",json.encode(env.event))
    end)

  local function getVar(name,dflt)
    local v = quickApp:getVariable(name)
    if v == nil or v == "" then return dflt else return v end
  end

  local NXTID,id2user = 2000,{}
  fibaro.event({type='start'},function(env)
      fibaro.enableSourceTriggers({"location"})
      getLocations()

      HomeVar = getVar('HomeVar')
      if HomeVar then
        fibaro.createGlobalVariable(HomeVar,"unknown")
        quickApp:tracef("Global variable for home status: %s",HomeVar)
      end

      MYHOME = getVar('HomeName','Home')
      MYAWAY = getVar('AwayName','away')
      quickApp:tracef("Name of home place: '%s'",MYHOME)
      quickApp:tracef("Name of AWAY place: '%s'",MYAWAY)
      printf("----------------------------------------------")
      local accountMap = {}
      for _,u in ipairs(ACCOUNTS) do
        u.name = u.icloud.user
        accountMap[u.name]=u
        for _,d in ipairs(u.devices) do
          assert(d.name,"Missing name for iOS user")
          d.deviceName = d.deviceName or devicePattern
          d.deviceFullName = d.deviceFullName or (d.deviceName..(d.deviceType and ("("..d.deviceType..")") or ""))
          d.deviceType = d.deviceType or ".*"
          if d.id == nil then
            d.id = NXTID; NXTID=NXTID+1 
            QA:debugf("Assigning id:%s to user %s",d.id,d.name)
          end
          Users[d.name]={
            iOS = true,
            id = d.id,
            name = d.name,
            QA = d.QA,
            global = d.global,
            deviceName = d.deviceName,
            deviceType = d.deviceType,
            home = d.home,
            deviceFullName = d.deviceFullName,
          }
          id2user[d.id]=Users[d.name]
          if d.home then numberOfHomeUsers=numberOfHomeUsers+1 end
        end
      end

      for _,u in ipairs(HC3USERS or {}) do
        if u.home then numberOfHomeUsers=numberOfHomeUsers+1 end
        assert(u.name,"Missing name for HC3 user")
        assert(u.id,"Missing id for HC3 user")
        Users[u.name]={
          id = u.id,
          name = u.name,
          QA = u.QA,
          global = u.global,
          deviceName = u.deviceName or "device",
          deviceType = u.deviceType or "",
          home = u.home,
          deviceFullName = u.deviceFullName or "device",
        }
        id2user[u.id]=Users[u.name]
      end

      class 'UserObject'(QuickerAppChild)
      function UserObject:__init(dev)
        local args = {
          name = dev.QAname or dev.name,
          className = 'UserObject',
          uid  = dev.uid or dev.name,
          type = 'com.fibaro.binarySensor',
          properties = {},
          interfaces = {"battery"},
        }
        Users[args.uid or dev.name].child = self
        self:debug("Instantiated QA child ",dev.name)
        QuickerAppChild.__init(self,args)
      end
      function UserObject:__tostring()
        return string.format("User:%s - %s",self.id,self.name)
      end

      quickApp:loadQuickerChildren(nil,
        function(dev,uid,className)
          if Users[uid]==nil or not Users[uid].QA then
            QA:warning("User removed %s (deviceId:%s)",uid,dev.id)
            api.delete("/plugins/removeChildDevice/" .. dev.id)
            return false
          else
            return true 
          end
        end)
      for id,c in pairs(quickApp.childDevices or {}) do
        Users[c.uid].child = c
      end
      for name,obj in pairs(Users) do
        if Users[name].QA and not Users[name].child then
          Users[name].child=UserObject({name=name,QAname=type(obj.QA)=='string' and obj.QA or name})
        end
      end

      if SCHEDULE_KEEP_TOGETHER and next(SCHEDULE_KEEP_TOGETHER) then
        local res = {}
        for k,v in ipairs(SCHEDULE_KEEP_TOGETHER) do
          QA:debugf("Scheduling accounts %s together",v)
          local as = {}
          for _,a in ipairs(v) do as[#as+1]=accountMap[a] accountMap[a]=nil end
          res[#res+1]=as
        end
        for _,a in pairs(accountMap) do res[#res+1]=a end
        ACCOUNTS = res
      end

      UserLocVars = {}
      for name,u in pairs(Users) do
        if u.global then
          UserLocVars[name] = type(u.global)=='string' and u.global or "iOS_"..u.name
        end
      end

      for n,v in pairs(UserLocVars) do
        quickApp:tracef("Global variable for user: '%s' is '%s'",n,v)
        fibaro.createGlobalVariable(v,"unknown")
      end

      if HomeVar then fibaro.setGlobalVariable(HomeVar,"unknown") end
      for id,c in pairs(quickApp.childDevices) do
        c:updateProperty('value',false)
        c:setVariable('place',"unknown")
      end
      printf("----------------------------------------------")
      for name,u in pairs(Users) do
        printf("[%s:%s, home:%s, iOS:%s, QA:%s]",name,u.id,u.home,u.iOS==true,u.QA~=nil and u.child.id or "_")
      end
      printf("----------------------------------------------")

      post({type='setupLocations'})
      post({type='poll',index=1,_sh=true})
    end)

  fibaro.event({type='location'},function(env)
      local e = env.event
      if id2user[e.id].iOS then return end
      e.type = 'location2'
      fibaro.post(env.event)
    end)

  fibaro.event({type='location2'},function(env)
      local e = env.event
      local uid = e.id
      local lid = e.property
      local action = e.value
      local time = e.timestamp
      local user = id2user[uid]
      local name = user.name
      local place = getLocationName(lid) or MYAWAY
      local nearest = user.nearest
      local homeDist = user.homeDist
      --QA:debugf("ID:%s, name:%s, action:%s, place:%s",uid,name,action,place)

      if place == HOME.name then place = MYHOME end

      if UserLocVars[name] then
        quickApp:tracef("Updating GV '%s' to '%s'",UserLocVars[name],place)
        fibaro.setGlobalVariable(UserLocVars[name],place)
      end

      if not user.iOS then
        if action == 'leave' then
          place = MYAWAY
        end
      end

      user.place = place

      if user.child then 
        quickApp:tracef("Updating %s QA:%s to %s", user.child.uid,user.child.id,place == MYHOME)
        user.child:updateProperty('value',place == MYHOME)
        user.child:setVariable('place',place)
      end

      if user.iOS then
        quickApp:tracef("User %s at %s (%.2f km from home)", name,place,homeDist)
        if place == MYAWAY then 
          quickApp:tracef("Nearest:%s, (%f km)",nearest.place,nearest.dist) 
        end
      else
        if place == MYAWAY then
          quickApp:tracef("User %s is away", name)
        else
          quickApp:tracef("User %s at %s", name,place)
        end
      end
      QA:setVariable("status",json.encodeFast(Users))
      local usersV = {}
      for _,u in pairs(Users) do
        usersV[#usersV+1]=string.format("User %s at %s",u.name,u.place or "unknown")
      end
      quickApp:updateView("user","text",table.concat(usersV,"\n"))

      if not HOME then return end

      local allAtHome,allAway,atHome = checkAllAtHome()

      if allAtHome then
        quickApp:tracef("All at home")
        if HomeVar then fibaro.setGlobalVariable(HomeVar,"all_home") end
        quickApp:setView("home","text","Home status: All at home")
        QA:updateProperty('value',true)
      elseif allAway then
        quickApp:tracef("All away")
        if HomeVar then fibaro.setGlobalVariable(HomeVar,"all_away") end
        quickApp:setView("home","text","Home status: All away")        
        QA:updateProperty('value',false)
      elseif atHome then
        if HomeVar then fibaro.setGlobalVariable(HomeVar,"some_home") end
        quickApp:setView("home","text","Home status: Some at home")
        QA:updateProperty('value',true)
      else
        if HomeVar then fibaro.setGlobalVariable(HomeVar,"unknown") end
        quickApp:setView("home","text","Home status: Unknown")
        QA:updateProperty('value',false)
      end

    end)

end -- setupEvents

function QuickApp:onInit()
  utils = fibaro.utils
  fibaro.debugFlags.extendedErrors=true
  local initVars = not preInit()
  setupEvents()
  self:debugf("%s deviceId:%s, v%s",self.name,self.id,VERSION)
  self:setVersion("iOSLOcator",SERIAL,VERSION)
  self:setView("version","text","iOSLocator, %s (#Accounts:%d)",tostring(VERSION),#ACCOUNTS)
  self:setView("home","text","Home status: Unknown")
  self:setView("user","text","")
  fibaro.post({type='start',initVars=initVars})
end