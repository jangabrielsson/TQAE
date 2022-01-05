--_=loadfile and loadfile("TQAE.lua"){
--  user="admin", 
--  pwd="admin", 
--  host="192.168.1.59",
----  refreshStates=true,
--  temp = "temp/",
--  debug = { traceFibaro = true },
--  copas=true,
----  offline = true,
--  --startTime="12/24/2024-07:00",
--  ---speed=true
--}

--%%name="Test"
--%%quickVars={x="a b c d e f g"}

a = { a=9, b=7, g=4}
n,b = next(a,'a') 
print(n)
n,b = next(a,n) 
print(n)
n,b = next(a,n) 
print(n)
n,b = next(a,n) 
print(n)



