#include "security_monitor.h"

#include <tlhelp32.h>
#include <string>
#include <vector>
#include <algorithm>

static std::wstring detected_process;

static bool CheckProcesses(
    const std::vector<std::wstring> &targets,
    std::wstring &detected)
{
    HANDLE snapshot =
        CreateToolhelp32Snapshot(
            TH32CS_SNAPPROCESS,
            0);

    if (snapshot == INVALID_HANDLE_VALUE)
        return false;

    PROCESSENTRY32W entry;
    entry.dwSize = sizeof(PROCESSENTRY32W);

    if (Process32FirstW(snapshot, &entry))
    {
        do
        {
            std::wstring exe = entry.szExeFile;
            size_t dot = exe.rfind(L'.');
            if (dot != std::wstring::npos)
                exe = exe.substr(0, dot);

            std::transform(
                exe.begin(),
                exe.end(),
                exe.begin(),
                towlower);

            for (const auto &target : targets)
            {
                if (exe == target)
                {
                    detected = entry.szExeFile;

                    CloseHandle(snapshot);

                    return true;
                }
            }

        } while (Process32NextW(snapshot, &entry));
    }

    CloseHandle(snapshot);

    return false;
}

bool IsRecordingSoftwareRunning()
{
    std::vector<std::wstring> targets = {

        // OBS
        L"obs64",
        L"obs32",

        // Popular
        L"bandicam",
        L"camtasiastudio",
        L"snagit32",
        L"xsplit.core",

        // Lightweight
        L"ocam",
        L"apowerrec",
        L"screenrec",
        L"flashback",
        L"bbflashback",

        // Windows
        L"gamebar",
        L"snippingtool",

        // Streaming platforms
        L"streamlabs-obs",
        L"twitchstudio",

        // Capture / recording
        L"sharex",
        L"greenshot",
        L"picpick",
        L"screenrecorder",
        L"ezvid",
        L"clipchamp",
        L"camstudio",
        L"camtasiarecorder",
        L"activepresenter",
        
    };

    return CheckProcesses(
        targets,
        detected_process);
}

const wchar_t *GetDetectedRecordingApp()
{
    return detected_process.c_str();
}