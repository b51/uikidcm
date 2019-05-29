/*************************************************************************
*
*              Author: b51
*                Mail: b51live@gmail.com
*            FileName: luaDLDetection.h
*
*          Created On: Wed 29 May 2019 11:01:18 PM CST
*     Licensed under The MIT License [see LICENSE for details]
*
************************************************************************/

#ifndef luaDLDetection_h_DEFINED
#define luaDLDetection_H_DEFINED

extern "C"
{
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}


extern "C"
int luaopen_DLDetection(lua_State *L);

#endif
