dofile(minetest.get_modpath("supercub") .. DIR_DELIM .. "supercub_global_definitions.lua")
dofile(minetest.get_modpath("supercub") .. DIR_DELIM .. "supercub_hud.lua")

function supercub.get_hipotenuse_value(point1, point2)
    return math.sqrt((point1.x - point2.x) ^ 2 + (point1.y - point2.y) ^ 2 + (point1.z - point2.z) ^ 2)
end

function supercub.dot(v1,v2)
	return v1.x*v2.x+v1.y*v2.y+v1.z*v2.z
end

function supercub.sign(n)
	return n>=0 and 1 or -1
end

function supercub.minmax(v,m)
	return math.min(math.abs(v),m)*supercub.sign(v)
end

--lift
local function pitchroll2pitchyaw(aoa,roll)
	if roll == 0.0 then return aoa,0 end
	-- assumed vector x=0,y=0,z=1
	local p1 = math.tan(aoa)
	local y = math.cos(roll)*p1
	local x = math.sqrt(p1^2-y^2)
	local pitch = math.atan(y)
	local yaw=math.atan(x)*math.sign(roll)
	return pitch,yaw
end

function supercub.getLiftAccel(self, velocity, accel, longit_speed, roll, curr_pos)
    --lift calculations
    -----------------------------------------------------------
    local max_height = 15000
    
    local retval = accel
    if longit_speed > 1 then
        local angle_of_attack = math.rad(self._angle_of_attack + supercub.wing_angle_of_attack)
        local lift = supercub.lift
        --local acc = 0.8
        local daoa = deg(angle_of_attack)

        --to decrease the lift coefficient at hight altitudes
        local curr_percent_height = (100 - ((curr_pos.y * 100) / max_height))/100

	    local rotation=self.object:get_rotation()
	    local vrot = mobkit.dir_to_rot(velocity,rotation)
	    
	    local hpitch,hyaw = pitchroll2pitchyaw(angle_of_attack,roll)

	    local hrot = {x=vrot.x+hpitch,y=vrot.y-hyaw,z=roll}
	    local hdir = mobkit.rot_to_dir(hrot) --(hrot)
	    local cross = vector.cross(velocity,hdir)
	    local lift_dir = vector.normalize(vector.cross(cross,hdir))

        local lift_coefficient = (0.24*abs(daoa)*(1/(0.025*daoa+3))^4*math.sign(angle_of_attack))
        local lift_val = math.abs((lift*(vector.length(velocity)^2)*lift_coefficient)*curr_percent_height)
        --minetest.chat_send_all('lift: '.. lift_val)

        local lift_acc = vector.multiply(lift_dir,lift_val)
        --lift_acc=vector.add(vector.multiply(minetest.yaw_to_dir(rotation.y),acc),lift_acc)

        retval = vector.add(retval,lift_acc)
    end
    -----------------------------------------------------------
    -- end lift
    return retval
end


function supercub.get_gauge_angle(value, initial_angle)
    initial_angle = initial_angle or 90
    local angle = value * 18
    angle = angle - initial_angle
    angle = angle * -1
	return angle
end

