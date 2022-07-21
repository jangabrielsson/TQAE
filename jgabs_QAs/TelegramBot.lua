local _=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { onAction=true, http=false, UIEevent=true },
--offline = true,
}

--%%name="TelegramBot"
--%%type="com.fibaro.binarySwitch"
--%%quickVars={["Users"]={jangabrielsson=EM.cfg.TelegramJan},["BOT_ID"]=EM.cfg.TelegramBot}
--%%u1={label='name',text=""}
--%%u2={button='bot', text='Bot ON'}
--%%u3={label='row1',text=""}
--%%u4={label='row2',text=""}
--%%u5={label='row3',text=""}

--FILE:lib/fibaroExtra.lua,fibaroExtra;

version = "v0.2"

local DEBUG = true
local format = string.format

--local testUser = 'jangabrielsson'
local Telegram,createTelegramSupport
local createSubscribers
local Subs,Users

function QuickApp:turnOn()
  self:tracef("Telegram bot turned on")
  self:updateProperty("value", true)
end

function QuickApp:turnOff()
  self:tracef("Telegram bot turned off")
  self:updateProperty("value", false)    
end

function QuickApp:sendTelegram(user,message)
  if type(user)=='table' then user=user.name end
  self:tracef("Send request, user:%s, msg:%s",user,message)
  Telegram.msg(user,message)  
end

local function setup()

  fibaro:event({type='start'},function(env)
      local ev = env.event
      Telegram = createTelegramSupport(fibaro.botID)
      Telegram.bot('msg')
      if testUser then
        quickApp:sendTelegram(testUser,"Hello1")  -- Send msg to Telegram without BOT setup
        quickApp:sendTelegram(testUser,"Hello2")  -- Send msg to Telegram without BOT setup
        quickApp:sendTelegram(testUser,"Hello3")  -- Send msg to Telegram without BOT setup
      end
    end)

  fibaro:event({type='msg'},function(env)
      local ev = env.event
      local from = ev.user
      local text = ev.text
      local info = ev.info
      local topic,msg = text:match("^/([%w]+)%s*(.*)")
      if not topic then topic=""; msg=text end
      if not Subs.notify(topic,msg,from) then
        quickApp:sendTelegram(from,format("Sorry, I don't understand '%s'",text))
      end
    end )

end

function createTelegramSupport(bot_key)
  local self={ _interval=2, _http=netSync.HTTPClient() }
  self._botkey = bot_key
  assert(self._botkey,"Missing Telegram bot key")

  local ERR = 0
  local function request(key,cmd,payload,cont)
    local url = key..cmd
    payload = json.encode(payload)
    return self._http:request(url,{options = {
          headers = {['Accept']='application/json',['Content-Type']='application/json',['Connection']='keep-alive'},
          timeout=2000, data=payload, checkCertificate = false, method = 'POST'},
        error = function(status) 
          if status~= "Operation canceled" then 
            quickApp:errorf("Telegram error: %s",json.encode(status)) 
          end
        end,
        success = function(status) 
          local data = json.decode(status.data)
          if status.status ~= 200 and data.ok==false then
            if ERR % 20 == 0 then quickApp:errorf("Telegram error: %s, %s",data.error_code,data.description) end
            ERR=ERR+1
          elseif cont then cont(data) end 
        end,
      })
  end

  local function recordUser(username,chatID)
    if username==nil then return end
    if chatID and (Users[username] ~= chatID) then
      Users[username]=chatID
    end
    return Users[username]
  end

  function self.findId(name) 
    return tonumber(name) and name or recordUser(name,nil) 
  end

  function self.bot(tag)
    tag = tag or "Telegram"
    local url,lastID,msg = "https://api.telegram.org/bot"..Telegram._botkey.."/",1,nil
    local function loop()
      request(url,"getUpdates",{offset=lastID+1},
        function(messages)
          --pdebug("Got %s",messages)
          if not(type(messages)=='table' and type(messages.result)=='table') then
            quickApp:warningf("Telegram: Bad result:%s",messages) return
          end
          for _,m in ipairs(messages.result or {}) do
            --pdebug("LID0:%s, LID1:%s, %s",lastID,m.update_id,m.message.text)
            if lastID == m.update_id then return end
            lastID,msg=m.update_id,m.message
            recordUser(msg.from.username,msg.chat.id)
            local user = {name=msg.from.username, id=msg.chat.id, verified=Users[msg.from.username] and true or false}
            fibaro.post({type=tag,user=user,text=msg.text,id={msg.chat.id},info=msg.chat,_sh=true})
          end
        end)
      setTimeout(loop,self._interval*1000)
    end
    loop()
  end

  function self.msg(name,text,keyboard)
    local id = self.findId(name)
    assert(id,"No user with name "..json.encode(name))
    return request("https://api.telegram.org/bot"..self._botkey.."/",
      "sendMessage",
      {chat_id=id,text=text,reply_markup=keyboard},
      function(msgs) 
        local m = msgs.result;
        --if m.chat.username==nil then pwarn(LOG.LOG,"Telegram warning: missing username,%s",m) end
        recordUser(m.chat.username,m.chat.id)
      end) 
  end

  return self
