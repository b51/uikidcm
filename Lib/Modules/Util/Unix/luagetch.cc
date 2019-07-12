/*
  Lua module to provide nonblocking keyboard input
*/

#include <lua.hpp>

#include <unistd.h>
#include <fcntl.h>
#include <termios.h>

static int lua_getch(lua_State* L) {
  char str[2];
  fcntl(0, F_SETFL, O_NONBLOCK);
  fcntl(0, F_GETFL, O_NONBLOCK);
  str[0] = 0;
  str[1] = 0;
  size_t n = read(0, &str, 1);
  lua_pushstring(L, str);
  return n;
}

static int lua_nonblock(lua_State *L){
 int i=luaL_checkinteger(L,1);
 struct termios ttystate;
 tcgetattr(0,&ttystate);
 if (i==1) {
	ttystate.c_lflag &=~ICANON;
	ttystate.c_cc[VMIN]=1;
 }else{
	ttystate.c_lflag|=ICANON;
 }
 tcsetattr(0,TCSANOW,&ttystate);
 return 1;
}

static const struct luaL_Reg getch_lib [] = {
  {"get", lua_getch},
  {"enableblock", lua_nonblock},
  {NULL, NULL}
};

extern "C"
int luaopen_getch (lua_State *L) {
  luaL_newlib(L, getch_lib);
  return 1;
}
