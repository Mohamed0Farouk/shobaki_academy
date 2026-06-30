#include "security_monitor.h"

#include <tlhelp32.h>
#include <string>
#include <vector>
#include <algorithm>

static std::wstring detected_process;
static std::vector<std::wstring> detected_processes;

static void CheckAllProcesses(
    const std::vector<std::wstring> &targets,
    std::vector<std::wstring> &detected)
{
    detected.clear();

    HANDLE snapshot =
        CreateToolhelp32Snapshot(
            TH32CS_SNAPPROCESS,
            0);

    if (snapshot == INVALID_HANDLE_VALUE)
        return;

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
                    detected.push_back(entry.szExeFile);
                    break;
                }
            }

        } while (Process32NextW(snapshot, &entry));
    }

    CloseHandle(snapshot);
}

static std::vector<std::wstring> GetTargetProcesses()
{
    return {
        // OBS
        L"obs64",
        L"obs32",

        // Popular
        L"bandicam",
        L"camtasiastudio",
        L"snagit32",

        // Lightweight
        L"ocam",
        L"apowerrec",
        L"screenrec",

        // Windows
        L"gamebar",
        L"snippingtool",

        // Streaming platforms
        L"streamlabs-obs",
        L"twitchstudio",
        L"camtasiarecorder",
    };
}

bool IsRecordingSoftwareRunning()
{
    CheckAllProcesses(
        GetTargetProcesses(),
        detected_processes);

    if (!detected_processes.empty())
    {
        detected_process = detected_processes[0];
    }
    else
    {
        detected_process.clear();
    }

    return !detected_processes.empty();
}

const wchar_t *GetDetectedRecordingApp()
{
    return detected_process.c_str();
}

std::vector<std::wstring> GetDetectedRecordingApps()
{
    return detected_processes;
}

bool CloseDetectedApp(const wchar_t* processName)
{
    if (processName == nullptr || wcslen(processName) == 0)
        return false;

    HANDLE snapshot = CreateToolhelp32Snapshot(
        TH32CS_SNAPPROCESS, 0);

    if (snapshot == INVALID_HANDLE_VALUE)
        return false;

    PROCESSENTRY32W entry;
    entry.dwSize = sizeof(PROCESSENTRY32W);
    bool success = false;

    if (Process32FirstW(snapshot, &entry))
    {
        do
        {
            if (_wcsicmp(processName, entry.szExeFile) == 0)
            {
                HANDLE hProcess = OpenProcess(
                    PROCESS_TERMINATE,
                    FALSE,
                    entry.th32ProcessID);

                if (hProcess != NULL)
                {
                    success = TerminateProcess(
                        hProcess, 0) != 0;
                    CloseHandle(hProcess);
                }

                break;
            }

        } while (Process32NextW(snapshot, &entry));
    }

    CloseHandle(snapshot);
    return success;
}

bool CloseAllDetectedApps()
{
    bool allSuccess = true;

    for (const auto &process : detected_processes)
    {
        if (!CloseDetectedApp(process.c_str()))
        {
            allSuccess = false;
        }
    }

    return allSuccess;
}