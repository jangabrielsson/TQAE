return {
  ["896661234567892"] = {
    name = "EventRunner4",
    type = "com.fibaro.deviceController",
    versions = {
      { version = 0.5,
        vars= {
          base1 = "https://raw.githubusercontent.com/jangabrielsson/EventRunner/master"
        },
        mainfile = "$base1/EventRunner4.lua",
        descr = "Old version of EventRunner4",
        files = "generate",
        keep= { "main" },
        viewLayout = [[{"$jason":{"head":{"title":"quickApp_device_53"},"body":{"header":{"title":"quickApp_device_53","style":{"height":"0"}},"sections":{"items":[{"style":{"weight":"1.2"},"type":"vertical","components":[{"type":"label","style":{"weight":"1.2"},"text":"...","name":"ERname"},{"type":"space","style":{"weight":"0.5"}}]},{"style":{"weight":"1.2"},"type":"vertical","components":[{"type":"button","style":{"weight":"1.2"},"text":"Triggers:ON","name":"debugTrigger"},{"type":"space","style":{"weight":"0.5"}}]},{"style":{"weight":"1.2"},"type":"vertical","components":[{"type":"button","style":{"weight":"1.2"},"text":"Post:ON","name":"debugPost"},{"type":"space","style":{"weight":"0.5"}}]},{"style":{"weight":"1.2"},"type":"vertical","components":[{"type":"button","style":{"weight":"1.2"},"text":"Rules:ON","name":"debugRule"},{"type":"space","style":{"weight":"0.5"}}]}]}}}}]],
        uiCallbacks = [[ [{"callback":"debugTriggerClicked","name":"debugTrigger","eventType":"onReleased"},{"callback":"debugPostClicked","name":"debugPost","eventType":"onReleased"},{"callback":"debugRuleClicked","name":"debugRule","eventType":"onReleased"}] ]],
        interfaces= {"quickApp"},
        quickAppVariables = {},
      },
      { version = 0.69,
        vars= {
          base1 = "https://raw.githubusercontent.com/jangabrielsson/TQAE/ER4_0.69"
        },
        mainfile = "$base1/jgabs_QAs/EventRunner/EventRunner4.lua",
        descr = "New version of EventRunner4",
        files = "generate",
        keep= { "main" },
        viewLayout = "generate",
        interfaces= {"quickApp"},
        quickAppVariables = {},
      },
      { version = 0.84,
        vars= {
          base1 = "https://raw.githubusercontent.com/jangabrielsson/TQAE/ER4_0.84"
        },
        mainfile = "$base1/jgabs_QAs/EventRunner/EventRunner4.lua",
        descr = "Bug fix",
        files = "generate",
        keep= { "main" },
        viewLayout = "generate",
        interfaces= {"quickApp"},
        quickAppVariables = {},
      },
      { version = 0.85,
        vars= {
          base1 = "https://raw.githubusercontent.com/jangabrielsson/TQAE/ER4_0.85"
        },
        mainfile = "$base1/jgabs_QAs/EventRunner/EventRunner4.lua",
        descr = "enable/disable trueFor rules",
        files = "generate",
        keep= { "main" },
        viewLayout = "generate",
        interfaces= {"quickApp"},
        quickAppVariables = {},
      },   
      { version = 0.86,
        vars= {
          base1 = "https://raw.githubusercontent.com/jangabrielsson/TQAE/ER4_0.86"
        },
        mainfile = "$base1/jgabs_QAs/EventRunner/EventRunner4.lua",
        descr = "enable/disable events",
        files = "generate",
        keep= { "main" },
        viewLayout = "generate",
        interfaces= {"quickApp"},
        quickAppVariables = {},
      }, 
--      { version = 0.x,
--        vars = {
--          base1 = "https://raw.githubusercontent.com/jangabrielsson/TQAE/ER4_0.XX"
--        },
--        descr = "Test version EventRunner4",
--        ref = 0.65
--      }
    }
  },

  ["896661234567893"] = {
    name = "ChildrenOfHue",
    type = "com.fibaro.deviceController",
    versions = {
      { version= 1.20,
        vars= {
          base1 = "https://raw.githubusercontent.com/jangabrielsson/TQAE/COH_1.20"
        },
        descr = "Stable version",
        mainfile = "$base1/jgabs_QAs/ChildrenOfHue.lua",
        files = "generate",
        keep = {
        },
        interfaces = {"quickApp"},
        viewLayout = "generate",
        quickAppVariables = {
          {
            name= "Hue_User",
            value= "q6eL9WdYiM--0kdQWFZB1NZHkvKL0GsNPJppEa-"
          },
          {
            name= "Hue_IP",
            value= "192.168.1.153"
          },
          {
            name= "CoH",
            value= "010"
          },
          {
            name= "pollingTime",
            value= 1
          },
          {
            name= "pollingFactor",
            value= 1
          }
        }
      }
    }
  },

  ["896661234567894"] = {
    name = "QAUpdater",
    type = "com.fibaro.deviceController",
    versions = {
      { version= 0.63,
        vars= {
          base1 = "https://raw.githubusercontent.com/jangabrielsson/TQAE/UpdaterQA_0.63"
        },
        descr = "First release",
        mainfile = "$base1/jgabs_QAs/Updater/UpdaterQA.lua",
        files = "generate",
        keep = {
        },
        interfaces = {"quickApp"},
        viewLayout = "generate",
      },
      { version= 0.66,
        vars= {
          base1 = "https://raw.githubusercontent.com/jangabrielsson/TQAE/UpdaterQA_0.66"
        },
        descr = "support for remote update by other QAs",
        mainfile = "$base1/jgabs_QAs/Updater/UpdaterQA.lua",
        files = "generate",
        keep = {
        },
        interfaces = {"quickApp"},
        viewLayout = "generate",
      },
      { version= 0.67,
        vars= {
          base1 = "https://raw.githubusercontent.com/jangabrielsson/TQAE/UpdaterQA_0.67"
        },
        descr = "support user keep files u_...",
        mainfile = "$base1/jgabs_QAs/Updater/UpdaterQA.lua",
        files = "generate",
        keep = {
        },
        interfaces = {"quickApp"},
        viewLayout = "generate",
      },
    }
  },

  ["896661234567895"] = {
    name = "TriggerQA",
    type = "com.fibaro.deviceController",
    versions = {
      { version= 1.21,
        vars= {
          base1 = "https://raw.githubusercontent.com/jangabrielsson/TQAE/TriggerQA_1.21"
        },
        descr = "First release",
        mainfile = "$base1/jgabs_QAs/TriggerQA.lua",
        files = "generate",
        keep = {
        },
        interfaces = {"quickApp"},
        viewLayout = "generate",
      },
    }
  },
  
    ["896781234567895"] = {
    name = "HueConnector",
    type = "com.fibaro.deviceController",
    versions = {
      { version= 0.1,
        vars= {
          base1 = "https://raw.githubusercontent.com/jangabrielsson/TQAE/HueConnector_0.1"
        },
        descr = "First release",
        mainfile = "$base1/jgabs_QAs/HueConnector.lua",
        files = "generate",
        keep = {
        },
        interfaces = {"quickApp"},
        viewLayout = "generate",
      },
    }
  }
}