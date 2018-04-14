local json = require('cjson')

function save_setting(name, value,psw)
  file.open(name, 'w') -- you don't need to do file.remove if you use the 'w' method of writing
  file.writeline(value)
  file.writeline(psw)
  file.close()
end
save_setting("global.conf", "addr", "192.168.15.6")

function read_setting(name)
  if (file.open(name)~=nil) then
      local result = string.sub(file.readline(), 1, -2) 
      local result2 = string.sub(file.readline(), 1, -2) 
      file.close()
      return true, result, result2
  else
      return false, nil
  end
end

local App = {}
local files = file.list()
if not files["setmode"] then
  save_setting("setmode", "mode", "setup")
end

function onpindown(level)
    response_kernel, type_kernel, mode_kernel = read_setting("setmode")
    if(mode_kernel == "setup") then
      save_setting("setmode", "mode", "normal")
    else
      save_setting("setmode", "mode", "setup")
    end
    node.restart()

end

function blinkLed(pin)
  setup_led = not setup_led
  if(setup_led) then
    gpio.write(pin, gpio.HIGH)  
  else
    gpio.write(pin, gpio.LOW)
  end
end

function motion()
  
  print("Motion Detected!")
  local json_data = {
    ["value"] = 111111,
    ["role"] = "super"
  }
  local json_data = json.encode(json_data)
  if(mode_kernel == "normal" and response_hub == true) then 
          readTSfield(addr_hub, "POST /requestin/" .. node.chipid() .. "994", 3000, json_data)
  end
end

function App.start()
  gpio.mode(6, gpio.OUTPUT)
  gpio.mode(7, gpio.OUTPUT)
  gpio.mode(2, gpio.INPUT, gpio.PULLUP)
  gpio.trig(2, 'up', onpindown)
  gpio.mode(8,gpio.INT,gpio.PULLUP) 
  
end

App.start();

function tryToConnect()
  local files = file.list()
  tmr.alarm(1, 2000, 1, function()
   if files["conf"] then
      response, ssid_file, psw_file = read_setting("conf") 
   end
   if(wifi.sta.getip() == nil) then
    wifi.sta.config(ssid_file,psw_file)
    tmr.alarm(2, 500, 1, function() blinkLed(6) end)
   else
    tmr.stop(1)
    tmr.stop(2)
    gpio.write(6, gpio.HIGH)  
    local response_communication, type_conf, addr_conf = read_setting("communication.pem")
    local response_auth, type_auth, con_auth_token = read_setting("auth.pem")
    gpio.trig(8,"up",motion) 
   end
  end)
end

response_kernel, type_kernel, mode_kernel = read_setting("setmode")
  tmr.alarm(2, 1200, 1, function() blinkLed(6) end)
if(mode_kernel == "setup" or mode_kernel == nil) then
  setup_led = false
  gpio.write(7, gpio.HIGH)  
  wifi.setmode(wifi.SOFTAP)
  ssid_name = "S@" .. node.chipid()
  wifi.ap.config({ssid=ssid_name,pwd="12345678"})
else
  response_communication, type_conf, addr_conf = read_setting("communication.pem") 
  tmr.stop(2)
  ssid_file = ""
  psw_file = ""
  if(wifi.sta.getip() ~= nil) then
    node.restore()
    node.restart()
  end
  wifi.setmode(wifi.STATION)
  tryToConnect()
end

function esp_update(request)
  wifi.sta.disconnect()

  if(request["uuid"] ~= nil and request["psw"] ~= nil) then
    save_setting('conf', request["uuid"], request["psw"])
  end
  if(request["addr"] ~= nil) then
    save_setting('hub', request["addr"], "0")
  end
  if(request["con_auth_token"] ~= nil) then
    save_setting('auth.pem', "pem", request["con_auth_token"])
  end
end

srv=net.createServer(net.TCP)
srv:listen(80,function(conn)
  conn:on("receive", function(client,payload)
    local buf ='{ \"status\": 200 }';
    local postparse_received={string.find(payload,"{")}
    local postend_received={string.find(payload,"}")}
    local received = string.sub(payload,postparse_received[2], postend_received[1])
    local received_format = json.decode(received)
    response_kernel, type_kernel, mode_kernel = read_setting("setmode")
    if(mode_kernel == "setup") then
      if received_format["mode"] == "stp" then 
        esp_update(received_format)
      end
    end
    client:send(buf);
    client:close();
    collectgarbage();
  end)
end)


response_hub, addr_hub, inf_hub = read_setting("hub") 
function readTSfield(ip_connect, route, port, j_data)
  serverStatus = 500
  conn = nil
  conn = net.createConnection(net.TCP, 0)
  conn:on("receive", function(conn, payload) 
      
    local postparse_request={string.find(payload,"{")}
    local postend_request={string.find(payload,"}")}
    local request = string.sub(payload,postparse_request[2], postend_request[1])
    local aux = json.decode(request)
    response_communication, type_conf, addr_conf = read_setting("communication.pem") 
    print(request)
    serverStatus = 200
    gpio.write(6, gpio.LOW)
    tmr.delay(500)
    if(aux["con_auth_token"] ~= nil ) then
      save_setting('communication.pem', "con_auth_token", aux["con_auth_token"])
      node.restore()
      node.restart()
    end
  end)
  conn:on("connection", function(conn, payload)
    conn:send(route .. " HTTP/1.0\r\n")
    conn:send("Content-Type: application/json\r\n")
    conn:send("Content-Length:"..string.len(j_data).."\r\n")
    conn:send("\r\n") 
    conn:send(j_data)
    conn:send("\r\n") 
  end)
  conn:on("disconnection", function(conn, payload)  
    if(serverStatus == 500) then
      gpio.write(6, gpio.LOW)
      gpio.write(7, gpio.HIGH)
    else
      gpio.write(6, gpio.HIGH)
      gpio.write(7, gpio.LOW)
    end
  end)
  conn:connect(port, ip_connect)
end

