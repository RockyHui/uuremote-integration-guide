
//  ViewController.swift
//  uuremote-demo
//
//  演示如何通过 URL Scheme 与 UU 远程客户端交互，包含：
//    1. 安装检测
//    2. 设备绑定  -> uuremote://external/device/authorize
//    3. 发起远控（全屏 / 小窗）-> uuremote://external/device/control
//    4. 回调解析（AppDelegate.swift 中接收，通知到本页）
//
//  协议参考：《UU远程》移动端远控互动接入技术文档 V1
//

import UIKit

// MARK: - 回调通知名

extension Notification.Name {
    static let uuRemoteBindCallback    = Notification.Name("uuRemoteBindCallback")
    static let uuRemoteControlCallback = Notification.Name("uuRemoteControlCallback")
}

// MARK: - ViewController

class ViewController: UIViewController {

    // MARK: - 常量

    /// UU 远程 URL Scheme
    private let uuremoteScheme = "uuremote"
    /// 本 demo App 注册的 URL Scheme（需与 Info.plist 中 CFBundleURLSchemes 一致）
    private let demoScheme     = "uuremote-demo"

    // MARK: - 持久化

    private var boundDeviceId: String? {
        get { UserDefaults.standard.string(forKey: "demo_bound_device_id") }
        set {
            UserDefaults.standard.set(newValue, forKey: "demo_bound_device_id")
            DispatchQueue.main.async { self.refreshUI() }
        }
    }

    // MARK: - UI

