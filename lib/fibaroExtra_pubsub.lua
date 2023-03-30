_MODULES = _MODULES or {} -- Global
_MODULES.pubsub={ author = "jan@gabrielsson.com", version = '0.4', init = function()
    fibaro.loadModule("event")
    local debugFlags,format = fibaro.debugFlags,string.format
    local SUB_VAR = "TPUBSUB"
    local idSubs = {}
    local function DEBUG(...) if debugFlags.pubsub then fibaro.debug(__TAG,format(...)) end end
    local inited,initPubSub,match,compile
    local member,equal,copy = table.member,table.equal,table.copy

    function fibaro.publish(event)
      if not inited then initPubSub(quickApp) end
      assert(type(event)=='table' and event.type,"Not an event")
      local subs = idSubs[event.type] or {}
      for _,e in ipairs(subs) do
        if match(e.pattern,event) then
          for id,_ in pairs(e.ids) do 
            DEBUG("Sending sub QA:%s",id)
            fibaro.call(id,"SUBSCRIPTION",event)
          end
        end
      end
    end

    if QuickApp then -- only subscribe if we are an QuickApp. Scenes can publish
      function fibaro.subscribe(events,handler)
        if not inited then initPubSub(quickApp) end
        if not events[1] then events = {events} end
        local subs = quickApp:getVariable(SUB_VAR)
        if subs == "" then subs = {} end
        for _,e in ipairs(events) do
          assert(type(e)=='table' and e.type,"Not an event")
          if not member(e,subs) then subs[#subs+1]=e end
        end
        DEBUG("Setting subscription")
        quickApp:setVariable(SUB_VAR,subs)
        if handler then
          fibaro.event(events,handler)
        end
      end
    end

--  idSubs = {
--    <type> = { { ids = {... }, event=..., pattern = ... }, ... }
--  }

    function initPubSub(selfv)
      fibaro.loadModule("event")
      DEBUG("Setting up pub/sub")
      inited = true

      match = fibaro.EM.match
      compile = fibaro.EM.compilePattern

      function selfv.SUBSCRIPTION(_,e)
        selfv:post(e)
      end

      local function updateSubscriber(id,events)
        if not idSubs[id] then DEBUG("New subscriber, QA:%s",id) end
        for _,ev in ipairs(events) do
          local subs = idSubs[ev.type] or {}
          for _,s in ipairs(subs) do s.ids[id]=nil end
        end
        for _,ev in ipairs(events) do
          local subs = idSubs[ev.type]
          if subs == nil then
            subs = {}
            idSubs[ev.type]=subs
          end
          for _,e in ipairs(subs) do
            if equal(ev,e.event) then
              e.ids[id]=true
              goto nxt
            end
          end
          subs[#subs+1] = { ids={[id]=true}, event=copy(ev), pattern=compile(ev) }
          ::nxt::
        end
      end

      local function checkVars(id,vars)
        for _,var in ipairs(vars or {}) do 
          if var.name==SUB_VAR then return updateSubscriber(id,var.value) end
        end
      end

-- At startup, check all QAs for subscriptions
      for _,d in ipairs(api.get("/devices?interface=quickApp") or {}) do
        checkVars(d.id,d.properties.quickAppVariables)
      end

      fibaro.event({type='quickvar',name=SUB_VAR},            -- If some QA changes subscription
        function(env) 
          local id = env.event.id
          DEBUG("QA:%s updated quickvar sub",id)
          updateSubscriber(id,env.event.value)       -- update
        end) 

      fibaro.event({type='deviceEvent',value='removed'},      -- If some QA is removed
        function(env) 
          local id = env.event.id
          if id ~= quickApp.id then
            DEBUG("QA:%s removed",id)
            updateSubscriber(env.event.id,{})               -- update
          end
        end)

      fibaro.event({
          {type='deviceEvent',value='created'},              -- If some QA is added or modified
          {type='deviceEvent',value='modified'}
        },
        function(env)                                             -- update
          local id = env.event.id
          if id ~= quickApp.id then
            DEBUG("QA:%s created/modified",id)
            checkVars(id,api.get("/devices/"..id).properties.quickAppVariables)
          end
        end)
    end
  end
} -- PubSub
