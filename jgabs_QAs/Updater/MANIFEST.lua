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
        viewLayout = "generate",
        interfaces= {"quickApp"},
        quickAppVariables = {},
      },
      { version = 0.6,
        vars= {
          base1 = "https://github.com/jangabrielsson/TQAE/raw/bc0cf2007df79877f3b971f516318a3975d93ddf"
        },
        mainfile = "$base1/jgabs_QAs/EventRunner/EventRunner4.lua",
        descr = "New version of EventRunner4",
        files = "generate",
        keep= { "main" },
        viewLayout = "generate",
        interfaces= {"quickApp"},
        quickAppVariables = {},
      },
      { version = 0.61,
        vars = {
          base1 = "https://github.com/jangabrielsson/TQAE/raw/1117a60af5e05fa3196f2c2cfc5766126c4272c3"
        },
        descr = "Test version EventRunner4",
        ref = 0.6
      }
    }
  },

  ["896661234567893"] = {
    name = "ChildrenOfHue",
    type = "com.fibaro.deviceController",
    versions = {
      { version= 1.19,
        vars= {
          base1 = "https://github.com/jangabrielsson/TQAE/raw/bc0cf2007df79877f3b971f516318a3975d93ddf"
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
            value= "q6eLpWdYiMGq0kdQWFZB1NZHSlLvKL0GsNPJeEa-"
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
  }
}