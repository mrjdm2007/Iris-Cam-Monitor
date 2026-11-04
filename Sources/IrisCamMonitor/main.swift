import SwiftUI
import WebKit

@main
struct IrisCamMonitorApp: App {
    var body: some Scene {
        WindowGroup {
            MonitorRootView()
                .frame(minWidth: 980, minHeight: 680)
        }
        .windowStyle(.titleBar)
    }
}

struct MonitorRootView: View {
    @AppStorage("monitor.host") private var savedHost = ""
    @State private var host = ""
    @State private var pin = ""
    @State private var connectedURL: URL?
    @State private var errorText: String?

    var body: some View {
        Group {
            if let url = connectedURL {
                VStack(spacing: 0) {
                    HStack {
                        Label("IRIS CAM", systemImage: "camera.aperture")
                            .font(.headline)
                            .foregroundStyle(.orange)
                        Text(url.host ?? url.absoluteString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Reconnect") { connectedURL = url }
                        Button("Disconnect") { connectedURL = nil }
                    }
                    .padding(12)
                    Divider()
                    MonitorWebView(url: url)
                }
            } else {
                connectionScreen
            }
        }
        .onAppear {
            if host.isEmpty { host = savedHost }
        }
    }

    private var connectionScreen: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.orange)
            Text("Iris Cam Monitor")
                .font(.largeTitle.weight(.semibold))
            Text("Connect to the monitor server running inside Iris Cam.")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 10) {
                Text("PHONE ADDRESS").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                TextField("http://192.168.1.20:8080", text: $host)
                    .textFieldStyle(.roundedBorder)
                Text("MONITOR PIN").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                SecureField("PIN shown in Iris Cam", text: $pin)
                    .textFieldStyle(.roundedBorder)
                if let errorText {
                    Text(errorText).font(.caption).foregroundStyle(.red)
                }
                Button(action: connect) {
                    Text("Connect").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pin.isEmpty)
            }
            .frame(maxWidth: 360)
            Divider().frame(maxWidth: 360)
            Text("USB: run adb reverse tcp:8080 tcp:8080, then enter http://localhost:8080")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .padding(36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func connect() {
        errorText = nil
        let raw = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = raw.contains("://") ? raw : "http://" + raw
        guard var components = URLComponents(string: candidate),
              let scheme = components.scheme, scheme == "http" || scheme == "https",
              components.host != nil else {
            errorText = "Enter a valid phone address, including its port (usually 8080)."
            return
        }
        components.path = "/"
        components.queryItems = (components.queryItems ?? []).filter { $0.name != "pin" }
        components.queryItems?.append(URLQueryItem(name: "pin", value: pin))
        guard let url = components.url else {
            errorText = "The address could not be opened."
            return
        }
        savedHost = raw
        connectedURL = url
    }
}

struct MonitorWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero)
        view.allowsBackForwardNavigationGestures = true
        view.load(URLRequest(url: url))
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        if view.url != url { view.load(URLRequest(url: url)) }
    }
}
