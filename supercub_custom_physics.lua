
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
	
    local new_velocity = nil

    local accell = {x=0, y=0, z=0}
    self.water_drag = 0.1

    mobkit.set_acceleration(self.object,{x=0,y=0,z=0})
	self.isinliquid = false
    new_velocity = vector.add(vel, {x=0,y=mobkit.gravity * self.dtime,z=0})
    --self.object:set_velocity(new_velocity)

    new_velocity = vector.add(new_velocity, vector.multiply(self._last_accell, self.dtime))
    self.object:set_pos(self.object:get_pos())
		-- dumb friction
	if self.isonground and not self.isinliquid then
		self.object:set_velocity({x=new_velocity.x*friction,
								y=new_velocity.y,
								z=new_velocity.z*friction})
    else
        self.object:set_velocity(new_velocity)
	end

end
