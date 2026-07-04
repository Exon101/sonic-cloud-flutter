#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>

#include "resource.h"

namespace {

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

constexpr const wchar_t kWindowName[] = L"Sonic Cloud";

constexpr DWORD kWindowStyle = WS_OVERLAPPEDWINDOW & ~WS_MAXIMIZEBOX;

constexpr DWORD kWindowExStyle = WS_EX_APPWINDOW;

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

LRESULT CALLBACK WndProc(HWND hwnd, UINT message, WPARAM wparam,
                         LPARAM lparam) {
  if (message == WM_NCCREATE) {
    auto window = reinterpret_cast<Win32Window*>(reinterpret_cast<CREATESTRUCT*>(lparam)->lpCreateParams);
    ::SetWindowLongPtr(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(window));
    auto module = ::GetModuleHandle(L"user32.dll");
    if (module) {
      auto enable_non_client_dpi_scaling =
          reinterpret_cast<EnableNonClientDpiScaling*>(
              ::GetProcAddress(module, "EnableNonClientDpiScaling"));
      if (enable_non_client_dpi_scaling) {
        enable_non_client_dpi_scaling(hwnd);
        const auto style = ::GetWindowLong(hwnd, GWL_STYLE);
        ::SetWindowLong(hwnd, GWL_STYLE, style);
        ::SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
                       SWP_NOACTIVATE | SWP_NOOWNERZORDER | SWP_NOSIZE |
                           SWP_NOMOVE | SWP_FRAMECHANGED);
      }
    }
  }
  if (message == WM_NCDESTROY) {
    auto window = reinterpret_cast<Win32Window*>(::GetWindowLongPtr(hwnd, GWLP_USERDATA));
    if (window) {
      ::SetWindowLongPtr(hwnd, GWLP_USERDATA, 0);
      window->OnDestroy();
    }
  }
  auto window = reinterpret_cast<Win32Window*>(::GetWindowLongPtr(hwnd, GWLP_USERDATA));
  if (window) {
    return window->MessageHandler(hwnd, message, wparam, lparam);
  }
  return ::DefWindowProc(hwnd, message, wparam, lparam);
}

}

Win32Window::Win32Window() {}

Win32Window::~Win32Window() { Destroy(); }

bool Win32Window::Create(const std::wstring& title, const Point& origin,
                         const Size& size) {
  WNDCLASS window_class{};
  window_class.hCursor = ::LoadCursor(nullptr, IDC_ARROW);
  window_class.lpszClassName = kWindowClassName;
  window_class.style = CS_HREDRAW | CS_VREDRAW;
  window_class.cbClsExtra = 0;
  window_class.cbWndExtra = 0;
  window_class.hInstance = ::GetModuleHandle(nullptr);
  window_class.hIcon =
      ::LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
  window_class.hbrBackground = 0;
  window_class.lpszMenuName = nullptr;
  window_class.lpfnWndProc = WndProc;
  ::RegisterClass(&window_class);

  int scaled_width = size.width;
  int scaled_height = size.height;
  HWND window = ::CreateWindow(
      kWindowClassName, title.c_str(), kWindowStyle, origin.x, origin.y,
      scaled_width, scaled_height, nullptr, nullptr,
      ::GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  ::UpdateWindow(window);
  return OnCreate();
}

bool Win32Window::Show() {
  return ::ShowWindow(window_handle_, SW_SHOWNORMAL);
}

void Win32Window::Destroy() {
  if (window_handle_) {
    ::DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  ::UnregisterClass(kWindowClassName, nullptr);
}

void Win32Window::SetChildContent(HWND window) {
  child_content_ = window;
  SetParent(window, window_handle_);
  RECT frame;
  ::GetClientRect(window_handle_, &frame);
  ::MoveWindow(window, frame.left, frame.top, frame.right - frame.left,
               frame.bottom - frame.top, true);
}

HWND Win32Window::GetHandle() { return window_handle_; }

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

bool Win32Window::OnCreate() {
  return true;
}

void Win32Window::OnDestroy() {}

LRESULT Win32Window::MessageHandler(HWND hwnd, UINT message, WPARAM wparam,
                                    LPARAM lparam) {
  switch (message) {
    case WM_FONTCHANGE:
      break;
    case WM_CLOSE:
      Destroy();
      if (quit_on_close_) {
        ::PostQuitMessage(0);
      }
      return 0;
    case WM_DPICHANGED: {
      auto newRectSize = reinterpret_cast<RECT*>(lparam);
      LONG newWidth = newRectSize->right - newRectSize->left;
      LONG newHeight = newRectSize->bottom - newRectSize->top;

      ::SetWindowPos(hwnd, nullptr, newRectSize->left, newRectSize->top, newWidth,
                     newHeight, SWP_NOZORDER | SWP_NOACTIVATE);
      return 0;
    }
    case WM_SIZE: {
      if (child_content_) {
        RECT frame;
        ::GetClientRect(hwnd, &frame);
        ::MoveWindow(child_content_, frame.left, frame.top,
                     frame.right - frame.left, frame.bottom - frame.top, TRUE);
      }
      return 0;
    }
    case WM_ACTIVATE:
      if (child_content_) {
        ::SetFocus(child_content_);
      }
      return 0;
    case WM_DWMCOLORIZATIONCOLORCHANGED:
      return 0;
  }
  return ::DefWindowProc(hwnd, message, wparam, lparam);
}

Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(::GetWindowLongPtr(window, GWLP_USERDATA));
}
