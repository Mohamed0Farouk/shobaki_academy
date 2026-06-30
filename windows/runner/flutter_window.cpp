#include "flutter_window.h"

#include <optional>
#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"
#include "security_monitor.h"

std::unique_ptr<
    flutter::MethodChannel<flutter::EncodableValue>>
    security_channel;

FlutterWindow::FlutterWindow(
    const flutter::DartProject &project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate()
{
  if (!Win32Window::OnCreate())
  {
    return false;
  }

  HWND hwnd = GetHandle();

  // Best effort protection
  SetWindowDisplayAffinity(
      hwnd,
      WDA_EXCLUDEFROMCAPTURE);

  RECT frame = GetClientArea();

  flutter_controller_ =
      std::make_unique<flutter::FlutterViewController>(
          frame.right - frame.left,
          frame.bottom - frame.top,
          project_);

  if (!flutter_controller_->engine() ||
      !flutter_controller_->view())
  {
    return false;
  }

  RegisterPlugins(
      flutter_controller_->engine());

  // Security channel
  security_channel =
      std::make_unique<
          flutter::MethodChannel<
              flutter::EncodableValue>>(
          flutter_controller_->engine()
              ->messenger(),
          "shobaki/security",
          &flutter::StandardMethodCodec::GetInstance());

  security_channel->SetMethodCallHandler(
      [](
          const flutter::MethodCall<
              flutter::EncodableValue> &call,

          std::unique_ptr<
              flutter::MethodResult<
                  flutter::EncodableValue>>
              result)
      {
        if (call.method_name() ==
            "isRecordingDetected")
        {
          bool detected =
              IsRecordingSoftwareRunning();

          result->Success(
              flutter::EncodableValue(
                  detected));

          return;
        }

        if (call.method_name() ==
            "getDetectedApp")
        {
          IsRecordingSoftwareRunning();
          std::wstring process =
              GetDetectedRecordingApp();

          int size_needed =
              WideCharToMultiByte(
                  CP_UTF8,
                  0,
                  process.c_str(),
                  -1,
                  NULL,
                  0,
                  NULL,
                  NULL);

          std::string process_utf8(
              size_needed,
              0);

          WideCharToMultiByte(
              CP_UTF8,
              0,
              process.c_str(),
              -1,
              &process_utf8[0],
              size_needed,
              NULL,
              NULL);

          result->Success(
              flutter::EncodableValue(
                  process_utf8));

          return;
        }

        if (call.method_name() ==
            "getDetectedApps")
        {
          IsRecordingSoftwareRunning();
          auto apps = GetDetectedRecordingApps();
          flutter::EncodableList list;

          for (const auto &app : apps)
          {
            int size_needed =
                WideCharToMultiByte(
                    CP_UTF8,
                    0,
                    app.c_str(),
                    -1,
                    NULL,
                    0,
                    NULL,
                    NULL);

            std::string app_utf8(
                size_needed,
                0);

            WideCharToMultiByte(
                CP_UTF8,
                0,
                app.c_str(),
                -1,
                &app_utf8[0],
                size_needed,
                NULL,
                NULL);

            list.push_back(
                flutter::EncodableValue(
                    app_utf8));
          }

          result->Success(
              flutter::EncodableValue(
                  list));

          return;
        }

        if (call.method_name() ==
            "closeDetectedApp")
        {
          const auto* args =
              std::get_if<std::string>(
                  &*call.arguments());

          bool success = false;

          if (args != nullptr)
          {
            int wide_len =
                MultiByteToWideChar(
                    CP_UTF8,
                    0,
                    args->c_str(),
                    -1,
                    NULL,
                    0);

            std::wstring wide_str(
                wide_len, L'\0');

            MultiByteToWideChar(
                CP_UTF8,
                0,
                args->c_str(),
                -1,
                &wide_str[0],
                wide_len);

            success = CloseDetectedApp(
                wide_str.c_str());
          }

          result->Success(
              flutter::EncodableValue(
                  success));

          return;
        }

        if (call.method_name() ==
            "closeAllDetectedApps")
        {
          bool success =
              CloseAllDetectedApps();

          result->Success(
              flutter::EncodableValue(
                  success));

          return;
        }

        result->NotImplemented();
      });

  SetChildContent(
      flutter_controller_->view()
          ->GetNativeWindow());

  flutter_controller_->engine()
      ->SetNextFrameCallback([&]()
                             { this->Show(); });

  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy()
{
  if (flutter_controller_)
  {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT FlutterWindow::MessageHandler(
    HWND hwnd,
    UINT const message,
    WPARAM const wparam,
    LPARAM const lparam) noexcept
{
  if (flutter_controller_)
  {
    std::optional<LRESULT> result =
        flutter_controller_
            ->HandleTopLevelWindowProc(
                hwnd,
                message,
                wparam,
                lparam);

    if (result)
    {
      return *result;
    }
  }

  switch (message)
  {
  case WM_FONTCHANGE:
  {
    flutter_controller_->engine()
        ->ReloadSystemFonts();

    break;
  }
  }

  return Win32Window::MessageHandler(
      hwnd,
      message,
      wparam,
      lparam);
}