# Sporallis

Convert Spore saves --> Stellaris saves.

This utility is made to convert Spore space stage maps into Stellaris
savegames, which can then be continued. While Spore is an amazing game,
Stellaris captures the prospect of a space-faring civilization better. So, why
not have the best of both worlds?

# Requirements and Dependencies

These conversion tools depend on Lua 5.1 (RaptorJIT is **extremely**
recommended) and [LPEG](http://www.inf.puc-rio.br/~roberto/lpeg/) for operation,
as well as [busted](https://olivinelabs.com/busted/) for unit tests. All of the
aforementioned are available through [LuaRocks](https://luarocks.org/).

## Fair Warning

LuaJIT 2.1.0-beta3 has been known to hit its 2 GB memory limit when parsing
late-game largest-size Stellaris maps. This isn't a problem on fresh,
default-sized Stellaris maps, though.
