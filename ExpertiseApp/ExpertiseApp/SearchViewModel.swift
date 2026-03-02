import Foundation
import SwiftUI
import ServiceManagement

enum SearchMode: String, CaseIterable {
    case search = "Search"
    case ask = "Ask"
}

@MainActor
class SearchViewModel: ObservableObject {
    // MARK: - Search state
    @Published var query: String = ""
    @Published var results: [SearchResult] = []
    @Published var isSearching: Bool = false
    @Published var error: String? = nil
    @Published var mode: SearchMode = .search

    // MARK: - Ask / Insights state
    @Published var askResponse: AskResponse? = nil
    @Published var isAsking: Bool = false
    @Published var insightResponse: AskResponse? = nil
    @Published var isLoadingInsights: Bool = false
    @Published var showInsights: Bool = true

    // MARK: - Server / UI state
    @Published var serverOnline: Bool = false
    @Published var stats: StatsResponse? = nil
    @Published var pipelineStatus: String? = nil
    @Published var isPipelineRunning: Bool = false
    @Published var autoScanEnabled: Bool = false
    @Published var showingStats: Bool = false
    @Published var launchAtLogin: Bool = false

    // MARK: - Tasks
    private var searchTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var autoScanTimer: Task<Void, Never>?
    private var insightDebounceTask: Task<Void, Never>?
    private var serverStartAttempted = false

    // MARK: - Quick-ask shortcuts
    let quickAskCommands: [(label: String, query: String)] = [
        ("Hooks",    "best practices for Claude Code hooks"),
        ("Agents",   "how to build agent swarms with Claude Code"),
        ("TDD",      "test driven development workflow with Claude Code"),
        ("Memory",   "persistent memory and context patterns"),
    ]

    init() {
        launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        Task {
            await checkServer()
            await refreshStats()
        }
    }

    // MARK: - Query handling

    func onQueryChanged() {
        debounceTask?.cancel()
        insightDebounceTask?.cancel()
        insightResponse = nil

        let delay: UInt64 = mode == .ask ? 800_000_000 : 300_000_000
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            let trimmed = query.trimmingCharacters(in: .whitespaces)
            if trimmed.count >= 2 {
                if mode == .ask {
                    await performAsk()
                } else {
                    await performSearch()
                }
            } else if trimmed.isEmpty {
                results = []
                askResponse = nil
                insightResponse = nil
                error = nil
            }
        }
    }

    // Called by keyboard shortcut — flips mode then re-runs
    func toggleMode() {
        mode = mode == .search ? .ask : .search
        onModeChanged()
    }

    // Called by Picker onChange — mode already set, just re-run
    func onModeChanged() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return }
        Task {
            if mode == .ask { await performAsk() }
            else { await performSearch() }
        }
    }

    func fireQuickAsk(_ query: String) {
        self.query = query
        mode = .ask
        Task { await performAsk() }
    }

    // MARK: - Search

    func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        searchTask?.cancel()
        isSearching = true
        error = nil
        insightResponse = nil

        searchTask = Task {
            do {
                let fetched = try await APIClient.shared.search(query: trimmed)
                guard !Task.isCancelled else { return }
                self.results = fetched
                self.scheduleInsights()
            } catch {
                guard !Task.isCancelled else { return }
                self.error = error.localizedDescription
                self.results = []
            }
            self.isSearching = false
        }
    }

    // MARK: - Ask (AI synthesis)

    func performAsk() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isAsking = true
        askResponse = nil
        error = nil

        do {
            let response = try await APIClient.shared.ask(query: trimmed)
            self.askResponse = response
        } catch {
            self.error = "Ask failed: \(error.localizedDescription)"
        }
        isAsking = false
    }

    // MARK: - Auto-insights (Search mode)

    private func scheduleInsights() {
        insightDebounceTask?.cancel()
        guard !results.isEmpty else { return }
        insightDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second idle
            guard !Task.isCancelled, mode == .search else { return }
            await loadInsights()
        }
    }

    private func loadInsights() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isLoadingInsights = true
        do {
            insightResponse = try await APIClient.shared.ask(query: trimmed)
        } catch {
            // Insights are supplemental — fail silently
        }
        isLoadingInsights = false
    }

    // MARK: - Server

    func checkServer() async {
        serverOnline = await APIClient.shared.healthCheck()
        if !serverOnline && !serverStartAttempted {
            serverStartAttempted = true
            startPhoenixServer()
        }
    }

    func startPhoenixServer() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let script = """
        PATH="$HOME/.asdf/shims:$HOME/.mise/shims:/opt/homebrew/bin:/usr/local/bin:$PATH" \
        MIX_ENV=dev \
        cd "\(home)/Developer/claude-expertise/expertise_api" && mix phx.server
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", script]
        var env = ProcessInfo.processInfo.environment
        env["HOME"] = home
        env["MIX_ENV"] = "dev"
        process.environment = env
        try? process.run()

        Task {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            await checkServer()
            if serverOnline { await refreshStats() }
        }
    }

    // MARK: - Stats & pipeline

    func refreshStats() async {
        do { stats = try await APIClient.shared.fetchStats() } catch { stats = nil }
    }

    func triggerScan() async {
        isPipelineRunning = true
        pipelineStatus = "Scanning for new content..."
        do {
            _ = try await APIClient.shared.triggerScan()
            pipelineStatus = "Scan complete"
            await refreshStats()
        } catch {
            pipelineStatus = "Scan failed: \(error.localizedDescription)"
        }
        isPipelineRunning = false
        clearStatusAfterDelay()
    }

    func triggerImport() async {
        isPipelineRunning = true
        pipelineStatus = "Running full import pipeline..."
        do {
            _ = try await APIClient.shared.triggerImport()
            pipelineStatus = "Import complete"
            await refreshStats()
        } catch {
            pipelineStatus = "Import failed: \(error.localizedDescription)"
        }
        isPipelineRunning = false
        clearStatusAfterDelay()
    }

    func triggerImageScrape() async {
        isPipelineRunning = true
        pipelineStatus = "Downloading images..."
        do {
            _ = try await APIClient.shared.triggerImageScrape()
            pipelineStatus = "Image scrape complete"
            await refreshStats()
        } catch {
            pipelineStatus = "Image scrape failed: \(error.localizedDescription)"
        }
        isPipelineRunning = false
        clearStatusAfterDelay()
    }

    // MARK: - Auto-scan

    func toggleAutoScan() {
        autoScanEnabled.toggle()
        if autoScanEnabled { startAutoScan() } else { autoScanTimer?.cancel(); autoScanTimer = nil }
    }

    private func startAutoScan() {
        autoScanTimer?.cancel()
        autoScanTimer = Task {
            while !Task.isCancelled && autoScanEnabled {
                await triggerScan()
                try? await Task.sleep(nanoseconds: 3_600_000_000_000)
            }
        }
    }

    // MARK: - Launch at login

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = enabled
        UserDefaults.standard.set(enabled, forKey: "launchAtLogin")
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // May fail for non-bundle builds; preference is still stored
        }
    }

    // MARK: - Misc

    func openInBrowser() {
        NSWorkspace.shared.open(URL(string: "http://localhost:8645")!)
    }

    private func clearStatusAfterDelay() {
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if !isPipelineRunning { pipelineStatus = nil }
        }
    }
}
