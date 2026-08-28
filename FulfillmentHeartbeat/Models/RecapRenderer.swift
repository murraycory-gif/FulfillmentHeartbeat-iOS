import UIKit
import WebKit

struct RecapMedia {
    var images: [UIImage]
}

@MainActor
enum RecapRenderer {
    static func render(html: String) async -> RecapMedia {
        let width: CGFloat = 900
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: width, height: 1600))
        web.isOpaque = true
        web.backgroundColor = UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1)
        web.scrollView.backgroundColor = web.backgroundColor
        web.scrollView.isScrollEnabled = false
        web.scrollView.contentInsetAdjustmentBehavior = .never

        let host = UIView(frame: CGRect(x: -width - 40, y: 0, width: width, height: 1600))
        host.isUserInteractionEnabled = false
        host.addSubview(web)
        let window = PulseShare.topController()?.view.window
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)
        window?.addSubview(host)
        defer { host.removeFromSuperview() }

        let loader = RecapWebLoader()
        web.navigationDelegate = loader
        do {
            try await loader.load(html, in: web)
            try await Task.sleep(nanoseconds: 350_000_000)
            var images = await snapshotPages(web, width: width, host: host)
            if images.isEmpty, let fallback = await snapshot(web) {
                images = [fallback]
            }
            return RecapMedia(images: images)
        } catch {
            if let fallback = await snapshot(web) {
                return RecapMedia(images: [fallback])
            }
            return RecapMedia(images: [])
        }
    }

    private static func snapshotPages(_ web: WKWebView, width: CGFloat, host: UIView) async -> [UIImage] {
        let rects = await pageRects(web)
        if rects.isEmpty {
            let height = (try? await contentHeight(web)) ?? 1600
            return await sliceSnapshots(web, width: width, height: height, host: host)
        }
        var images: [UIImage] = []
        images.reserveCapacity(rects.count)
        for rect in rects {
            let height = min(max(rect.height + 8, 240), 8_000)
            web.frame = CGRect(x: 0, y: 0, width: width, height: height)
            host.frame.size = CGSize(width: width, height: height)
            web.scrollView.contentOffset = CGPoint(x: 0, y: max(rect.y - 4, 0))
            try? await Task.sleep(nanoseconds: 40_000_000)
            let config = WKSnapshotConfiguration()
            config.rect = CGRect(x: 0, y: 0, width: width, height: height)
            config.snapshotWidth = NSNumber(value: Double(width * 2))
            if let image = await snapshot(web, config: config) {
                images.append(image)
            }
        }
        return images
    }

    private static func sliceSnapshots(_ web: WKWebView, width: CGFloat, height: CGFloat, host: UIView) async -> [UIImage] {
        let slice = min(height, 1_800)
        web.frame = CGRect(x: 0, y: 0, width: width, height: slice)
        host.frame.size = CGSize(width: width, height: slice)
        var images: [UIImage] = []
        var offset: CGFloat = 0
        while offset < height - 8 {
            web.scrollView.contentOffset = CGPoint(x: 0, y: offset)
            try? await Task.sleep(nanoseconds: 30_000_000)
            let config = WKSnapshotConfiguration()
            config.rect = CGRect(x: 0, y: 0, width: width, height: min(slice, height - offset))
            config.snapshotWidth = NSNumber(value: Double(width * 2))
            if let image = await snapshot(web, config: config) {
                images.append(image)
            }
            offset += slice - 24
        }
        return images
    }

    private struct PageRect { var y: CGFloat; var height: CGFloat }

    private static func pageRects(_ web: WKWebView) async -> [PageRect] {
        let js = """
        JSON.stringify(Array.from(document.querySelectorAll('.page')).map(function(el) {
          var r = el.getBoundingClientRect();
          return { y: r.top + window.scrollY, h: r.height };
        }))
        """
        guard let raw = try? await web.evaluateJavaScript(js) as? String,
              let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }
        return json.compactMap { row in
            let y = (row["y"] as? NSNumber)?.doubleValue ?? 0
            let h = (row["h"] as? NSNumber)?.doubleValue ?? 0
            guard h > 40 else { return nil }
            return PageRect(y: CGFloat(y), height: CGFloat(h))
        }
    }

    private static func contentHeight(_ web: WKWebView) async throws -> CGFloat {
        let raw = try await web.evaluateJavaScript("Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)")
        if let number = raw as? CGFloat { return number }
        if let number = raw as? Double { return CGFloat(number) }
        if let number = raw as? Int { return CGFloat(number) }
        return 1600
    }

    private static func snapshot(_ web: WKWebView, config: WKSnapshotConfiguration? = nil) async -> UIImage? {
        await withCheckedContinuation { cont in
            web.takeSnapshot(with: config) { image, _ in
                cont.resume(returning: image)
            }
        }
    }
}

private final class RecapWebLoader: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?

    func load(_ html: String, in web: WKWebView) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            continuation = cont
            DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
                self?.finish(.failure(URLError(.timedOut)))
            }
            web.loadHTMLString(html, baseURL: nil)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finish(.success(()))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }

    private func finish(_ result: Result<Void, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}
