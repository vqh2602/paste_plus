#include "clipboard_plugin.h"

#include <windows.h>
#include <gdiplus.h>
#include <psapi.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <shlwapi.h>

#include <memory>
#include <string>
#include <vector>
#include <cctype>

#pragma comment (lib,"Gdiplus.lib")

using namespace Gdiplus;

extern std::string utf8_encode(const std::wstring &wstr);
extern std::wstring utf8_decode(const std::string &str);

static const std::string base64_chars = 
             "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
             "abcdefghijklmnopqrstuvwxyz"
             "0123456789+/";

std::string base64_encode(unsigned char const* bytes_to_encode, unsigned int in_len) {
  std::string ret;
  int i = 0;
  int j = 0;
  unsigned char char_array_3[3];
  unsigned char char_array_4[4];

  while (in_len--) {
    char_array_3[i++] = *(bytes_to_encode++);
    if (i == 3) {
      char_array_4[0] = (char_array_3[0] & 0xfc) >> 2;
      char_array_4[1] = ((char_array_3[0] & 0x03) << 4) + ((char_array_3[1] & 0xf0) >> 4);
      char_array_4[2] = ((char_array_3[1] & 0x0f) << 2) + ((char_array_3[2] & 0xc0) >> 6);
      char_array_4[3] = char_array_3[2] & 0x3f;

      for(i = 0; (i <4) ; i++)
        ret += base64_chars[char_array_4[i]];
      i = 0;
    }
  }

  if (i)
  {
    for(j = i; j < 3; j++)
      char_array_3[j] = '\0';

    char_array_4[0] = (char_array_3[0] & 0xfc) >> 2;
    char_array_4[1] = ((char_array_3[0] & 0x03) << 4) + ((char_array_3[1] & 0xf0) >> 4);
    char_array_4[2] = ((char_array_3[1] & 0x0f) << 2) + ((char_array_3[2] & 0xc0) >> 6);
    char_array_4[3] = char_array_3[2] & 0x3f;

    for (j = 0; (j < i + 1); j++)
      ret += base64_chars[char_array_4[j]];

    while((i++ < 3))
      ret += '=';
  }
  return ret;
}

std::vector<BYTE> base64_decode(std::string const& encoded_string) {
  int in_len = encoded_string.size();
  int i = 0;
  int j = 0;
  int in_ = 0;
  unsigned char char_array_4[4], char_array_3[3];
  std::vector<BYTE> ret;

  while (in_len-- && ( encoded_string[in_] != '=') && isalnum(encoded_string[in_]) || (encoded_string[in_] == '+') || (encoded_string[in_] == '/')) {
    char_array_4[i++] = encoded_string[in_]; in_++;
    if (i ==4) {
      for (i = 0; i <4; i++)
        char_array_4[i] = base64_chars.find(char_array_4[i]);

      char_array_3[0] = (char_array_4[0] << 2) + ((char_array_4[1] & 0x30) >> 4);
      char_array_3[1] = ((char_array_4[1] & 0xf) << 4) + ((char_array_4[2] & 0x3c) >> 2);
      char_array_3[2] = ((char_array_4[2] & 0x3) << 6) + char_array_4[3];

      for (i = 0; (i < 3); i++)
        ret.push_back(char_array_3[i]);
      i = 0;
    }
  }

  if (i) {
    for (j = i; j <4; j++)
      char_array_4[j] = 0;

    for (j = 0; j <4; j++)
      char_array_4[j] = base64_chars.find(char_array_4[j]);

    char_array_3[0] = (char_array_4[0] << 2) + ((char_array_4[1] & 0x30) >> 4);
    char_array_3[1] = ((char_array_4[1] & 0xf) << 4) + ((char_array_4[2] & 0x3c) >> 2);
    char_array_3[2] = ((char_array_4[2] & 0x3) << 6) + char_array_4[3];

    for (j = 0; (j < i - 1); j++) ret.push_back(char_array_3[j]);
  }

  return ret;
}

int GetEncoderClsid(const WCHAR* format, CLSID* pClsid)
{
   UINT  num = 0;
   UINT  size = 0;

   ImageCodecInfo* pImageCodecInfo = NULL;

   GetImageEncodersSize(&num, &size);
   if(size == 0)
      return -1;

   pImageCodecInfo = (ImageCodecInfo*)(malloc(size));
   if(pImageCodecInfo == NULL)
      return -1;

   GetImageEncoders(num, size, pImageCodecInfo);

   for(UINT j = 0; j < num; ++j)
   {
      if( wcscmp(pImageCodecInfo[j].MimeType, format) == 0 )
      {
         *pClsid = pImageCodecInfo[j].Clsid;
         free(pImageCodecInfo);
         return j;
      }    
   }

   free(pImageCodecInfo);
   return -1;
}

