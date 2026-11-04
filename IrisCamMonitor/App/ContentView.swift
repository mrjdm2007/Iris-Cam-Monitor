import SwiftUI
import AppKit
import WebKit

struct ContentView: View {
    @AppStorage("monitorAddress") private var savedAddress = ""
    @State private var address = ""
    @State private var pin = ""
    @State private var connectedURL: URL?
    @State private var connectionMessage = "Enter the phone's local IP address and monitor PIN."
    @State private var isConnected = false

    var body: some View {
        VStack(spacing: 0) {
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

            HStack(spacing: 10) {
                Image(systemName: "network").foregroundStyle(.secondary)
                TextField("Phone IP address (e.g. 192.168.1.25:8080)", text: $address)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 240)
                    .onSubmit(connect)
                SecureField("Monitor PIN", text: $pin)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                    .onSubmit(connect)
                Button(action: connect) {
                    Label("Connect", systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.95, green: 0.62, blue: 0.0))
                .disabled(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pin.isEmpty)
                Button {
                    connectedURL = nil
                    isConnected = false
                    connectionMessage = "Disconnected."
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .help("Disconnect")
                .disabled(connectedURL == nil)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))

            if let url = connectedURL {
                MonitorWebView(url: url, onLoadChange: { loaded in
                    isConnected = loaded
                    connectionMessage = loaded ? "Monitor page loaded. Video and controls are provided by Iris Cam." : "Loading monitor…"
                })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "display.2").font(.system(size: 54, weight: .ultraLight)).foregroundStyle(.tertiary)
                    Text("Connect to your phone").font(.title2.weight(.semibold))
                    Text("Open the Monitor panel in Iris Cam, then enter the displayed IP address, port, and PIN.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 430)
                    Text("Both devices must be connected to the same Wi-Fi network.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack {
                Text(connectionMessage).font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Text("LOCAL NETWORK").font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { address = savedAddress }
    }

    private func connect() {
        let raw = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, !pin.isEmpty else { return }

        let normalized = raw
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard let url = URL(string: "http://\(normalized)/?pin=\(pin.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"),
              let host = url.host, !host.isEmpty,
              url.port == nil || (1...65535).contains(url.port!) else {
            connectionMessage = "Enter a valid phone IP address and optional port."
            return
        }

        savedAddress = normalized
        isConnected = false
        connectionMessage = "Connecting to \(host)…"
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
