import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = self.registrar(forPlugin: "HammeShareStory") {
      let channel = FlutterMethodChannel(
        name: "hamme/share_story",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler(handleShareStory)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handleShareStory(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isInstagramInstalled":
      result(canOpen("instagram-stories://share"))
    case "isSnapchatInstalled":
      result(canOpen("snapchat://"))
    case "shareToInstagramStory":
      guard let args = call.arguments as? [String: Any],
            let imagePath = args["imagePath"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "imagePath is required", details: nil))
        return
      }
      // Instagram requires the Meta App ID; it is set as MetaAppID in Info.plist.
      guard let appId = Bundle.main.object(forInfoDictionaryKey: "MetaAppID") as? String,
            Int(appId) != nil else {
        NSLog("Instagram Stories disabled: MetaAppID missing or invalid in Info.plist")
        result("NOT_CONFIGURED")
        return
      }
      shareToInstagramStory(
        imagePath: imagePath,
        appId: appId,
        attributionUrl: args["attributionUrl"] as? String,
        result: result
      )
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func canOpen(_ urlString: String) -> Bool {
    guard let url = URL(string: urlString) else { return false }
    return UIApplication.shared.canOpenURL(url)
  }

  // Instagram reads the story from the pasteboard. Only real Data values may be
  // set: empty placeholders for unused keys (sticker/video) make Instagram open
  // with a blank story or reject the share.
  private func shareToInstagramStory(
    imagePath: String,
    appId: String,
    attributionUrl: String?,
    result: @escaping FlutterResult
  ) {
    guard let url = URL(string: "instagram-stories://share?source_application=\(appId)"),
          UIApplication.shared.canOpenURL(url) else {
      result("NOT_INSTALLED")
      return
    }
    guard let imageData = FileManager.default.contents(atPath: imagePath) else {
      result(FlutterError(code: "IMAGE_ERROR", message: "Could not read story image", details: nil))
      return
    }

    var item: [String: Any] = [
      "com.instagram.sharedSticker.backgroundImage": imageData,
      "com.instagram.sharedSticker.backgroundTopColor": "#9F6FFF",
      "com.instagram.sharedSticker.backgroundBottomColor": "#9F6FFF",
    ]
    if let attributionUrl = attributionUrl, !attributionUrl.isEmpty {
      item["com.instagram.sharedSticker.contentURL"] = attributionUrl
    }

    UIPasteboard.general.setItems(
      [item],
      options: [.expirationDate: Date().addingTimeInterval(60 * 5)]
    )
    UIApplication.shared.open(url, options: [:]) { opened in
      result(opened ? "SUCCESS" : "OPEN_FAILED")
    }
  }
}
