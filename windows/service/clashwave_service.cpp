#include <windows.h>
#include <sddl.h>

#include <string>
#include <vector>

namespace {
constexpr wchar_t kServiceName[] = L"ClashWaveCore";
constexpr wchar_t kDisplayName[] = L"ClashWave Mihomo Core";

SERVICE_STATUS_HANDLE g_status_handle = nullptr;
SERVICE_STATUS g_status{};
HANDLE g_stop_event = nullptr;
HANDLE g_job = nullptr;
std::wstring g_core;
std::wstring g_home;
std::wstring g_config;

std::wstring Quote(const std::wstring& value) {
  std::wstring result = L"\"";
  unsigned int backslashes = 0;
  for (const wchar_t ch : value) {
    if (ch == L'\\') {
      ++backslashes;
      continue;
    }
    if (ch == L'\"') {
      result.append(backslashes * 2 + 1, L'\\');
      result.push_back(L'\"');
      backslashes = 0;
      continue;
    }
    result.append(backslashes, L'\\');
    backslashes = 0;
    result.push_back(ch);
  }
  result.append(backslashes * 2, L'\\');
  result.push_back(L'\"');
  return result;
}

void ReportStatus(DWORD state, DWORD error = NO_ERROR, DWORD hint = 0) {
  g_status.dwServiceType = SERVICE_WIN32_OWN_PROCESS;
  g_status.dwCurrentState = state;
  g_status.dwWin32ExitCode = error;
  g_status.dwWaitHint = hint;
  g_status.dwControlsAccepted =
      state == SERVICE_RUNNING ? SERVICE_ACCEPT_STOP | SERVICE_ACCEPT_SHUTDOWN
                               : 0;
  SetServiceStatus(g_status_handle, &g_status);
}

void WINAPI ControlHandler(DWORD control) {
  if (control != SERVICE_CONTROL_STOP && control != SERVICE_CONTROL_SHUTDOWN) {
    return;
  }
  ReportStatus(SERVICE_STOP_PENDING, NO_ERROR, 5000);
  if (g_stop_event != nullptr) {
    SetEvent(g_stop_event);
  }
}

DWORD RunMihomo() {
  g_job = CreateJobObjectW(nullptr, nullptr);
  if (g_job == nullptr) return GetLastError();

  JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits{};
  limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
  if (!SetInformationJobObject(g_job, JobObjectExtendedLimitInformation,
                               &limits, sizeof(limits))) {
    return GetLastError();
  }

  std::wstring command = Quote(g_core) + L" -d " + Quote(g_home) + L" -f " +
                         Quote(g_config);
  std::vector<wchar_t> buffer(command.begin(), command.end());
  buffer.push_back(L'\0');

  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  PROCESS_INFORMATION process{};
  if (!CreateProcessW(nullptr, buffer.data(), nullptr, nullptr, FALSE,
                      CREATE_NO_WINDOW, nullptr, g_home.c_str(), &startup,
                      &process)) {
    return GetLastError();
  }
  CloseHandle(process.hThread);
  if (!AssignProcessToJobObject(g_job, process.hProcess)) {
    const DWORD error = GetLastError();
    TerminateProcess(process.hProcess, error);
    CloseHandle(process.hProcess);
    return error;
  }

  HANDLE waits[] = {g_stop_event, process.hProcess};
  const DWORD result = WaitForMultipleObjects(2, waits, FALSE, INFINITE);
  DWORD exit_code = NO_ERROR;
  if (result == WAIT_OBJECT_0) {
    TerminateJobObject(g_job, NO_ERROR);
  } else if (result == WAIT_OBJECT_0 + 1) {
    GetExitCodeProcess(process.hProcess, &exit_code);
    if (exit_code == NO_ERROR) exit_code = ERROR_PROCESS_ABORTED;
  } else {
    exit_code = GetLastError();
  }
  CloseHandle(process.hProcess);
  CloseHandle(g_job);
  g_job = nullptr;
  return exit_code;
}

void WINAPI ServiceMain(DWORD, wchar_t**) {
  g_status_handle = RegisterServiceCtrlHandlerW(kServiceName, ControlHandler);
  if (g_status_handle == nullptr) return;
  ReportStatus(SERVICE_START_PENDING, NO_ERROR, 5000);
  g_stop_event = CreateEventW(nullptr, TRUE, FALSE, nullptr);
  if (g_stop_event == nullptr) {
    ReportStatus(SERVICE_STOPPED, GetLastError());
    return;
  }
  ReportStatus(SERVICE_RUNNING);
  const DWORD result = RunMihomo();
  CloseHandle(g_stop_event);
  g_stop_event = nullptr;
  ReportStatus(SERVICE_STOPPED, result);
}

bool StopAndWait(SC_HANDLE service) {
  SERVICE_STATUS_PROCESS status{};
  DWORD bytes = 0;
  if (!QueryServiceStatusEx(service, SC_STATUS_PROCESS_INFO,
                            reinterpret_cast<BYTE*>(&status), sizeof(status),
                            &bytes)) {
    return false;
  }
  if (status.dwCurrentState == SERVICE_STOPPED) return true;
  SERVICE_STATUS ignored{};
  if (status.dwCurrentState != SERVICE_STOP_PENDING &&
      !ControlService(service, SERVICE_CONTROL_STOP, &ignored)) {
    return GetLastError() == ERROR_SERVICE_NOT_ACTIVE;
  }
  for (int attempt = 0; attempt < 50; ++attempt) {
    Sleep(100);
    if (!QueryServiceStatusEx(service, SC_STATUS_PROCESS_INFO,
                              reinterpret_cast<BYTE*>(&status), sizeof(status),
                              &bytes)) {
      return false;
    }
    if (status.dwCurrentState == SERVICE_STOPPED) return true;
  }
  return false;
}

bool GrantInteractiveControl(SC_HANDLE service) {
  constexpr wchar_t kSddl[] =
      L"D:(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)"
      L"(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)"
      L"(A;;LCRPWPLO;;;IU)";
  PSECURITY_DESCRIPTOR descriptor = nullptr;
  if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(
          kSddl, SDDL_REVISION_1, &descriptor, nullptr)) {
    return false;
  }
  const BOOL result =
      SetServiceObjectSecurity(service, DACL_SECURITY_INFORMATION, descriptor);
  LocalFree(descriptor);
  return result == TRUE;
}

