cmake_minimum_required(VERSION 3.22)
set (CMAKE_CXX_COMPILER /usr/bin/g++)
set (CMAKE_CXX_STANDARD 20)

# RayRay is a C/C++ project
project(Ether
        VERSION 1.0
        LANGUAGES CXX
        )


set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Werror")
set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall")
set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wextra")
set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -pedantic")
set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wconversion")
set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wdouble-promotion")
set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wimplicit-fallthrough")
set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wmisleading-indentation")
set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wnull-dereference")
set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wshadow")
set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wsign-conversion")
set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wunreachable-code")
set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wunused")
set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -g")


# Include the source and test files
add_subdirectory(src)