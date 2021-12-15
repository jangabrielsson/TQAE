_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  copas=true,
  debug = { onAction=true, http=false, UIEevent=true, refreshStates=false },
}

--%%name="HueTest"
--%%quickVars = {["Hue_IP"]=EM.cfg.Hue_IP,["Hue_User"]=EM.cfg.Hue_user }
--%%type="com.fibaro.deviceController"
--%%proxy=true

--FILE:jgabs_QAs/CoH2/CoH2_2.lua,CoH;
--FILE:lib/fibaroExtra.lua,fibaroExtra;
--FILE:lib/UI.lua,UI;
--FILE:lib/HUEv2Engine.lua,hueEngine;
--FILE:lib/colorConversion.lua,colorConversion;
--FILE:lib/colorComponents.lua,colorComponents;

HueTable = {
--   ['4de3ac70-81e5-408e-9e65-d25ddc483ed9'] = {type='Hue ambiance lamp', name='Hue ambiance        ', model='LTA001'},
--   ['59cbfb37-eba9-4746-9e64-ded409857abc'] = {type='Hue color candle ', name='Left window         ', model='LCT012'},
--   ['1c10e485-e52b-4144-9991-46dbb2eedafa'] = {type='Hue color candle ', name='Middle window       ', model='LCT012'},
--   ['8dddf049-0a73-44e2-8fdd-e3c2310c1bb1'] = {type='Hue color candle ', name='Roof1               ', model='LCT012'},
--   ['598e4796-be01-482f-99c1-92f95fa8a18c'] = {type='Hue color candle ', name='Roof2               ', model='LCT012'},
--   ['429ee799-9b86-43e5-bf31-ce3d06b45cc7'] = {type='Hue color candle ', name='Roof3               ', model='LCT012'},
--   ['d3b04b72-c2f0-401f-85d7-a65f2db5c48e'] = {type='Hue color candle ', name='Roof4               ', model='LCT012'},
--   ['c4bef7c5-0173-4d57-ae6a-d7f8a14b4dde'] = {type='Hue color candle ', name='Roof5               ', model='LCT012'},
--   ['5ddcb36b-f985-4876-88b6-a238c58b9dbf'] = {type='Hue color candle ', name='Star left           ', model='LCT012'},
--   ['721e69c5-bc75-4e99-b3ea-c05038ffa1af'] = {type='Hue color candle ', name='Star middle         ', model='LCT012'},
--   ['2d7bfac8-688b-4889-b813-b927e875b533'] = {type='Hue color candle ', name='Star right          ', model='LCT012'},
--   ['9be444b2-1587-4fbe-89ac-efb809d7e629'] = {type='Hue color lamp   ', name='Roof lamp           ', model='LCT015'},
--   ['a001f510-48dd-47fc-b9ff-f779c40dd693'] = {type='Hue color lamp   ', name='Table1              ', model='LCA001'},
--   ['a2b30b76-f044-46b6-9e1c-c8156baf00ab'] = {type='Hue color lamp   ', name='Table2              ', model='LCA001'},
   ['3ab27084-d02f-44b9-bd56-70ea41163cb6'] = {type='Hue color lamp   ', name='Tim                 ', model='LCT015'},
--   ['e82c2285-20f3-401f-9621-9dc356feb694'] = {type='Hue color spot   ', name='Köksö1            ', model='LCG002'},
--   ['2219eadd-9464-4149-b52d-073ed1d9754a'] = {type='Hue color spot   ', name='Köksö2            ', model='LCG002'},
--   ['a007e50b-0bdd-4e48-bee0-97636d57285a'] = {type='Hue dimmer switch', name='Dimmer switch       ', model='RWL021'},
--   ['93d49902-6ce5-4383-9037-bfaeec8cd538'] = {type='Hue filament bulb', name='Right window        ', model='LWO003'},
--   ['9222ea53-37a6-4ac0-b57d-74bca1cfa23f'] = {type='Hue motion sensor', name='Living room sensor  ', model='SML001'},
--   ['8a453c82-0072-4223-9c42-f395b5cb0c40'] = {type='Hue smart plug   ', name='Hue smart plug 1    ', model='LOM007'},
--   ['932bd43b-d8cd-44bc-b8bd-daaf72ae6f82'] = {type='Hue wall switch module', name='Living room wall switch', model='RDM001'},
--   ['4c7e05ca-abe2-49cb-a12d-2ca6005cbda6'] = {type='Hue white lamp   ', name='Hue white lamp      ', model='LWA001'},
--   ['f2a231b4-9c27-466f-8344-05c4012c742b'] = {type='Philips hue      ', name='Philips hue         ', model='BSB002'},
--   ['cc309f30-d0f4-4ab5-a31f-39cd2206be57'] = {type='room             ', name='Bedroom             '},
--   ['795959f5-9313-4aae-b930-b178b48249e0'] = {type='room             ', name='Guest room          '},
--   ['bbe472e6-8ea8-477b-a116-ca345452e056'] = {type='room             ', name='Hall                '},
--   ['bcd3daec-82a9-4de7-813a-3464beee0090'] = {type='room             ', name='Living room         '},
--   ['b5f12b5f-20c7-47a5-8535-c7a20fb9e66d'] = {type='zone             ', name='Kitchen island      '},
--   ['fe101c36-3dcc-4831-90f1-5052fc54e08b'] = {type='zone             ', name='Kitchen table       '},
--   ['39e1fc25-e926-42e5-a840-b2d21aaa08f3'] = {type='zone             ', name='Stars               '},
--   ['9bfda4bf-b17e-4ec9-9123-a97afbcca814'] = {type='zone             ', name='Window lights       '},
}