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

    // MARK: - Insights badge (menubar)
    @Published var newInsightsCount: Int = 0

    func clearNewInsights() { newInsightsCount = 0 }

    // MARK: - Start page state
    @Published var recommendations: [RecommendedPost] = []
    @Published var topQueries: [TopQuery] = []
    @Published var isLoadingStartPage: Bool = false

    // MARK: - Insights feed state
    @Published var insightsFeed: InsightsFeedResponse? = nil
    @Published var isLoadingFeed: Bool = false
    @Published var showFeed: Bool = false

    // MARK: - Server / UI state
    @Published var serverOnline: Bool = false
    @Published var stats: StatsResponse? = nil
    @Published var pipelineStatus: String? = nil
    @Published var isPipelineRunning: Bool = false
    @Published var autoScanEnabled: Bool = false
    @Published var showingStats: Bool = false
    @Published var launchAtLogin: Bool = false
    @Published var autoVikiSync: Bool = false
    @Published var vikiSyncStatus: String? = nil

    // MARK: - Server management
    @Published var serverPID: Int32? = nil
    @Published var serverUptime: TimeInterval = 0
    @Published var autoRestart: Bool = false
    @Published var serverAction: String? = nil  // transient status label

    // MARK: - Authorities
    @Published var authorities: [Authority] = []
    @Published var isLoadingAuthorities: Bool = false
    @Published var syncingAuthority: String? = nil
    @Published var showAuthorities: Bool = false
    @Published var authorityAction: String? = nil

    // MARK: - Tasks
    private var searchTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var autoScanTimer: Task<Void, Never>?
    private var insightDebounceTask: Task<Void, Never>?
    private var healthPollTask: Task<Void, Never>?
    private var serverStartAttempted = false
    private var serverStartedAt: Date? = nil
    private var managedProcess: Process? = nil

    // MARK: - Quick-ask shortcuts
    let quickAskCommands: [(label: String, query: String)] = [
        ("Hooks",    "best practices for Claude Code hooks"),
        ("Agents",   "how to build agent swarms with Claude Code"),
        ("TDD",      "test driven development workflow with Claude Code"),
        ("Memory",   "persistent memory and context patterns"),
    ]

    init() {
        launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        autoVikiSync = UserDefaults.standard.bool(forKey: "autoVikiSync")
        autoRestart = UserDefaults.standard.bool(forKey: "autoRestart")
        Task {
            await checkServer()
            await refreshStats()
            await refreshStartPage()
            startHealthPolling()
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
        let start = Date()

        searchTask = Task {
            do {
                let fetched = try await APIClient.shared.search(query: trimmed)
                guard !Task.isCancelled else { return }
                self.results = fetched
                self.scheduleInsights()
                let latency = Int(Date().timeIntervalSince(start) * 1000)
                Task { await APIClient.shared.logSearch(query: trimmed, mode: "search", resultCount: fetched.count, latencyMs: latency) }
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
        let start = Date()

        do {
            let response = try await APIClient.shared.ask(query: trimmed)
            self.askResponse = response
            self.newInsightsCount += 1
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            Task { await APIClient.shared.logSearch(query: trimmed, mode: "ask", resultCount: response.citations.count, latencyMs: latency) }
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
            newInsightsCount += 1
        } catch {
            // Insights are supplemental — fail silently
        }
        isLoadingInsights = false
    }

    // MARK: - Server lifecycle

    func checkServer() async {
        let wasOnline = serverOnline
        serverOnline = await APIClient.shared.healthCheck()

        if serverOnline {
            if serverStartedAt == nil { serverStartedAt = Date() }
            serverUptime = Date().timeIntervalSince(serverStartedAt ?? Date())
            detectServerPID()
        } else {
            serverPID = nil
            serverUptime = 0
            serverStartedAt = nil
        }

        // Auto-start on first launch
        if !serverOnline && !serverStartAttempted {
            serverStartAttempted = true
            await startServer()
        }

        // Auto-restart if enabled and server dropped
        if wasOnline && !serverOnline && autoRestart {
            serverAction = "Auto-restarting..."
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await startServer()
        }
    }

    func startServer() async {
        guard !serverOnline else {
            serverAction = "Already running"
            clearServerActionAfterDelay()
            return
        }
        serverAction = "Starting server..."
        launchPhoenixProcess()
        // Poll until ready (up to 15s)
        for _ in 0..<15 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            serverOnline = await APIClient.shared.healthCheck()
            if serverOnline {
                serverStartedAt = Date()
                detectServerPID()
                serverAction = "Server started"
                await refreshStats()
                clearServerActionAfterDelay()
                return
            }
        }
        serverAction = "Start timed out"
        clearServerActionAfterDelay()
    }

    func stopServer() async {
        serverAction = "Stopping server..."
        killServerProcess()
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        serverOnline = await APIClient.shared.healthCheck()
        if !serverOnline {
            serverPID = nil
            serverUptime = 0
            serverStartedAt = nil
            serverAction = "Server stopped"
        } else {
            serverAction = "Stop failed"
        }
        clearServerActionAfterDelay()
    }

    func restartServer() async {
        serverAction = "Restarting..."
        killServerProcess()
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        await startServer()
    }

    func setAutoRestart(_ enabled: Bool) {
        autoRestart = enabled
        UserDefaults.standard.set(enabled, forKey: "autoRestart")
    }

    // MARK: - Server internals

    private func launchPhoenixProcess() {
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
        managedProcess = process
    }

    private func killServerProcess() {
        // Kill managed process if we have one
        if let proc = managedProcess, proc.isRunning {
            proc.terminate()
            managedProcess = nil
        }
        // Also kill anything on port 8645
        let pipe = Pipe()
        let lsof = Process()
        lsof.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        lsof.arguments = ["-ti:8645"]
        lsof.standardOutput = pipe
        lsof.standardError = FileHandle.nullDevice
        try? lsof.run()
        lsof.waitUntilExit()
        let pids = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .split(separator: "\n")
            .compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) } ?? []
        for pid in pids {
            kill(pid, SIGTERM)
        }
    }

    private func detectServerPID() {
        let pipe = Pipe()
        let lsof = Process()
        lsof.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        lsof.arguments = ["-ti:8645"]
        lsof.standardOutput = pipe
        lsof.standardError = FileHandle.nullDevice
        try? lsof.run()
        lsof.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        serverPID = output.split(separator: "\n")
            .compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
            .first
    }

    private func startHealthPolling() {
        healthPollTask?.cancel()
        healthPollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000) // 15s
                await checkServer()
            }
        }
    }

    private func clearServerActionAfterDelay() {
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if serverAction != nil { serverAction = nil }
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
            syncToVikiIfEnabled()
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
            syncToVikiIfEnabled()
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

    // MARK: - VIKI Sync

    func setAutoVikiSync(_ enabled: Bool) {
        autoVikiSync = enabled
        UserDefaults.standard.set(enabled, forKey: "autoVikiSync")
    }

    func syncToViki() async {
        vikiSyncStatus = "Syncing with VIKI..."
        let success = await APIClient.shared.syncToViki()
        vikiSyncStatus = success ? "VIKI sync complete" : "VIKI unreachable (skipped)"
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if vikiSyncStatus != nil { vikiSyncStatus = nil }
        }
    }

    private func syncToVikiIfEnabled() {
        guard autoVikiSync else { return }
        Task { await syncToViki() }
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

    // MARK: - Start page

    func refreshStartPage() async {
        isLoadingStartPage = true
        async let recs = try? APIClient.shared.fetchRecommendations()
        async let queries = try? APIClient.shared.fetchTopQueries(limit: 8)
        recommendations = (await recs)?.recommendations ?? []
        topQueries = (await queries)?.queries ?? []
        isLoadingStartPage = false
    }

    // MARK: - Insights feed

    func refreshInsightsFeed() async {
        isLoadingFeed = true
        do {
            insightsFeed = try await APIClient.shared.fetchInsightsFeed()
        } catch {
            insightsFeed = nil
        }
        isLoadingFeed = false
    }

    func toggleFeed() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showFeed.toggle()
        }
        if showFeed {
            Task { await refreshInsightsFeed() }
        }
    }

    // MARK: - Authorities

    func toggleAuthorities() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showAuthorities.toggle()
            if showAuthorities { showFeed = false }
        }
        if showAuthorities {
            Task { await loadAuthorities() }
        }
    }

    func loadAuthorities() async {
        isLoadingAuthorities = true
        do {
            let response = try await APIClient.shared.fetchAuthorities()
            authorities = response.authorities
        } catch {
            authorities = []
        }
        isLoadingAuthorities = false
    }

    func syncAuthority(_ slug: String) {
        guard syncingAuthority == nil else { return }
        syncingAuthority = slug
        authorityAction = "Syncing \(slug)…"
        Task {
            do {
                let result = try await APIClient.shared.syncAuthority(slug: slug)
                let newCount = result.newPosts ?? 0
                authorityAction = newCount > 0 ? "\(slug): \(newCount) new posts" : "\(slug): up to date"
                if newCount > 0 { await refreshStats() }
                await loadAuthorities()
            } catch {
                authorityAction = "\(slug): sync failed"
            }
            syncingAuthority = nil
            clearAuthorityActionAfterDelay()
        }
    }

    private func clearAuthorityActionAfterDelay() {
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if authorityAction != nil { authorityAction = nil }
        }
    }

    // MARK: - Interaction tracking

    func trackResultClick(postId: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        Task { await APIClient.shared.logInteraction(query: trimmed, postId: postId, action: "click") }
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
