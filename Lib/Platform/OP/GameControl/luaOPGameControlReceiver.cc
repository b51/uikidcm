#include "timeScalar.h"
#include "string.h"
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

// Needed typedefs:
typedef unsigned char uint8;
typedef unsigned short uint16;
typedef unsigned int uint32;

#include "RoboCupGameControlData.h"

#ifdef __cplusplus
extern "C"
{
#endif
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#ifdef __cplusplus
}
#endif

#define PORT 3838

static int sock_fd = 0;
static struct RoboCupGameControlData gameControlData;
static int nGameControlData = 0;
static double recvTime = 0;
static bool logOut = false;

#define LOG_WHEN_MSG_RECV(fmt, ...)\
        do { ; } while(0)
        //do { if (logOut) printf(fmt, ##__VA_ARGS__); } while(0)

/*
void mexExit(void)
{
  if (sock_fd > 0)
    close(sock_fd);
}
*/


static int lua_gamecontrolpacket_parse(lua_State *L, RoboCupGameControlData *data) {
  if (data == NULL) {
    return 0;
  }

  if (strncmp(data->header, GAMECONTROLLER_STRUCT_HEADER, 4) != 0) {
    return 0;
  }

  lua_createtable(L, 0, 16);

  lua_pushstring(L, "time");
  lua_pushnumber(L, recvTime);
  lua_settable(L, -3);

  // version field
  lua_pushstring(L, "version");
  lua_pushnumber(L, data->version);
  LOG_WHEN_MSG_RECV("data->version: %d\n", data->version);
  lua_settable(L, -3);

  // uint8_t packetNumber, number incremented with each packet sent (with wraparound)
  lua_pushstring(L, "packetNumber");
  lua_pushnumber(L, data->packetNumber);
  LOG_WHEN_MSG_RECV("data->packetNumber: %d\n", data->packetNumber);
  lua_settable(L, -3);

  // uint8_t playersPerTeam, the number of players on a team
  lua_pushstring(L, "playersPerTeam");
  lua_pushnumber(L, data->playersPerTeam);
  LOG_WHEN_MSG_RECV("data->playersPerTeam: %d\n", data->playersPerTeam);
  lua_settable(L, -3);

  // uint8_t competitionPhase, phase of the competition (COMPETITION_PHASE_ROUNDROBIN, COMPETITION_PHASE_PLAYOFF)
  lua_pushstring(L, "competitionPhase");
  lua_pushnumber(L, data->competitionPhase);
  LOG_WHEN_MSG_RECV("data->competitionPhase: %d\n", data->competitionPhase);
  lua_settable(L, -3);

  // uint8_t competitionType, type of the competition (COMPETITION_TYPE_NORMAL, COMPETITION_TYPE_MIXEDTEAM, COMPETITION_TYPE_GENERAL_PENALTY_KICK)
  lua_pushstring(L, "competitionType");
  lua_pushnumber(L, data->competitionType);
  LOG_WHEN_MSG_RECV("data->competitionType: %d\n", data->competitionType);
  lua_settable(L, -3);

  // uint8_t gamePhase, phase of the game (GAME_PHASE_NORMAL, GAME_PHASE_PENALTYSHOOT, etc)
  lua_pushstring(L, "gamePhase");
  lua_pushnumber(L, data->gamePhase);
  LOG_WHEN_MSG_RECV("data->gamePhase: %d\n", data->gamePhase);
  lua_settable(L, -3);

  // uint8_t state, state of the game (STATE_READY, STATE_PLAYING, etc)
  lua_pushstring(L, "state");
  lua_pushnumber(L, data->state);
  LOG_WHEN_MSG_RECV("data->state: %d\n", data->state);
  lua_settable(L, -3);

  // uint8_t setPlay, active set play (SET_PLAY_NONE, SET_PLAY_GOAL_FREE_KICK, etc)
  lua_pushstring(L, "setPlay");
  lua_pushnumber(L, data->setPlay);
  LOG_WHEN_MSG_RECV("data->setPlay: %d\n", data->setPlay);
  lua_settable(L, -3);

  // uint8_t firstHalf, 1 = game in first half, 0 otherwise
  lua_pushstring(L, "firstHalf");
  lua_pushnumber(L, data->firstHalf);
  LOG_WHEN_MSG_RECV("data->firstHalf: %d\n", data->firstHalf);
  lua_settable(L, -3);

  // uint8_t kickingTeam, the team number of the next team to kick off, free kick, DROPBALL etc.
  lua_pushstring(L, "kickingTeam");
  lua_pushnumber(L, data->kickingTeam);
  LOG_WHEN_MSG_RECV("data->kickingTeam: %d\n", data->kickingTeam);
  lua_settable(L, -3);

  // uint8_t dropInTeam, number of team that caused last drop in
  lua_pushstring(L, "dropInTeam");
  lua_pushnumber(L, data->dropInTeam);
  LOG_WHEN_MSG_RECV("data->dropInTeam: %d\n", data->dropInTeam);
  lua_settable(L, -3);

  // uint16_t dropInTime, number of seconds passed since the last drop in. -1 (0xffff) before first dropin
  lua_pushstring(L, "dropInTime");
  lua_pushnumber(L, data->dropInTime);
  LOG_WHEN_MSG_RECV("data->dropInTime: %d\n", data->dropInTime);
  lua_settable(L, -3);

  // uint16_t secsRemaining, estimate of number of seconds remaining in the half
  lua_pushstring(L, "secsRemaining");
  lua_pushnumber(L, data->secsRemaining);
  LOG_WHEN_MSG_RECV("data->secsRemaining: %d\n", data->secsRemaining);
  lua_settable(L, -3);

  // uint16_t secondaryTime, number of seconds shown as secondary time (remaining ready, until free ball, etc)
  lua_pushstring(L, "secondaryTime");
  lua_pushnumber(L, data->secondaryTime);
  LOG_WHEN_MSG_RECV("data->secondaryTime: %d\n", data->secondaryTime);
  lua_settable(L, -3);

  lua_pushstring(L, "teams");
  lua_createtable(L, 2, 0);

  for (int iteam = 0; iteam < 2; iteam++) {
    lua_createtable(L, 0, 6);

    lua_pushstring(L, "teamNumber");
    lua_pushnumber(L, data->teams[iteam].teamNumber);
    LOG_WHEN_MSG_RECV("data->teams[%d].teamNumber: %d\n", iteam, data->teams[iteam].teamNumber);
    lua_settable(L, -3);

    lua_pushstring(L, "teamColour");
    lua_pushnumber(L, data->teams[iteam].teamColour);
    LOG_WHEN_MSG_RECV("data->teams[%d].teamColour: %d\n", iteam, data->teams[iteam].teamColour);
    lua_settable(L, -3);

    // OP has a different goal color than its team color sometimes...
    //lua_pushstring(L, "goalColour");
    //lua_pushnumber(L, data->teams[iteam].goalColour);
    //lua_settable(L, -3);

    lua_pushstring(L, "score");
    lua_pushnumber(L, data->teams[iteam].score);
    LOG_WHEN_MSG_RECV("data->teams[%d].score: %d\n", iteam, data->teams[iteam].score);
    lua_settable(L, -3);

    lua_pushstring(L, "penaltyShot");
    lua_pushnumber(L, data->teams[iteam].penaltyShot);
    LOG_WHEN_MSG_RECV("data->teams[%d].penaltyShot: %d\n", iteam, data->teams[iteam].penaltyShot);
    lua_settable(L, -3);

    lua_pushstring(L, "singleShots");
    lua_pushnumber(L, data->teams[iteam].singleShots);
    LOG_WHEN_MSG_RECV("data->teams[%d].singleShots: %d\n", iteam, data->teams[iteam].singleShots);
    lua_settable(L, -3);

    lua_pushstring(L, "player");
    lua_createtable(L, MAX_NUM_PLAYERS, 0);
    // TODO: Populate robot info tables
    for (int iplayer = 0; iplayer < MAX_NUM_PLAYERS; iplayer++) {
      lua_createtable(L, 0, 2);

      lua_pushstring(L, "penalty");
      lua_pushnumber(L, data->teams[iteam].players[iplayer].penalty);
      LOG_WHEN_MSG_RECV("data->teams[%d].players[%d].penalty: %d\n", iteam, iplayer, data->teams[iteam].players[iplayer].penalty);
      lua_settable(L, -3);

      lua_pushstring(L, "secsRemaining");
      lua_pushnumber(L, data->teams[iteam].players[iplayer].secsTillUnpenalised);
      LOG_WHEN_MSG_RECV("data->teams[%d].players[%d].secsTillUnpenalised: %d\n", iteam, iplayer, data->teams[iteam].players[iplayer].secsTillUnpenalised);
      lua_settable(L, -3);

      lua_rawseti(L, -2, iplayer+1);
    }
    lua_settable(L, -3);

    lua_rawseti(L, -2, iteam+1);
  }

  lua_settable(L, -3);
  logOut = false;
  return 1;
}