-- attach player
function supercub.attach(self, player, instructor_mode)
    instructor_mode = instructor_mode or false
    local name = player:get_player_name()
    self.driver_name = name

    -- attach the driver
    if instructor_mode == true then
        player:set_attach(self.passenger_seat_base, "", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
        player:set_eye_offset({x = 0, y = -2.5, z = 2}, {x = 0, y = 1, z = -30})
    else
        player:set_attach(self.pilot_seat_base, "", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
        player:set_eye_offset({x = 0, y = -4, z = 2}, {x = 0, y = 1, z = -30})
    end
    player:set_eye_offset({x = 0, y = -4, z = 2}, {x = 0, y = 1, z = -30})
    player_api.player_attached[name] = true
    --player:set_physics_override({gravity = 0})
    -- make the driver sit
    minetest.after(0.2, function()
        player = minetest.get_player_by_name(name)
        if player then
	        player_api.set_animation(player, "sit")
            --apply_physics_override(player, {speed=0,gravity=0,jump=0})
        end
    end)
end

-- attach passenger
function supercub.attach_pax(self, player)
    local name = player:get_player_name()
    self._passenger = name

    -- attach the driver
    if self._instruction_mode == true then
        player:set_attach(self.pilot_seat_base, "", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
        player:set_eye_offset({x = 0, y = -4, z = 2}, {x = 0, y = 3, z = -30})
    else
        player:set_attach(self.passenger_seat_base, "", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
        player:set_eye_offset({x = 0, y = -2.5, z = 2}, {x = 0, y = 3, z = -30})
    end
    player_api.player_attached[name] = true
    --player:set_physics_override({gravity = 0})
    -- make the driver sit
    minetest.after(0.2, function()
        player = minetest.get_player_by_name(name)
        if player then
	        player_api.set_animation(player, "sit")
            --apply_physics_override(player, {speed=0,gravity=0,jump=0})
        end
    end)
end

function supercub.dettachPlayer(self, player)
    local name = self.driver_name
    supercub.setText(self)

    supercub.remove_hud(player)

    --self._engine_running = false

    -- driver clicked the object => driver gets off the vehicle
    self.driver_name = nil

    -- detach the player
    --player:set_physics_override({speed = 1, jump = 1, gravity = 1, sneak = true})
    player:set_detach()
    player_api.player_attached[name] = nil
    player:set_eye_offset({x=0,y=0,z=0},{x=0,y=0,z=0})
    player_api.set_animation(player, "stand")
    self.driver = nil
    --remove_physics_override(player, {speed=1,gravity=1,jump=1})
end

function supercub.dettach_pax(self, player)
    local name = self._passenger

    -- passenger clicked the object => driver gets off the vehicle
    self._passenger = nil

    -- detach the player
    --player:set_physics_override({speed = 1, jump = 1, gravity = 1, sneak = true})
    player:set_detach()
    player_api.player_attached[name] = nil
    player_api.set_animation(player, "stand")
    player:set_eye_offset({x=0,y=0,z=0},{x=0,y=0,z=0})
    --remove_physics_override(player, {speed=1,gravity=1,jump=1})
end

function supercub.checkAttach(self, player)
    if player then
        local player_attach = player:get_attach()
        if player_attach then
            if player_attach == self.pilot_seat_base or player_attach == self.passenger_seat_base then
                return true
            end
        end
    end
    return false
end

--painting
function supercub.paint(self, object, colstr, search_string)
    if colstr then
        self._color = colstr
        local entity = object:get_luaentity()
        local l_textures = entity.initial_properties.textures
        for _, texture in ipairs(l_textures) do
            local indx = texture:find(search_string)
            if indx then
                l_textures[_] = search_string .."^[multiply:".. colstr
            end
        end
        object:set_properties({textures=l_textures})
    end
end

-- destroy the boat
function supercub.destroy(self)
    if self.sound_handle then
        minetest.sound_stop(self.sound_handle)
        self.sound_handle = nil
    end

    if self._passenger then
        -- detach the passenger
        local passenger = minetest.get_player_by_name(self._passenger)
        if passenger then
            supercub.dettach_pax(self, passenger)
        end
    end

    if self.driver_name then
        -- detach the driver
        local player = minetest.get_player_by_name(self.driver_name)
        supercub.dettachPlayer(self, player)
    end

    local pos = self.object:get_pos()
    if self.fuel_gauge then self.fuel_gauge:remove() end
    if self.power_gauge then self.power_gauge:remove() end
    if self.climb_gauge then self.climb_gauge:remove() end
    if self.speed_gauge then self.speed_gauge:remove() end
    if self.engine then self.engine:remove() end
    if self.pilot_seat_base then self.pilot_seat_base:remove() end
    if self.passenger_seat_base then self.passenger_seat_base:remove() end

    if self.stick then self.stick:remove() end

    self.object:remove()

    pos.y=pos.y+2
    minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'hidroplane:wings')

    for i=1,6 do
	    minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'default:steel_ingot')
    end

    for i=1,2 do
	    minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'wool:white')
    end

    for i=1,6 do
	    minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'default:mese_crystal')
        minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'default:diamond')
    end

    --minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'hidroplane:hidro')
