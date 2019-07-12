cmake_minimum_required(VERSION 3.2)
project(uikidcm)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra -pedantic")

##############################################################
# Find required libraries
#find_package(Eigen3 REQUIRED)
#find_package(OpenCV REQUIRED)
#find_package(GLog REQUIRED)
#
#include_directories(
#  ${EIGEN3_INCLUDE_DIR}
#  ${OpenCV_INCLUDE_DIRS}
#  ${GLog_INCLUDE_DIRS}
#)
##############################################################

add_subdirectory(Modules)
add_subdirectory(Platform/MOS)
