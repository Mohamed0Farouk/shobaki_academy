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

            std::transform(
                exe.begin(),
                exe.end(),
                exe.begin(),
                towlower);

            for (auto target : targets)
            {
                std::transform(
                    target.begin(),
                    target.end(),
                    target.begin(),
                    towlower);

                if (exe.find(target) != std::wstring::npos)
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
        L"obs",

        // Popular
        L"bandicam",
        L"camtasia",
        L"snagit",
        L"xsplit",

        // Lightweight
        L"ocam",
        L"apowerrec",
        L"screenrec",
        L"flashback",
        L"bbflashback",

        // Windows
        L"gamebar",
        L"screenrecorder"};

    return CheckProcesses(
        targets,
        detected_process);
}

const wchar_t *GetDetectedRecordingApp()
{
    return detected_process.c_str();
}