int Install(const std::wstring& core, const std::wstring& home,
            const std::wstring& config) {
  wchar_t self[MAX_PATH]{};
  const DWORD length = GetModuleFileNameW(nullptr, self, MAX_PATH);
  if (length == 0 || length == MAX_PATH) return 10;
  const std::wstring image = Quote(self) + L" --service " + Quote(core) +
                             L" " + Quote(home) + L" " + Quote(config);

  SC_HANDLE manager = OpenSCManagerW(nullptr, nullptr, SC_MANAGER_CONNECT |
                                                       SC_MANAGER_CREATE_SERVICE);
  if (manager == nullptr) return 11;
  SC_HANDLE service = CreateServiceW(
      manager, kServiceName, kDisplayName, SERVICE_ALL_ACCESS,
      SERVICE_WIN32_OWN_PROCESS, SERVICE_AUTO_START, SERVICE_ERROR_NORMAL,
      image.c_str(), nullptr, nullptr, nullptr, nullptr, nullptr);
  if (service == nullptr && GetLastError() == ERROR_SERVICE_EXISTS) {
    service = OpenServiceW(manager, kServiceName, SERVICE_ALL_ACCESS);
    if (service != nullptr) {
      StopAndWait(service);
      if (!ChangeServiceConfigW(service, SERVICE_NO_CHANGE, SERVICE_AUTO_START,
                                SERVICE_NO_CHANGE, image.c_str(), nullptr,
                                nullptr, nullptr, nullptr, nullptr,
                                kDisplayName)) {
        CloseServiceHandle(service);
        CloseServiceHandle(manager);
        return 12;
      }
    }
  }
  if (service == nullptr) {
    CloseServiceHandle(manager);
    return 13;
  }

  SERVICE_DESCRIPTIONW description{};
  description.lpDescription =
      const_cast<wchar_t*>(L"Runs the ClashWave Mihomo core outside the GUI.");
  ChangeServiceConfig2W(service, SERVICE_CONFIG_DESCRIPTION, &description);
  SC_ACTION actions[] = {{SC_ACTION_RESTART, 3000},
                         {SC_ACTION_RESTART, 10000},
                         {SC_ACTION_NONE, 0}};
  SERVICE_FAILURE_ACTIONSW failure{};
  failure.dwResetPeriod = 86400;
  failure.cActions = 3;
  failure.lpsaActions = actions;
  ChangeServiceConfig2W(service, SERVICE_CONFIG_FAILURE_ACTIONS, &failure);
  SERVICE_FAILURE_ACTIONS_FLAG flag{};
  flag.fFailureActionsOnNonCrashFailures = TRUE;
  ChangeServiceConfig2W(service, SERVICE_CONFIG_FAILURE_ACTIONS_FLAG, &flag);
  SERVICE_DELAYED_AUTO_START_INFO delayed{};
  delayed.fDelayedAutostart = TRUE;
  ChangeServiceConfig2W(service, SERVICE_CONFIG_DELAYED_AUTO_START_INFO,
                        &delayed);
  if (!GrantInteractiveControl(service)) {
    CloseServiceHandle(service);
    CloseServiceHandle(manager);
    return 14;
  }
  const BOOL started = StartServiceW(service, 0, nullptr);
  const DWORD start_error = GetLastError();
  CloseServiceHandle(service);
  CloseServiceHandle(manager);
  return started || start_error == ERROR_SERVICE_ALREADY_RUNNING ? 0 : 15;
}

