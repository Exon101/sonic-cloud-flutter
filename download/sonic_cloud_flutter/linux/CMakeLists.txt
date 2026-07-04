cmake_minimum_required(VERSION 3.10)
project(runner LANGUAGES CXX)

define_property(GLOBAL PROPERTY PROPERTY_TARGET_SUPPORTS_SHARED_SONAME
  BRIEF_DOCS "Whether the target platform supports soname."
  FULL_DOCS "Whether the target platform supports soname."
)

set(BINARY_NAME "sonic_cloud")
set(APPLICATION_ID "com.example.sonic_cloud")

cmake_policy(SET CMP0078 NEW)

set(WAYLAND_PROTOCOLS_DIR "${CMAKE_CURRENT_LIST_DIR}/wayland-protocols")
set(WAYLAND_PROTOCOLS_VERSION 1.15)

set(FLUTTER_LIBRARY_DIR "${CMAKE_CURRENT_LIST_DIR}/../flutter/ephemeral")

set(FLUTTER_MANIFEST_DIR "${CMAKE_CURRENT_LIST_DIR}/..")

apply_standard_settings()
add_compile_definitions(FLUTTER_VERSION="1.0.0+1")
add_compile_definitions(FLUTTER_VERSION_MAJOR=1)
add_compile_definitions(FLUTTER_VERSION_MINOR=0)
add_compile_definitions(FLUTTER_VERSION_PATCH=0)
add_compile_definitions(FLUTTER_VERSION_BUILD=1)

add_executable(${BINARY_NAME}
  main.cc
  my_application.cc
  ${FLUTTER_MANIFEST_DIR}/ephemeral/generated_plugin_registrant.cc
)

apply_standard_settings(${BINARY_NAME})
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)
add_dependencies(${BINARY_NAME} flutter_assemble)
target_compile_definitions(${BINARY_NAME} PRIVATE APPLICATION_ID="${APPLICATION_ID}")
