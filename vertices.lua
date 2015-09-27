access = {
["yes"] = "true",
["private"] = "true",
["no"] = "false",
["permissive"] = "true",
["agricultural"] = "false",
["use_sidepath"] = "true",
["delivery"] = "true",
["designated"] = "true",
["dismount"] = "true",
["discouraged"] = "false",
["forestry"] = "false",
["destination"] = "true",
["customers"] = "true",
["official"] = "false",
["public"] = "true",
["restricted"] = "true",
["allowed"] = "true",
["emergency"] = "false"
}

motor_vehicle = {
["yes"] = 1,
["private"] = 1,
["no"] = 0,
["permissive"] = 1,
["agricultural"] = 0,
["delivery"] = 1,
["designated"] = 1,
["discouraged"] = 0,
["forestry"] = 0,
["destination"] = 1,
["customers"] = 1,
["official"] = 0,
["public"] = 1,
["restricted"] = 1,
["allowed"] = 1
}

bicycle = {
["yes"] = 4,
["designated"] = 4,
["use_sidepath"] = 4,
["no"] = 0,
["permissive"] = 4,
["destination"] = 4,
["dismount"] = 4,
["lane"] = 4,
["track"] = 4,
["shared"] = 4,
["shared_lane"] = 4,
["sidepath"] = 4,
["share_busway"] = 4,
["none"] = 0,
["allowed"] = 4,
["private"] = 4
}

foot = {
["yes"] = 2,
["private"] = 2,
["no"] = 0,
["permissive"] = 2,
["agricultural"] = 0,
["use_sidepath"] = 2,
["delivery"] = 2,
["designated"] = 2,
["discouraged"] = 0,
["forestry"] = 0,
["destination"] = 2,
["customers"] = 2,
["official"] = 0,
["public"] = 2,
["restricted"] = 2,
["crossing"] = 2,
["sidewalk"] = 2,
["allowed"] = 2,
["passable"] = 2,
["footway"] = 2
}

bus = {
["no"] = 0,
["yes"] = 64,
["designated"] = 64,
["urban"] = 64,
["permissive"] = 64,
["restricted"] = 64,
["destination"] = 64,
["delivery"] = 0
}

psv = {
["bus"] = 64,
["no"] = 0,
["yes"] = 64,
["designated"] = 64,
["permissive"] = 64,
["1"] = 64,
["2"] = 64
}

--TODO: snowmobile might not really be passable for much other than ped..
toll = {
["yes"] = "true",
["no"] = "false",
["true"] = "true",
["false"] = "false",
["1"] = "true",
["interval"] = "true",
["snowmobile"] = "true"
}

