--[[
	Mod by Kotolegokot and Xiong (2012-2013)
	Rev. kilbith and nerzhul (2015)
]]

money = {}

dofile(minetest.get_modpath("money") .. "/settings.txt") -- Loading settings.
dofile(minetest.get_modpath("money") .. "/hud.lua") -- Account display in HUD.

local accounts = {}
local input = io.open(minetest.get_worldpath() .. "/accounts", "r")
if input then
	accounts = minetest.deserialize(input:read("*l"))
	io.close(input)
end

function money.save_accounts()
	local output = io.open(minetest.get_worldpath() .. "/accounts", "w")
	output:write(minetest.serialize(accounts))
	io.close(output)
end
function money.set_money(name, amount)
	accounts[name].money = amount
	if money.hud[name] ~= nil then
		money.hud_change(name)
	end
	money.save_accounts()
end
function money.get_money(name)
	return accounts[name].money
end
function money.exist(name)
	return accounts[name] ~= nil
end

local save_accounts = money.save_accounts
local set_money = money.set_money
local get_money = money.get_money
local exist = money.exist

minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	if not exist(name) then
		local input = io.open(minetest.get_worldpath() .. "/money_" .. name .. ".txt") --For compatible with old versions.
		if input then
			local n = input:read("*n")
			io.close(input)
			accounts[name] = {money = n}
			os.remove(minetest.get_worldpath() .. "/money_" .. name .. ".txt")
			save_accounts()
		else
			accounts[name] = {money = INITIAL_MONEY}
			save_accounts()
		end
	end
	money.hud_add(name)
end)

minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	money.hud[name] = nil
end)

minetest.register_privilege("money", "Can use /money [pay <account> <amount>] command")
minetest.register_privilege("money_admin", {
	description = "Can use /money <account> | take/set/inc/dec <account> <amount>",
	give_to_singleplayer = false,
})

minetest.register_chatcommand("money", {
	privs = {money=true},
	params = "[<account> | pay/take/set/inc/dec <account> <amount>]",
	description = "Operations with money",
	func = function(name, param)
		if param == "" then --/money
			minetest.chat_send_player(name, "My money account : " .. CURRENCY_PREFIX .. get_money(name) .. CURRENCY_POSTFIX)
			return true
		end
		local m = string.split(param, " ")
		local param1, param2, param3 = m[1], m[2], m[3]
		if param1 and not param2 then --/money <account>
			if minetest.get_player_privs(name)["money_admin"] then
				if exist(param1) then
					minetest.chat_send_player(name, "Account of player '" .. param1 .. "' : " .. CURRENCY_PREFIX .. get_money(param1) .. CURRENCY_POSTFIX)
				else
					minetest.chat_send_player(name, "\"" .. param1 .. "\" account don't exist.")
				end
			else
				minetest.chat_send_player(name, "You don't have permission to run this command (missing privilege: money_admin)")
			end
			return true
		end
		if param1 and param2 and param3 then --/money pay/take/set/inc/dec <account> <amount>
			if param1 == "pay" or param1 == "take" or param1 == "set" or param1 == "inc" or param1 == "dec" then
				if exist(param2) then
					if tonumber(param3) then
						if tonumber(param3) >= 0 then
							param3 = tonumber(param3)
							if param1 == "pay" then
								if get_money(name) >= param3 then
									set_money(param2, get_money(param2) + param3)
									set_money(name, get_money(name) - param3)
									minetest.chat_send_player(param2, name .. " sent you " .. CURRENCY_PREFIX .. param3 .. CURRENCY_POSTFIX .. ".")
									minetest.chat_send_player(name, param2 .. " took your " .. CURRENCY_PREFIX .. param3 .. CURRENCY_POSTFIX .. ".")
								else
									minetest.chat_send_player(name, "You don't have " .. CURRENCY_PREFIX .. param3 - get_money(name) .. CURRENCY_POSTFIX .. ".")
								end
								return true
							end
							if minetest.get_player_privs(name)["money_admin"] then
								if param1 == "take" then
									if get_money(param2) >= param3 then
										set_money(param2, get_money(param2) - param3)
										set_money(name, get_money(name) + param3)
										minetest.chat_send_player(param2, name .. " took your " .. CURRENCY_PREFIX .. param3 .. CURRENCY_POSTFIX .. ".")
										minetest.chat_send_player(name, "You took " .. param2 .. "'s " .. CURRENCY_PREFIX .. param3 .. CURRENCY_POSTFIX .. ".")
									else
										minetest.chat_send_player(name, "Player named \""..param2.."\" do not have enough " .. CURRENCY_PREFIX .. param3 - get_money(player) .. CURRENCY_POSTFIX .. ".")
									end
								elseif param1 == "set" then
									set_money(param2, param3)
									minetest.chat_send_player(name, param2 .. " " .. CURRENCY_PREFIX .. param3 .. CURRENCY_POSTFIX)
								elseif param1 == "inc" then
									set_money(param2, get_money(param2) + param3)
									minetest.chat_send_player(name, param2 .. " " .. CURRENCY_PREFIX .. get_money(param2) .. CURRENCY_POSTFIX)
								elseif param1 == "dec" then
									if get_money(param2) >= param3 then
										set_money(param2, get_money(param2) - param3)
										minetest.chat_send_player(name, param2 .. " " .. CURRENCY_PREFIX .. get_money(param2) .. CURRENCY_POSTFIX)
									else
										minetest.chat_send_player(name, "Player named \""..param2.."\" don't have enough " .. CURRENCY_PREFIX .. param3 - get_money(player) .. CURRENCY_POSTFIX .. ".")
									end
								end
							else
								minetest.chat_send_player(name, "You don't have permission to run this command (missing privilege: money_admin)")
							end
						else
							minetest.chat_send_player(name, "You must specify a positive amount.")
						end
					else
						minetest.chat_send_player(name, "The amount must be a number.")
					end
				else
					minetest.chat_send_player(name, "\"" .. param2 .. "\" account don't exist.")
				end
				return true
			end
		end
		minetest.chat_send_player(name, "Invalid parameters (see /help money)")
	end,
})

