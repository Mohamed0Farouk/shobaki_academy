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
        L"screenrecorder",
        L"snippingtool",
        L"screensketch",

        // Meeting / conferencing
        L"zoom",
        L"meet",
        L"teams",
        L"skype",
        L"webex",
        L"gotomeeting",
        L"gotowebinar",
        L"gotoassist",

        // Remote desktop (can be used for recording/observation)
        L"teamviewer",
        L"anydesk",

        // NVIDIA / AMD
        // L"shadowplay",
        // L"geforce",
        // L"nvcontainer",
        // L"amdrelive",
        // L"amddvr",
        // L"relive",

        // Streaming platforms
        L"streamlabs",
        L"slobs",
        L"twitchstudio",
        L"streamelements",

        // Screen capture / screenshots
        L"lightshot",
        L"snipaste",
        L"monosnap",
        L"cloudapp",
        L"tinytake",

        // Capture / recording
        L"fraps",
        L"dxtory",
        L"action",
        L"mirillis",
        L"medal",
        L"medaltv",
        L"outplayed",
        L"overwolf",
        L"loom",
        L"manycam",
        L"splitcam",
        L"sharex",
        L"greenshot",
        L"picpick",
        L"durecorder",
        L"azrecorder",
        L"screenpresso",
        L"movavi",
        L"icecream",
        L"ezvid",
        L"democreator",
        L"debut",
        L"vmix",
        L"wirecast",
        L"vlc",
        L"clipchamp",
        L"discord",
        L"camstudio",
        L"screentogif",
        L"activepresenter",
        L"recordcast",
        L"psr",
        L"stepsrecorder"};

    return CheckProcesses(
        targets,
        detected_process);
}

const wchar_t *GetDetectedRecordingApp()
{
    return detected_process.c_str();
}