function nodes_proc (kv, nokeys)
  --normalize a few tags that we care about
  local access = access[kv["access"]] or "true"

  if (kv["impassable"] == "yes" or (kv["access"] == "private" and (kv["emergency"] == "yes" or kv["service"] == "emergency_access"))) then
    access = "false"
  end 

  local foot_tag = foot[kv["foot"]] 
  local bike_tag = bicycle[kv["bicycle"]] 
  local auto_tag = motor_vehicle[kv["motorcar"]]
  if auto_tag == nil then
    auto_tag = motor_vehicle[kv["motor_vehicle"]]
  end
  local bus_tag = bus[kv["bus"]]
  if bus_tag == nil then
    bus_tag = psv[kv["psv"]]
  end
  --if bus was not set and car is 
  if bus_tag == nil and auto_tag == 1 then
    bus_tag = 64
  end

  local emergency_tag = kv["access"] == "emergency" or kv["emergency"] == "yes" or kv["service"] == "emergency_access" or nil
  local emergency = 0
  if emergency_tag ~= nil then
     emergency = 16
  end

  local auto = auto_tag or 0
  local bus = bus_tag or 0
  local foot = foot_tag or 0
  local bike = bike_tag or 0
   
  --access was set, but foot, bus, bike, and auto tags were not.
  if access == "true" and bit32.bor(auto, emergency, bike, foot, bus) == 0 then
    bus  = 64
    emergency = 16
    bike = 4
    foot = 2
    auto = 1
  end 

  --check for gates and bollards
  local gate = kv["barrier"] == "gate" or kv["barrier"] == "lift_gate" or kv["barrier"] == "border_control"
  local bollard = false
  if gate == false then
    --if there was a bollard cars can't get through it
    bollard = kv["barrier"] == "bollard" or kv["barrier"] == "block" or kv["bollard"] == "removable" or false

    --save the following as gates.
    if (bollard and (kv["bollard"] == "rising")) then
      gate = true
      bollard = false
    end
   
    if bollard == true then
      if bus_tag == nil then
        bus = 0
      end
      if auto_tag == nil then
        auto = 0
      end
      if emergency_tag == nil then
        emergency = 0
      end
    end
  end

  --if nothing blocks access at this node assume access is allowed.
  if gate == false and bollard == false and access == "true" then    
    if kv["highway"] == "crossing" or kv["railway"] == "crossing" or 
       kv["footway"] == "crossing" or kv["cycleway"] == "crossing" or
       kv["foot"] == "crossing" or kv["bicycle"] == "crossing" or
       kv["pedestrian"] == "crossing" or kv["crossing"] then
      bus  = 64
      emergency = 16
      bike = 4
      foot = 2
      auto = 1

      if bus_tag then 
        bus = bus_tag
      end
  
      if bike_tag then
        bike = bike_tag
      end
 
      if foot_tag then
        foot = foot_tag
      end
      if auto_tag then
        auto = auto_tag
      end
      if emergency_tag then
        emergency = emergency_tag
      end
    end
  end

  --store the gate and bollard info
  kv["gate"] = tostring(gate)
  kv["bollard"] = tostring(bollard)

  if kv["barrier"] == "toll_booth" then
    kv["toll_booth"] = "true"
  end

  local coins = toll[kv["payment:coins"]] or "false"
  local notes = toll[kv["payment:notes"]] or "false"

  --assume cash for toll, toll:*, and fee
  local cash =  toll[kv["toll"]] or toll[kv["toll:hgv"]] or toll[kv["toll:bicycle"]] or toll[kv["toll:hov"]] or
                toll[kv["toll:motorcar"]] or toll[kv["toll:motor_vehicle"]] or toll[kv["toll:bus"]] or 
                toll[kv["toll:motorcycle"]] or toll[kv["payment:cash"]] or toll[kv["fee"]] or "false"
  
  local etc = toll[kv["payment:e_zpass"]] or toll[kv["payment:e_zpass:name"]] or
              toll[kv["payment:pikepass"]] or toll[kv["payment:via_verde"]] or "false"
  
  local cash_payment = 0

  if (cash == "true" or (coins == "true" and notes == "true")) then
    cash_payment = 3
  elseif coins == "true" then
    cash_payment = 1
  elseif notes == "true" then
    cash_payment = 2
  end

  local etc_payment = 0

  if etc == "true" then 
    etc_payment = 4
  end

  --store a mask denoting payment type 
  kv["payment_mask"] = bit32.bor(cash_payment, etc_payment)

  if kv["amenity"] == "bicycle_rental" or (kv["shop"] == "bicycle" and kv["service:bicycle:rental"] == "yes") then
    kv["bicycle_rental"] = "true"
  end

  if kv["traffic_signals:direction"] == "forward" then
    kv["forward_signal"] = "true"
  end

  if kv["traffic_signals:direction"] == "backward" then
    kv["backward_signal"] = "true"
  end
 
  --store a mask denoting access
  kv["access_mask"] = bit32.bor(auto, emergency, bike, foot, bus)

  return 0, kv
end

function ways_proc (keyvalues, nokeys)
  --we dont care about ways at all so filter all of them
  return 1, keyvalues, 0, 0
end

function rels_proc (keyvalues, nokeys)
  --we dont care about rels at all so filter all of them
  return 1, keyvalues
end

function rel_members_proc (keyvalues, keyvaluemembers, roles, membercount)
  --because we filter all rels we never call this function
  membersuperseeded = {}
  for i = 1, membercount do
    membersuperseeded[i] = 0
  end

  return 1, keyvalues, membersuperseeded, 0, 0, 0
end


