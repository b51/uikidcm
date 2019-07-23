### TODO lists
* [X] Update Makefile to CMakelists
* [ ] Update lua version
    + [X] update C API
    + [X] update Config
    + [X] update run_dcm.lua
        - [X] update Util
    + [X] update run_main.lua
        - [X] update Motion FSM
        - [X] update BodyFSM
        - [X] update HeadFSM
        - [X] update GameFSM
    + [X] update run_cognition.lua
        - [X] update Vision
        - [X] update World
    + [ ] Test all upgraded modules on robot
* [ ] Update variables with rules
* [ ] Update team communication
* [ ] Update localization
* [ ] May should make some modules as global variables, such as Config

### Variable Name Rules
local variables in a lua module(file) will named with _ after it
```lua
eg.
  local variable_ = 0;
```
local variables in a function should name normally unless it encount
a function with parameter, then it should named with _ before it
```lua
eg. parameter c may be nil if only pass two parameters

  local f = function(a, b, c)
    local _c = c or 0;
    ...
  end
```
