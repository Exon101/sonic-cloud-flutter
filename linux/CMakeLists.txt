cmake_minimum_required(VERSION 3.10)
project(runner LANGUAGES CXX)

# Define apply_standard_settings as a macro — this is normally generated
# by `flutter create` but we define it here since our CMakeLists.txt is
# hand-written.
macro(apply_standard_settings target_name)
  if(target_name STREQUAL "")
    # Global settings
    set(CMAKE_CXX_STANDARD 17)
    set(CMAKE_CXX_STANDARD_REQUIRED ON)
    set(CMAKE_CXX_EXTENSIONS OFF)
  else()
    # Per-target settings
    set_target_properties(${target_name} PROPERTIES
      CXX_STANDARD 17
      CXX_STANDARD_REQUIRED ON
      CXX_VISIBILITY_PRESET hidden
      VISIBILITY_INLINES_HIDDEN YES
    )
    if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
      target_compile_options(${target_name} PRIVATE -Wall -Wno-conversion)
    endif()
  endif()
endmacro()

# Apply global standard settings
apply_standard_settings("")

set(BINARY_NAME "sonic_cloud")
set(APPLICATION_ID "com.example.sonic_cloud")

cmake_policy(SET CMP0078 NEW)

set(FLUTTER_MANIFEST_DIR "${CMAKE_CURRENT_LIST_DIR}/..")

add_compile_definitions(FLUTTER_VERSION="3.1.0+4")
add_compile_definitions(FLUTTER_VERSION_MAJOR=3)
add_compile_definitions(FLUTTER_VERSION_MINOR=1)
add_compile_definitions(FLUTTER_VERSION_PATCH=0)
add_compile_definitions(FLUTTER_VERSION_BUILD=4)

# The generated_plugin_registrant.cc is created by `flutter pub get` in
# build/linux/ephemeral/. If it doesn't exist yet, create an empty stub
# so CMake configure doesn't fail. The real file will be present after
# `flutter pub get` runs in CI.
set(GENERATED_PLUGIN_REGISTRANT
  "${CMAKE_CURRENT_BINARY_DIR}/generated_plugin_registrant.cc")
if(NOT EXISTS "${GENERATED_PLUGIN_REGISTRANT}")
  file(WRITE "${GENERATED_PLUGIN_REGISTRANT}"
    "// Auto-generated stub. Real file is created by flutter pub get.\n"
    "#include <flutter/plugin_registry.h>\n"
    "void RegisterPlugins(flutter::PluginRegistry* registry) {}\n")
endif()

add_executable(${BINARY_NAME}
  main.cc
  my_application.cc
  "${GENERATED_PLUGIN_REGISTRANT}"
)

apply_standard_settings(${BINARY_NAME})

# Link against Flutter engine and GTK
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED gtk+-3.0)

target_link_libraries(${BINARY_NAME} PRIVATE ${GTK_LIBRARIES})
target_include_directories(${BINARY_NAME} PRIVATE ${GTK_INCLUDE_DIRS})

target_compile_definitions(${BINARY_NAME} PRIVATE APPLICATION_ID="${APPLICATION_ID}")
