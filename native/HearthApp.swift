import SwiftUI
import WebKit
import HomeKit

@main
struct HearthApp: App {
    var body: some Scene {
        WindowGroup { DashboardView().preferredColorScheme(.dark) }
    }
}

struct DashboardView: UIViewRepresentable {
    func makeCoordinator() -> HomeBridge { HomeBridge() }
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "homekit")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.086, green: 0.106, blue: 0.098, alpha: 1)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "dist") {
            context.coordinator.assetRoot = url.deletingLastPathComponent()
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    static func dismantleUIView(_ uiView: WKWebView, coordinator: HomeBridge) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "homekit")
    }
}

// A read-only bridge: no characteristic writes, scene execution, or camera access.
final class HomeBridge: NSObject, WKScriptMessageHandler, WKNavigationDelegate, HMHomeManagerDelegate {
    weak var webView: WKWebView?
    var assetRoot: URL?
    private var homeManager: HMHomeManager?
    private var homesReady = false
    private var inventoryRequested = false
    private var timeout: DispatchWorkItem?

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame,
              let url = message.frameInfo.request.url, isBundled(url),
              let body = message.body as? [String: Any], body["action"] as? String == "inventory" else { return }
        inventoryRequested = true
        if let manager = homeManager {
            if manager.authorizationStatus.contains(.restricted) {
                send(["error": "Home access is restricted on this device."])
            } else if manager.authorizationStatus.contains(.determined) && !manager.authorizationStatus.contains(.authorized) {
                send(["error": "Allow Hearth to access Home data in Settings, then try again."])
            } else if homesReady { sendInventory() }
        } else {
            let manager = HMHomeManager()
            homeManager = manager
            manager.delegate = self
        }
        if inventoryRequested {
            timeout?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self = self, self.inventoryRequested else { return }
                self.send(["error": "Home data is not ready. Check permission and your Apple Home setup, then try again."])
            }
            timeout = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: work)
        }
    }

    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        homesReady = true
        if inventoryRequested { sendInventory() }
    }
    func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        if status.contains(.determined) && !status.contains(.authorized) && inventoryRequested {
            send(["error": "Home access was not granted. Enable it for Hearth in Settings to read your accessories."])
        } else if status.contains(.authorized) && homesReady && inventoryRequested { sendInventory() }
    }

    private func sendInventory() {
        guard let manager = homeManager else { return }
        guard manager.authorizationStatus.contains(.authorized) else {
            send(["error": "Home data access has not been granted."]); return
        }
        let homes: [[String: Any]] = manager.homes.map { home in
            let accessories: [[String: Any]] = home.accessories.map { accessory in
                let services: [[String: Any]] = accessory.services.map { service in
                    ["name": service.name, "type": service.serviceType,
                     "characteristics": service.characteristics.map { characteristic in
                        ["id": characteristic.uniqueIdentifier.uuidString,
                         "type": characteristic.characteristicType,
                         "properties": characteristic.properties] as [String: Any]
                     }] as [String: Any]
                }
                return ["id": accessory.uniqueIdentifier.uuidString,
                        "name": accessory.name, "room": accessory.room?.name ?? "Unassigned",
                        "reachable": accessory.isReachable,
                        "services": accessory.services.map { $0.name }, "capabilities": services]
            }
            return ["id": home.uniqueIdentifier.uuidString, "name": home.name,
                    "accessories": accessories,
                    "scenes": home.actionSets.map { ["id": $0.uniqueIdentifier.uuidString, "name": $0.name] }]
        }
        send(["homes": homes])
    }
    private func send(_ payload: [String: Any]) {
        inventoryRequested = false
        timeout?.cancel()
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        // Encode the JSON as a JS string literal before parsing it in the page.
        guard let quotedData = try? JSONSerialization.data(withJSONObject: [json]),
              let quotedArray = String(data: quotedData, encoding: .utf8) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript("window.hearthReceiveInventory(JSON.parse(\(quotedArray)[0]));", completionHandler: nil)
        }
    }
    private func isBundled(_ url: URL) -> Bool {
        guard url.isFileURL, let root = assetRoot?.standardizedFileURL.path else { return false }
        return url.standardizedFileURL.path.hasPrefix(root + "/")
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url, isBundled(url) else { decisionHandler(.cancel); return }
        decisionHandler(.allow)
    }
}
