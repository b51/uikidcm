cmake_minimum_required(VERSION 3.2)
project(Launcher)

add_definitions(-std=c++11)

# set optimization level
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O2")

# luancher main library definition
add_library(launcher SHARED
  lualauncher.cc
)

# set library prefix to "" otherwise it will create liblauncher.so
set_target_properties(launcher PROPERTIES PREFIX "")

# link to libusb
target_link_libraries(launcher usb)
