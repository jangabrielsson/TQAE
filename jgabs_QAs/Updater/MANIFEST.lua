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
      { version = 0.91,
        vars= {
          base1 = "https://raw.githubusercontent.com/jangabrielsson/TQAE/ER4_0.91"
        },
        mainfile = "$base1/jgabs_QAs/EventRunner/EventRunner4.lua",
        descr = "better kill",
        files = "generate",
        keep= { "main" },
        viewLayout = "generate",
        interfaces= {"quickApp"},
        quickAppVariables = {},
      },
      { version = 0.95,
        vars= {
          base1 = "https://raw.githubusercontent.com/jangabrielsson/TQAE/ER4_0.95"
        },
        mainfile = "$base1/jgabs_QAs/EventRunner/EventRunner4.lua",
        descr = "fixed mapAnd bug",
        files = "generate",
        keep= { "main" },
        viewLayout = "generate",
        interfaces= {"quickApp"},
        quickAppVariables = {},
      },
      { version = 0.98,
        vars= {
          base1 = "https://raw.githubusercontent.com/jangabrielsson/TQAE/ER4_0.98"
        },
        mainfile = "$base1/jgabs_QAs/EventRunner/EventRunner4.lua",
        descr = "Tidy up and added nicer printing",
        files = "generate",
        keep= { "main" },
        viewLayout = "generate",
        interfaces= {"quickApp"},
        quickAppVariables = {},
      },
      { version = 0.991,
        vars= {
          base1 = "https://raw.githubusercontent.com/jangabrielsson/TQAE/ER4_0.991"
        },
        mainfile = "$base1/jgabs_QAs/EventRunner/EventRunner4.lua",
        descr = "Tidy up and added nicer printing",
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
      { version= 1.23,
        vars= {
          base1 = "https://raw.githubusercontent.com/jangabrielsson/TQAE/TriggerQA_1.23"
        },
        descr = "Fix cron",
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
      { version= 0.14,
        vars= {
          base1 = "https://raw.githubusercontent.com/jangabrielsson/TQAE/HueConnector_0.14"
        },
        descr = "Rotary support",
        mainfile = "$base1/jgabs_QAs/HueConnector.lua",
        files = "generate",
        keep = {
        },
        interfaces = {"quickApp"},
        viewLayout = "generate",
      },
      { version= 0.17,
        vars= {
          base1 = "https://raw.githubusercontent.com/jangabrielsson/TQAE/HueConnector_0.17"
        },
        descr = "More fixes",
        mainfile = "$base1/jgabs_QAs/HueConnector.lua",
        files = "generate",
        keep = {
        },
        interfaces = {"quickApp"},
        viewLayout = "generate",
      },
    }
  },
  ["896781234551432"] = {
    name = "HueSensors",
    type = "com.fibaro.deviceController",
    versions = {
      { version= 0.1,
        vars= {
          base1 = "https://raw.githubusercontent.com/jangabrielsson/TQAE/HueSensors_0.1"
        },
        descr = "First version",
        mainfile = "$base1/jgabs_QAs/HueSensors.lua",
        files = "generate",
        keep = {
        },
        interfaces = {"quickApp"},
        viewLayout = "generate",
      },
      { version= 0.11,
        vars= {
          base1 = "https://raw.githubusercontent.com/jangabrielsson/TQAE/HueSensors_0.11"
        },
        descr = "Rotary and wall plug support",
        mainfile = "$base1/jgabs_QAs/HueSensors.lua",
        files = "generate",
        keep = {
        },
        interfaces = {"quickApp"},
        viewLayout = "generate",
      },
    },
  },
  ["8969654324567896"] = {
    name = "iOSLocator",
    type = "com.fibaro.binarySensor",
    versions = {
      { version= 0.51,
        vars= {
          base1 = "https://raw.githubusercontent.com/jangabrielsson/TQAE/iOSLocator_0.51"
        },
        descr = "Fixed sort bug again",
        mainfile = "$base1/jgabs_QAs/iOSLocator.lua",
        files = "generate",
        keep = {
          "main"
        },
        interfaces = {"quickApp"},
        viewLayout = "generate",
      },
      { version= 0.52,
        vars= {
          base1 = "https://raw.githubusercontent.com/jangabrielsson/TQAE/iOSLocator_0.52"
        },
        descr = "Fixed sort bug again",
        mainfile = "$base1/jgabs_QAs/iOSLocator.lua",
        files = "generate",
        keep = {
          "main"
        },
        interfaces = {"quickApp"},
        viewLayout = "generate",
      },
    },
  },
}