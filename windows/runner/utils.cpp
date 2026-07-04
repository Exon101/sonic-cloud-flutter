#include "utils.h"

#include <flutter_windows.h>
#include <io.h>
#include <stdio.h>
#include <windows.h>

#include <iostream>

std::vector<std::string> GetCommandLineArguments() {
  int argc;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return std::vector<std::string>();
  }
  std::vector<std::string> command_line_arguments;
  for (int i = 1; i < argc; i++) {
    int length = WideCharToMultiByte(CP_UTF8, 0, argv[i], -1, nullptr, 0, nullptr, nullptr);
    std::string s;
    s.reserve(length);
    WideCharToMultiByte(CP_UTF8, 0, argv[i], -1, s.data(), length, nullptr, nullptr);
    command_line_arguments.push_back(s);
  }
  ::LocalFree(argv);
  return command_line_arguments;
}