local function has_shop_privilege(meta, player)
	return player:get_player_name() == meta:get_string("owner") or minetest.get_player_privs(player:get_player_name())["money_admin"]
end

minetest.register_node("money:shop", {
	description = "Shop",
	tiles = {"shop.png"},
	groups = {snappy=2,choppy=2,oddly_breakable_by_hand=2},
	sounds = default.node_sound_wood_defaults(),
	paramtype2 = "facedir",
	after_place_node = function(pos, placer)
	local meta = minetest.get_meta(pos)
	meta:set_string("owner", placer:get_player_name())
		meta:set_string("infotext", "Untuned Shop (owned by " .. placer:get_player_name() .. ")")
	end,
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec", "size[6,5]"..default.gui_bg..default.gui_bg_img..
			"field[0.256,0.5;6,1;shopname;Name of your shop;]"..
			"label[-0.025,1.03;Trade Type]"..
			"dropdown[-0.025,1.45;2.5,1;action;Sell,Buy,Buy and Sell;]"..
			"field[2.7,1.7;3.55,1;amount;Trade lot quantity (1-99);]"..
			"field[0.256,2.85;6,1;nodename;Node name to trade (eg. default:mese);]"..
			"field[0.256,4;3,1;costbuy;Buying price (per lot);]"..
			"field[3.25,4;3,1;costsell;Selling price (per lot);]"..
			"button_exit[2,4.5;2,1;button;Tune]")
		meta:set_string("infotext", "Untuned Shop")
		meta:set_string("owner", "")
		local inv = meta:get_inventory()
		inv:set_size("main", 32)
		meta:set_string("form", "yes")
	end,

	can_dig = function(pos, player)
		local meta = minetest.get_meta(pos);
		local inv = meta:get_inventory()
		return inv:is_empty("main") and (meta:get_string("owner") == player:get_player_name() or minetest.get_player_privs(player:get_player_name())["money_admin"])
	end,
	allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		local meta = minetest.get_meta(pos)
		if not has_shop_privilege(meta, player) then
			minetest.log("action", player:get_player_name().." tried to access a shop belonging to "..
			meta:get_string("owner").." at "..
			minetest.pos_to_string(pos))
			return 0
		end
		return count
	end,
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		local meta = minetest.get_meta(pos)
		if not has_shop_privilege(meta, player) then
			minetest.log("action", player:get_player_name().." tried to access a shop belonging to "..
			meta:get_string("owner").." at "..
			minetest.pos_to_string(pos))
			return 0
		end
		return stack:get_count()
	end,
	allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		local meta = minetest.get_meta(pos)
		if not has_shop_privilege(meta, player) then
			minetest.log("action", player:get_player_name()..
					" tried to access a shop belonging to "..
					meta:get_string("owner").." at "..
					minetest.pos_to_string(pos))
			return 0
		end
		return stack:get_count()
	end,
	on_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		minetest.log("action", player:get_player_name().." moves stuff in shop at "..minetest.pos_to_string(pos))
	end,
	on_metadata_inventory_put = function(pos, listname, index, stack, player)
		minetest.log("action", player:get_player_name().." moves stuff to shop at "..minetest.pos_to_string(pos))
	end,
	on_metadata_inventory_take = function(pos, listname, index, count, player)
		minetest.log("action", player:get_player_name().." takes stuff from shop at "..minetest.pos_to_string(pos))
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		local meta = minetest.get_meta(pos)
		if meta:get_string("form") == "yes" then
			if fields.shopname ~= "" and minetest.registered_items[fields.nodename] and tonumber(fields.amount) and tonumber(fields.amount) >= 1 and tonumber(fields.amount) <= 99 and (meta:get_string("owner") == sender:get_player_name() or minetest.get_player_privs(sender:get_player_name())["money_admin"]) then
				if fields.action == "Sell" then
					if not tonumber(fields.costbuy) then
						return
					end
					if not (tonumber(fields.costbuy) >= 0) then
						return
					end
				end
				if fields.action == "Buy" then
					if not tonumber(fields.costsell) then
						return
					end
					if not (tonumber(fields.costsell) >= 0) then
						return
					end
				end
				if fields.action == "Buy and Sell" then
					if not tonumber(fields.costbuy) then
						return
					end
					if not (tonumber(fields.costbuy) >= 0) then
						return
					end
					if not tonumber(fields.costsell) then
						return
					end
					if not (tonumber(fields.costsell) >= 0) then
						return
					end
				end
				local s, ss
				if fields.action == "Sell" then
					s = " sell "
					ss = "button[1,4.5;2,1;buttonsell;Sell("..fields.costbuy..")]"
				elseif fields.action == "Buy" then
					s = " buy "
					ss = "button[1,4.5;2,1;buttonbuy;Buy("..fields.costsell..")]"
				else
					s = " buy and sell "
					ss = "button[1,4.5;2,1;buttonbuy;Buy("..fields.costsell..")]" .. "button[5,4.5;2,1;buttonsell;Sell("..fields.costbuy..")]"
				end
				local meta = minetest.get_meta(pos)
				meta:set_string("formspec", "size[8,9.35;]"..default.gui_bg..default.gui_bg_img..
					"list[context;main;0,0;8,4;]"..
					"label[1.5,4;You can"..s..fields.amount.." "..fields.nodename.."]"..
						ss..
					"list[current_player;main;0,5.5;8,4;]")
				meta:set_string("shopname", fields.shopname)
				meta:set_string("action", fields.action)
				meta:set_string("nodename", fields.nodename)
				meta:set_string("amount", fields.amount)
				meta:set_string("costbuy", fields.costbuy)
				meta:set_string("costsell", fields.costsell)
				meta:set_string("infotext", "Shop \"" .. fields.shopname .. "\" (owned by " .. meta:get_string("owner") .. ")")
				meta:set_string("form", "no")
			end
		elseif fields["buttonbuy"] then
			local sender_name = sender:get_player_name()
			local inv = meta:get_inventory()
			local sender_inv = sender:get_inventory()
			if not inv:contains_item("main", meta:get_string("nodename") .. " " .. meta:get_string("amount")) then
				minetest.chat_send_player(sender_name, "Not enough goods in the shop.")
				return true
			elseif not sender_inv:room_for_item("main", meta:get_string("nodename") .. " " .. meta:get_string("amount")) then
				minetest.chat_send_player(sender_name, "Not enough space in your inventory.")
				return true
			elseif get_money(sender_name) - tonumber(meta:get_string("costsell")) < 0 then
				minetest.chat_send_player(sender_name, "You don't have enough money.")
				return true
			elseif not exist(meta:get_string("owner")) then
				minetest.chat_send_player(sender_name, "The owner's account does not currently exist; try again later.")
				return true
			end
			set_money(sender_name, get_money(sender_name) - meta:get_string("costsell"))
			set_money(meta:get_string("owner"), get_money(meta:get_string("owner")) + meta:get_string("costsell"))
			sender_inv:add_item("main", meta:get_string("nodename") .. " " .. meta:get_string("amount"))
			inv:remove_item("main", meta:get_string("nodename") .. " " .. meta:get_string("amount"))
			minetest.chat_send_player(sender_name, "You bought " .. meta:get_string("amount") .. " " .. meta:get_string("nodename") .. " at a price of " .. CURRENCY_PREFIX .. meta:get_string("costsell") .. CURRENCY_POSTFIX .. ".")
		elseif fields["buttonsell"] then
			local sender_name = sender:get_player_name()
			local inv = meta:get_inventory()
			local sender_inv = sender:get_inventory()
			if not sender_inv:contains_item("main", meta:get_string("nodename") .. " " .. meta:get_string("amount")) then
				minetest.chat_send_player(sender_name, "You do not have enough product.")
				return true
			elseif not inv:room_for_item("main", meta:get_string("nodename") .. " " .. meta:get_string("amount")) then
				minetest.chat_send_player(sender_name, "Not enough space in the shop.")
				return true
			elseif get_money(meta:get_string("owner")) - meta:get_string("costbuy") < 0 then
				minetest.chat_send_player(sender_name, "The buyer is not enough money.")
				return true
			elseif not exist(meta:get_string("owner")) then
				minetest.chat_send_player(sender_name, "The owner's account does not currently exist; try again later.")
				return true
			end
			set_money(sender_name, get_money(sender_name) + meta:get_string("costbuy"))
			set_money(meta:get_string("owner"), get_money(meta:get_string("owner")) - meta:get_string("costbuy"))
			sender_inv:remove_item("main", meta:get_string("nodename") .. " " .. meta:get_string("amount"))
			inv:add_item("main", meta:get_string("nodename") .. " " .. meta:get_string("amount"))
			minetest.chat_send_player(sender_name, "You sold " .. meta:get_string("amount") .. " " .. meta:get_string("nodename") .. " at a price of " .. CURRENCY_PREFIX .. meta:get_string("costbuy") .. CURRENCY_POSTFIX .. ".")
		end
	end,
})