    private let stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 16
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var bindButton         = makeButton(title: "绑定 UU 远程设备",   color: .systemBlue)
    private lazy var fullscreenButton   = makeButton(title: "发起远控（全屏）",   color: .systemGreen)
    private lazy var smallWindowButton  = makeButton(title: "发起远控（小窗）",   color: .systemOrange)
    private lazy var clearButton        = makeButton(title: "清除已绑定设备",     color: .systemRed)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "UU 远程接入 Demo"
        view.backgroundColor = .systemBackground
        setupLayout()
        refreshUI()
        observeCallbacks()
    }

    // MARK: - Layout

    private func setupLayout() {
        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])

        [statusLabel, bindButton, fullscreenButton, smallWindowButton, clearButton].forEach {
            stackView.addArrangedSubview($0)
        }

        bindButton.addTarget(self, action: #selector(bindTapped), for: .touchUpInside)
        fullscreenButton.addTarget(self, action: #selector(fullscreenTapped), for: .touchUpInside)
        smallWindowButton.addTarget(self, action: #selector(smallWindowTapped), for: .touchUpInside)
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
    }

    private func makeButton(title: String, color: UIColor) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = color
        btn.layer.cornerRadius = 10
        btn.layer.masksToBounds = true
        btn.heightAnchor.constraint(equalToConstant: 48).isActive = true
        return btn
    }

    private func refreshUI() {
        if let deviceId = boundDeviceId {
            statusLabel.text = "已绑定设备\n\(deviceId)"
            fullscreenButton.isEnabled = true
            smallWindowButton.isEnabled = true
            clearButton.isEnabled = true
        } else {
            statusLabel.text = "尚未绑定设备"
            fullscreenButton.isEnabled = false
            smallWindowButton.isEnabled = false
            clearButton.isEnabled = false
        }
    }

    // MARK: - 安装检测

    /// 协议文档 §1.1 / §1.2：iOS 需在 Info.plist 添加 LSApplicationQueriesSchemes -> uuremote
    private func isUURemoteInstalled() -> Bool {
        guard let url = URL(string: "\(uuremoteScheme)://external") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    // MARK: - 绑定

    /// 协议文档 §2.1-§2.3
    @objc private func bindTapped() {
        guard isUURemoteInstalled() else {
            showAlert(title: "未安装 UU 远程", message: "请先在 App Store 安装 UU 远程后重试。")
            return
        }
        let nonce = UUID().uuidString
        let callback = "\(demoScheme)://bind_uuremote"
        guard let encodedCallback = callback.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(uuremoteScheme)://external/device/authorize?callback=\(encodedCallback)&nonce=\(nonce)") else {
            return
        }
        UIApplication.shared.open(url)
    }

    // MARK: - 发起远控

    /// 协议文档 §3.1-§3.4  window_type: 0=全屏 1=小窗
    @objc private func fullscreenTapped() {
        openControl(windowType: 0)
    }

    @objc private func smallWindowTapped() {
        openControl(windowType: 1)
    }

    private func openControl(windowType: Int) {
        guard isUURemoteInstalled() else {
            showAlert(title: "未安装 UU 远程", message: "请先在 App Store 安装 UU 远程后重试。")
            return
        }
        guard let deviceId = boundDeviceId, !deviceId.isEmpty else {
            showAlert(title: "未绑定设备", message: "请先绑定设备后再发起远控。")
            return
        }
        let callback = "\(demoScheme)://control_uuremote"
        guard let encodedDeviceId = deviceId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedCallback = callback.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(uuremoteScheme)://external/device/control?anonymous_device_id=\(encodedDeviceId)&window_type=\(windowType)&callback=\(encodedCallback)") else {
            return
        }
        UIApplication.shared.open(url)
    }

    // MARK: - 清除绑定

    @objc private func clearTapped() {
        boundDeviceId = nil
        showToast("已清除绑定设备")
    }

    // MARK: - 回调处理（由 AppDelegate 解析后 post 通知）

    private func observeCallbacks() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBindCallback(_:)),
            name: .uuRemoteBindCallback,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleControlCallback(_:)),
            name: .uuRemoteControlCallback,
            object: nil
        )
    }

    /// 协议文档 §2.5：绑定回调
    @objc private func handleBindCallback(_ notification: Notification) {
        guard let params = notification.userInfo as? [String: String] else { return }
        if let deviceId = params["anonymous_device_id"] {
            boundDeviceId = deviceId
            showToast("绑定成功\n\(deviceId)")
        } else {
            let error = params["error"] ?? "unknown"
            showToast("绑定失败：\(failureReasonText(error))")
        }
    }

    /// 协议文档 §3.5：远控回调
    @objc private func handleControlCallback(_ notification: Notification) {
        guard let params = notification.userInfo as? [String: String] else { return }
        if params["status"] == "success" {
            showToast("远控连接成功")
        } else {
            let reason = params["reason"] ?? "unknown"
            // device_not_found：设备标识已失效，需重新绑定（协议文档 §3.7）
            if reason == "device_not_found" {
                boundDeviceId = nil
                showAlert(title: "设备不存在", message: "设备标识已失效（可能已切换账号或解绑），请重新绑定设备。")
            } else {
                showToast("远控失败：\(failureReasonText(reason))")
            }
        }
    }

    // MARK: - 失败原因映射（协议文档 §3.5 / §2.5）

    private func failureReasonText(_ reason: String) -> String {
        let map: [String: String] = [
            // 远控 reason
            "busy":                "设备正在被其他控制端使用",
            "device_offline":      "被控端已离线",
            "device_not_found":    "设备不存在或标识已失效",
            "not_allowed":         "设备不允许被远控",
            "pip_unsupported":     "设备不支持小窗（PiP）",
            "login_timeout":       "等待登录超时",
            "network_unavailable": "网络不可用",
            "connect_timeout":     "连接超时",
            "connect_failed":      "连接失败",
            "user_cancel":         "用户取消",
            "invalid_request":     "请求参数非法",
            "internal_error":      "端内异常",
            // 绑定 error
            "timeout":             "等待超时",
            "not_logined":         "未登录或首页未就绪",
            "superseded":          "已被新的同类请求取代",
            "logout":              "排队期间已退出登录",
            "no_device":           "无可绑定的 Windows/macOS 设备",
        ]
        return map[reason] ?? reason
    }

    // MARK: - 辅助 UI

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }

    private func showToast(_ message: String) {
        DispatchQueue.main.async {
            let label = UILabel()
            label.text = message
            label.font = .systemFont(ofSize: 14)
            label.textColor = .white
            label.backgroundColor = UIColor.black.withAlphaComponent(0.75)
            label.textAlignment = .center
            label.numberOfLines = 0
            label.layer.cornerRadius = 8
            label.layer.masksToBounds = true
            label.translatesAutoresizingMaskIntoConstraints = false

            guard let window = self.view.window else { return }
            window.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: window.centerXAnchor),
                label.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -40),
                label.widthAnchor.constraint(lessThanOrEqualTo: window.widthAnchor, multiplier: 0.8),
                label.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),
            ])
            label.layoutIfNeeded()

            UIView.animate(withDuration: 0.3, delay: 2.5, options: [], animations: {
                label.alpha = 0
            }, completion: { _ in
                label.removeFromSuperview()
            })
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
