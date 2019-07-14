cmake_minimum_required(VERSION 3.2)

add_subdirectory(DspCode)
add_subdirectory(Dynamixel)

install(FILES dcm.lua MOSCommManager.lua MOSBody.lua
  DESTINATION ${CMAKE_INSTALL_PREFIX}
)
