#if targetEnvironment(macCatalyst)
import AppKit
#endif
import Foundation

/// Mac Catalyst Mail send with a real completion.
/// `mailto:` / presentMail hop is not delivery. `NSSharingService.composeEmail`
/// reports `didShareItems` only after the user sends from Mail.
enum MacMailComposer {
    static func canComposeWithSendCompletion() -> Bool {
        #if targetEnvironment(macCatalyst)
        return NSSharingService(named: .composeEmail) != nil
        #else
        return false
        #endif
    }

    /// Returns true when Mail compose started. Completion is `didShareItems`
    /// (user sent) or `didFailToShareItems` (cancel / fail) only.
    @discardableResult
    static func compose(
        subject: String,
        recipients: [String],
        items: [Any],
        completion: @escaping (Bool) -> Void
    ) -> Bool {
        #if targetEnvironment(macCatalyst)
        guard let service = NSSharingService(named: .composeEmail),
              service.canPerform(withItems: items) else {
            return false
        }
        let box = DelegateBox(completion: completion)
        retained = box
        service.delegate = box
        service.recipients = recipients
        service.subject = subject
        service.perform(withItems: items)
        return true
        #else
        return false
        #endif
    }

    #if targetEnvironment(macCatalyst)
    private static var retained: DelegateBox?

    private final class DelegateBox: NSObject, NSSharingServiceDelegate {
        let completion: (Bool) -> Void
        init(completion: @escaping (Bool) -> Void) { self.completion = completion }

        func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
            MacMailComposer.retained = nil
            DispatchQueue.main.async { self.completion(true) }
        }

        func sharingService(
            _ sharingService: NSSharingService,
            didFailToShareItems items: [Any],
            error: Error
        ) {
            MacMailComposer.retained = nil
            DispatchQueue.main.async { self.completion(false) }
        }
    }
    #endif
}