end -- Telegram()

function QuickApp:onInit()  
  self:tracef(format("Telegram %s (deviceId:%s)",version,self.id))
  local botID = self:getVariable("BOT_ID")
  if not botID then 
    fibaro.printf("Please set quickvar 'BOT_ID' to your Telegram bot key")
  end
  Users = self:getVariable("Users")
  if Users == "" then Users = {} end
  for _,u in ipairs(Users) do u.verified = true end  -- We trust users declared
  fibaro.botID = botID
  Subs = createSubscribers()
  setup()
  fibaro.post({type='start'})
end

function createSubscribers()
  local self = {}
  local topics = {}
  local isSubscriber = {}

  local function addSusbcriberToTopic(topic,id)
    local s = topics[topic] or {}
    s[id]=true
    topics[topic] = s
  end

  local function removeSubscriber(id)
    for topic,subs in pairs(topics) do
      topic[id]=nil
    end
  end

  function self.notify(topic,msg,from)
    local method = topic=="" and "TELEGRAM" or "TELEGRAM_"..topic
    local notified = false
    for id,_ in pairs(topics[topic] or {}) do
      notified = true
      fibaro.call(id,method,msg,from)
    end
    return notified
  end

  local function checkDevice(id)
    if id == quickApp.id then return end
    local isSub=false
    local files = fibaro.getFiles(id)    
    for _,name in ipairs(files) do
      local f = fibaro.getFile(
    end
    local code = d.properties.mainFunction or ""
    if code:match("QuickApp:TELEGRAMQA") then
      fibaro.call(id,"TELEGRAMQA",quickApp.id)
    end
    for match in code:gmatch("QuickApp:TELEGRAM(.-)%(") do
      if match~="QA" then
        local topic = ""
        if match:sub(1,1)=="_" then topic=match:sub(2) end
        addSusbcriberToTopic(topic,id)
        self:tracef("DeviceId:%s subscribed to '%s'",id,topic)
        isSubscriber[id]=true
        isSub=true
      end
    end
    if (not isSub) and isSubscriber[id] then
      self:tracef("DeviceId:%s unsubscribed",id) 
      isSubscriber[id]=nil
      removeSubscriber(id)
    end
  end
  self.checkDevice = checkDevice

  -- At startup, check all QAs for subscriptions
  for _,d in ipairs(api.get("/devices?interface=quickApp") or {}) do
    checkDevice(d.id)
  end

  self:event({type='deviceEvent',value='removed'},        -- If some QA is removed
    function(env) 
      local id = env.event.id
      if id ~= self.id then
        isSubscriber[id]= nil                            -- update
        removeSubscriber(id)
      end
    end)

  self:event({
      {type='deviceEvent',value='created'},              -- If some QA is added or modified
      {type='deviceEvent',value='modified'}
    },
    function(env)                                        -- update
      local id = env.event.id
      if id ~= self.id then
        checkDevice(id)
      end
    end)

  return self
end
