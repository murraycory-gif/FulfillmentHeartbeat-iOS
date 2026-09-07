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
        pager.view.clipsToBounds = true
        pager.view.layer.masksToBounds = true
        context.coordinator.attach(pager)
        let dest = router.current == .upload ? .dashboard : router.current
        context.coordinator.snap(to: dest, animated: false)
        return pager
    }

    func updateUIViewController(_ pager: UIPageViewController, context: Context) {
        let coordinator = context.coordinator
        coordinator.page = page
        coordinator.router = router
        coordinator.attach(pager)

        let dest = router.current
        if coordinator.filterStamp != filterStamp {
            coordinator.filterStamp = filterStamp
            coordinator.reloadHydrated()
        }

        guard dest != .upload else { return }
        if dest != coordinator.displayed, !coordinator.isSwiping {
            coordinator.snap(to: dest, animated: false)
        }
    }


    final class PageHost: UIHostingController<AnyView> {
        let dest: HubDestination
        var hydrated = false

        init(dest: HubDestination, rootView: AnyView) {
            self.dest = dest
            super.init(rootView: rootView)
            view.backgroundColor = AppTheme.uiBg
            view.clipsToBounds = true
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = AppTheme.uiBg
            view.clipsToBounds = true
            view.layer.masksToBounds = true
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
        var isSwiping = false
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
            let host = PageHost(dest: dest, rootView: Self.blank)
            cache[dest] = host
            return host
        }

        func hydrate(_ dest: HubDestination) {
            let host = host(for: dest)
            let root = page(dest)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.bg.ignoresSafeArea())
            host.rootView = AnyView(root)
            host.hydrated = true
        }

        func reloadHydrated() {
            hydrate(displayed)
            warmNeighbors(of: displayed)
        }

        func neighbors(of dest: HubDestination) -> [HubDestination] {
            let items = HubDestination.sectionItems
            guard let index = items.firstIndex(of: dest) else { return [] }
            var out: [HubDestination] = []
            if index > 0 { out.append(items[index - 1]) }
            if index + 1 < items.count { out.append(items[index + 1]) }
            return out
        }

        func dehydrate(keeping dest: HubDestination) {
            let keep: Set<HubDestination>
            if HubLayout.hydrateNeighbors {
                keep = Set(neighbors(of: dest) + [dest])
            } else {
                keep = [dest]
            }
            for (key, host) in cache where host.hydrated && !keep.contains(key) {
                host.rootView = Self.blank
                host.hydrated = false
            }
        }

        func snap(to dest: HubDestination, animated: Bool) {
            guard let pager else { return }
            hydrate(dest)
            displayed = dest
            pager.dataSource = nil
            pager.setViewControllers([host(for: dest)], direction: .forward, animated: false)
            pager.dataSource = self
            resetScroll(pager)
            hydrateNeighborsNow(of: dest)
        }

        private func hydrateNeighborsNow(of dest: HubDestination) {
            guard HubLayout.hydrateNeighbors else { return }
            let sides = neighbors(of: dest)
            guard let first = sides.first else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.displayed == dest else { return }
                if self.cache[first]?.hydrated != true {
                    self.hydrate(first)
                }
                if sides.count > 1 {
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.displayed == dest else { return }
                        let other = sides[1]
                        if self.cache[other]?.hydrated != true {
                            self.hydrate(other)
                        }
                    }
                }
            }
        }

        private func warmNeighbors(of dest: HubDestination) {
            hydrateNeighborsNow(of: dest)
        }

        private static let blank = AnyView(Color(AppTheme.uiBg).ignoresSafeArea())

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
            let dest = items[index - 1]
            let next = self.host(for: dest)
            if !next.hydrated { hydrate(dest) }
            return next
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard let host = viewController as? PageHost else { return nil }
            let items = HubDestination.sectionItems
            guard let index = items.firstIndex(of: host.dest), index + 1 < items.count else { return nil }
            let dest = items[index + 1]
            let next = self.host(for: dest)
            if !next.hydrated { hydrate(dest) }
            return next
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            willTransitionTo pendingViewControllers: [UIViewController]
        ) {
            if let host = pendingViewControllers.first as? PageHost {
                isSwiping = true
            }
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
            isSwiping = false
            resetScroll(pageViewController)
            if !host.hydrated {
                hydrate(host.dest)
            }
            dehydrate(keeping: host.dest)
            warmNeighbors(of: host.dest)
            if router.destination != host.dest {
                router.open(host.dest)
            }
        }
    }
}
