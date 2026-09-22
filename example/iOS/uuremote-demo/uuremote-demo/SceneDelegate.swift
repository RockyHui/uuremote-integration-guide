
//  SceneDelegate.swift
//  uuremote-demo
//
//  Scene 生命周期 + UU 远程 URL 回调入口（UISceneDelegate 模式）
//
//  使用 UISceneDelegate 的 App，URL Scheme 回调由
//  scene(_:openURLContexts:) 接收，而非 AppDelegate.application(_:open:options:)。
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let _ = (scene as? UIWindowScene) else { return }
        // App 未运行时通过 URL 冷启动
        if let url = connectionOptions.urlContexts.first?.url {
            handleUURemoteCallback(url: url)
        }
    }

    /// App 已在前台或后台时，通过 URL Scheme 唤起（热启动回调入口）
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let url = URLContexts.first?.url {
            handleUURemoteCallback(url: url)
        }
    }

    // MARK: - UU 远程回调解析

    /// 解析 UU 远程回调 URL，post NotificationCenter 通知给 ViewController
    @discardableResult
    private func handleUURemoteCallback(url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }
        let params = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
                item.value.map { (item.name, $0) }
            }
        )
        switch url.host {
        case "bind_uuremote":
            // 协议文档 §2.5：成功带 anonymous_device_id，失败带 error
            NotificationCenter.default.post(
                name: .uuRemoteBindCallback,
                object: nil,
                userInfo: params
            )
            return true
        case "control_uuremote":
            // 协议文档 §3.5：status=success / status=failure&reason=...
            NotificationCenter.default.post(
                name: .uuRemoteControlCallback,
                object: nil,
                userInfo: params
            )
            return true
        default:
            return false
        }
    }

    // MARK: - 其余生命周期（保留空实现）

    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
}
