-- Domoticz script to check radars
--
-- This script uses the ANWB feed to check for radars in a list of specified
-- roads. If one or more radars are stationed on one of the roads, it will
-- send out a notification.
--
-- In Domotics create new hardware of type Dummy if you don't already
-- have it. After that, create a new virtual sensor, type = 'tekst'. In
-- 'apparaten' you will find this new device. The number in the 'Idx'
-- column is your virtual_device_index.
--
-- Create a new user variable in 'gebruikers variablen'. Give it a name
-- and set type to 'integer'. The name you used is your user_variable_name.
--
-- (c) 2017 Johnny Mijnhout

commandArray={}

-- road names to check, enclosed and separated by pipe symbols(for example |A1|A201|)
roads="<-- your road list -->"

-- virtual text sensor index number
virtual_device_index = "<-- your index number -->"

-- user variable to store if a notification has been sent
user_variable_name = "<-- your user variable name -->"

-- check interval
check_internal_minutes = 15

-- hours between which you want to check
home_hour_start = 7
home_hour_end   = 9
work_hour_start = 15
work_hour_end   = 17

-- check if a message has been sent
message_sent = tonumber(uservariables[user_variable_name])

-- only run this script every x minutes on week days
day_number  = tonumber(os.date("%w"))
time_object = os.date("*t")
if time_object.min % check_internal_minutes > 0 or day_number >= 6 then
  goto done
end

-- only check between speicified times
if (time_object.hour < home_hour_start or time_object.hour > home_hour_end) and (time_object.hour < work_hour_start or time_object.hour > work_hour_end) then
  if message_sent == 1 then
    commandArray["Variable:"..user_variable_name] = "0"
  end
  goto done
end

-- import json lib
json = (loadfile "/home/pi/domoticz/scripts/lua/JSON.lua")()

-- set defaults
message     = ""
radar_found = false

-- get data from ANWB
jsondata    = assert(io.popen("curl 'https://www.anwb.nl/feeds/gethf'"))
jsondevices = jsondata:read("*all")
jsondata:close()
anwb = json:decode(jsondevices)
for k, v in pairs(anwb.roadEntries) do
  road = tostring(v.road)
  if string.match(roads,"|"..road.."|") then
    radar_number = # v.events.radars
    if radar_number > 0 then
      radar_found = true
      message = message..tostring(radar_number).." flitser(s) op de "..road.."! "
    end
  end
end

-- if no radars are found, set this in the message
if not radar_found then
  message = "Geen flitsers gevonden op de "..string.sub(string.gsub(roads, "|", ", "), 3, -3)
end

-- append time to message
message = message.." (update "..tostring(os.date("%H:%M"))..")"

-- send message if radars are found
if radar_found and message_sent == 0 then
    commandArray["SendNotification"] = message
    commandArray["Variable:"..user_variable_name] = "1"
end

-- update virtual device text
commandArray["UpdateDevice"] = virtual_device_index.."|0|"..tostring(message)

::done::
return commandArray