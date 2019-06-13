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
local inspect = require "inspect"
local stelp = {}

--------------------------------------------------------------------------------
-- For parsing Stellaris gamedata files, using LPEG grammars.

local lP, lV, lCg, lCt, lCc = lpeg.P, lpeg.V, lpeg.Cg, lpeg.Ct, lpeg.Cc
local lR, lS, lCs = lpeg.R, lpeg.S, lpeg.Cs
local parse = {}

parse.string = lP'"' * ((lR"\x00\xFF" - "\\" - '"') + '\\"' + "\\")^0 * '"'
parse.number = lS"+-"^-1 * lR"09"^1 * (lP"." * lR"09"^1)^-1
parse.bool = lP"yes" + "no"
parse.newline = (lP(string.char(0x0A)) + lS" \t\n")^1 + lP(-1)
parse.data = lP{"file",
	ws = lS" \t\n"^0,
	name = lCg((lR"az" + lR"AZ" + lR"09" + "_") ^ 1, "name"),
	basic_union = parse.string + parse.number + parse.bool,
	record_inner = lCt((lV"ws" * lCg((lV"assign" + lV"record" + lV"basic_union"))) ^ 0),
	record = lV"ws" * "{" * parse.newline * lV"ws" * lV"record_inner" * lV"ws" * "}",
	value = lV"ws" * lCg(lV"record" + lV"basic_union", "value"),
	assign = lV"ws" * lCt(lV"name" * "=" * lV"value") * parse.newline,
	file = lCt(lCg(lV"assign")^0)
}

--------------------------------------------------------------------------------

local stellaris_file_path = "/home/ocornoc/Downloads/stellars_test_save/gamestate"
local stellaris_file = assert(io.open(stellaris_file_path))
local stellaris_data = assert(stellaris_file:read"*all")
stellaris_file:close()

--[=[
print(inspect(parse.data:match[[
fleet_presence={
		83 84 85 86 87 88 89 90 91 92 93 94 95 96 97 98 99 100 101 102 
	}
]]))]=]

print(inspect(parse.data:match(stellaris_data)))