ULONG_PTR gdiplusToken;

void ClipboardPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "clipflow/clipboard",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<ClipboardPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
  
  GdiplusStartupInput gdiplusStartupInput;
  GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, NULL);
}

ClipboardPlugin::ClipboardPlugin() {}

ClipboardPlugin::~ClipboardPlugin() {
    GdiplusShutdown(gdiplusToken);
}

void ClipboardPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  if (method_call.method_name().compare("readClipboard") == 0) {
    flutter::EncodableMap map;
    
    HWND owner = GetClipboardOwner();
    if (owner) {
        DWORD processId;
        GetWindowThreadProcessId(owner, &processId);
        HANDLE hProcess = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, processId);
        if (hProcess) {
            WCHAR buffer[MAX_PATH];
            if (GetModuleFileNameExW(hProcess, NULL, buffer, MAX_PATH)) {
                std::wstring path(buffer);
                size_t pos = path.find_last_of(L"\\/");
                std::wstring name = (pos != std::wstring::npos) ? path.substr(pos + 1) : path;
                
                map[flutter::EncodableValue("sourceAppName")] = flutter::EncodableValue(utf8_encode(name));
                map[flutter::EncodableValue("sourceAppIdentifier")] = flutter::EncodableValue(utf8_encode(path));
            }
            CloseHandle(hProcess);
        }
    }
    
    if (OpenClipboard(nullptr)) {
        if (IsClipboardFormatAvailable(CF_UNICODETEXT)) {
            HANDLE hData = GetClipboardData(CF_UNICODETEXT);
            if (hData) {
                WCHAR* pszText = static_cast<WCHAR*>(GlobalLock(hData));
                if (pszText) {
                    map[flutter::EncodableValue("text")] = flutter::EncodableValue(utf8_encode(std::wstring(pszText)));
                    GlobalUnlock(hData);
                }
            }
        }
        
        if (IsClipboardFormatAvailable(CF_DIB) || IsClipboardFormatAvailable(CF_BITMAP)) {
            HANDLE hData = GetClipboardData(CF_BITMAP);
            if (!hData && IsClipboardFormatAvailable(CF_DIB)) {
                 hData = GetClipboardData(CF_DIB);
            }
            if (hData) {
                Bitmap* bmp = Bitmap::FromHBITMAP((HBITMAP)hData, NULL);
                if (bmp) {
                    IStream* pStream = NULL;
                    if (CreateStreamOnHGlobal(NULL, TRUE, &pStream) == S_OK) {
                        CLSID pngClsid;
                        GetEncoderClsid(L"image/png", &pngClsid);
                        bmp->Save(pStream, &pngClsid, NULL);
                        
                        STATSTG stat;
                        pStream->Stat(&stat, STATFLAG_NONAME);
                        ULONG size = stat.cbSize.LowPart;
                        
                        LARGE_INTEGER pos = {0};
                        pStream->Seek(pos, STREAM_SEEK_SET, NULL);
                        
                        std::vector<BYTE> buffer(size);
                        ULONG read;
                        pStream->Read(buffer.data(), size, &read);
                        
                        map[flutter::EncodableValue("imageBase64")] = flutter::EncodableValue(base64_encode(buffer.data(), read));
                        pStream->Release();
                    }
                    delete bmp;
                }
            }
        }
        CloseClipboard();
    }
    
    result->Success(flutter::EncodableValue(map));
  } else if (method_call.method_name().compare("writeImage") == 0) {
    std::string base64Str = "";
    if (const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments())) {
      if (auto it = args->find(flutter::EncodableValue("imageBase64")); it != args->end()) {
        base64Str = std::get<std::string>(it->second);
      }
    }
    if (!base64Str.empty()) {
        std::vector<BYTE> data = base64_decode(base64Str);
        IStream* pStream = NULL;
        if (CreateStreamOnHGlobal(NULL, TRUE, &pStream) == S_OK) {
            pStream->Write(data.data(), data.size(), NULL);
            Bitmap* bmp = Bitmap::FromStream(pStream);
            if (bmp) {
                HBITMAP hBitmap;
                bmp->GetHBITMAP(Color(0,0,0), &hBitmap);
                
                if (OpenClipboard(nullptr)) {
                    EmptyClipboard();
                    SetClipboardData(CF_BITMAP, hBitmap);
                    CloseClipboard();
                }
                DeleteObject(hBitmap);
                delete bmp;
            }
            pStream->Release();
        }
    }
    result->Success();
  } else {
    result->NotImplemented();
  }
}