static int lua_gamecontrolpacket_receive(lua_State *L) {
  const int MAX_LENGTH = 4096;
  static char data[MAX_LENGTH];
  static bool init = false;

  // TODO: figure out lua error throw method
  if (!init) {
    sock_fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock_fd < 0) {
      LOG_WHEN_MSG_RECV("Could not open datagram socket\n");
      return -1;
    }

    struct sockaddr_in local_addr;
    bzero((char *) &local_addr, sizeof(local_addr));
    local_addr.sin_family = AF_INET;
    local_addr.sin_addr.s_addr = htonl(INADDR_ANY);
    local_addr.sin_port = htons(PORT);
    if (bind(sock_fd, (struct sockaddr *) &local_addr, sizeof(local_addr)) < 0) {
      LOG_WHEN_MSG_RECV("Could not bind to port\n");
      return -1;
    }

    // Nonblocking receive:
    int flags  = fcntl(sock_fd, F_GETFL, 0);
    if (flags == -1)
      flags = 0;
    if (fcntl(sock_fd, F_SETFL, flags | O_NONBLOCK) < 0) {
      LOG_WHEN_MSG_RECV("Could not set nonblocking mode\n");
      return -1;
    }

    // TODO: set lua on close? is it possible
    init = true;
  }


  // Process incoming game controller messages:
  static sockaddr_in source_addr;
  socklen_t source_addr_len = sizeof(source_addr);
  int len = recvfrom(sock_fd, data, MAX_LENGTH, 0, (struct sockaddr *) &source_addr, &source_addr_len);

  while (len > 0) {
    LOG_WHEN_MSG_RECV("Packet: %d bytes\n", len);

    // Verify game controller header:
    if (memcmp(data, GAMECONTROLLER_STRUCT_HEADER, sizeof(GAMECONTROLLER_STRUCT_HEADER) - 1) == 0) {
      memcpy(&gameControlData, data, sizeof(RoboCupGameControlData));
      nGameControlData++;
      logOut = true;
      LOG_WHEN_MSG_RECV("Game control: %d received.\n", nGameControlData);
    }
    len = recvfrom(sock_fd, data, MAX_LENGTH, 0, (struct sockaddr *) &source_addr, &source_addr_len);

		recvTime = time_scalar();
  }

  if (nGameControlData == 0) {
    // no messages received yet
    lua_pushnil(L);
  } else {
    return lua_gamecontrolpacket_parse(L, &gameControlData);
  }

  return 1;
}

static const struct luaL_reg OPGameControlReceiver_lib [] = {
  {"receive", lua_gamecontrolpacket_receive},
  //{"parse", lua_gamecontrolpacket_parse},
  {NULL, NULL}
};

#ifdef __cplusplus
extern "C"
#endif
int luaopen_OPGameControlReceiver (lua_State *L) {
  luaL_register(L, "OPGameControlReceiver", OPGameControlReceiver_lib);

  return 1;
}
