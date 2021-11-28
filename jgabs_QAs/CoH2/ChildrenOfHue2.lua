_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  copas=true,
  debug = { onAction=true, http=false, UIEevent=true, refreshStates=false },
}

--%%name="HueTest"
--%%quickVars = {["Hue_IP"]=EM.cfg.Hue_IP,["Hue_User"]=EM.cfg.Hue_user }
--%%type="com.fibaro.deviceController"
--%%proxy=true

--FILE:jgabs_QAs/CoH2/CoH2.lua,CoH;
--FILE:lib/fibaroExtra.lua,fibaroExtra;
--FILE:lib/UI.lua,UI;
--FILE:lib/colorConversion.lua,colorConversion;

HueTable = {
--  ['0d9dc2ae-9dbe-4eba-a2c3-f1d036c401b9'] = { type='room'    , product='*'                      , name = 'Star' },
--  ['1c10e485-e52b-4144-9991-46dbb2eedafa'] = { type='device'  , product='Hue color candle'       , name = 'Middle window' },
--  ['1d83a9ef-1012-446d-94f0-ab95ae655931'] = { type='room'    , product='*'                      , name = 'Living room' },
--  ['20174df3-48c1-44a6-bf91-cb8aa1010ef2'] = { type='room'    , product='*'                      , name = 'Right window' },
--  ['2219eadd-9464-4149-b52d-073ed1d9754a'] = { type='device'  , product='Hue color spot'         , name = 'Köksö2' },
--  ['2d7bfac8-688b-4889-b813-b927e875b533'] = { type='device'  , product='Hue color candle'       , name = 'Star right' },
--  ['3ab27084-d02f-44b9-bd56-70ea41163cb6'] = { type='device'  , product='Hue color lamp'         , name = 'Tim' },
--  ['429ee799-9b86-43e5-bf31-ce3d06b45cc7'] = { type='device'  , product='Hue color candle'       , name = 'Roof3' },
--  ['4b40852d-290a-4dfe-9dcc-00b1f88be5c3'] = { type='room'    , product='*'                      , name = 'Köksö' },
--  ['4c7e05ca-abe2-49cb-a12d-2ca6005cbda6'] = { type='device'  , product='Hue white lamp'         , name = 'Hue white lamp' },
--  ['4de3ac70-81e5-408e-9e65-d25ddc483ed9'] = { type='device'  , product='Hue ambiance lamp'      , name = 'Hue ambiance' },
--  ['598e4796-be01-482f-99c1-92f95fa8a18c'] = { type='device'  , product='Hue color candle'       , name = 'Roof2' },
--  ['59cbfb37-eba9-4746-9e64-ded409857abc'] = { type='device'  , product='Hue color candle'       , name = 'Left window' },
--  ['5ddcb36b-f985-4876-88b6-a238c58b9dbf'] = { type='device'  , product='Hue color candle'       , name = 'Star left' },
--  ['721e69c5-bc75-4e99-b3ea-c05038ffa1af'] = { type='device'  , product='Hue color candle'       , name = 'Star middle' },
--  ['795959f5-9313-4aae-b930-b178b48249e0'] = { type='room'    , product='*'                      , name = 'Tim' },
--  ['8a453c82-0072-4223-9c42-f395b5cb0c40'] = { type='device'  , product='Hue smart plug'         , name = 'Hue smart plug 1' },
--  ['8dddf049-0a73-44e2-8fdd-e3c2310c1bb1'] = { type='device'  , product='Hue color candle'       , name = 'Roof1' },
  ['9222ea53-37a6-4ac0-b57d-74bca1cfa23f'] = { type='device'  , product='Hue motion sensor'      , name = 'Living room sensor' },
--  ['932bd43b-d8cd-44bc-b8bd-daaf72ae6f82'] = { type='device'  , product='Hue wall switch module' , name = 'Hue wall switch module 1' },
--  ['93d49902-6ce5-4383-9037-bfaeec8cd538'] = { type='device'  , product='Hue filament bulb'      , name = 'Right window' },
--  ['9be444b2-1587-4fbe-89ac-efb809d7e629'] = { type='device'  , product='Hue color lamp'         , name = 'Roof lamp' },
--  ['9de7ef07-fba9-4f9d-86c4-655352bb3c1f'] = { type='room'    , product='*'                      , name = 'Hue1' },
--  ['a001f510-48dd-47fc-b9ff-f779c40dd693'] = { type='device'  , product='Hue color lamp'         , name = 'Table1' },
  ['a007e50b-0bdd-4e48-bee0-97636d57285a'] = { type='device'  , product='Hue dimmer switch'      , name = 'Dimmer switch' },
--  ['a2b30b76-f044-46b6-9e1c-c8156baf00ab'] = { type='device'  , product='Hue color lamp'         , name = 'Table2' },
--  ['bbe472e6-8ea8-477b-a116-ca345452e056'] = { type='room'    , product='*'                      , name = 'Hall' },
--  ['c4bef7c5-0173-4d57-ae6a-d7f8a14b4dde'] = { type='device'  , product='Hue color candle'       , name = 'Roof5' },
--  ['cc309f30-d0f4-4ab5-a31f-39cd2206be57'] = { type='room'    , product='*'                      , name = 'Bedroom' },
--  ['d3b04b72-c2f0-401f-85d7-a65f2db5c48e'] = { type='device'  , product='Hue color candle'       , name = 'Roof4' },
--  ['d8dd9da2-59ac-4910-bbd2-11a68d685e2e'] = { type='device'  , product='Hue color lamp'         , name = 'Globe' },
--  ['e82c2285-20f3-401f-9621-9dc356feb694'] = { type='device'  , product='Hue color spot'         , name = 'Köksö1' },
--  ['f2a231b4-9c27-466f-8344-05c4012c742b'] = { type='device'  , product='Philips hue'            , name = 'Philips hue' },
--  ['f82fc11f-9d4d-4a10-ab27-7736269dbcdc'] = { type='room'    , product='*'                      , name = 'Kitchen table' },
}