#ifndef luaImageProc_h_DEFINED
#define luaImageProc_H_DEFINED

extern "C"
{
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}


extern "C"
int luaopen_ImagePreProc(lua_State *L);

#endif
