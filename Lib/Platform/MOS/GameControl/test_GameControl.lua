package.cpath = "./build/?.so;" .. package.cpath
local unix = require('unix')
local receiver = require('GameControlReceiver')

teamNumber = 6;
playerID = 1;
teamIndex = 0;
nPlayers = 2;
--teamColor = -1;
teamColor = 0;

gamePacket = nil;
gameState = 0;
timeRemaining = 0;
lastUpdate = 0;

buttonPressed = 0;

kickoff = -1;
half = 1;

teamPenalty = {};

penalty = {};

our_score = 0;
opponent_score = 0;

for t = 1,2 do
  penalty[t] = {};
  for p = 1,nPlayers do
    penalty[t][p] = 0;
  end
end
-- use if no game packets received
buttonPenalty = {};
for p = 1,nPlayers do
  buttonPenalty[p] = 0;
end

function get_team_color()
  return teamColor;
end

function get_state()
  return gameState;
end

function get_kickoff_team()
  return kickoff;
end

function which_half()
  return half;
end

function get_penalty()
  return teamPenalty;
end

function set_team_color(color)
  if teamColor ~= color then
    teamColor = color;
    if (teamColor == 1) then
      --print('I am on the red team');
    else
      --print('I am on the blue team');
    end
  end
end

function set_kickoff(k)
  if (kickoff ~= k) then
    kickoff = k;
    if (kickoff == 1) then
      --print('We have kickoff');
    else
      --print('Opponents have kickoff');
    end
  end
end

function receive()
  return receiver.receive();
end

function entry()
end

count = 0;
updateCount = 1;
function update()
  -- get latest game control packet
  gamePacket = receive();
  count = count + 1;

    teamIndex = 0;
    OtherTeamIndex = 0;

  if (gamePacket) then
    --print("Game State: "..gamePacket.state)
    for i = 1,2 do
      if gamePacket.teams[i].teamNumber == teamNumber then
        teamIndex = i;
      else
        OtherTeamIndex = i;
      end
    end

    if OtherTeamIndex ~=0 then
      opponent_score = gamePacket.teams[OtherTeamIndex].score;
    end

    if teamIndex ~= 0 then
      updateCount = count;

      -- upadate game state
      gameState = gamePacket.state;

--[[
      -- update team color
      set_team_color(gamePacket.teams[teamIndex].teamColour);
--]]

      -- update goal color
      --set_team_color(gamePacket.teams[teamIndex].goalColour);
      our_score = gamePacket.teams[teamIndex].score;

      -- update kickoff team
      -- Dropball Handling
      if (gamePacket.kickOffTeam == teamNumber) then
        --Kickoff, robot inside center circle, cannot score directly
        set_kickoff(1);
        print("we are kick off team")
      else
        --Waiting, robot outside center circle, cannot move for 10sec
        print("others are kick off team")
      end

      -- update which half it is
      if gamePacket.firstHalf == 1 then
        half = 1;
      else
        half = 2;
      end

      -- update game time remaining
      timeRemaining = gamePacket.secsRemaining;

      -- update player penalty info
      for p=1,nPlayers do
        teamPenalty[p] = gamePacket.teams[teamIndex].player[p].penalty;
      end
    end
  end

end

function exit()
end

while 1 do
  update();
  os.usleep(10000);
end
