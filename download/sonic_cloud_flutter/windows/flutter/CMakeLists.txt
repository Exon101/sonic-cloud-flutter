cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "sonic_cloud")
project(${PROJECT_NAME} LANGUAGES CXX)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/intermediates_do_not_run")

set(EPHEMERAL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../flutter/ephemeral")

if(NOT EXISTS "${EPHEMERAL_DIR}/generated_plugin_registrant.cc")
  message(WARNING "Flutter ephemeral files not found. Run `flutter pub get` first.")
endif()

add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/flutter" "${CMAKE_CURRENT_BINARY_DIR}/flutter")
add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/runner" "${CMAKE_CURRENT_BINARY_DIR}/runner")