end

function supercub.check_node_below(obj)
    local pos_below = obj:get_pos()
    if pos_below then
        pos_below.y = pos_below.y - 1.3
        local node_below = minetest.get_node(pos_below).name
        --minetest.chat_send_all(dump(node_below))
        local nodedef = minetest.registered_nodes[node_below]
        local touching_ground = not nodedef or -- unknown nodes are solid
		        nodedef.walkable or false
        local liquid_below = not touching_ground and nodedef.liquidtype ~= "none"
        --minetest.chat_send_all(dump(touching_ground))
        return touching_ground, liquid_below
    end
    return nil, nil
end

function supercub.setText(self)
    local properties = self.object:get_properties()
    local formatted = string.format(
       "%.2f", self.hp_max
    )
    if properties then
        properties.infotext = "Nice supercub of " .. self.owner .. ". Current hp: " .. formatted
        self.object:set_properties(properties)
    end
end

function supercub.testImpact(self, velocity, position)
    local p = position --self.object:get_pos()
    local collision = false
    if self._last_vel == nil then return end
    --lets calculate the vertical speed, to avoid the bug on colliding on floor with hard lag
    if abs(velocity.y - self._last_vel.y) > 2 then
		local noded = mobkit.nodeatpos(mobkit.pos_shift(p,{y=-2.8}))
	    if (noded and noded.drawtype ~= 'airlike') then
		    collision = true
	    else
            self.object:set_velocity(self._last_vel)
            --self.object:set_acceleration(self._last_accell)
            self.object:set_velocity(vector.add(velocity, vector.multiply(self._last_accell, self.dtime/8)))
        end
    end
    local impact = abs(supercub.get_hipotenuse_value(velocity, self._last_vel))
    --minetest.chat_send_all('impact: '.. impact .. ' - hp: ' .. self.hp_max)
    if impact > 2 then
        --minetest.chat_send_all('impact: '.. impact .. ' - hp: ' .. self.hp_max)
		local nodeu = mobkit.nodeatpos(mobkit.pos_shift(p,{y=1}))
		local noded = mobkit.nodeatpos(mobkit.pos_shift(p,{y=-2.8}))
        local nodel = mobkit.nodeatpos(mobkit.pos_shift(p,{x=-1}))
        local noder = mobkit.nodeatpos(mobkit.pos_shift(p,{x=1}))
        local nodef = mobkit.nodeatpos(mobkit.pos_shift(p,{z=1}))
        local nodeb = mobkit.nodeatpos(mobkit.pos_shift(p,{z=-1}))
		if (nodeu and nodeu.drawtype ~= 'airlike') or
            (nodef and nodef.drawtype ~= 'airlike') or
            (nodeb and nodeb.drawtype ~= 'airlike') or
            (noder and noder.drawtype ~= 'airlike') or
            (nodel and nodel.drawtype ~= 'airlike') then
			collision = true
		end
    end

    if impact > 1.2 then
        local noded = mobkit.nodeatpos(mobkit.pos_shift(p,{y=-2.8}))
	    if (noded and noded.drawtype ~= 'airlike') then
            minetest.sound_play("supercub_touch", {
                --to_player = self.driver_name,
                object = self.object,
                max_hear_distance = 15,
                gain = 1.0,
                fade = 0.0,
                pitch = 1.0,
            }, true)
	    end
    end

    if collision then
        --self.object:set_velocity({x=0,y=0,z=0})
        local damage = impact / 2
        self.hp_max = self.hp_max - damage --subtract the impact value directly to hp meter
        minetest.sound_play("supercub_collision", {
            --to_player = self.driver_name,
            object = self.object,
            max_hear_distance = 15,
            gain = 1.0,
            fade = 0.0,
            pitch = 1.0,
        }, true)

        if self.driver_name then
            local player_name = self.driver_name
            supercub.setText(self)

            --minetest.chat_send_all('damage: '.. damage .. ' - hp: ' .. self.hp_max)
            if self.hp_max < 0 then --if acumulated damage is greater than 50, adieu
                supercub.destroy(self)
            end

            local player = minetest.get_player_by_name(player_name)
            if player then
		        if player:get_hp() > 0 then
			        player:set_hp(player:get_hp()-(damage/2))
		        end
            end
            if self._passenger ~= nil then
                local passenger = minetest.get_player_by_name(self._passenger)
                if passenger then
		            if passenger:get_hp() > 0 then
			            passenger:set_hp(passenger:get_hp()-(damage/2))
		            end
                end
            end
        end

    end
