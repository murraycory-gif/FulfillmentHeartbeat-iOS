import SwiftUI
import UIKit

/// Native paging between Dashboard and scorecards. Sidebar taps jump; swipes page.
struct ScorecardPager: UIViewControllerRepresentable {
    @ObservedObject var router: HubRouter
    var filterStamp: Int
    var page: (HubDestination) -> AnyView

    func makeCoordinator() -> Coordinator {
        Coordinator(page: page, router: router, filterStamp: filterStamp)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pager = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: nil
        )
        pager.delegate = context.coordinator
        pager.dataSource = context.coordinator
        pager.view.backgroundColor = AppTheme.uiBg
        context.coordinator.attach(pager)
        let dest = router.current == .upload ? .dashboard : router.current
        context.coordinator.snap(to: dest, animated: false)
        context.coordinator.prefetch(around: dest)
        return pager
    }

    func updateUIViewController(_ pager: UIPageViewController, context: Context) {
        let coordinator = context.coordinator
        coordinator.page = page
        coordinator.router = router
        coordinator.attach(pager)

        if coordinator.filterStamp != filterStamp {
            coordinator.filterStamp = filterStamp
            return
        }

        let dest = router.current
        guard dest != .upload, dest != coordinator.displayed else { return }
        coordinator.snap(to: dest, animated: false)
        coordinator.prefetch(around: dest)
    }

    final class PageHost: UIHostingController<AnyView> {
        let dest: HubDestination

        init(dest: HubDestination, rootView: AnyView) {
            self.dest = dest
            super.init(rootView: rootView)
            view.backgroundColor = AppTheme.uiBg
            view.clipsToBounds = true
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = AppTheme.uiBg
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var page: (HubDestination) -> AnyView
        var router: HubRouter
        var filterStamp: Int
        var cache: [HubDestination: PageHost] = [:]
        var displayed: HubDestination = .dashboard
        private weak var pager: UIPageViewController?

        init(page: @escaping (HubDestination) -> AnyView, router: HubRouter, filterStamp: Int) {
            self.page = page
            self.router = router
            self.filterStamp = filterStamp
        }

        func attach(_ pager: UIPageViewController) {
            self.pager = pager
        }

        func host(for dest: HubDestination) -> PageHost {
            if let existing = cache[dest] { return existing }
            let root = page(dest)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.bg.ignoresSafeArea())
            let host = PageHost(dest: dest, rootView: AnyView(root))
            cache[dest] = host
            return host
        }

        func snap(to dest: HubDestination, animated: Bool) {
            guard let pager else { return }
            let host = host(for: dest)
            displayed = dest
            pager.dataSource = nil
            pager.setViewControllers([host], direction: .forward, animated: false)
            pager.dataSource = self
            resetScroll(pager)
            pager.view.layoutIfNeeded()
        }

        func prefetch(around dest: HubDestination) {
            let items = HubDestination.sectionItems
            guard let index = items.firstIndex(of: dest) else { return }
            trimCache(around: index)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                for offset in [1, -1] {
                    let item = index + offset
                    guard items.indices.contains(item) else { continue }
                    let next = items[item]
                    if next == .checklist { continue }
                    _ = self.host(for: next)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self else { return }
                guard self.displayed == dest else { return }
                for offset in [1, -1] {
                    let item = index + offset
                    guard items.indices.contains(item) else { continue }
                    _ = self.host(for: items[item])
                }
            }
        }

        private func trimCache(around index: Int) {
            let items = HubDestination.sectionItems
            var keep = Set<HubDestination>()
            for offset in -1...1 {
                let i = index + offset
                if items.indices.contains(i) {
                    keep.insert(items[i])
                }
            }
            if cache.count <= keep.count { return }
            cache = cache.filter { keep.contains($0.key) }
        }

        private func resetScroll(_ pager: UIPageViewController) {
            for sub in pager.view.subviews {
                guard let scroll = sub as? UIScrollView else { continue }
                let width = scroll.bounds.width
                if width > 0, scroll.contentSize.width >= width * 2 {
                    scroll.contentOffset = CGPoint(x: width, y: 0)
                }
            }
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            guard let host = viewController as? PageHost else { return nil }
            let items = HubDestination.sectionItems
            guard let index = items.firstIndex(of: host.dest), index > 0 else { return nil }
            return self.host(for: items[index - 1])
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard let host = viewController as? PageHost else { return nil }
            let items = HubDestination.sectionItems
            guard let index = items.firstIndex(of: host.dest), index + 1 < items.count else { return nil }
            return self.host(for: items[index + 1])
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            let current = (completed ? pageViewController.viewControllers?.first : previousViewControllers.first) as? PageHost
            guard let host = current ?? pageViewController.viewControllers?.first as? PageHost else { return }
            displayed = host.dest
            resetScroll(pageViewController)
            if router.destination != host.dest {
                router.open(host.dest)
            }
            if completed {
                prefetch(around: host.dest)
            }
        }
    }
}
