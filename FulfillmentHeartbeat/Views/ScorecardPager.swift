import SwiftUI
import UIKit

/// Native paging between Dashboard and scorecards. Caches pages so the next swipe is already drawn.
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
        pager.dataSource = context.coordinator
        pager.delegate = context.coordinator
        pager.view.backgroundColor = UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1)
        let start = context.coordinator.host(for: router.current == .upload ? .dashboard : router.current)
        pager.setViewControllers([start], direction: .forward, animated: false)
        context.coordinator.displayed = start.dest
        context.coordinator.attach(pager)
        context.coordinator.prefetch(around: start.dest)
        return pager
    }

    func updateUIViewController(_ pager: UIPageViewController, context: Context) {
        let coordinator = context.coordinator
        coordinator.page = page
        coordinator.router = router

        if coordinator.filterStamp != filterStamp {
            coordinator.filterStamp = filterStamp
            coordinator.cache.removeAll()
            let dest = router.current == .upload ? .dashboard : router.current
            let host = coordinator.host(for: dest)
            pager.setViewControllers([host], direction: .forward, animated: false)
            coordinator.displayed = dest
            coordinator.prefetch(around: dest)
            return
        }

        guard !coordinator.isAnimating else { return }
        let dest = router.current
        guard dest != .upload, dest != coordinator.displayed else { return }
        let items = HubDestination.sectionItems
        let from = items.firstIndex(of: coordinator.displayed) ?? 0
        let to = items.firstIndex(of: dest) ?? 0
        let host = coordinator.host(for: dest)
        pager.setViewControllers(
            [host],
            direction: to >= from ? .forward : .reverse,
            animated: abs(to - from) == 1
        )
        coordinator.displayed = dest
        coordinator.prefetch(around: dest)
    }

    final class PageHost: UIHostingController<AnyView> {
        let dest: HubDestination

        init(dest: HubDestination, rootView: AnyView) {
            self.dest = dest
            super.init(rootView: rootView)
            view.backgroundColor = UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1)
            view.clipsToBounds = true
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
        var isAnimating = false
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
            let host = PageHost(dest: dest, rootView: AnyView(root))
            cache[dest] = host
            return host
        }

        func prefetch(around dest: HubDestination) {
            let items = HubDestination.sectionItems
            guard let index = items.firstIndex(of: dest) else { return }
            let neighbors = [index + 1, index - 1, index + 2]
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                for item in neighbors where items.indices.contains(item) {
                    _ = self.host(for: items[item])
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
            willTransitionTo pendingViewControllers: [UIViewController]
        ) {
            isAnimating = true
            if let host = pendingViewControllers.first as? PageHost {
                prefetch(around: host.dest)
            }
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            isAnimating = false
            guard completed, let host = pageViewController.viewControllers?.first as? PageHost else { return }
            displayed = host.dest
            if router.destination != host.dest {
                router.open(host.dest)
            }
            prefetch(around: host.dest)
        }
    }
}
