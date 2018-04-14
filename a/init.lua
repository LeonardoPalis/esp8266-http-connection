
inpin=8                   
gpio.mode(inpin,gpio.INT,gpio.PULLUP)  
function motion()
print("Motion Detected!")
 
end

function motionD()
print("Motion not Detected!")
 
end
 gpio.trig(8,"up",motion)