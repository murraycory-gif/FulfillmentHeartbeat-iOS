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

    static func jpegFiles(_ images: [UIImage]) -> [URL] {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("hb-recap", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return inlineImages(images).enumerated().compactMap { index, image in
            let url = dir.appendingPathComponent("heartbeat-page-\(index + 1).jpg")
            guard let data = image.jpegData(compressionQuality: 0.72) else { return nil }
            try? data.write(to: url, options: .atomic)
            return url
        }
    }

    static func inlineImages(_ images: [UIImage]) -> [UIImage] {
        stacked(images, maxHeight: 7_200).map { scale($0, maxWidth: 1080) }
    }

    private static func stacked(_ images: [UIImage], maxHeight: CGFloat) -> [UIImage] {
        guard !images.isEmpty else { return [] }
        var tiles: [UIImage] = []
        var bucket: [UIImage] = []
        var height: CGFloat = 0
        let gap: CGFloat = 16
        for image in images {
            let next = height == 0 ? image.size.height : height + gap + image.size.height
            if !bucket.isEmpty, next > maxHeight {
                tiles.append(stack(bucket, gap: gap))
                bucket = [image]
                height = image.size.height
            } else {
                bucket.append(image)
                height = next
            }
        }
        if !bucket.isEmpty { tiles.append(stack(bucket, gap: gap)) }
        return tiles
    }

    private static func stack(_ images: [UIImage], gap: CGFloat) -> UIImage {
        guard let first = images.first else { return UIImage() }
        if images.count == 1 { return first }
        let width = images.map(\.size.width).max() ?? first.size.width
        let height = images.reduce(0) { $0 + $1.size.height } + gap * CGFloat(images.count - 1)
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            var y: CGFloat = 0
            for image in images {
                let x = (width - image.size.width) / 2
                image.draw(in: CGRect(x: x, y: y, width: image.size.width, height: image.size.height))
                y += image.size.height + gap
            }
        }
    }

    private static func scale(_ image: UIImage, maxWidth: CGFloat) -> UIImage {
        guard image.size.width > maxWidth, image.size.width > 0 else { return image }
        let ratio = maxWidth / image.size.width
        let size = CGSize(width: maxWidth, height: image.size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
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
