cmake_minimum_required (VERSION 3.10)

# projectname is the same as the main-executable
project(%HERE%%FDIR%)

# def
add_definitions('-g')
add_definitions('-Wall')
#add_definitions('-std=c++11')

# compile exe
add_executable(${PROJECT_NAME} ${PROJECT_NAME}.cpp)

# link .so
find_library(log liblog.so)
target_link_libraries(hello log)


# for YCM
SET(CMAKE_EXPORT_COMPILE_COMMANDS ON)

IF( EXISTS "${CMAKE_CURRENT_BINARY_DIR}/compile_commands.json" )
  EXECUTE_PROCESS( COMMAND ${CMAKE_COMMAND} -E create_symlink
    ${CMAKE_CURRENT_BINARY_DIR}/compile_commands.json
    ${CMAKE_CURRENT_SOURCE_DIR}/compile_commands.json
  )
ENDIF()

# for Android NDK: MUST be placed before project()
# $NDK is needed: eg. NDK=/home/yu/.programs/AndroidSdk/ndk-bundle
SET(CMAKE_TOOLCHAIN_FILE $ENV{NDK}/build/cmake/android.toolchain.cmake)
SET(ANDROID_ABI armeabi-v7a)
SET(ANDROID_NATIVE_API_LEVEL 26)
message("ABI ${ANDROID_ABI}")
message("CMAKE_TOOLCHAIN_FILE  is ${CMAKE_TOOLCHAIN_FILE}")
