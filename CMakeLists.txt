cmake_minimum_required(VERSION 3.10)
project(live VERSION 1.0)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED True)

find_package(CURL REQUIRED)

# Specify the include directory for Gumbo
include_directories(/usr/include)

# Find the Gumbo library
find_library(GUMBO_LIB gumbo)
if (NOT GUMBO_LIB)
    message(FATAL_ERROR "Gumbo library not found!")
endif()

# Add the executable target
add_executable(${PROJECT_NAME} src/main.cpp src/custom.cpp)

# Link the libraries to the executable
target_link_libraries(${PROJECT_NAME} PRIVATE CURL::libcurl ${GUMBO_LIB})
