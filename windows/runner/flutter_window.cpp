#include "flutter_window.h"

#include <optional>
#include <string>
#include <windows.h>

#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"
#include "security_monitor.h"

static std::string WideToUtf8(const wchar_t* wide) {
  if (!wide || wcslen(wide) == 0) return "";
  int size = WideCharToMultiByte(CP_UTF8, 0, wide, -1, nullptr, 0, nullptr, nullptr);
  if (size <= 0) return "";
  std::string result(size - 1, '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide, -1, &result[0], size, nullptr, nullptr);
  return result;
}

static std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) return L"";
  int size = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  if (size <= 0) return L"";
  std::wstring result(size - 1, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, &result[0], size);
  return result;
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  HWND hwnd = GetHandle();
  SetWindowDisplayAffinity(hwnd, WDA_EXCLUDEFROMCAPTURE);

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "shobaki/security",
      &flutter::StandardMethodCodec::GetInstance());

  channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "isRecordingDetected") {
          result->Success(flutter::EncodableValue(IsRecordingSoftwareRunning()));
        } else if (call.method_name() == "getDetectedApp") {
          IsRecordingSoftwareRunning();
          const wchar_t* app = GetDetectedRecordingApp();
          result->Success(flutter::EncodableValue(WideToUtf8(app)));
        } else if (call.method_name() == "getDetectedApps") {
          IsRecordingSoftwareRunning();
          auto apps = GetDetectedRecordingApps();
          flutter::EncodableList list;
          for (const auto& a : apps) {
            list.push_back(flutter::EncodableValue(WideToUtf8(a.c_str())));
          }
          result->Success(flutter::EncodableValue(std::move(list)));
        } else if (call.method_name() == "closeDetectedApp") {
          const auto* args = std::get_if<std::string>(&*call.arguments());
          if (args != nullptr) {
            std::wstring wname = Utf8ToWide(*args);
            result->Success(flutter::EncodableValue(CloseDetectedApp(wname.c_str())));
          } else {
            result->Error("INVALID_ARGUMENT", "Expected a string process name");
          }
        } else if (call.method_name() == "closeAllDetectedApps") {
          result->Success(flutter::EncodableValue(CloseAllDetectedApps()));
        } else {
          result->NotImplemented();
        }
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
