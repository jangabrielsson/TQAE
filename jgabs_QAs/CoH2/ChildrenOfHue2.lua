-- luacheck: globals ignore QuickAppBase QuickApp QuickerAppChild quickApp fibaro class
-- luacheck: globals ignore plugin api net netSync setTimeout clearTimeout setInterval clearInterval json
-- luacheck: globals ignore hc3_emulator __fibaro_get_device_property
-- luacheck: globals ignore HueDeviceQA MotionSensorQA TempSensorQA LuxSensorQA SwitchQA HueTable HUEv2Engine
-- luacheck: globals ignore LightOnOff LightDimmable LightTemperature LightColor

local _=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { onAction=true, http=false, UIEevent=true },
--offline = true,
  copas=true,
}

--%%name="Huev2"
--%%type="com.fibaro.deviceController"
--%%quickVars = {["Hue_IP"]=EM.cfg.Hue_IP,["Hue_User"]=EM.cfg.Hue_user }
-- %%proxy=true

--FILE:lib/fibaroExtra.lua,fibaroExtra;
--FILE:test/HUEv2Engine2.lua,HueEngine;
--FILE:jgabs_QAs/CoH2/HueColors.lua,Colors;
----------- Code -----------------------------------------------------------
HueTable = {
  ['1c10e485-e52b-4144-9991-46dbb2eedafa']={name='Middle window',model='LCT012',used=true}
  ['2219eadd-9464-4149-b52d-073ed1d9754a']={name='Köksö2',model='LCG002',used=true}
  ['2d7bfac8-688b-4889-b813-b927e875b533']={name='Star right',model='LCT012',used=true}
  ['3ab27084-d02f-44b9-bd56-70ea41163cb6']={name='Tim',model='LCT015',used=true}
  ['429ee799-9b86-43e5-bf31-ce3d06b45cc7']={name='Roof3',model='LCT012',used=true}
  ['598e4796-be01-482f-99c1-92f95fa8a18c']={name='Roof2',model='LCT012',used=true}
  ['59cbfb37-eba9-4746-9e64-ded409857abc']={name='Left window',model='LCT012',used=true}
  ['5ddcb36b-f985-4876-88b6-a238c58b9dbf']={name='Star left',model='LCT012',used=true}
  ['721e69c5-bc75-4e99-b3ea-c05038ffa1af']={name='Star middle',model='LCT012',used=true}
  ['8a453c82-0072-4223-9c42-f395b5cb0c40']={name='Hue smart plug 1',model='LOM007',used=true}
  ['8dddf049-0a73-44e2-8fdd-e3c2310c1bb1']={name='Roof1',model='LCT012',used=true}
  ['9222ea53-37a6-4ac0-b57d-74bca1cfa23f']={name='Living room sensor',model='SML001',used=true}
  ['932bd43b-d8cd-44bc-b8bd-daaf72ae6f82']={name='Living room wall switch',model='RDM001',used=true}
  ['93d49902-6ce5-4383-9037-bfaeec8cd538']={name='Right window',model='LWO003',used=true}
  ['9be444b2-1587-4fbe-89ac-efb809d7e629']={name='Roof lamp',model='LCT015',used=true}
  ['a001f510-48dd-47fc-b9ff-f779c40dd693']={name='Table1',model='LCA001',used=true}
  ['a007e50b-0bdd-4e48-bee0-97636d57285a']={name='Dimmer switch',model='RWL021',used=true}
  ['a2b30b76-f044-46b6-9e1c-c8156baf00ab']={name='Table2',model='LCA001',used=true}
  ['c4bef7c5-0173-4d57-ae6a-d7f8a14b4dde']={name='Roof5',model='LCT012',used=true}
  ['d3b04b72-c2f0-401f-85d7-a65f2db5c48e']={name='Roof4',model='LCT012',used=true}
  ['e82c2285-20f3-401f-9621-9dc356feb694']={name='Köksö1',model='LCG002',used=true}
  ['f2a231b4-9c27-466f-8344-05c4012c742b']={name='Philips hue',model='BSB002',used=true}
  ['795959f5-9313-4aae-b930-b178b48249e0']={name='Guest room',model='bedroom',used=true}
  ['bbe472e6-8ea8-477b-a116-ca345452e056']={name='Hall',model='living_room',used=true}
  ['bcd3daec-82a9-4de7-813a-3464beee0090']={name='Living room',model='living_room',used=true}
  ['cc309f30-d0f4-4ab5-a31f-39cd2206be57']={name='Bedroom',model='bedroom',used=true}
  ['39e1fc25-e926-42e5-a840-b2d21aaa08f3']={name='Stars',model='recreation',used=true}
  ['79e44c37-15e0-4d93-8d89-230b14822270']={name='Gymet',model='gym',used=true}
  ['9bfda4bf-b17e-4ec9-9123-a97afbcca814']={name='Window lights',model='recreation',used=true}
  ['b5f12b5f-20c7-47a5-8535-c7a20fb9e66d']={name='Kitchen island',model='kitchen',used=true}
  ['fe101c36-3dcc-4831-90f1-5052fc54e08b']={name='Kitchen table',model='kitchen',used=true}
  ['03541e04-3481-47e7-ad22-c167437ca905']={name='Bright',model='unknown',used=true}
  ['29d8ba67-980a-4ab9-9fa6-50a0f994b273']={name='Bright',model='unknown',used=true}
}
local HUE

local function main()
  HUE:listAllDevicesGrouped()
  for id,r in pairs(HUE:getResourceIds()) do
    for _,prop in ipairs(r:props()) do
      r:subscribe(prop,function(key,value)
          quickApp:debugf("E: name:%s, %s=%s",r.name or r.owner.name,key,value)
        end)
    end
  end
  local tim = HUE:getResource("3ab27084-d02f-44b9-bd56-70ea41163cb6")
  tim:turnOn()
  setTimeout(function() tim:turnOff() end,4000)
end

function QuickApp:onInit()
  self:debugf("%s, deviceId:%s",self.name ,self.id)
  HUE = HUEv2Engine
  self:debug(self.name, self.id)
  local ip = self:getVariable("Hue_IP")
  local key = self:getVariable("Hue_User")
  HUEv2Engine.resourceFilter = HueTable
  HUE:initEngine(ip,key,function()
--      HUEv2Engine:dumpDevices()
      HUE:dumpDeviceTable()
      self:post(main)
    end)
end
