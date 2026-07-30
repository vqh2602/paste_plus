#include "window_plugin.h"

#include <windows.h>
#include <shobjidl.h> // for IFileDialog
#include <psapi.h> // for GetModuleFileNameEx
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <vector>
#include <locale>
#include <codecvt>
#include <map>
#include <thread>

// Helper to convert wstring to string
std::string utf8_encode(const std::wstring &wstr) {
    if (wstr.empty()) return std::string();
    int size_needed = WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), NULL, 0, NULL, NULL);
    std::string strTo(size_needed, 0);
    WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), &strTo[0], size_needed, NULL, NULL);
    return strTo;
}

// Helper to convert string to wstring
std::wstring utf8_decode(const std::string &str) {
    if (str.empty()) return std::wstring();
    int size_needed = MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), NULL, 0);
    std::wstring wstrTo(size_needed, 0);
    MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), &wstrTo[0], size_needed);
    return wstrTo;
}

void WindowPlugin::RegisterWithMessenger(
    flutter::BinaryMessenger* messenger) {
  auto plugin = std::make_shared<WindowPlugin>();

  auto channel =
      std::make_shared<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "clipflow/window",
          &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [plugin](const auto& call, auto result) {
        plugin->HandleMethodCall(call, std::move(result));
      });

  // Keep channel alive for the lifetime of the app
  static std::vector<std::shared_ptr<flutter::MethodChannel<flutter::EncodableValue>>> s_channels;
  s_channels.push_back(channel);
}

WindowPlugin::WindowPlugin() {}

WindowPlugin::~WindowPlugin() {}

BOOL CALLBACK EnumWindowsProc(HWND hwnd, LPARAM lParam) {
    auto& list = *reinterpret_cast<flutter::EncodableList*>(lParam);
    
    if (IsWindowVisible(hwnd)) {
        DWORD processId;
        GetWindowThreadProcessId(hwnd, &processId);
        
        HANDLE hProcess = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, processId);
        if (hProcess) {
            WCHAR buffer[MAX_PATH];
            if (GetModuleFileNameExW(hProcess, NULL, buffer, MAX_PATH)) {
                std::wstring path(buffer);
                size_t pos = path.find_last_of(L"\\/");
                std::wstring name = (pos != std::wstring::npos) ? path.substr(pos + 1) : path;
                
                flutter::EncodableMap map;
                map[flutter::EncodableValue("appName")] = flutter::EncodableValue(utf8_encode(name));
                map[flutter::EncodableValue("bundleId")] = flutter::EncodableValue(utf8_encode(path));
                list.push_back(flutter::EncodableValue(map));
            }
            CloseHandle(hProcess);
        }
    }
    return TRUE;
}

void WindowPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("pasteToPreviousApplication") == 0) {
    // Send Ctrl+V
    INPUT inputs[4] = {};
    ZeroMemory(inputs, sizeof(inputs));

    inputs[0].type = INPUT_KEYBOARD;
    inputs[0].ki.wVk = VK_CONTROL;

    inputs[1].type = INPUT_KEYBOARD;
    inputs[1].ki.wVk = 'V';

    inputs[2].type = INPUT_KEYBOARD;
    inputs[2].ki.wVk = 'V';
    inputs[2].ki.dwFlags = KEYEVENTF_KEYUP;

    inputs[3].type = INPUT_KEYBOARD;
    inputs[3].ki.wVk = VK_CONTROL;
    inputs[3].ki.dwFlags = KEYEVENTF_KEYUP;

    UINT uSent = SendInput(ARRAYSIZE(inputs), inputs, sizeof(INPUT));
    result->Success(flutter::EncodableValue(uSent == ARRAYSIZE(inputs)));
  } else if (method_call.method_name().compare("checkAccessibilityPermission") == 0) {
    result->Success(flutter::EncodableValue(true));
  } else if (method_call.method_name().compare("requestAccessibilityPermission") == 0) {
    result->Success(flutter::EncodableValue(true));
  } else if (method_call.method_name().compare("resetAccessibilityPermission") == 0) {
    result->Success(flutter::EncodableValue(true));
  } else if (method_call.method_name().compare("setShowInDock") == 0) {
    result->Success(); // Managed by window_manager
  } else if (method_call.method_name().compare("setQuickPanelMode") == 0) {
    result->Success(); // Managed by window_manager mostly on Windows
  } else if (method_call.method_name().compare("getRunningApplications") == 0) {
    flutter::EncodableList list;
    EnumWindows(EnumWindowsProc, reinterpret_cast<LPARAM>(&list));
    result->Success(flutter::EncodableValue(list));
  } else if (method_call.method_name().compare("openUrl") == 0) {
    std::string url = "";
    if (const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments())) {
      if (auto it = args->find(flutter::EncodableValue("url")); it != args->end()) {
        url = std::get<std::string>(it->second);
      }
    }
    if (!url.empty()) {
      ShellExecuteW(NULL, L"open", utf8_decode(url).c_str(), NULL, NULL, SW_SHOWNORMAL);
    }
    result->Success();
  } else if (method_call.method_name().compare("restartApp") == 0) {
    WCHAR path[MAX_PATH];
    GetModuleFileNameW(NULL, path, MAX_PATH);
    ShellExecuteW(NULL, L"open", path, NULL, NULL, SW_SHOWNORMAL);
    ExitProcess(0);
  } else if (method_call.method_name().compare("pickApplicationFile") == 0) {
    IFileOpenDialog *pFileOpen;
    HRESULT hr = CoCreateInstance(CLSID_FileOpenDialog, NULL, CLSCTX_ALL, IID_IFileOpenDialog, reinterpret_cast<void**>(&pFileOpen));
    if (SUCCEEDED(hr)) {
      COMDLG_FILTERSPEC rgSpec[] = { { L"Executables", L"*.exe" } };
      pFileOpen->SetFileTypes(1, rgSpec);
      hr = pFileOpen->Show(NULL);
      if (SUCCEEDED(hr)) {
        IShellItem *pItem;
        hr = pFileOpen->GetResult(&pItem);
        if (SUCCEEDED(hr)) {
          PWSTR pszFilePath;
          hr = pItem->GetDisplayName(SIGDN_FILESYSPATH, &pszFilePath);
          if (SUCCEEDED(hr)) {
            std::wstring filePath(pszFilePath);
            CoTaskMemFree(pszFilePath);
            
            size_t pos = filePath.find_last_of(L"\\/");
            std::wstring name = (pos != std::wstring::npos) ? filePath.substr(pos + 1) : filePath;
            
            flutter::EncodableMap map;
            map[flutter::EncodableValue("appName")] = flutter::EncodableValue(utf8_encode(name));
            map[flutter::EncodableValue("bundleId")] = flutter::EncodableValue(utf8_encode(filePath));
            
            result->Success(flutter::EncodableValue(map));
            pItem->Release();
            pFileOpen->Release();
            return;
          }
          pItem->Release();
        }
      }
      pFileOpen->Release();
    }
    result->Success();
  } else if (method_call.method_name().compare("pickConfigFile") == 0) {
    IFileOpenDialog *pFileOpen;
    HRESULT hr = CoCreateInstance(CLSID_FileOpenDialog, NULL, CLSCTX_ALL, IID_IFileOpenDialog, reinterpret_cast<void**>(&pFileOpen));
    if (SUCCEEDED(hr)) {
      COMDLG_FILTERSPEC rgSpec[] = { { L"ClipFlow Config", L"*.clipflow" } };
      pFileOpen->SetFileTypes(1, rgSpec);
      hr = pFileOpen->Show(NULL);
      if (SUCCEEDED(hr)) {
        IShellItem *pItem;
        hr = pFileOpen->GetResult(&pItem);
        if (SUCCEEDED(hr)) {
          PWSTR pszFilePath;
          hr = pItem->GetDisplayName(SIGDN_FILESYSPATH, &pszFilePath);
          if (SUCCEEDED(hr)) {
            std::string path = utf8_encode(std::wstring(pszFilePath));
            CoTaskMemFree(pszFilePath);
            result->Success(flutter::EncodableValue(path));
            pItem->Release();
            pFileOpen->Release();
            return;
          }
          pItem->Release();
        }
      }
      pFileOpen->Release();
    }
    result->Success();
  } else if (method_call.method_name().compare("saveConfigFile") == 0) {
    std::string defaultName = "";
    if (const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments())) {
      if (auto it = args->find(flutter::EncodableValue("defaultName")); it != args->end()) {
        defaultName = std::get<std::string>(it->second);
      }
    }
    IFileSaveDialog *pFileSave;
    HRESULT hr = CoCreateInstance(CLSID_FileSaveDialog, NULL, CLSCTX_ALL, IID_IFileSaveDialog, reinterpret_cast<void**>(&pFileSave));
    if (SUCCEEDED(hr)) {
      COMDLG_FILTERSPEC rgSpec[] = { { L"ClipFlow Config", L"*.clipflow" } };
      pFileSave->SetFileTypes(1, rgSpec);
      pFileSave->SetDefaultExtension(L"clipflow");
      if (!defaultName.empty()) {
        pFileSave->SetFileName(utf8_decode(defaultName).c_str());
      }
      hr = pFileSave->Show(NULL);
      if (SUCCEEDED(hr)) {
        IShellItem *pItem;
        hr = pFileSave->GetResult(&pItem);
        if (SUCCEEDED(hr)) {
          PWSTR pszFilePath;
          hr = pItem->GetDisplayName(SIGDN_FILESYSPATH, &pszFilePath);
          if (SUCCEEDED(hr)) {
            std::string path = utf8_encode(std::wstring(pszFilePath));
            CoTaskMemFree(pszFilePath);
            result->Success(flutter::EncodableValue(path));
            pItem->Release();
            pFileSave->Release();
            return;
          }
          pItem->Release();
        }
      }
      pFileSave->Release();
    }
    result->Success();
  } else {
    result->NotImplemented();
  }
}