minetest.register_craft({
	output = "money:shop",
	recipe = {
		{"default:wood", "default:wood", "default:wood"},
		{"default:wood", "default:mese", "default:wood"},
		{"default:wood", "default:wood", "default:wood"},
	},
})

--Admin shop.
minetest.register_node("money:admin_shop", {
	description = "Admin Shop",
	tiles = {"admin_shop.png"},
	groups = {snappy=2,choppy=2,oddly_breakable_by_hand=2},
	sounds = default.node_sound_wood_defaults(),
	paramtype2 = "facedir",
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "Untuned Admin Shop")
		meta:set_string("formspec", "size[6,3.75]"..default.gui_bg..default.gui_bg_img..
			"label[-0.025,-0.2;Trade Type]"..
			"dropdown[-0.025,0.25;2.5,1;action;Sell,Buy,Buy and Sell;]"..
			"field[2.7,0.48;3.55,1;amount;Trade lot quantity (1-99);]"..
			"field[0.256,1.65;5.2,1;nodename;Node name to trade (eg. default:mese);]"..
			"item_image[5,1.25;1,1;default:diamond]" ..
			"field[0.256,2.75;3,1;costbuy;Buying price (per lot);]"..
			"field[3.25,2.75;3,1;costsell;Selling price (per lot);]"..
			"button_exit[2,3.25;2,1;button;Proceed]")
		meta:set_string("form", "yes")
	end,
	can_dig = function(pos,player)
		return minetest.get_player_privs(player:get_player_name())["money_admin"]
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		local meta = minetest.get_meta(pos)
		if meta:get_string("form") == "yes" then
			if minetest.registered_items[fields.nodename] and tonumber(fields.amount) and tonumber(fields.amount) >= 1 and tonumber(fields.amount) <= 99 and (meta:get_string("owner") == sender:get_player_name() or minetest.get_player_privs(sender:get_player_name())["money_admin"]) then
				if fields.action == "Sell" then
					if not tonumber(fields.costbuy) then
						return
					end
					if not (tonumber(fields.costbuy) >= 0) then
						return
					end
				end
				if fields.action == "Buy" then
					if not tonumber(fields.costsell) then
						return
					end
					if not (tonumber(fields.costsell) >= 0) then
						return
					end
				end
				if fields.action == "Buy and Sell" then
					if not tonumber(fields.costbuy) then
						return
					end
					if not (tonumber(fields.costbuy) >= 0) then
						return
					end
					if not tonumber(fields.costsell) then
						return
					end
					if not (tonumber(fields.costsell) >= 0) then
						return
					end
				end
				local s, ss
				if fields.action == "Sell" then
					s = " sell "
					ss = "button[1,0.5;2,1;buttonsell;Sell("..fields.costbuy..")]"
				elseif fields.action == "Buy" then
					s = " buy "
					ss = "button[1,0.5;2,1;buttonbuy;Buy("..fields.costsell..")]"
				else
					s = " buy and sell "
					ss = "button[1,0.5;2,1;buttonbuy;Buy("..fields.costsell..")]" .. "button[5,0.5;2,1;buttonsell;Sell("..fields.costbuy..")]"
				end
				local meta = minetest.get_meta(pos)
				meta:set_string("formspec", "size[8,5.5;]"..default.gui_bg..default.gui_bg_img..
					"label[0.256,0;You can"..s..fields.amount.." "..fields.nodename.."]"..
					ss..
					"list[current_player;main;0,1.5;8,4;]")
				meta:set_string("nodename", fields.nodename)
				meta:set_string("amount", fields.amount)
				meta:set_string("costbuy", fields.costsell)
				meta:set_string("costsell", fields.costbuy)
				meta:set_string("infotext", "Admin Shop")
				meta:set_string("form", "no")
			end
		elseif fields["buttonbuy"] then
			local sender_name = sender:get_player_name()
			local sender_inv = sender:get_inventory()
			if not sender_inv:room_for_item("main", meta:get_string("nodename") .. " " .. meta:get_string("amount")) then
				minetest.chat_send_player(sender_name, "In your inventory is not enough space.")
			return true
			elseif get_money(sender_name) - tonumber(meta:get_string("costbuy")) < 0 then
				minetest.chat_send_player(sender_name, "You do not have enough money.")
			return true
			end
			set_money(sender_name, get_money(sender_name) - meta:get_string("costbuy"))
			sender_inv:add_item("main", meta:get_string("nodename") .. " " .. meta:get_string("amount"))
			minetest.chat_send_player(sender_name, "You bought " .. meta:get_string("amount") .. " " .. meta:get_string("nodename") .. " at a price of " .. CURRENCY_PREFIX .. meta:get_string("costbuy") .. CURRENCY_POSTFIX .. ".")
		elseif fields["buttonsell"] then
			local sender_name = sender:get_player_name()
			local sender_inv = sender:get_inventory()
			if not sender_inv:contains_item("main", meta:get_string("nodename") .. " " .. meta:get_string("amount")) then
				minetest.chat_send_player(sender_name, "You don't have enough product.")
				return true
			end
			set_money(sender_name, get_money(sender_name) + meta:get_string("costsell"))
			sender_inv:remove_item("main", meta:get_string("nodename") .. " " .. meta:get_string("amount"))
			minetest.chat_send_player(sender_name, "You sold " .. meta:get_string("amount") .. " " .. meta:get_string("nodename") .. " at a price of " .. CURRENCY_PREFIX .. meta:get_string("costsell") .. CURRENCY_POSTFIX .. ".")
		end
	end,
})
