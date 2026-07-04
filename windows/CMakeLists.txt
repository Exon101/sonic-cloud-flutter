cmake_minimum_required(VERSION 3.14)
project(sonic_cloud LANGUAGES CXX)

set(BINARY_NAME "sonic_cloud")
set(APPLICATION_ID "com.example.sonic_cloud")

cmake_policy(SET CMP0078 NEW)
cmake_policy(SET CMP0147 NEW)

set(WINDOWS_PACKAGES_DIR "${CMAKE_CURRENT_LIST_DIR}/../flutter/ephemeral/.package_tmp")
set(FLUTTER_MANIFEST_DIR "${CMAKE_CURRENT_LIST_DIR}/..")

add_compile_definitions(FLUTTER_VERSION="1.0.0+1")
add_compile_definitions(FLUTTER_VERSION_MAJOR=1)
add_compile_definitions(FLUTTER_VERSION_MINOR=0)
add_compile_definitions(FLUTTER_VERSION_PATCH=0)
add_compile_definitions(FLUTTER_VERSION_BUILD=1)

configure_file(${FLUTTER_MANIFEST_DIR}/windows/runner/Runner.rc.in ${CMAKE_CURRENT_BINARY_DIR}/Runner.rc)

add_executable(${BINARY_NAME} WIN32
  "runner/main.cpp"
  "runner/flutter_window.cpp"
  "runner/utils.cpp"
  "runner/win32_window.cpp"
  "${CMAKE_CURRENT_BINARY_DIR}/Runner.rc"
  "runner/Runner.exe.manifest"
)

apply_standard_settings(${BINARY_NAME})
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

add_dependencies(${BINARY_NAME} flutter_assemble)
