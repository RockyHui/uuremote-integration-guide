
//  AppDelegate.swift
//  uuremote-demo
//
//  处理 UU 远程回调（URL Scheme）：
//    - uuremote-demo://bind_uuremote   -> 设备绑定回调（协议文档 §2.5 / §2.6）
//    - uuremote-demo://control_uuremote -> 远控结果回调（协议文档 §3.5 / §3.7）
//
//  解析完成后通过 NotificationCenter 通知 ViewController。
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(
        _ application: UIApplication,
        didDiscardSceneSessions sceneSessions: Set<UISceneSession>
    ) {}

    // MARK: - URL 回调处理

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return handleUURemoteCallback(url: url)
    }

    // MARK: - 回调解析

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
            // 协议文档 §2.5：anonymous_device_id 表示成功，error 表示失败
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
}
