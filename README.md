# TQAE
Forum documentation here <https://forum.fibaro.com/topic/55045-tiny-quickapp-emulator-tqae/>

The source for the emulator is aviable at the Fibaro forum link or directly from this GitHub

First time download the archive, TQAE.tar.gz and unpack it in a directory on your PC/Mac.
On Linux:
>tar xvf TQAE.tar.gz

On PC/Mac use suitable archive program to unpack the archive.

/TQAE.lua

/TQAE_QA.lua

/TQAEmodules/*

/TQAEexamples/*

...or pull the repository from here.

Download ZeroBrane studio <link>
Open ZBS and open the TQAE_QA.lua file
Set project directory in ZBS to the current file, TQAE_QA.lua (Project->Project Directory->Set From Current File)
Also set Lua interpreter to Lua 5.3 (Project->Lua Interpreter->Lua 5.3)

Now, run TQAE_QA.lua (F5 in ZBS).

The output will look something like:
```Lua
---------------- Tiny QuickAppEmulator (TQAE) v0.30 -------------
[11.10.2021] [08:33:23] |  SYS|: No connection to HC3
[11.10.2021] [08:33:23] |  SYS|: Created WebAPI at 192.168.1.18:8976
[11.10.2021] [08:33:23] |  SYS|: sunrise 07:43, sunset 19:50
```
Note first that there is no connection to the HC3 - we are missing user,  password, and IP for the HC3.
Secondly, note the WebAPI address. 192.168.1.18 is my machine, your IP address may be different. The port is 8976.
Open http://192.168.1.18:8976/web/main in your browser.

Goto [Settings] in the web page menu (upper right).
In the right hand column "Settings file", fill in User ID, Password, and IP address for the HC3.
Scroll down to the bottom of the page and click "Save"

Hopefully there is now a TQAEconfigs.lua file with the HC3 credentials that the emulator can use.

Go back to ZBS and stop the program (Shift-F5) and run it again:

```Lua
---------------- Tiny QuickAppEmulator (TQAE) v0.30 -------------
[11.10.2021] [09:13:43] |  SYS|: Using config file TQAEconfigs.lua
[11.10.2021] [09:13:43] |  SYS|: Created WebAPI at 192.168.1.18:8976
[11.10.2021] [09:13:43] |  SYS|: sunrise 07:14, sunset 17:52
```
It loads the config file and doesn'yt complain that there is no connection to the HC3 anymore.

Great we are up and running!
Now go to the forum thread and read more <https://forum.fibaro.com/topic/55045-tiny-quickapp-emulator-tqae/>
