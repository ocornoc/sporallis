--[============================================================================[

    parse_stellaris.lua
    Performs a basic lex on Stellaris save files. 
    Copyright (C) 2019 Grayson Burton <ocornoc `AT` protonmail.com>
                   and Ryan Lutes <RyanJamesLutes `AT` gmail.com>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published
    by the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

--]============================================================================]



local lpeg = require "lpeg"

--------------------------------------------------------------------------------
-- For parsing Stellaris gamedata files, using LPEG grammars.

local lP, lV, lCg, lCt, lCc = lpeg.P, lpeg.V, lpeg.Cg, lpeg.Ct, lpeg.Cc
local lR, lS, lCs = lpeg.R, lpeg.S, lpeg.Cs
local parse = {}

-- Parses a string: AKA, any sequence of bytes head'd and tail'd by quotes ("),
-- that does allow of '\"' escaping in the string.
parse.string = lP'"' * ((lR"\x00\xFF" - "\\" - '"') + '\\"' + "\\")^0 * '"'
-- A number, defined as (in sequence):
--   An optional plus or minus
--   A sequence of digits
--   Optionally:
--     A period/decimal point
--     A sequence of digits
parse.number = lS"+-"^-1 * lR"09"^1 * (lP"." * lR"09"^1)^-1
-- Stellaris's equivalent to booleans. Either "yes" or "no", case-sensitive.
parse.bool = lP"yes" + "no"
-- Stellaris uses 0x0A line feeds even on Windows, so we make sure to allow that
-- in the set in case "\n" escapes to something weird.
-- A "newline" is defined as a sequence of at least one line feed, space, tab,
-- or escaped newline. It also can be the end of the input string.
parse.newline = (lP(string.char(10)) + lS" \t\n")^1 + lP(-1)
-- This parses the file.
parse.data = lP{"file",
-- "ws" is defined as a sequence of 0 or more spaces, tabs, or escaped newlines.
	ws = lS" \t\n"^0,
-- "namechars" is defined as a sequence of at least one letter, number, or
-- underscore.
	namechars = (lR"az" + lR"AZ" + lR"09" + "_") ^ 1,
-- "name" is defined as a string, or a "namechars" optionally followed by a
-- period and one or more digits.
	name = lCg(lV"namechars" * ("." * lR"09"^1)^-1 + parse.string, "name"),
	
-- "star" is defined simply as the text "star".
	star = lP"star",
	
	station_mod = lP"shipyard" + "hangar_bay" + "gun_battery" +
		"anchorage" + "trading_hub" + "solar_panel_network" +
		"missile_battery",
	station_bld = lP"crew_quarters" + "command_center" +
		"target_uplink_computer" + "listening_post" + "defense_grid" +
		"titan_yards" + "fleet_academy" + "resource_silo" +
		"warp_fluctuator" + "naval_logistics_office" +
		"hydroponics_bay" + "disruption_field" +
		"communications_jammer" + "nebula_refinery",
	station_upgrade = lP"single_ship_upgrade" + "starbase_upgrade" +
		"starbase_building",
	station_build = lP"ship" + "building" + "army" + "upgrade" + "district",
-- Represents the different keywords used for stations/starbases, including in
-- build queue and their modules and buildings.
	station = lV"station_mod" + lV"station_bld" + lV"station_upgrade" +
		lV"station_build",
	
	orbital_policy = "orbital_bombardment_" * (lP"indiscriminate" +
		"armageddon" + "selective"),
	border_policy = "border_policy_" * (lP"open" + "closed"),
	robot_policy = "robots_" * (lP"allowed" + "outlawed"),
-- Represents policies that have "_allowed" and "_not_allowed" suffixes.
	all_nall_policies = (lP"resettlement" + "first_contact_attack" +
		"refugees" + "population_controls" + "enlightenment" +
		"slavery" + "purge" + "appropriation" + "robots") *
		(lP"_allowed" + "_not_allowed"),
	war_policy = (lP"unrestricted" + "defensive" + "liberation" + "no") *
		"_wars",
	interference_policy = "interference_" * (lP"full" + "active" +
		"passive"),
	leader_enhancement = "leader_enhancement_" * (lP"selected_lineages" +
		"capacity_boosters"),
	presap_policy = "pre_sapients_" * (lP"purge" + "allow" + "protect"),
	ai_policy = "ai_" * (lP"servitude" + "outlawed"),
	special_policies = lP"trade_conversion_unity" +
		"purge_displacement_only" + "refugees_only_citizens",
-- Lexes keywords for different policies.
	policy = lV"orbital_policy" + lV"border_policy" +
		lV"all_nall_policies" + lV"war_policy" + lV"robot_policy" +
		lV"interference_policy" + lV"leader_enhancement" +
		lV"presap_policy" + lV"ai_policy" + lV"special_policies",
	
	aggro = lP"self",
	
-- Lexes event scopes.
	event_type = lP"country" + "leader" + "none" + "fleet" +
		"galactic_object" + "ambient_object" + "species" + "empire",
	event_status = lP"completed" + "in_progress",
	event = lV"event_type" + lV"event_status",
	
	citizenship = "citizenship_" * (lP"limited" + "full_machine" + "full" +
		"purge" + "slavery" + "robot_servitude" + "assimilation"),
	y_n_conrights = (lP"colonization" + "migration" + "population") *
		"_control_" * parse.bool,
	milservice = "military_service_" * (lP"full" + "limited" + "none"),
	purge_rights = "purge_" * (lP"displacement_only" + "normal" +
		"labor_camps" + "displacement" + "neutering"),
	slavery_rights = "slavery_" * (lP"normal" + "domestic" + "matrix" +
		"military" + "livestock"),
-- Lexes the rights of species.
	rights = lV"citizenship" + lV"y_n_conrights" + lV"milservice" +
		lV"purge_rights" + lV"slavery_rights",
	
-- Lexes species' living standards.
	living_standard = lP"living_standard_" * (lP"stratified" + "normal" +
		"servitude" + "subsistence" + "none" + "good" + "utopian" +
		"academic_privilege" + "psi_assimilation" + "hive_mind"),
	
	bypass = lP"gateway" + lP"wormhole",
-- Parses relics. !!NOT COMPLETE!!. Would be great if someone could find a full
-- list of keywords for relics. These are all that I found.
	relics = "r_" * (lP"cryo_core" + "ancient_sword" + "omnicodex"),
	last_changed_value = lP"citizenship" + "living_standard" + "slavery",
	contact_rule = lP"script_only",
-- All of the attributes of a country.
	country = lV"policy" + lV"aggro" + lV"event" + lV"rights" +
		lV"living_standard" + lV"relics" + lV"last_changed_value" +
		lV"contact_rule" + lV"bypass",
	
	gender = lP"male" + "female" + "indeterminable",
	leader_location = lP"planet" + "sector" + "tech" + "ship",
	leader_area = lP"physics" + "society" + "engineering" + "none",
-- All of the attributes of a leader.
	leader = lV"gender" + lV"leader_location" + lV"leader_area",
	
	formation = lP"circle" + "wedge",
	jump_method = lP"jump_count" + "jump_bypass",
	stance = lP"evasive" + "aggressive",
	auto_movement = lP"auto_move_planet",
	path = lP"jump_hyperlane",
	state = "move_" * (lP"idle" + "system" + "to_origin" + "galaxy" +
		"wind_up") + "upgrade_" * (lP"upgrading" + "done" + "waiting" +
		"none"),
	mia_type = lP"mia_return_home",
	shipclass = "shipclass_" * (lP"starbase" + "military_station" +
		"military" + "transport" + "mining_station" +
		"research_station"),
	actions_method = lP"random" + "closest",
	actions_target = lP"event_target:" * lCt(lCg(lV"name", "target")) +
		"this",
	actions = lV"actions_method" + lV"actions_target",
-- Parses fleets, ships, formations, MIAs, etc.
	fleet = lV"formation" + lV"jump_method" + lV"stance" +
		lV"auto_movement" + lV"state" + lV"actions" + lV"path" +
		lV"shipclass" + lV"mia_type",
	
-- !!HELP!! Could someone check to make sure these are all correct? All but the
-- "ensign" difficulty are guessed.
	galaxy_difficulty = lP"cadet" + "ensign" + "captain" + "commodore" +
		"admiral" + "grand_admiral",
	galaxy_shape = lP"elliptical" + "spiral" + "ring",
	galaxy_aggro = lP"normal",
	galaxy_location = lP"normal",
	galaxy = lV"galaxy_difficulty" + lV"galaxy_shape" + lV"galaxy_aggro" +
		lV"galaxy_location",
	
	truce = lP"alliance" + "war",
	
	call_type = lP"primary" + "alliance" + "defensive" + "offensive" +
		"overlord",
	battle_type = lP"armies" + "ships",
	war = lV"call_type" + lV"battle_type",
	
	message_type = lP"accept",
	message = lV"message_type",

	trade_type = lP"internal",
	trade = lV"trade_type",
	
	arch_type = lP"archaeological_site",
	arch = lV"arch_type",
	
	market_type = "market_" * (lP"sell" + "buy"),
	market = lV"market_type",
	
-- Parses all special keywords.
	specials = lV"fleet" + lV"war" + lV"station" + lV"truce" + lV"star" +
		lV"country" + lV"leader" + lV"galaxy" + lV"message" +
		lV"trade" + lV"arch" + lV"market",
	
	basic_union = lV"specials" + parse.string + parse.number + parse.bool,
	
	record_inner = lCt((lV"ws" *
		lCg((lV"assign" + lV"record" + lV"basic_union"))) ^ 0),
	record = lV"ws" * "{" * parse.newline * lV"ws" * lV"record_inner" *
		lV"ws" * "}",
	
	value = lV"ws" * lCg(lV"record" + lV"basic_union", "value"),
	assign = lV"ws" * lCt((lV"name" * lP"\n"^-1 * "=")^-1 * lV"value") *
		parse.newline,
	file = lCt(lCg(lV"assign")^0) * lP(-1)
}

--------------------------------------------------------------------------------

return function(text)
	assert(type(text) == "string", "Stellaris map data not given.")
	
	return parse.data:match(text)
end
