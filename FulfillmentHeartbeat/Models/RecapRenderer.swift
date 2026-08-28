import UIKit
import WebKit
import PDFKit

struct RecapMedia {
    var images: [UIImage]
    var pdf: URL?
}

@MainActor
enum RecapRenderer {
    static func render(html: String) async -> RecapMedia {
        let width: CGFloat = 900
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: width, height: 1400))
        web.isOpaque = true
        web.backgroundColor = UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1)
        web.scrollView.backgroundColor = web.backgroundColor
        web.scrollView.isScrollEnabled = false

        let host = UIView(frame: CGRect(x: -width, y: 0, width: width, height: 1400))
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
            try await Task.sleep(nanoseconds: 250_000_000)
            let height = try await contentHeight(web)
            let tall = min(max(height + 24, 800), 24_000)
            web.frame = CGRect(x: 0, y: 0, width: width, height: tall)
            host.frame.size.height = tall
            web.scrollView.contentSize = CGSize(width: width, height: tall)

            let pdfData = try await pdfData(from: web, width: width, height: tall)
            let pdfURL = FileManager.default.temporaryDirectory.appendingPathComponent("Fulfillment-Heartbeat.pdf")
            try pdfData.write(to: pdfURL, options: .atomic)
            let images = pageImages(from: pdfData)
            if images.isEmpty, let fallback = await snapshot(web) {
                return RecapMedia(images: [fallback], pdf: pdfURL)
            }
            return RecapMedia(images: images, pdf: pdfURL)
        } catch {
            if let fallback = await snapshot(web) {
                return RecapMedia(images: [fallback], pdf: nil)
            }
            return RecapMedia(images: [], pdf: nil)
        }
    }

    private static func contentHeight(_ web: WKWebView) async throws -> CGFloat {
        let raw = try await web.evaluateJavaScript("Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)")
        if let number = raw as? CGFloat { return number }
        if let number = raw as? Double { return CGFloat(number) }
        if let number = raw as? Int { return CGFloat(number) }
        return 1400
    }

    private static func pdfData(from web: WKWebView, width: CGFloat, height: CGFloat) async throws -> Data {
        try await withCheckedThrowingContinuation { cont in
            let config = WKPDFConfiguration()
            config.rect = CGRect(x: 0, y: 0, width: width, height: height)
            web.createPDF(configuration: config) { result in
                cont.resume(with: result)
            }
        }
    }

    private static func snapshot(_ web: WKWebView) async -> UIImage? {
        await withCheckedContinuation { cont in
            web.takeSnapshot(with: nil) { image, _ in
                cont.resume(returning: image)
            }
        }
    }

    private static func pageImages(from data: Data) -> [UIImage] {
        guard let doc = PDFDocument(data: data) else { return [] }
        var images: [UIImage] = []
        images.reserveCapacity(doc.pageCount)
        for index in 0..<doc.pageCount {
            guard let page = doc.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let maxSide: CGFloat = 1600
            let scale = min(maxSide / max(bounds.width, 1), maxSide / max(bounds.height, 1), 2)
            let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
            let image = page.thumbnail(of: size, for: .mediaBox)
            if image.size.width > 8, image.size.height > 8 {
                images.append(image)
            }
        }
        return images
    }

    nonisolated static func writeEML(subject: String, html: String, images: [UIImage]) -> URL? {
        let boundary = "HB-\(UUID().uuidString.prefix(8))"
        var htmlBody = html
        if !images.isEmpty {
            let imgs = images.enumerated().map { index, _ in
                "<img src=\"cid:page\(index)\" alt=\"Heartbeat page \(index + 1)\" style=\"width:100%;max-width:900px;display:block;margin:0 0 18px;border:0\" />"
            }.joined()
            htmlBody = "<html><body style=\"margin:0;padding:16px;background:#F5F7FC\">\(imgs)</body></html>"
        }
        var eml = ""
        eml += "X-Unsent: 1\r\n"
        eml += "Subject: \(subject.replacingOccurrences(of: "\r", with: "").replacingOccurrences(of: "\n", with: " "))\r\n"
        eml += "MIME-Version: 1.0\r\n"
        eml += "Content-Type: multipart/related; type=\"text/html\"; boundary=\"\(boundary)\"\r\n\r\n"
        eml += "--\(boundary)\r\n"
        eml += "Content-Type: text/html; charset=utf-8\r\n"
        eml += "Content-Transfer-Encoding: 8bit\r\n\r\n"
        eml += htmlBody
        eml += "\r\n"
        for (index, image) in images.enumerated() {
            guard let jpeg = image.jpegData(compressionQuality: 0.78) else { continue }
            eml += "--\(boundary)\r\n"
            eml += "Content-Type: image/jpeg\r\n"
            eml += "Content-Transfer-Encoding: base64\r\n"
            eml += "Content-ID: <page\(index)>\r\n"
            eml += "Content-Disposition: inline; filename=\"heartbeat-page-\(index + 1).jpg\"\r\n\r\n"
            eml += jpeg.base64EncodedString(options: [.lineLength76Characters, .endLineWithCarriageReturn])
            eml += "\r\n"
        }
        eml += "--\(boundary)--\r\n"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Fulfillment-Heartbeat.eml")
        do {
            try eml.data(using: .utf8)?.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
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