end

function supercub.checkattachBug(self)
    -- for some engine error the player can be detached from the submarine, so lets set him attached again
    if self.owner and self.driver_name then
        -- attach the driver again
        local player = minetest.get_player_by_name(self.owner)
        if player then
		    if player:get_hp() > 0 then
                supercub.attach(self, player, self._instruction_mode)
            else
                supercub.dettachPlayer(self, player)
		    end
        else
            if self._passenger ~= nil and self._command_is_given == false then
                self._autopilot = false
                supercub.transfer_control(self, true)
            end
        end
    end
end

function supercub.check_is_under_water(obj)
	local pos_up = obj:get_pos()
	pos_up.y = pos_up.y + 0.1
	local node_up = minetest.get_node(pos_up).name
	local nodedef = minetest.registered_nodes[node_up]
	local liquid_up = nodedef.liquidtype ~= "none"
	return liquid_up
end

function supercub.transfer_control(self, status)
    if status == false then
        self._command_is_given = false
        if self._passenger then
            minetest.chat_send_player(self._passenger,
                core.colorize('#ff0000', " >>> The flight instructor got the control."))
        end
        if self.driver_name then
            minetest.chat_send_player(self.driver_name,
                core.colorize('#00ff00', " >>> The control is with you now."))
        end
    else
        self._command_is_given = true
        if self._passenger then
            minetest.chat_send_player(self._passenger,
                core.colorize('#00ff00', " >>> The control is with you now."))
        end
        if self.driver_name then minetest.chat_send_player(self.driver_name," >>> The control was given.") end
    end
end

function supercub.engineSoundPlay(self)
    --sound
    if self.sound_handle then minetest.sound_stop(self.sound_handle) end
    if self.object then
        self.sound_handle = minetest.sound_play({name = "supercub_engine"},
            {object = self.object, gain = 2.0,
                pitch = 0.5 + ((self._power_lever/100)/2),
                max_hear_distance = 15,
                loop = true,})
    end
end

function supercub.engine_set_sound_and_animation(self)
    --minetest.chat_send_all('test1 ' .. dump(self._engine_running) )
    if self._engine_running then
        if self._last_applied_power ~= self._power_lever then
            --minetest.chat_send_all('test2')
            self._last_applied_power = self._power_lever
            self.engine:set_animation_frame_speed(60 + self._power_lever)
            supercub.engineSoundPlay(self)
        end
    else
        if self.sound_handle then
            minetest.sound_stop(self.sound_handle)
            self.sound_handle = nil
            self.engine:set_animation_frame_speed(0)
        end
    end
end

