local _=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { onAction=true, http=false, UIEevent=true, color=true },
  copas=true,
}

--%%name="HueConnector"
--%%type="com.fibaro.deviceController"
--%%quickVars = {["Hue_IP"]=EM.cfg.Hue_IP,["Hue_User"]=EM.cfg.Hue_user }
-- %%proxy=true
--%%u1={label='info', text=""}
--%%u2={button='deviceTable', text="Print device table"}
--%%u3={button='dump', text="List all Hue devices"}

--FILE:lib/fibaroExtra.lua,fibaroExtra;
--FILE:jgabs_QAs/HueConnectorMain.lua,Setup;
--FILE:lib/HUEv2Engine.lua,HueEngine;
--FILE:lib/HueColors.lua,Colors;
--FILE:lib/ColorConversion3.lua,ColorConversion;

if hc3_emulator then
--  hc3_emulator.installQA{id=88,file='test/HueConnectorClient.lua'}
  hc3_emulator.installQA{id=88,file='jgabs_QAs/HueSensors.lua'}
end

--luacheck: globals ignore QuickApp
----------- Code -----------------------------------------------------------

local debug = { QA=true, info = true, resource_mgmt=false, call=true, event=true, all_event=false, v2api=true, logger=false, class=false }

local HueDeviceTable = {
--['1c10e485-e52b-4144-9991-46dbb2eedafa']={type='device',name='Middle window',model='LCT012',room='Living room'},
--['21fc2e2f-05e6-4fbd-ad3b-a12762c88e72']={type='device',name='Hue white lamp 1',model='LWA001',room='Guest room'},
--['2219eadd-9464-4149-b52d-073ed1d9754a']={type='device',name='Köksö2',model='LCG002',room='Köksö'},
--['2d7bfac8-688b-4889-b813-b927e875b533']={type='device',name='Star right',model='LCT012',room='Guest room'},
  ['3ab27084-d02f-44b9-bd56-70ea41163cb6']={type='device',name='Tim',model='LCT015',room='Guest room'},
--['429ee799-9b86-43e5-bf31-ce3d06b45cc7']={type='device',name='Roof3',model='LCT012',room='Hall'},
--['598e4796-be01-482f-99c1-92f95fa8a18c']={type='device',name='Roof2',model='LCT012',room='Hall'},
--['59cbfb37-eba9-4746-9e64-ded409857abc']={type='device',name='Left window',model='LCT012',room='Living room'},
--['5ddcb36b-f985-4876-88b6-a238c58b9dbf']={type='device',name='Star left',model='LCT012',room='Guest room'},
--['721e69c5-bc75-4e99-b3ea-c05038ffa1af']={type='device',name='Star middle',model='LCT012',room='Guest room'},
--['8a453c82-0072-4223-9c42-f395b5cb0c40']={type='device',name='Hue smart plug 1',model='LOM007',room='Guest room'},
--['8dddf049-0a73-44e2-8fdd-e3c2310c1bb1']={type='device',name='Roof1',model='LCT012',room='Hall'},
  ['9222ea53-37a6-4ac0-b57d-74bca1cfa23f']={type='device',name='Living room sensor',model='SML001',ref='XX'},
--['932bd43b-d8cd-44bc-b8bd-daaf72ae6f82']={type='device',name='Living room wall switch',model='RDM001'},
--['93d49902-6ce5-4383-9037-bfaeec8cd538']={type='device',name='Right window',model='LWO003',room='Living room'},
--['9be444b2-1587-4fbe-89ac-efb809d7e629']={type='device',name='Roof lamp',model='LCT015',room='Bedroom'},
--['a001f510-48dd-47fc-b9ff-f779c40dd693']={type='device',name='Table1',model='LCA001',room='Living room'},
  ['a007e50b-0bdd-4e48-bee0-97636d57285a']={type='device',name='Dimmer switch',model='RWL021'},
--['a2b30b76-f044-46b6-9e1c-c8156baf00ab']={type='device',name='Table2',model='LCA001',room='Living room'},
--['c4bef7c5-0173-4d57-ae6a-d7f8a14b4dde']={type='device',name='Roof5',model='LCT012',room='Hall'},
--['d3b04b72-c2f0-401f-85d7-a65f2db5c48e']={type='device',name='Roof4',model='LCT012',room='Hall'},
--['e82c2285-20f3-401f-9621-9dc356feb694']={type='device',name='Köksö1',model='LCG002',room='Köksö'},
--['f2a231b4-9c27-466f-8344-05c4012c742b']={type='device',name='Philips hue',model='BSB002'},
--['795959f5-9313-4aae-b930-b178b48249e0']={type='room',name='Guest room',model='bedroom'},
--['9ab242fb-fae1-47e5-a54f-51bb8e80ac31']={type='room',name='Köksö',model='kitchen'},
--['bbe472e6-8ea8-477b-a116-ca345452e056']={type='room',name='Hall',model='living_room'},
--['bcd3daec-82a9-4de7-813a-3464beee0090']={type='room',name='Living room',model='living_room'},
--['cc309f30-d0f4-4ab5-a31f-39cd2206be57']={type='room',name='Bedroom',model='bedroom'},
--['39e1fc25-e926-42e5-a840-b2d21aaa08f3']={type='zone',name='Stars',model='recreation'},
--['79e44c37-15e0-4d93-8d89-230b14822270']={type='zone',name='Gymet',model='gym'},
--['9bfda4bf-b17e-4ec9-9123-a97afbcca814']={type='zone',name='Window lights',model='recreation'},
--['b5f12b5f-20c7-47a5-8535-c7a20fb9e66d']={type='zone',name='Kitchen island',model='kitchen'},
--['fe101c36-3dcc-4831-90f1-5052fc54e08b']={type='zone',name='Kitchen table',model='kitchen'},
--['03541e04-3481-47e7-ad22-c167437ca905']={type='scene',name='Bright',model='unknown',room='Kitchen table'},
--['29d8ba67-980a-4ab9-9fa6-50a0f994b273']={type='scene',name='Bright',model='unknown',room='Window lights'},
--  ['dd2cef77-e4fb-455b-867f-bad85f8f846c']={type='scene',name='Miami',model='unknown',room='Guest room'},
  ['f1677f3f-db72-45b2-a922-97046cdbff9d']={type='scene',name='Bright',model='unknown',room='Guest room'},
}

function QuickApp:main(HUE)  
--  HUE:dumpDeviceTable(nil,function(id) return HueDeviceTable[id] end,HueDeviceTable)
--  HUE:listAllDevicesGrouped()
  self:deviceTable()
--  self:dump()
end

function QuickApp:onInit() 
  self:setupHue(HueDeviceTable,debug) 
end