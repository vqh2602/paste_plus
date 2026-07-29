#ifndef CLIPBOARD_PLUGIN_H_
#define CLIPBOARD_PLUGIN_H_

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>

#include <memory>

class ClipboardPlugin {
 public:
  static void RegisterWithMessenger(flutter::BinaryMessenger* messenger);

  ClipboardPlugin();
  ~ClipboardPlugin();

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

#endif  // CLIPBOARD_PLUGIN_H_
