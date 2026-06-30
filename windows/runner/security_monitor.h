#pragma once
#include <windows.h>
#include <vector>
#include <string>

bool IsRecordingSoftwareRunning();
const wchar_t* GetDetectedRecordingApp();
std::vector<std::wstring> GetDetectedRecordingApps();
bool CloseDetectedApp(const wchar_t* processName);
bool CloseAllDetectedApps();