int Uninstall() {
  SC_HANDLE manager = OpenSCManagerW(nullptr, nullptr, SC_MANAGER_CONNECT);
  if (manager == nullptr) return 20;
  SC_HANDLE service = OpenServiceW(manager, kServiceName,
                                   SERVICE_STOP | SERVICE_QUERY_STATUS | DELETE);
  if (service == nullptr) {
    const DWORD error = GetLastError();
    CloseServiceHandle(manager);
    return error == ERROR_SERVICE_DOES_NOT_EXIST ? 0 : 21;
  }
  StopAndWait(service);
  const BOOL removed = DeleteService(service);
  const DWORD error = GetLastError();
  CloseServiceHandle(service);
  CloseServiceHandle(manager);
  return removed || error == ERROR_SERVICE_MARKED_FOR_DELETE ? 0 : 22;
}

int StartInstalled() {
  SC_HANDLE manager = OpenSCManagerW(nullptr, nullptr, SC_MANAGER_CONNECT);
  if (manager == nullptr) return 30;
  SC_HANDLE service = OpenServiceW(
      manager, kServiceName, SERVICE_START | SERVICE_QUERY_STATUS);
  if (service == nullptr) {
    CloseServiceHandle(manager);
    return 31;
  }
  const BOOL started = StartServiceW(service, 0, nullptr);
  const DWORD error = GetLastError();
  CloseServiceHandle(service);
  CloseServiceHandle(manager);
  return started || error == ERROR_SERVICE_ALREADY_RUNNING ? 0 : 32;
}

int StopInstalled() {
  SC_HANDLE manager = OpenSCManagerW(nullptr, nullptr, SC_MANAGER_CONNECT);
  if (manager == nullptr) return 33;
  SC_HANDLE service = OpenServiceW(
      manager, kServiceName, SERVICE_STOP | SERVICE_QUERY_STATUS);
  if (service == nullptr) {
    const DWORD error = GetLastError();
    CloseServiceHandle(manager);
    return error == ERROR_SERVICE_DOES_NOT_EXIST ? 0 : 34;
  }
  const bool stopped = StopAndWait(service);
  CloseServiceHandle(service);
  CloseServiceHandle(manager);
  return stopped ? 0 : 35;
}

int IsInstalled() {
  SC_HANDLE manager = OpenSCManagerW(nullptr, nullptr, SC_MANAGER_CONNECT);
  if (manager == nullptr) return 1;
  SC_HANDLE service = OpenServiceW(manager, kServiceName, SERVICE_QUERY_STATUS);
  if (service != nullptr) CloseServiceHandle(service);
  CloseServiceHandle(manager);
  return service == nullptr ? 1 : 0;
}
}  // namespace

int wmain(int argc, wchar_t* argv[]) {
  if (argc >= 2 && std::wstring(argv[1]) == L"--install" && argc == 5) {
    return Install(argv[2], argv[3], argv[4]);
  }
  if (argc >= 2 && std::wstring(argv[1]) == L"--uninstall") {
    return Uninstall();
  }
  if (argc >= 2 && std::wstring(argv[1]) == L"--start") {
    return StartInstalled();
  }
  if (argc >= 2 && std::wstring(argv[1]) == L"--stop") {
    return StopInstalled();
  }
  if (argc >= 2 && std::wstring(argv[1]) == L"--is-installed") {
    return IsInstalled();
  }
  if (argc == 5 && std::wstring(argv[1]) == L"--service") {
    g_core = argv[2];
    g_home = argv[3];
    g_config = argv[4];
    SERVICE_TABLE_ENTRYW table[] = {
        {const_cast<wchar_t*>(kServiceName), ServiceMain}, {nullptr, nullptr}};
    return StartServiceCtrlDispatcherW(table) ? 0 : 40;
  }
  return 2;
}
