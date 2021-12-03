dofile(minetest.get_modpath("supercub") .. DIR_DELIM .. "supercub_global_definitions.lua")

--------------
-- Manual --
--------------

function supercub.getPlaneFromPlayer(player)
    local seat = player:get_attach()
    local plane = seat:get_attach()
    return plane
end

function supercub.pilot_formspec(name)
    local basic_form = table.concat({
        "formspec_version[3]",
        "size[6,4.5]",
	}, "")

	basic_form = basic_form.."button[1,1.0;4,1;go_out;Go Offboard]"
	basic_form = basic_form.."button[1,2.5;4,1;hud;Show/Hide Gauges]"

    minetest.show_formspec(name, "supercub:pilot_main", basic_form)
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname == "supercub:pilot_main" then
        local name = player:get_player_name()
        local plane_obj = supercub.getPlaneFromPlayer(player)
        local ent = plane_obj:get_luaentity()
        if fields.hud then
            if ent._show_hud == true then
                ent._show_hud = false
            else
                ent._show_hud = true
            end
        end
		if fields.go_out then
            --=========================
            --  dettach player
            --=========================
            -- eject passenger if the plane is on ground
            local touching_ground, liquid_below = supercub.check_node_below(ent.object)
            if ent.isinliquid or touching_ground or liquid_below then --isn't flying?
                --ok, remove pax
                if ent._passenger then
                    local passenger = minetest.get_player_by_name(ent._passenger)
                    if passenger then supercub.dettach_pax(ent, passenger) end
                end
            else
                --give the control to the pax
                if ent._passenger then
                    ent._autopilot = false
                    supercub.transfer_control(ent, true)
                end
            end
            ent._instruction_mode = false
            supercub.dettachPlayer(ent, player)
		end
        minetest.close_formspec(name, "supercub:pilot_main")
    end
end)
