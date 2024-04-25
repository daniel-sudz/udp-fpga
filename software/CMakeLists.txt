cmake_minimum_required(VERSION 3.22)
set (CMAKE_CXX_COMPILER /usr/bin/g++)
set (CMAKE_CXX_STANDARD 20)

# RayRay is a C/C++ project
project(Ether
        VERSION 1.0
        LANGUAGES CXX
        )


set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -g")


# Include the source and test files
add_subdirectory(src)