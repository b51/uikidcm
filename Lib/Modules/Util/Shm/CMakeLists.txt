cmake_minimum_required(VERSION 3.2)
project(Shm)

add_definitions(-std=c++11)

# set optimization level (shm cannot be higher than 1)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O1")

find_package(Boost REQUIRED)

include_directories(
  ${Boost_INCLUDE_DIRS}
)

string(TOLOWER ${PROJECT_NAME} LIBRARY_NAME)

# shm main library definition
add_library(${LIBRARY_NAME} SHARED
  luashm.cc
)

# set library prefix to "" otherwise it will create libshm.so
set_target_properties(${LIBRARY_NAME} PROPERTIES PREFIX "")

# link to rt for shared memory ipc
target_link_libraries(${LIBRARY_NAME}
  rt
)

install(TARGETS ${LIBRARY_NAME}
  LIBRARY DESTINATION ${CMAKE_INSTALL_PREFIX}
)