function supercub.flightstep(self)
    local velocity = self.object:get_velocity()
    local curr_pos = self.object:get_pos()

    self._last_time_command = self._last_time_command + self.dtime

    if self._last_time_command > 1 then self._last_time_command = 1 end

    local player = nil
    if self.driver_name then player = minetest.get_player_by_name(self.driver_name) end
    local passenger = nil
    if self._passenger then passenger = minetest.get_player_by_name(self._passenger) end

    if player then
        local ctrl = player:get_player_control()
        ---------------------
        -- change the driver
        ---------------------
        if passenger and self._last_time_command >= 1 and self._instruction_mode == true then
            if self._command_is_given == true then
                if ctrl.sneak or ctrl.jump or ctrl.up or ctrl.down or ctrl.right or ctrl.left then
                    self._last_time_command = 0
                    --take the control
                    supercub.transfer_control(self, false)
                end
            else
                if ctrl.sneak == true and ctrl.jump == true then
                    self._last_time_command = 0
                    --trasnfer the control to student
                    supercub.transfer_control(self, true)
                end
            end
        end
        -----------
        --autopilot
        -----------
        if self._instruction_mode == false and self._last_time_command >= 1 then
            if self._autopilot == true then
                if ctrl.sneak or ctrl.jump or ctrl.up or ctrl.down or ctrl.right or ctrl.left then
                    self._last_time_command = 0
                    self._autopilot = false
                    minetest.chat_send_player(self.driver_name," >>> Autopilot deactivated")
                end
            else
                if ctrl.sneak == true and ctrl.jump == true then
                    self._last_time_command = 0
                    self._autopilot = true
                    self._auto_pilot_altitude = curr_pos.y
                    minetest.chat_send_player(self.driver_name,core.colorize('#00ff00', " >>> Autopilot on"))
                end
            end
        end
        ----------------------------------
        -- shows the hud for the player
        ----------------------------------
        if ctrl.up == true and ctrl.down == true and self._last_time_command >= 1 then
            self._last_time_command = 0
            if self._show_hud == true then
                self._show_hud = false
            else
                self._show_hud = true
            end
        end
    end

    local accel_y = self.object:get_acceleration().y
    local rotation = self.object:get_rotation()
    local yaw = rotation.y
	local newyaw=yaw
    local pitch = rotation.x
	local roll = rotation.z
	local newroll=roll
    if newroll > 360 then newroll = newroll - 360 end
    if newroll < -360 then newroll = newroll + 360 end

    local hull_direction = mobkit.rot_to_dir(rotation) --minetest.yaw_to_dir(yaw)
    local nhdir = {x=hull_direction.z,y=0,z=-hull_direction.x}		-- lateral unit vector

    local longit_speed = vector.dot(velocity,hull_direction)
    self._longit_speed = longit_speed
    local longit_drag = vector.multiply(hull_direction,longit_speed*
            longit_speed*SUPERCUB_LONGIT_DRAG_FACTOR*-1*supercub.sign(longit_speed))
	local later_speed = supercub.dot(velocity,nhdir)
    --minetest.chat_send_all('later_speed: '.. later_speed)
	local later_drag = vector.multiply(nhdir,later_speed*later_speed*
            SUPERCUB_LATER_DRAG_FACTOR*-1*supercub.sign(later_speed))
    local accel = vector.add(longit_drag,later_drag)
    local stop = false

    local node_bellow = mobkit.nodeatpos(mobkit.pos_shift(curr_pos,{y=-1.3}))
    local is_flying = true
    if node_bellow and node_bellow.drawtype ~= 'airlike' then is_flying = false end
    --if is_flying then minetest.chat_send_all('is flying') end

    local is_attached = supercub.checkAttach(self, player)

    --ajustar angulo de ataque
    local percentage = math.abs(((longit_speed * 100)/(supercub.min_speed + 5))/100)
    if percentage > 1.5 then percentage = 1.5 end
    self._angle_of_attack = self._angle_of_attack - ((self._elevator_angle / 20)*percentage)
    if self._angle_of_attack < -0.5 then
        self._angle_of_attack = -0.1
        self._elevator_angle = self._elevator_angle - 0.1
    end --limiting the negative angle]]--
    if self._angle_of_attack > 20 then
        self._angle_of_attack = 20
        self._elevator_angle = self._elevator_angle + 0.1
    end --limiting the very high climb angle due to strange behavior]]--

    --minetest.chat_send_all(self._angle_of_attack)

    -- pitch
    local speed_factor = 0
    if longit_speed > supercub.min_speed then speed_factor = (velocity.y * math.rad(1)) end
    local newpitch = math.rad(self._angle_of_attack) + speed_factor


    -- adjust pitch at ground
    local tail_lift_min_speed = 4
    local tail_lift_max_speed = 8
    local tail_angle = 12
    if math.abs(longit_speed) > tail_lift_min_speed then
        if math.abs(longit_speed) < tail_lift_max_speed then
            --minetest.chat_send_all(math.abs(longit_speed))
            local speed_range = tail_lift_max_speed - tail_lift_min_speed
            percentage = 1-((math.abs(longit_speed) - tail_lift_min_speed)/speed_range)
            if percentage > 1 then percentage = 1 end
            if percentage < 0 then percentage = 0 end
            local angle = tail_angle * percentage
            local calculated_newpitch = math.rad(angle)
            if newpitch < calculated_newpitch then newpitch = calculated_newpitch end --ja aproveita o pitch atual se ja estiver cerrto
            if newpitch > math.rad(tail_angle) then newpitch = math.rad(tail_angle) end --não queremos arrastar o cauda no chão
        end
    else
        if math.abs(longit_speed) < tail_lift_min_speed then
            newpitch = math.rad(tail_angle)
        end
    end

    -- new yaw
	if math.abs(self._rudder_angle)>1.5 then
        local turn_rate = math.rad(14)
        local yaw_turn = self.dtime * math.rad(self._rudder_angle) * turn_rate *
                supercub.sign(longit_speed) * math.abs(longit_speed/2)
		newyaw = yaw + yaw_turn
	end

    --roll adjust
    ---------------------------------
    local delta = 0.002
    if is_flying then
        local roll_reference = newyaw
        local sdir = minetest.yaw_to_dir(roll_reference)
        local snormal = {x=sdir.z,y=0,z=-sdir.x}	-- rightside, dot is negative
        local prsr = supercub.dot(snormal,nhdir)
        local rollfactor = -90
        local roll_rate = math.rad(10)
        newroll = (prsr*math.rad(rollfactor)) * (later_speed * roll_rate) * supercub.sign(longit_speed)
        --minetest.chat_send_all('newroll: '.. newroll)
    else
        delta = 0.2
        if roll > 0 then
            newroll = roll - delta
            if newroll < 0 then newroll = 0 end
        end
        if roll < 0 then
            newroll = roll + delta
            if newroll > 0 then newroll = 0 end
        end
    end

    ---------------------------------
    -- end roll

	if not is_attached then
        -- for some engine error the player can be detached from the machine, so lets set him attached again
        supercub.checkattachBug(self)
    end

    local pilot = player
    if self._command_is_given and passenger then
        pilot = passenger
    else
        self._command_is_given = false
    end

    ------------------------------------------------------
    --accell calculation block
    ------------------------------------------------------
    if is_attached or passenger then
        if self._autopilot ~= true then
            accel, stop = supercub.control(self, self.dtime, hull_direction,
                longit_speed, longit_drag, later_speed, later_drag, accel, pilot, is_flying)
        else
            accel = supercub.autopilot(self, self.dtime, hull_direction, longit_speed, accel, curr_pos)
        end
    end

    --end accell

    if accel == nil then accel = {x=0,y=0,z=0} end

    --lift calculation
    accel.y = accel_y

    --lets apply some bob in water
	if self.isinliquid then
        local bob = supercub.minmax(supercub.dot(accel,hull_direction),0.2)	-- vertical bobbing
        accel.y = accel.y + bob
        local max_pitch = 6
        local h_vel_compensation = (((longit_speed * 2) * 100)/max_pitch)/100
        if h_vel_compensation < 0 then h_vel_compensation = 0 end
        if h_vel_compensation > max_pitch then h_vel_compensation = max_pitch end
        newpitch = newpitch + (velocity.y * math.rad(max_pitch - h_vel_compensation))
    end

    local new_accel = accel
    if longit_speed > 1.5 then
        new_accel = supercub.getLiftAccel(self, velocity, new_accel, longit_speed, roll, curr_pos)
    end
    -- end lift

    if stop ~= true then --maybe == nil
        self._last_accell = new_accel
	    self.object:set_pos(curr_pos)
        self.object:set_velocity(velocity)
        mobkit.set_acceleration(self.object, new_accel)
    else
        if stop == true then
            self.object:set_acceleration({x=0,y=0,z=0})
            self.object:set_velocity({x=0,y=0,z=0})
        end
    end

    if is_flying == false then --isn't flying?
        --animate wheels
        if math.abs(longit_speed) > 0.2 then
            self.object:set_animation_frame_speed(longit_speed * 20)
        else
            self.object:set_animation_frame_speed(0)
        end
    else
        --stop wheels
        self.object:set_animation_frame_speed(0)
    end



    ------------------------------------------------------
    -- end accell
    ------------------------------------------------------

    ------------------------------------------------------
    -- sound and animation
    ------------------------------------------------------
    supercub.engine_set_sound_and_animation(self)
    ------------------------------------------------------

    --self.object:get_luaentity() --hack way to fix jitter on climb

    --adjust climb indicator
    local climb_rate = velocity.y
    if climb_rate > 5 then climb_rate = 5 end
    if climb_rate < -5 then
        climb_rate = -5
    end

    --is an stall, force a recover
    if self._angle_of_attack > 3 and climb_rate < -3 then
        self._elevator_angle = 0
        self._angle_of_attack = -1
        newpitch = math.rad(self._angle_of_attack)
    end

    --minetest.chat_send_all('rate '.. climb_rate)
    local climb_angle = supercub.get_gauge_angle(climb_rate)
    self.climb_gauge:set_attach(self.object,'',SUPERCUB_GAUGE_CLIMBER_POSITION,{x=0,y=0,z=climb_angle})

    local indicated_speed = longit_speed * 0.9
    if indicated_speed < 0 then indicated_speed = 0 end
    local speed_angle = supercub.get_gauge_angle(indicated_speed, -45)
    self.speed_gauge:set_attach(self.object,'',SUPERCUB_GAUGE_SPEED_POSITION,{x=0,y=0,z=speed_angle})

    if is_attached then
        if self._show_hud then
            supercub.update_hud(player, climb_angle, speed_angle)
        else
            supercub.remove_hud(player)
        end
    end

    --adjust power indicator
    local power_indicator_angle = supercub.get_gauge_angle(self._power_lever/10)
    self.power_gauge:set_attach(self.object,'',SUPERCUB_GAUGE_POWER_POSITION,{x=0,y=0,z=power_indicator_angle})

    --apply rotations
    self.object:set_rotation({x=newpitch,y=newyaw,z=newroll})
    --end

    --adjust elevator pitch (3d model)
    --self.elevator:set_attach(self.object,'',{x=0,y=4,z=-35.5},{x=-self._elevator_angle*2,y=0,z=0})
    self.object:set_bone_position("elevator", {x=0, y=4, z=-35.5}, {x=-self._elevator_angle*2 - 90, y=0, z=0})
    --adjust rudder
    --self.rudder:set_attach(self.object,'',{x=0,y=0.12,z=-36.85},{x=0,y=self._rudder_angle,z=0})
    self.object:set_bone_position("rudder", {x=0,y=8.4,z=-36.85}, {x=0,y=self._rudder_angle,z=0})
    --adjust ailerons
    self.object:set_bone_position("aileron.r", {x=30.377,y=8.2,z=-7}, {x=-self._rudder_angle - 90,y=0,z=0})
    self.object:set_bone_position("aileron.l", {x=-30.377,y=8.2,z=-7}, {x=self._rudder_angle - 90,y=0,z=0})
    --set stick position
    self.stick:set_attach(self.object,'',{x=0,y=-6,85,z=8},{x=self._elevator_angle/2,y=0,z=self._rudder_angle})

    -- calculate energy consumption --
    supercub.consumptionCalc(self, accel)

    --test collision
    supercub.testImpact(self, velocity, curr_pos)

    --saves last velocity for collision detection (abrupt stop)
    self._last_vel = self.object:get_velocity()
end

