local _=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = { onAction=true, http=false, UIEevent=true },
--offline = true,
}

--%%name="My QA"
--%%type="com.fibaro.binarySwitch"

--- https://github.com/lunarmodules/Penlight/blob/master/lua/pl/Date.lua
--- Date and Date Format classes.
-- See  @{05-dates.md|the Guide}.
--
-- NOTE: the date module is deprecated! see
-- https://github.com/lunarmodules/Penlight/issues/285
--
-- Dependencies: `pl.class`, `pl.stringx`, `pl.utils`
-- @classmod pl.Date
-- @pragma nostrip

local os_time, os_date = os.time, os.date

--[[
Class pl.Date

Date and Date Format classes.

See the Guide.

NOTE: the date module is deprecated! see https://github.com/lunarmodules/Penlight/issues/285

Dependencies: pl.class, pl.stringx, pl.utils

Functions

Date:set (t)	set the current time of this Date object.
Date.tzone (ts)	get the time zone offset from UTC.
Date:toUTC ()	convert this date to UTC.
Date:toLocal ()	convert this UTC date to local.
Date:year (y)	set the year.
Date:month (m)	set the month.
Date:day (d)	set the day.
Date:hour (h)	set the hour.
Date:min (min)	set the minutes.
Date:sec (sec)	set the seconds.
Date:yday (yday)	set the day of year.
Date:year (y)	get the year.
Date:month ()	get the month.
Date:day ()	get the day.
Date:hour ()	get the hour.
Date:min ()	get the minutes.
Date:sec ()	get the seconds.
Date:yday ()	get the day of year.
Date:weekday_name (full)	name of day of week.
Date:month_name (full)	name of month.
Date:is_weekend ()	is this day on a weekend?.
Date:add (t)	add to a date object.
Date:last_day ()	last day of the month.
Date:diff (other)	difference between two Date objects.
Date:__tostring ()	long numerical ISO data format version of this date.
Date:__eq (other)	equality between Date objects.
Date:__lt (other)	ordering between Date objects.
Date:__sub ()	difference between Date objects.
Date:__add (other)	add a date and an interval.
Date.Interval (t)	Date.Interval constructor
Date.Interval:__tostring ()	If it's an interval then the format is '2 hours 29 sec' etc.
Date.Format (fmt.)	Date.Format constructor.
Date.Format:parse (str)	parse a string into a Date object.
Date.Format:tostring (d)	convert a Date object into a string.
Date.Format:US_order (yesno)	force US order in dates like 9/11/2001
Methods

pl.Date:Date (t, ...)	Date constructor.


Functions

Date:set (t)
set the current time of this Date object.
Parameters:

t int seconds since epoch
Date.tzone (ts)
get the time zone offset from UTC.
Parameters:

ts int seconds ahead of UTC
Date:toUTC ()
convert this date to UTC.
Date:toLocal ()
convert this UTC date to local.
Date:year (y)
set the year.
Parameters:

y int Four-digit year
Date:month (m)
set the month.
Parameters:

m int month
Date:day (d)
set the day.
Parameters:

d int day
Date:hour (h)
set the hour.
Parameters:

h int hour
Date:min (min)
set the minutes.
Parameters:

min int minutes
Date:sec (sec)
set the seconds.
Parameters:

sec int seconds
Date:yday (yday)
set the day of year.
Parameters:

yday int day of year
Date:year (y)
get the year.
Parameters:

y int Four-digit year
Date:month ()
get the month.
Date:day ()
get the day.
Date:hour ()
get the hour.
Date:min ()
get the minutes.
Date:sec ()
get the seconds.
Date:yday ()
get the day of year.
Date:weekday_name (full)
name of day of week.
Parameters:

full bool abbreviated if true, full otherwise.
Returns:

string name
Date:month_name (full)
name of month.
Parameters:

full int abbreviated if true, full otherwise.
Returns:

string name
Date:is_weekend ()
is this day on a weekend?.
Date:add (t)
add to a date object.
Parameters:

t a table containing one of the following keys and a value: one of year,month,day,hour,min,sec
Returns:

this date
Date:last_day ()
last day of the month.
Returns:

int day
Date:diff (other)
difference between two Date objects.
Parameters:

other Date Date object
Returns:

Date.Interval object
Date:__tostring ()
long numerical ISO data format version of this date.
Date:__eq (other)
equality between Date objects.
Parameters:

other
Date:__lt (other)
ordering between Date objects.
Parameters:

other
Date:__sub ()
difference between Date objects.
Date:__add (other)
add a date and an interval.
Parameters:

other either a Date.Interval object or a table such as passed to Date:add
Date.Interval (t)
Date.Interval constructor
Parameters:

t int an interval in seconds
Date.Interval:__tostring ()
If it's an interval then the format is '2 hours 29 sec' etc.
Date.Format (fmt.)
Date.Format constructor.
Parameters:

fmt. string A string where the following fields are significant:
d day (either d or dd)
y year (either yy or yyy)
m month (either m or mm)
H hour (either H or HH)
M minute (either M or MM)
S second (either S or SS)
Alternatively, if fmt is nil then this returns a flexible date parser that tries various date/time schemes in turn:

ISO 8601, like 2010-05-10 12:35:23Z or 2008-10-03T14:30+02
times like 15:30 or 8.05pm (assumed to be today's date)
dates like 28/10/02 (European order!) or 5 Feb 2012
month name like march or Mar (case-insensitive, first 3 letters); here the day will be 1 and the year this current year
A date in format 3 can be optionally followed by a time in format 2. Please see test-date.lua in the tests folder for more examples.

Usage:

df = Date.Format("yyyy-mm-dd HH:MM:SS")
Date.Format:parse (str)
parse a string into a Date object.
Parameters:

str string a date string
Returns:

date object
Date.Format:tostring (d)
convert a Date object into a string.
Parameters:

d a date object, or a time value as returned by os.time
Returns:

string
Date.Format:US_order (yesno)
force US order in dates like 9/11/2001
Parameters:

yesno
Methods

pl.Date:Date (t, ...)
Date constructor.
Parameters:

t
this can be either

nil or empty - use current date and time
number - seconds since epoch (as returned by os.time). Resulting time is UTC
Date - make a copy of this date
table - table containing year, month, etc as for os.time. You may leave out year, month or day, in which case current values will be used.
year (will be followed by month, day etc)
... true if Universal Coordinated Time, or two to five numbers: month,day,hour,min,sec
--]]

class "Date"
class "DateFormat"
Date.Format = DateFormat
--- Date constructor.
-- @param t this can be either
--
--   * `nil` or empty - use current date and time
--   * number - seconds since epoch (as returned by `os.time`). Resulting time is UTC
--   * `Date` - make a copy of this date
--   * table - table containing year, month, etc as for `os.time`. You may leave out year, month or day,
-- in which case current values will be used.
--   * year (will be followed by month, day etc)
--
-- @param ...  true if  Universal Coordinated Time, or two to five numbers: month,day,hour,min,sec
-- @function Date
function Date:__init(t,...)
  local time
  local nargs = select('#',...)
  if nargs > 2 then
    local extra = {...}
    local year = t
    t = {
      year = year,
      month = extra[1],
      day = extra[2],
      hour = extra[3],
      min = extra[4],
      sec = extra[5]
    }
  end
  if nargs == 1 then
    self.utc = select(1,...) == true
  end
  if t == nil or t == 'utc' then
    time = os_time()
    self.utc = t == 'utc'
  elseif type(t) == 'number' then
    time = t
    if self.utc == nil then self.utc = true end
  elseif type(t) == 'table' then
--        if getmetatable(t) == Date then -- copy ctor
    if type(t) == 'userdata' then -- copy ctor
      time = t.time
      self.utc = t.utc
    else
      if not (t.year and t.month) then
        local lt = os_date('*t')
        if not t.year and not t.month and not t.day then
          t.year = lt.year
          t.month = lt.month
          t.day = lt.day
        else
          t.year = t.year or lt.year
          t.month = t.month or (t.day and lt.month or 1)
          t.day = t.day or 1
        end
      end
      t.day = t.day or 1
      time = os_time(t)
    end
  else
    error("bad type for Date constructor: "..type(t),2)
  end
  self._type='Date'
  self:set(time)
end

--- set the current time of this Date object.
-- @int t seconds since epoch
function Date:set(t)
  self.time = t
  if self.utc then
    self.tab = os_date('!*t',t)
  else
    self.tab = os_date('*t',t)
  end
end

--- get the time zone offset from UTC.
-- @int ts seconds ahead of UTC
function Date.tzone (ts)
  if ts == nil then
    ts = os_time()
  elseif type(ts) == "userdata" then
--        if getmetatable(ts) == Date then
    if type(ts) == 'userdata' then
      ts = ts.time
    else
      ts = Date(ts).time
    end
  end
  local utc = os_date('!*t',ts)
  local lcl = os_date('*t',ts)
  lcl.isdst = false
  return os.difftime(os_time(lcl), os_time(utc))
end

--- convert this date to UTC.
function Date:toUTC ()
  local ndate = Date(self.tab)
  if not self.utc then
    ndate.utc = true
    ndate:set(ndate.time)
  end
  return ndate
end

--- convert this UTC date to local.
function Date:toLocal ()
  local ndate = Date(self.tab)
  if self.utc then
    ndate.utc = false
    ndate:set(ndate.time)
--~         ndate:add { sec = Date.tzone(self) }
  end
  return ndate
end

--- set the year.
-- @int y Four-digit year
-- @class function
-- @name Date:year

--- set the month.
-- @int m month
-- @class function
-- @name Date:month

--- set the day.
-- @int d day
-- @class function
-- @name Date:day

--- set the hour.
-- @int h hour
-- @class function
-- @name Date:hour

--- set the minutes.
-- @int min minutes
-- @class function
-- @name Date:min

--- set the seconds.
-- @int sec seconds
-- @class function
-- @name Date:sec

--- set the day of year.
-- @class function
-- @int yday day of year
-- @name Date:yday

--- get the year.
-- @int y Four-digit year
-- @class function
-- @name Date:year

--- get the month.
-- @class function
-- @name Date:month

--- get the day.
-- @class function
-- @name Date:day

--- get the hour.
-- @class function
-- @name Date:hour

--- get the minutes.
-- @class function
-- @name Date:min

--- get the seconds.
-- @class function
-- @name Date:sec

--- get the day of year.
-- @class function
-- @name Date:yday


for _,c in ipairs{'year','month','day','hour','min','sec','yday'} do
  Date[c] = function(self,val)
    if val then
      assert(type(val)=="number","Number expected")
      self.tab[c] = val
      self:set(os_time(self.tab))
      return self
    else
      return self.tab[c]
    end
  end
end

--- name of day of week.
-- @bool full abbreviated if true, full otherwise.
-- @ret string name
function Date:weekday_name(full)
  return os_date(full and '%A' or '%a',self.time)
end

--- name of month.
-- @int full abbreviated if true, full otherwise.
-- @ret string name
function Date:month_name(full)
  return os_date(full and '%B' or '%b',self.time)
end

--- is this day on a weekend?.
function Date:is_weekend()
  return self.tab.wday == 1 or self.tab.wday == 7
end

--- add to a date object.
-- @param t a table containing one of the following keys and a value:
-- one of `year`,`month`,`day`,`hour`,`min`,`sec`
-- @return this date
function Date:add(t)
  local old_dst = self.tab.isdst
  local key,val = next(t)
  self.tab[key] = self.tab[key] + val
  self:set(os_time(self.tab))
  if old_dst ~= self.tab.isdst then
    self.tab.hour = self.tab.hour - (old_dst and 1 or -1)
    self:set(os_time(self.tab))
  end
  return self
end

--- last day of the month.
-- @return int day
function Date:last_day()
  local d = 28
  local m = self.tab.month
  while self.tab.month == m do
    d = d + 1
    self:add{day=1}
  end
  self:add{day=-1}
  return self
end

--- difference between two Date objects.
-- @tparam Date other Date object
-- @treturn Date.Interval object
function Date:diff(other)
  local dt = self.time - other.time
  if dt < 0 then error("date difference is negative!",2) end
  return DateInterval(dt)
end

--- long numerical ISO data format version of this date.
function Date:__tostring()
  local fmt = '%Y-%m-%dT%H:%M:%S'
  if self.utc then
    fmt = "!"..fmt
  end
  local t = os_date(fmt,self.time)
  if self.utc then
    return  t .. 'Z'
  else
    local offs = self:tzone()
    if offs == 0 then
      return t .. 'Z'
    end
    local sign = offs > 0 and '+' or '-'
    local h = math.ceil(offs/3600)
    local m = (offs % 3600)/60
    if m == 0 then
      return t .. ('%s%02d'):format(sign,h)
    else
      return t .. ('%s%02d:%02d'):format(sign,h,m)
    end
  end
end

--- equality between Date objects.
function Date:__eq(other)
  return self.time == other.time
end

--- ordering between Date objects.
function Date:__lt(other)
  return self.time < other.time
end

--- difference between Date objects.
-- @function Date:__sub
Date.__sub = Date.diff

--- add a date and an interval.
-- @param other either a `Date.Interval` object or a table such as
-- passed to `Date:add`
function Date:__add(other)
  local nd = Date(self.tab)
  if type(other)=='userdata' and other._type=='DateInterval' then
    other = {sec=other.time}
  end
  nd:add(other)
  return nd
end

class 'DateInterval'(Date)
Date.Interval = DateInterval

---- Date.Interval constructor
-- @int t an interval in seconds
-- @function Date.Interval
function DateInterval:__init(t)
  Date.__init(self)
  self._type='DateInterval'
  self:set(t)
end

function DateInterval:set(t)
  self.time = t
  self.tab = os_date('!*t',self.time)
end

local function ess(n)
  if n > 1 then return 's '
  else return ' '
  end
end

--- If it's an interval then the format is '2 hours 29 sec' etc.
function DateInterval:__tostring()
  local t, res = self.tab, ''
  local y,m,d = t.year - 1970, t.month - 1, t.day - 1
  if y > 0 then res = res .. y .. ' year'..ess(y) end
  if m > 0 then res = res .. m .. ' month'..ess(m) end
  if d > 0 then res = res .. d .. ' day'..ess(d) end
  if y == 0 and m == 0 then
    local h = t.hour
    if h > 0 then res = res .. h .. ' hour'..ess(h) end
    if t.min > 0 then res = res .. t.min .. ' min ' end
    if t.sec > 0 then res = res .. t.sec .. ' sec ' end
  end
  if res == '' then res = 'zero' end
  return res
end

------------ Date.Format class: parsing and renderinig dates ------------

-- short field names, explicit os.date names, and a mask for allowed field repeats
local formats = {
  d = {'day',{true,true}},
  y = {'year',{false,true,false,true}},
  m = {'month',{true,true}},
  H = {'hour',{true,true}},
  M = {'min',{true,true}},
  S = {'sec',{true,true}},
}

--- Date.Format constructor.
-- @string fmt. A string where the following fields are significant:
--
--   * d day (either d or dd)
--   * y year (either yy or yyy)
--   * m month (either m or mm)
--   * H hour (either H or HH)
--   * M minute (either M or MM)
--   * S second (either S or SS)
--
-- Alternatively, if fmt is nil then this returns a flexible date parser
-- that tries various date/time schemes in turn:
--
--  * [ISO 8601](http://en.wikipedia.org/wiki/ISO_8601), like `2010-05-10 12:35:23Z` or `2008-10-03T14:30+02`
--  * times like 15:30 or 8.05pm  (assumed to be today's date)
--  * dates like 28/10/02 (European order!) or 5 Feb 2012
--  * month name like march or Mar (case-insensitive, first 3 letters); here the
-- day will be 1 and the year this current year
--
-- A date in format 3 can be optionally followed by a time in format 2.
-- Please see test-date.lua in the tests folder for more examples.
-- @usage df = Date.Format("yyyy-mm-dd HH:MM:SS")
-- @class function
-- @name Date.Format
function DateFormat:__init(fmt)
  if not fmt then
    self.fmt = '%Y-%m-%d %H:%M:%S'
    self.outf = self.fmt
    self.plain = true
    self._type='DateFormat'
    return
  end
  local append = table.insert
  local D,PLUS,OPENP,CLOSEP = '\001','\002','\003','\004'
  local vars,used = {},{}
  local patt,outf = {},{}
  local i = 1
  while i < #fmt do
    local ch = fmt:sub(i,i)
    local df = formats[ch]
    if df then
      if used[ch] then error("field appeared twice: "..ch,4) end
      used[ch] = true
      -- this field may be repeated
      local _,inext = fmt:find(ch..'+',i+1)
      local cnt = not _ and 1 or inext-i+1
      if not df[2][cnt] then error("wrong number of fields: "..ch,4) end
      -- single chars mean 'accept more than one digit'
      local p = cnt==1 and (D..PLUS) or (D):rep(cnt)
      append(patt,OPENP..p..CLOSEP)
      append(vars,ch)
      if ch == 'y' then
        append(outf,cnt==2 and '%y' or '%Y')
      else
        append(outf,'%'..ch)
      end
      i = i + cnt
    else
      append(patt,ch)
      append(outf,ch)
      i = i + 1
    end
  end
  -- escape any magic characters
  fmt = utils.escape(table.concat(patt))
  -- fmt = table.concat(patt):gsub('[%-%.%+%[%]%(%)%$%^%%%?%*]','%%%1')
  -- replace markers with their magic equivalents
  fmt = fmt:gsub(D,'%%d'):gsub(PLUS,'+'):gsub(OPENP,'('):gsub(CLOSEP,')')
  self.fmt = fmt
  self.outf = table.concat(outf)
  self.vars = vars
end

local parse_date

--- parse a string into a Date object.
-- @string str a date string
-- @return date object
function DateFormat:parse(str)
  assert(type(str)=='string',"String expected")
  if self.plain then
    return parse_date(str,self.us)
  end
  local res = {str:match(self.fmt)}
  if #res==0 then return nil, 'cannot parse '..str end
  local tab = {}
  for i,v in ipairs(self.vars) do
    local name = formats[v][1] -- e.g. 'y' becomes 'year'
    tab[name] = tonumber(res[i])
  end
  -- os.date() requires these fields; if not present, we assume
  -- that the time set is for the current day.
  if not (tab.year and tab.month and tab.day) then
    local today = Date()
    tab.year = tab.year or today:year()
    tab.month = tab.month or today:month()
    tab.day = tab.day or today:day()
  end
  local Y = tab.year
  if Y < 100 then -- classic Y2K pivot
    tab.year = Y + (Y < 35 and 2000 or 1999)
  elseif not Y then
    tab.year = 1970
  end
  return Date(tab)
end

--- convert a Date object into a string.
-- @param d a date object, or a time value as returned by @{os.time}
-- @return string
function DateFormat:tostring(d)
  local tm
  local fmt = self.outf
  if type(d) == 'number' then
    tm = d
  else
    tm = d.time
    if d.utc then
      fmt = '!'..fmt
    end
  end
  return os_date(fmt,tm)
end

--- force US order in dates like 9/11/2001
function DateFormat:US_order(yesno)
  self.us = yesno
end

--local months = {jan=1,feb=2,mar=3,apr=4,may=5,jun=6,jul=7,aug=8,sep=9,oct=10,nov=11,dec=12}
local months
local parse_date_unsafe
local function create_months()
  local ld, day1 = parse_date_unsafe '2000-12-31', {day=1}
  months = {}
  for i = 1,12 do
    ld = ld:last_day()
    ld:add(day1)
    local mon = ld:month_name():lower()
    months [mon] = i
  end
end

--[[
Allowed patterns:
- [day] [monthname] [year] [time]
- [day]/[month][/year] [time]
]]

local function looks_like_a_month(w)
  return w:match '^%a+,*$' ~= nil
end
local is_number = tonumber
local function tonum(s,l1,l2,kind)
  kind = kind or ''
  local n = tonumber(s)
  if not n then error(("%snot a number: '%s'"):format(kind,s)) end
  if n < l1 or n > l2 then
    error(("%s out of range: %s is not between %d and %d"):format(kind,s,l1,l2))
  end
  return n
end

local function  parse_iso_end(p,ns,sec)
  -- may be fractional part of seconds
  local _,nfrac,secfrac = p:find('^%.%d+',ns+1)
  if secfrac then
    sec = sec .. secfrac
    p = p:sub(nfrac+1)
  else
    p = p:sub(ns+1)
  end
  -- ISO 8601 dates may end in Z (for UTC) or [+-][isotime]
  -- (we're working with the date as lower case, hence 'z')
  if p:match 'z$' then -- we're UTC!
    return  sec, {h=0,m=0}
  end
  p = p:gsub(':','') -- turn 00:30 to 0030
  local _,_,sign,offs = p:find('^([%+%-])(%d+)')
  if not sign then return sec, nil end -- not UTC

  if #offs == 2 then offs = offs .. '00' end -- 01 to 0100
  local tz = { h = tonumber(offs:sub(1,2)), m = tonumber(offs:sub(3,4)) }
  if sign == '-' then tz.h = -tz.h; tz.m = -tz.m end
  return sec, tz
end

function parse_date_unsafe (s,US)
  s = s:gsub('T',' ') -- ISO 8601
  local parts = stringx.split(s:lower())
  local i,p = 1,parts[1]
  local function nextp() i = i + 1; p = parts[i] end
  local year,min,hour,sec,apm
  local tz
  local _,nxt,day, month = p:find '^(%d+)/(%d+)'
  if day then
    -- swop for US case
    if US then
      day, month = month, day
    end
    _,_,year = p:find('^/(%d+)',nxt+1)
    nextp()
  else -- ISO
    year,month,day = p:match('^(%d+)%-(%d+)%-(%d+)')
    if year then
      nextp()
    end
  end
  if p and not year and is_number(p) then -- has to be date
    if #p < 4 then
      day = p
      nextp()
    else -- unless it looks like a 24-hour time
      year = true
    end
  end
  if p and looks_like_a_month(p) then -- date followed by month
    p = p:sub(1,3)
    if not months then
      create_months()
    end
    local mon = months[p]
    if mon then
      month = mon
    else error("not a month: " .. p) end
    nextp()
  end
  if p and not year and is_number(p) then
    year = p
    nextp()
  end

  if p then -- time is hh:mm[:ss], hhmm[ss] or H.M[am|pm]
    _,nxt,hour,min = p:find '^(%d+):(%d+)'
    local ns
    if nxt then -- are there seconds?
      _,ns,sec = p:find ('^:(%d+)',nxt+1)
      --if ns then
      sec,tz = parse_iso_end(p,ns or nxt,sec)
      --end
    else -- might be h.m
      _,ns,hour,min = p:find '^(%d+)%.(%d+)'
      if ns then
        apm = p:match '[ap]m$'
      else  -- or hhmm[ss]
        local hourmin
        _,nxt,hourmin = p:find ('^(%d+)')
        if nxt then
          hour = hourmin:sub(1,2)
          min = hourmin:sub(3,4)
          sec = hourmin:sub(5,6)
          if #sec == 0 then sec = nil end
          sec,tz = parse_iso_end(p,nxt,sec)
        end
      end
    end
  end
  local today
  if year == true then year = nil end
  if not (year and month and day) then
    today = Date()
  end
  day = day and tonum(day,1,31,'day') or (month and 1 or today:day())
  month = month and tonum(month,1,12,'month') or today:month()
  year = year and tonumber(year) or today:year()
  if year < 100 then -- two-digit year pivot around year < 2035
    year = year + (year < 35 and 2000 or 1900)
  end
  hour = hour and tonum(hour,0,apm and 12 or 24,'hour') or 12
  if apm == 'pm' then
    hour = hour + 12
  end
  min = min and tonum(min,0,59) or 0
  sec = sec and tonum(sec,0,60) or 0  --60 used to indicate leap second
  local res = Date {year = year, month = month, day = day, hour = hour, min = min, sec = sec}
  if tz then -- ISO 8601 UTC time
    local corrected = false
    if tz.h ~= 0 then res:add {hour = -tz.h}; corrected = true end
    if tz.m ~= 0 then res:add {min = -tz.m}; corrected = true end
    res.utc = true
    -- we're in UTC, so let's go local...
    if corrected then
      res = res:toLocal()
    end-- we're UTC!
  end
  return res
end

function parse_date(s)
  local ok, d = pcall(parse_date_unsafe,s)
  if not ok then -- error
    d = d:gsub('.-:%d+: ','')
    return nil, d
  else
    return d
  end
end


function QuickApp:onInit()
  self:debug(self.name, self.id)
  local d = Date()
  print(d)
  print(d:is_weekend())
  local ikl = Date.Interval(3600*24)
  print(ikl)
  d = d+ikl
  print(d)
end