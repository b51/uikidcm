module(..., package.seeall);

require('Body')
require('walk')
require('util')
require('vector')
require('Config')
require('wcm')
require('gcm')
require('Team')

t0 = 0;
last_score = 0;

do_motion = false;


enable_ceremony = Config.enable_ceremony or 0;
ceremony_score = Config.ceremony_score or 0;


function entry()
  print(_NAME.." entry");
  phase=0;
  Motion.event('standup')

  if gcm.get_game_our_score() > last_score and
     gcm.get_game_our_score() >= gcm.get_game_opponent_score() +
	ceremony_score then
    --Only celebrate when we score and we are leading
    do_motion = true;
    last_score = gcm.get_game_our_score();
  else
    do_motion=false;
  end
end


function update()

  if enable_ceremony == 0 then
    print("done 1");		--b51
    return "done"
  end

  role=gcm.get_team_role();
  t = Body.get_time();
  if not do_motion then
    print("done 2");		--b51
    return "done"
  end

  if walk.active then
    print("walk.stop");		--b51
    walk.stop();
    return;
  else
    if phase==0 then
      phase = 1;
      t0 = Body.get_time();
      if role==0 then --goalie
        walk.startMotion("hurray2");
      elseif role==1 then --attacker
        walk.startMotion("point");
        print("walk.point");		--b51
      elseif role==1 then --attacker
        walk.startMotion("hurray1");
        print("hurray1");		--b51
      end
    elseif t-t0>3.0 then
      print("done 3");		--b51
      return "done";
    end
  end
end

function exit()
end
