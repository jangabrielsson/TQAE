local version = "1.0"
local downloads = {
  ["TQAE.lua"] = {
    url="https://raw.githubusercontent.com/jangabrielsson/TQAE/master/TQAE.lua",
    path = "TQAE.lua"
  },  
  ["setup/TQAEplugin.lua"] = {
    url="https://raw.githubusercontent.com/jangabrielsson/TQAE/master/setup/TQAEplugin.lua",
    path = "setup/TQAEplugin.lua"
  },
  ["setup/codeTemplates.lua"] = {
    url="https://raw.githubusercontent.com/jangabrielsson/TQAE/master/setup/codeTemplates.lua",
    path = "setup/codeTemplates.lua"
  },
  ["setup/fileDownloads.lua"] = {
    url="https://raw.githubusercontent.com/jangabrielsson/TQAE/master/setup/fileDownloads.lua",
    path = "setup/fileDownloads.lua"
  },
  ["libs/fibaroExtra.lua"] = {
    url="https://raw.githubusercontent.com/jangabrielsson/TQAE/master/lib/fibaroExtra.lua",
    path = "lib/fibaroExtra.lua"
  },
  ["QAs/EventRunner/EventRunner4.lua"] = {
    url="https://raw.githubusercontent.com/jangabrielsson/TQAE/master/jgabs_QAs/EventRunner/EventRunner4.lua",
    path = "QAs/EventRunner/EventRunner4.lua"
  },
  ["QAs/EventRunner/EventRunner4Engine.lua"] = {
    url="https://raw.githubusercontent.com/jangabrielsson/TQAE/master/jgabs_QAs/EventRunner/EventRunner4Engine.lua",
    path = "QAs/EventRunner/EventRunner4Engine.lua"
  },
  ["modules"] = {
    pathdir = "modules",
    urldir = "https://raw.githubusercontent.com/jangabrielsson/TQAE/master/modules/",
    files = {
      ["api.lua"]="api.lua",
      ["async.lua"]="async.lua",
      ["class.lua"]="class.lua",
      ["copas.lua"]="copas.lua",
      ["devices.json"]="devices.json",
      ["fibaro.lua"]="fibaro.lua",
      ["fibaroPatch.lua"]="fibaroPatch.lua",
      ["files.lua"]="files.lua",
      ["json.lua"]="json.lua",
      ["LuWS.lua"]="LuWS.lua",
      ["net.lua"]="net.lua",
      ["offline.lua"]="offline.lua",
      ["proxy.lua"]="proxy.lua",
      ["QuickApp.lua"]="QuickApp.lua",
      ["refreshStates.lua"]="refreshStates.lua",
      ["Scene.lua"]="Scene.lua",
      ["settings.lua"]="settings.lua",
      ["stdQA.lua"]="stdQA.lua",
      ["sync.lua"]="sync.lua",
      ["SyncCall.lua"]="SyncCall.lua",
      ["time.lua"]="time.lua",
      ["ToDo.txt"]="ToDo.txt",
      ["ui.lua"]="ui.lua",
      ["utilities.lua"]="utilities.lua",
      ["webserver.lua"]="webserver.lua",
    }
  },
}

return {version=version, files=downloads}