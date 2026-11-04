import SwiftUI
import AppKit
import WebKit

private enum ConnectionMode: String, CaseIterable, Identifiable {
    case wireless = "Wireless"
    case wired = "Wired (USB)"
    var id: String { rawValue }
}

struct ContentView: View {
    @AppStorage("monitorAddress") private var savedAddress = ""
    @AppStorage("monitorPhonePort") private var savedPhonePort = "8080"
    @AppStorage("monitorLocalPort") private var savedLocalPort = "18080"
    @State private var mode: ConnectionMode = .wireless
    @State private var address = ""
    @State private var phonePort = "8080"
    @State private var localPort = "18080"
    @State private var pin = ""
    @State private var connectedURL: URL?
    @State private var connectionMessage = "Choose a connection type and enter the monitor details."
    @State private var isConnected = false

    private var canConnect: Bool {
        !pin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (mode == .wireless
            ? !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            : validPort(phonePort) && validPort(localPort))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 12) {
                Picker("Connection", selection: $mode) {
                    ForEach(ConnectionMode.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: mode) { _ in
                    disconnect(message: mode == .wireless
                        ? "Wireless mode selected. Use the phone's Wi-Fi address and PIN."
                        : "Wired mode selected. Connect USB, enable USB debugging, then apply the ADB reverse command.")
                }

                if mode == .wireless {
                    HStack(spacing: 10) {
                        Image(systemName: "wifi").foregroundStyle(.secondary)
                        TextField("Phone IP address (e.g. 192.168.1.25:8080)", text: $address)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(connect)
                    }
                    Text("Connect the Mac and phone to the same Wi-Fi network. Copy the Wi-Fi URL from Iris Cam.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "cable.connector").foregroundStyle(.secondary)
                        TextField("Phone monitor port (from Iris Cam)", text: $phonePort)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity)
                        TextField("Mac local port", text: $localPort)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 130)
                    }
                    Text("Connect USB and enable USB debugging. Use the phone port shown in Iris Cam. The Mac port defaults to 18080 to avoid the commonly occupied 8080.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Text("Run this in Mac Terminal:")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(adbCommand, forType: .string)
                            connectionMessage = "ADB reverse command copied. Run it in Terminal before connecting."
                        } label: {
                            Label("Copy ADB command", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                    }
                    Text(adbCommand)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    Text("After running the command, connect using localhost:\(localPort). If the Mac port is occupied, change it above, copy the updated command, and run it again.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    SecureField("Monitor PIN", text: $pin)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(connect)
                    Button(action: connect) {
                        Label("Connect", systemImage: "arrow.right.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.95, green: 0.62, blue: 0.0))
                    .disabled(!canConnect)
                    Button {
                        disconnect(message: "Disconnected.")
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .help("Disconnect")
                    .disabled(connectedURL == nil)
                }
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))

            if let url = connectedURL {
                MonitorWebView(url: url, onLoadChange: { loaded in
                    isConnected = loaded
                    connectionMessage = loaded
                        ? "Monitor page loaded. Video and controls are provided by Iris Cam."
                        : "Could not load monitor. Check the address, port, PIN, ADB reverse, and that Monitor is running."
                })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 14) {
                    Image(systemName: mode == .wireless ? "wifi" : "cable.connector")
                        .font(.system(size: 54, weight: .ultraLight))
                        .foregroundStyle(.tertiary)
                    Text(mode == .wireless ? "Connect over Wi-Fi" : "Connect over USB")
                        .font(.title2.weight(.semibold))
                    Text(mode == .wireless
                         ? "Enter the phone's Wi-Fi address and monitor PIN shown in Iris Cam."
                         : "Enter the phone's monitor port and PIN. Run the generated ADB reverse command first.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 440)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack {
                Text(connectionMessage).font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Text(mode == .wireless ? "WIRELESS" : "USB ADB")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 680, minHeight: 500)
        .onAppear {
            address = savedAddress
            phonePort = savedPhonePort
            localPort = savedLocalPort
        }
        .onChange(of: address) { savedAddress = $0 }
        .onChange(of: phonePort) { savedPhonePort = $0 }
        .onChange(of: localPort) { savedLocalPort = $0 }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(Color(red: 1, green: 0.70, blue: 0.0))
            VStack(alignment: .leading, spacing: 2) {
                Text("IRIS CAM").font(.system(size: 14, weight: .heavy, design: .rounded)).tracking(2)
                Text("MAC MONITOR").font(.system(size: 10, weight: .medium)).tracking(1.5).foregroundStyle(.secondary)
            }
            Spacer()
            Circle().fill(isConnected ? .green : .gray).frame(width: 8, height: 8)
            Text(isConnected ? "CONNECTED" : "NOT CONNECTED")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var adbCommand: String {
        "adb reverse tcp:\(localPort) tcp:\(phonePort)"
    }

    private func validPort(_ value: String) -> Bool {
        guard let port = Int(value) else { return false }
        return (1...65535).contains(port)
    }

    private func disconnect(message: String) {
        connectedURL = nil
        isConnected = false
        connectionMessage = message
    }

    private func connect() {
        guard !pin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let hostAndPort: String
        if mode == .wireless {
            let raw = address.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = raw
                .replacingOccurrences(of: "http://", with: "")
                .replacingOccurrences(of: "https://", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard let candidate = URL(string: "http://\(normalized)"),
                  let host = candidate.host, !host.isEmpty,
                  candidate.port == nil || validPort(String(candidate.port!)) else {
                connectionMessage = "Enter a valid phone IP address with its monitor port."
                return
            }
            hostAndPort = normalized
        } else {
            guard validPort(phonePort), validPort(localPort) else {
                connectionMessage = "Both USB ports must be numbers between 1 and 65535."
                return
            }
            hostAndPort = "localhost:\(localPort)"
        }

        guard let url = URL(string: "http://\(hostAndPort)/?pin=\(pin.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
            connectionMessage = "Could not create a valid monitor address."
            return
        }

        isConnected = false
        connectionMessage = "Connecting to \(url.host ?? hostAndPort)…"
        connectedURL = url
    }
}

private struct MonitorWebView: NSViewRepresentable {
    let url: URL
    let onLoadChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onLoadChange: onLoadChange) }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsAirPlayForMediaPlayback = true
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15))
        return view
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onLoadChange: (Bool) -> Void
        init(onLoadChange: @escaping (Bool) -> Void) { self.onLoadChange = onLoadChange }
        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if let response = navigationResponse.response as? HTTPURLResponse,
               !(200...299).contains(response.statusCode) {
                onLoadChange(false)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onLoadChange(true)
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onLoadChange(false)
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            onLoadChange(false)
        }
    }
}
