Table = {}
Table.__index = table                     

function Table.new()
   local t = {}
   setmetatable(t, Table)
   return t
end

function printTable(mytable)
    print("TABLE START")
    for _, s in ipairs(mytable) do    
        print(s)
    end
    print("TABLE END")
end

function get_element(mytable,pos)
  for _, s in ipairs(mytable) do    
        if(_ == pos) then
          return s
        end
  end
  return nil
end

function addValueToTable(mytable, e)
     if(has_value(mytable,e)) then
         mytable:insert(e)
     end
end

function has_value(tab, val)
    for _,v in pairs(table_ip) do
          if v == val then
             print("ALREADY EXISTS-> ", ip)
            return false
          end
    end
    return true
end
