#ifndef WINDOW_PLUGIN_H_
#define WINDOW_PLUGIN_H_

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>

#include <memory>
#include <string>

class WindowPlugin {
 public:
  static void RegisterWithMessenger(flutter::BinaryMessenger* messenger);

  WindowPlugin();
  ~WindowPlugin();

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

#endif  // WINDOW_PLUGIN_H_
