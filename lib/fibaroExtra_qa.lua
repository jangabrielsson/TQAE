_MODULES = _MODULES or {} -- Global
_MODULES.qa={ author = "jan@gabrielsson.com", version = '0.4', depends={'base','debug','event'}, 
  init = function()
    local debugFlags,format,copy = fibaro.debugFlags,string.format,table.copy
    function fibaro.restartQA(id)
      __assert_type(id,"number")
      return api.post("/plugins/restart",{deviceId=id or plugin.mainDeviceId})
    end

    function fibaro.getQAVariable(id,name)
      __assert_type(id,"number")
      __assert_type(name,"string")
      local props = (api.get("/devices/"..(id or plugin.mainDeviceId)) or {}).properties or {}
      for _, v in ipairs(props.quickAppVariables or {}) do
        if v.name==name then return v.value end
      end
    end

    function fibaro.setQAVariable(id,name,value)
      __assert_type(id,"number")
      __assert_type(name,"string")
      return fibaro.call(id,"setVariable",name,value)
    end

    function fibaro.getAllQAVariables(id)
      __assert_type(id,"number")
      local props = (api.get("/devices/"..(id or plugin.mainDeviceId)) or {}).properties or {}
      local res = {}
      for _, v in ipairs(props.quickAppVariables or {}) do
        res[v.name]=v.value
      end
      return res
    end

    function fibaro.isQAEnabled(id)
      __assert_type(id,"number")
      local dev = api.get("/devices/"..(id or plugin.mainDeviceId))
      return (dev or {}).enabled
    end

    function fibaro.setQAValue(device, property, value)
      fibaro.call(device, "updateProperty", property, (json.encode(value)))
    end

    function fibaro.enableQA(id,enable)
      __assert_type(id,"number")
      __assert_type(enable,"boolean")
      return api.post("/devices/"..(id or plugin.mainDeviceId),{enabled=enable==true})
    end

    function QuickApp.debug(_,...) fibaro.debug(nil,...) end
    function QuickApp.trace(_,...) fibaro.trace(nil,...) end
    function QuickApp.warning(_,...) fibaro.warning(nil,...) end
    function QuickApp.error(_,...) fibaro.error(nil,...) end
    function QuickApp.debugf(_,...) fibaro.debugf(nil,...) end
    function QuickApp.tracef(_,...) fibaro.tracef(nil,...) end
    function QuickApp.warningf(_,...) fibaro.warningf(nil,...) end
    function QuickApp.errorf(_,...) fibaro.errorf(nil,...) end
    function QuickApp.debug2(_,tl,...) fibaro.debug(tl,...) end
    function QuickApp.trace2(_,tl,...) fibaro.trace(tl,...) end
    function QuickApp.warning2(_,tl,...) fibaro.warning(tl,...) end
    function QuickApp.error2(_,tl,...) fibaro.error(tl,...) end
    function QuickApp.debugf2(_,tl,...) fibaro.debugf(tl,...) end
    function QuickApp.tracef2(_,tl,...) fibaro.tracef(tl,...) end
    function QuickApp.warningf2(_,tl,...) fibaro.warningf(tl,...) end
    function QuickApp.errorf2(_,tl,...) fibaro.errorf(tl,...) end

    for _,f in ipairs({'debugf','tracef','warningf','errorf','debugf2','tracef2','warningf2','errorf2'}) do
      QuickApp[f]=fibaro.protectFun(QuickApp[f],f,2)
    end

-- Like self:updateView but with formatting. Ex self:setView("label","text","Now %d days",days)
    function QuickApp:setView(elm,prop,fmt,...)
      local str = format(fmt,...)
      self:updateView(elm,prop,str)
    end

-- Get view element value. Ex. self:getView("mySlider","value")
    function QuickApp:getView(elm,prop)
      assert(type(elm)=='string' and type(prop)=='string',"Strings expected as arguments")
      local function find(s)
        if type(s) == 'table' then
          if s.name==elm then return s[prop]
          else for _,v in pairs(s) do local r = find(v) if r then return r end end end
        end
      end
      return find(api.get("/plugins/getView?id="..self.id)["$jason"].body.sections)
    end

-- Change name of QA. Note, if name is changed the QA will restart
    function QuickApp:setName(name)
      if self.name ~= name then api.put("/devices/"..self.id,{name=name}) end
      self.name = name
    end

-- Set log text under device icon - optional timeout to clear the message
    function QuickApp:setIconMessage(msg,timeout)
      if self._logTimer then clearTimeout(self._logTimer) self._logTimer=nil end
      self:updateProperty("log", tostring(msg))
      if timeout then 
        self._logTimer=setTimeout(function() self:updateProperty("log",""); self._logTimer=nil end,1000*timeout) 
      end
    end

-- Disable QA. Note, difficult to enable QA...
    function QuickApp:setEnabled(bool)
      local d = __fibaro_get_device(self.id)
      if d.enabled ~= bool then api.put("/devices/"..self.id,{enabled=bool}) end
    end

-- Hide/show QA. Note, if state is changed the QA will restart
    function QuickApp:setVisible(bool) 
      local d = __fibaro_get_device(self.id)
      if d.visible ~= bool then api.put("/devices/"..self.id,{visible=bool}) end
    end

    function QuickApp.post(_,...) return fibaro.post(...) end
    function QuickApp.event(_,...) return fibaro.event(...) end
    function QuickApp.cancel(_,...) return fibaro.cancel(...) end
    function QuickApp.postRemote(_,...) return fibaro.postRemote(...) end
    function QuickApp.publish(_,...) return fibaro.publish(...) end
    function QuickApp.subscribe(_,...) return fibaro.subscribe(...) end

    function QuickApp:setVersion(model,serial,version)
      local m = model..":"..serial.."/"..version
      if __fibaro_get_device_property(self.id,'model') ~= m then
        quickApp:updateProperty('model',m) 
      end
    end

    function fibaro.deleteFile(deviceId,file)
      local name = type(file)=='table' and file.name or file
      return api.delete("/quickApp/"..(deviceId or plugin.mainDeviceId).."/files/"..name)
    end

    function fibaro.updateFile(deviceId,file,content)
      if type(file)=='string' then
        file = {isMain=false,type='lua',isOpen=false,name=file,content=""}
      end
      file.content = type(content)=='string' and content or file.content
      return api.put("/quickApp/"..(deviceId or plugin.mainDeviceId).."/files/"..file.name,file) 
    end

    function fibaro.updateFiles(deviceId,list)
      if #list == 0 then return true end
      return api.put("/quickApp/"..(deviceId or plugin.mainDeviceId).."/files",list) 
    end

    function fibaro.createFile(deviceId,file,content)
      if type(file)=='string' then
        file = {isMain=false,type='lua',isOpen=false,name=file,content=""}
      end
      file.content = type(content)=='string' and content or file.content
      return api.post("/quickApp/"..(deviceId or plugin.mainDeviceId).."/files",file) 
    end

    function fibaro.getFile(deviceId,file)
      local name = type(file)=='table' and file.name or file
      return api.get("/quickApp/"..(deviceId or plugin.mainDeviceId).."/files/"..name) 
    end

    function fibaro.getFiles(deviceId)
      local res,code = api.get("/quickApp/"..(deviceId or plugin.mainDeviceId).."/files")
      return res or {},code
    end

    function fibaro.copyFileFromTo(fileName,deviceFrom,deviceTo)
      deviceTo = deviceTo or plugin.mainDeviceId
      local copyFile = fibaro.getFile(deviceFrom,fileName)
      assert(copyFile,"File doesn't exists")
      fibaro.addFileTo(copyFile.content,fileName,deviceTo)
    end

    function fibaro.addFileTo(fileContent,fileName,deviceId)
      deviceId = deviceId or plugin.mainDeviceId
      local file = fibaro.getFile(deviceId,fileName)
      if not file then
        local _,res = fibaro.createFile(deviceId,{   -- Create new file
            name=fileName,
            type="lua",
            isMain=false,
            isOpen=false,
            content=fileContent
          })
        if res == 200 then
          fibaro.debug(nil,"File '",fileName,"' added")
        else quickApp:error("Error:",res) end
      elseif file.content ~= fileContent then
        local _,res = fibaro.updateFile(deviceId,{   -- Update existing file
            name=file.name,
            type="lua",
            isMain=file.isMain,
            isOpen=file.isOpen,
            content=fileContent
          })
        if res == 200 then
          fibaro.debug(nil,"File '",fileName,"' updated")
        else fibaro.error(nil,"Error:",res) end
      else
        fibaro.debug(nil,"File '",fileName,"' not changed")
      end
    end

    function fibaro.getFQA(deviceId) return api.get("/quickApp/export/"..deviceId) end

    function fibaro.putFQA(content) -- Should be .fqa json
      if type(content)=='table' then content = json.encode(content) end
      return api.post("/quickApp/",content)
    end

-- Add interfaces to QA. Note, if interfaces are added the QA will restart
function QuickApp:addInterfaces(interfaces)
  assert(type(interfaces) == "table")
  local d, map, i2, res = __fibaro_get_device(self.id), {}, {}, {}
  for _, i in ipairs(d.interfaces or {}) do map[i] = true end
  for _, i in ipairs(interfaces) do i2[i] = true end
  for j, _ in pairs(i2) do if map[j] then i2[j]=nil end end
  for j,_ in pairs(i2) do res[#res+1]=j end
  --print("EX:",json.encode(i2))
  if res[1] then
    api.post("/plugins/interfaces", { action = 'add', deviceId = self.id, interfaces = res })
  end
end

    local _updateProperty = QuickApp.updateProperty
    function QuickApp:updateProperty(prop,value)
      local _props = self.properties
      if _props==nil or _props[prop] ~= nil then
        return _updateProperty(self,prop,value)
      elseif debugFlags.propWarn then self:warningf("Trying to update non-existing property - %s",prop) end
    end

    function QuickApp.setChildIconPath(_,childId,path)
      api.put("/devices/"..childId,{properties={icon={path=path}}})
    end

--Ex. self:callChildren("method",1,2) will call MyClass:method(1,2)
    function QuickApp:callChildren(method,...)
      for _,child in pairs(self.childDevices or {}) do 
        if child[method] then 
          local stat,res = pcall(child[method],child,...)  
          if not stat then self:debug(res,2) end
        end
      end
    end

    function QuickApp:removeAllChildren()
      for id,_ in pairs(self.childDevices or {}) do self:removeChildDevice(id) end
    end

    function QuickApp:numberOfChildren()
      local n = 0
      for _,_ in pairs(self.childDevices or {}) do n=n+1 end
      return n
    end

    function QuickApp.getChildVariable(_,child,varName) 
      for _,v in ipairs(child.properties.quickAppVariables or {}) do
        if v.name==varName then return v.value end
      end
      return ""
    end

    local function annotateClass(self,classObj)
      if not classObj then return end
      local stat,res = pcall(function() return classObj._annotated end) 
      if stat and res then return end
      --self:debug("Annotating class")
      for _,m in ipairs({
          "notify","setVisible","setEnabled","setIconMessage","setName","getView","updateProperty",
          "setView","debug","trace","error","warning","debugf","tracef","errorf","warningf"}) 
      do classObj[m] = self[m] end
      classObj.debugFlags = self.debugFlags
    end

    local function setCallbacks(obj,callbacks)
      if callbacks =="" then return end
      local cbs = {}
      for _,cb in ipairs(callbacks or {}) do
        cbs[cb.name]=cbs[cb.name] or {}
        cbs[cb.name][cb.eventType] = cb.callback
      end
      obj.uiCallbacks = cbs
    end

--[[
  QuickApp:createChild{
    className = "MyChildDevice",      -- class name of child object
    name = "MyName",                  -- Name of child device
    type = "com.fibaro.binarySwitch", -- Type of child device
    properties = {},                  -- Initial properties
    interfaces = {},                  -- Initial interfaces
  }
--]]
    function QuickApp:createChild(args)
      local className = args.className or "QuickAppChild"
      annotateClass(self,_G[className])
      local name = args.name or "Child"
      local tpe = args.type or "com.fibaro.binarySensor"
      local properties = args.properties or {}
      local interfaces = args.interfaces or {}
      properties.quickAppVariables = properties.quickAppVariables or {}
      local function addVar(n,v) table.insert(properties.quickAppVariables,1,{name=n,value=v}) end
      for n,v in pairs(args.quickVars or {}) do addVar(n,v) end
      local callbacks = properties.uiCallbacks
      if  callbacks then 
        callbacks = copy(callbacks)
        addVar('_callbacks',callbacks)
      end
      -- Save class name so we know when we load it next time
      addVar('className',className) -- Add first
      local child = self:createChildDevice({
          name = name,
          type=tpe,
          initialProperties = properties,
          initialInterfaces = interfaces
        },
        _G[className] -- Fetch class constructor from class name
      )
      if callbacks then setCallbacks(child,callbacks) end
      return child
    end

-- Loads all children, called automatically at startup
    function QuickApp:loadChildren()
      local cdevs,n = api.get("/devices?parentId="..self.id) or {},0 -- Pick up all my children
      function self.initChildDevices() end -- Null function, else Fibaro calls it after onInit()...
      for _,child in ipairs(cdevs or {}) do
        if not self.childDevices[child.id] then
          local className = self:getChildVariable(child,"className")
          local callbacks = self:getChildVariable(child,"_callbacks")
          annotateClass(self,_G[className])
          local childObject = _G[className] and _G[className](child) or QuickAppChild(child)
          self.childDevices[child.id]=childObject
          childObject.parent = self
          setCallbacks(childObject,callbacks)
        end
        n=n+1
      end
      return n
    end

    local orgRemoveChildDevice = QuickApp.removeChildDevice
    local childRemovedHook
    function QuickApp:removeChildDevice(id)
      if childRemovedHook then
        pcall(childRemovedHook,id)
      end
      return orgRemoveChildDevice(self,id)
    end
    function QuickApp.setChildRemovedHook(_,fun) childRemovedHook=fun end

    do
      local refs = {}
      function QuickApp.INTERACTIVE_OK_BUTTON(_,ref)
        ref,refs[ref]=refs[ref],nil
        if ref then ref(true) end
      end

      function QuickApp:pushYesNo(mobileId,title,message,callback,timeout)
        local ref = fibaro._orgToString({}):match("%s(.*)")
        api.post("/mobile/push", 
          {
            category = "YES_NO", 
            title = title, 
            message = message, 
            service = "Device", 
            data = {
              actionName = "INTERACTIVE_OK_BUTTON", 
              deviceId = self.id, 
              args = {ref}
            }, 
            action = "RunAction", 
            mobileDevices = { mobileId }, 
          })
        timeout = timeout or 20*60
        local timer = setTimeout(function()
            local r
            r,refs[ref] = refs[ref],nil
            if r then r(false) end 
          end, 
          timeout*1000)
        refs[ref]=function(val) clearTimeout(timer) callback(val) end
      end
    end
-- UI handler to pass button clicks to children
    function QuickApp:UIHandler(event)
      local obj = self
      if self.id ~= event.deviceId then obj = (self.childDevices or {})[event.deviceId] end
      if not obj then return end
      local elm,etyp = event.elementName, event.eventType
      local cb = obj.uiCallbacks or {}
      if obj[elm] then return obj:callAction(elm, event) end
      if cb[elm] and cb[elm][etyp] and obj[cb[elm][etyp]] then return obj:callAction(cb[elm][etyp], event) end
      if obj[elm.."Clicked"] then return obj:callAction(elm.."Clicked", event) end
      self:warning("UI callback for element:", elm, " not found.")
    end
  end
} -- QA

