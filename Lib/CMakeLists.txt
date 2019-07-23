cmake_minimum_required(VERSION 3.2)
project(uikidcm)

add_definitions(-std=c++11)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra -pedantic")

set(UIKIDCM_LIB_DIR ${CMAKE_CURRENT_SOURCE_DIR})
set(UIKIDCM_PLAYER_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../Player)

if (NOT ${CMAKE_INSTALL_PREFIX})
  set(CMAKE_INSTALL_PREFIX "${UIKIDCM_PLAYER_DIR}/Lib")
  message(STATUS "Default install libs to ${CMAKE_INSTALL_PREFIX}")
endif()

set(MOS_COMPONENTS
  Modules/Comm
  Modules/DLDetection
  Modules/ImagePreProc
  Modules/Util
  Platform/MOS
)

foreach(subdir ${MOS_COMPONENTS})
  add_subdirectory(${subdir})
endforeach(subdir)
