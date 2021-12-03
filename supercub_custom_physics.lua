
local min = math.min
local abs = math.abs
--local deg = math.deg

function supercub.physics(self)
    local friction = 0.99
	local vel=self.object:get_velocity()
	
	-- bounciness
	if self.springiness and self.springiness > 0 then
		local vnew = vector.new(vel)
		
		if not self.collided then						-- ugly workaround for inconsistent collisions
			for _,k in ipairs({'y','z','x'}) do
				if vel[k]==0 and abs(self.lastvelocity[k])> 0.1 then
					vnew[k]=-self.lastvelocity[k]*self.springiness
				end
			end
		end
		
		if not vector.equals(vel,vnew) then
			self.collided = true
		else
			if self.collided then
				vnew = vector.new(self.lastvelocity)
			end
			self.collided = false
		end
		
		self.object:set_velocity(vnew)
	end
	
    local new_velocity = {x=0, y=0, z=0}

    local accell = self._last_accell

    accell.y = accell.y + mobkit.gravity
    self.water_drag = 0.1

    mobkit.set_acceleration(self.object,{x=0,y=0,z=0})
	self.isinliquid = false
    --new_velocity = vector.add(vel, {x=0,y=mobkit.gravity * self.dtime,z=0})
    --self.object:set_velocity(new_velocity)

    new_velocity = vector.add(vel, vector.multiply(accell, self.dtime))
    self.object:set_pos(self.object:get_pos())

    --[[
    accell correction
    under some circunstances the acceleration exceeds the max value accepted by set_acceleration and
    the game crashes with an overflow, so limiting the max acceleration in each axis prevents the crash
    ]]--
    local max_factor = 200
    local acc_adjusted = 20
    if new_velocity.x > max_factor then new_velocity.x = acc_adjusted end
    if new_velocity.x < -max_factor then new_velocity.x = -acc_adjusted end
    if new_velocity.y > max_factor then new_velocity.y = acc_adjusted end
    if new_velocity.y < -max_factor then new_velocity.y = -acc_adjusted end
    if new_velocity.z > max_factor then new_velocity.z = acc_adjusted end
    if new_velocity.z < -max_factor then new_velocity.z = -acc_adjusted end
    -- end correction

		-- dumb friction
	if self.isonground and not self.isinliquid then
		self.object:set_velocity({x=new_velocity.x*friction,
								y=new_velocity.y,
								z=new_velocity.z*friction})
        
    else
        self.object:set_velocity(new_velocity)
        --self.object:set_acceleration(accell)
	end

end
