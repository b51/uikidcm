package.cpath = './build/?.so;' .. package.cpath;
-- For unix test
local unix = require('unix');

cwd = unix.getcwd();
username = unix.getusername();
print(username);
print(unix.gethostname());
print(cwd);
print(unix.time());

unix.usleep(500 * 1e3);

unix.chdir("/home/"..username);
print(unix.getcwd());

unix.sleep(1);

unix.chdir(cwd);
dir = unix.readdir(unix.getcwd());
for k, v in pairs(dir) do
  print(k, v);
end

-- new a file named test
unix.system("touch test");
dir = unix.readdir(cwd);
for k, v in pairs(dir) do
  print(k, v);
end

-- remove test file
unix.system("rm test");
dir = unix.readdir(cwd);
for k, v in pairs(dir) do
  print(k, v);
end

-- For getch test
local getch = require('getch');
getch.enableblock(1);

while 1 do
  local str = getch.get();
  if #str > 0 then
    local byte = string.byte(str, 1);
    print(byte);
  end
end
