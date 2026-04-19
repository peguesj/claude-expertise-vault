import SwiftUI

struct SearchView: View {
    @ObservedObject var viewModel: SearchViewModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            toolBar
            searchBar
            if viewModel.query.isEmpty && !viewModel.showingStats {
                quickAskChips
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            if let status = viewModel.pipelineStatus {
                statusBanner(status)
            }
            Divider().padding(.top, 4)
            if viewModel.showingStats {
                statsPanel
            } else if viewModel.showAuthorities {
                authoritiesView
            } else if viewModel.showFeed {
                insightsFeedView
            } else if viewModel.mode == .ask {
                askResultView
            } else {
                searchResultsView
            }
        }
        .background(.ultraThinMaterial)
        .background(keyboardShortcuts)
        .onAppear { viewModel.clearNewInsights() }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            ClaudeIcon(size: 22)
                .foregroundColor(.purple)
            Text("Claude Expertise")
                .font(.headline)
            Spacer()

            if viewModel.autoScanEnabled {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.green)
                    .font(.caption)
                    .help("Auto-scan active (hourly)")
            }

            Button(action: viewModel.openInBrowser) {
                Image(systemName: "safari")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open in Browser")

            Circle()
                .fill(viewModel.serverOnline ? Color.green : Color.red)
                .frame(width: 8, height: 8)
                .help(viewModel.serverOnline ? "Server online" : "Server offline — attempting to start...")
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .background(.ultraThinMaterial)
    }

    // MARK: - Toolbar

    private var toolBar: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                MenuButton(title: "Scan", icon: "arrow.clockwise", isLoading: viewModel.isPipelineRunning) {
                    Task { await viewModel.triggerScan() }
                }
                .help("Scan for new posts ⌘S")

                MenuButton(title: "Import", icon: "square.and.arrow.down", isLoading: viewModel.isPipelineRunning) {
                    Task { await viewModel.triggerImport() }
                }
                .help("Ingest + embed pipeline ⌘I")

                MenuButton(title: "Images", icon: "photo.on.rectangle.angled", isLoading: viewModel.isPipelineRunning) {
                    Task { await viewModel.triggerImageScrape() }
                }
                .help("Download images ⌘⇧I")

                Divider().frame(height: 16)

                Button(action: { viewModel.toggleAutoScan() }) {
                    HStack(spacing: 3) {
                        Image(systemName: viewModel.autoScanEnabled ? "timer.circle.fill" : "timer")
                            .font(.system(size: 10))
                        Text("Auto")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(viewModel.autoScanEnabled ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .help("Toggle hourly auto-scan")

                Spacer()

                // Authorities toggle
                Button(action: { viewModel.toggleAuthorities() }) {
                    Image(systemName: viewModel.showAuthorities ? "person.2.fill" : "person.2")
                        .font(.system(size: 11))
                        .foregroundColor(viewModel.showAuthorities ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .help("Authority sources ⌘⇧A")

                // Insights feed toggle
                Button(action: { viewModel.toggleFeed() }) {
                    Image(systemName: viewModel.showFeed ? "newspaper.fill" : "newspaper")
                        .font(.system(size: 11))
                        .foregroundColor(viewModel.showFeed ? .orange : .secondary)
                }
                .buttonStyle(.plain)
                .help("Insights feed ⌘⇧F")

                // Stats toggle
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { viewModel.showingStats.toggle() }
                    if viewModel.showingStats { Task { await viewModel.refreshStats() } }
                }) {
                    Image(systemName: viewModel.showingStats ? "chart.bar.fill" : "chart.bar")
                        .font(.system(size: 11))
                        .foregroundColor(viewModel.showingStats ? .purple : .secondary)
                }
                .buttonStyle(.plain)
                .help("Database stats ⌘,")
            }

            // Mode picker
            Picker("Mode", selection: $viewModel.mode) {
                ForEach(SearchMode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: viewModel.mode) { viewModel.onModeChanged() }
            .help("Toggle mode ⌘T")
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack {
            Image(systemName: viewModel.mode == .ask ? "sparkles" : "magnifyingglass")
                .foregroundColor(viewModel.mode == .ask ? .purple : .secondary)
            TextField(
                viewModel.mode == .ask ? "Ask anything about Claude Code..." : "Search tips & patterns...",
                text: $viewModel.query
            )
            .textFieldStyle(.plain)
            .focused($searchFocused)
            .onSubmit {
                Task {
                    if viewModel.mode == .ask { await viewModel.performAsk() }
                    else { await viewModel.performSearch() }
                }
            }
            .onChange(of: viewModel.query) { viewModel.onQueryChanged() }

            if viewModel.isSearching || viewModel.isAsking || viewModel.isLoadingInsights {
                ProgressView().controlSize(.small)
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .padding(.horizontal)
    }

    // MARK: - Quick-ask chips

    private var quickAskChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(viewModel.quickAskCommands, id: \.label) { item in
                    Button(action: { viewModel.fireQuickAsk(item.query) }) {
                        Text(item.label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.purple)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .help(item.query)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Status banner

    private func statusBanner(_ status: String) -> some View {
        HStack(spacing: 6) {
            if viewModel.isPipelineRunning {
                ProgressView().controlSize(.mini)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 10))
            }
            Text(status)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(.thinMaterial)
    }

    // MARK: - Stats panel

    private var statsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let stats = viewModel.stats {
                    Text("Database Statistics")
                        .font(.system(size: 13, weight: .semibold))

                    StatRow(label: "Raw Posts", value: "\(stats.rawPosts)")
                    StatRow(label: "Processed Chunks", value: "\(stats.processedChunks)")
                    StatRow(label: "Images Downloaded", value: "\(stats.images)")
                    StatRow(label: "Vector Index", value: stats.indexExists ? "Built" : "Not built")
                    StatRow(label: "Authors", value: stats.authors.joined(separator: ", "))
                } else {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Loading stats...").font(.caption).foregroundColor(.secondary)
                    }
                }

                Divider()

                // Server management
                VStack(alignment: .leading, spacing: 8) {
                    Text("Server").font(.system(size: 13, weight: .semibold))

                    HStack(spacing: 8) {
                        Circle()
                            .fill(viewModel.serverOnline ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(viewModel.serverOnline ? "Online" : "Offline")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(viewModel.serverOnline ? .green : .red)
                            if viewModel.serverOnline {
                                Text("PID \(viewModel.serverPID.map(String.init) ?? "?") \u{2022} uptime \(formatUptime(viewModel.serverUptime))")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }

                    if let action = viewModel.serverAction {
                        HStack(spacing: 4) {
                            ProgressView().controlSize(.mini)
                            Text(action)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack(spacing: 6) {
                        Button(action: { Task { await viewModel.startServer() } }) {
                            Label("Start", systemImage: "play.fill")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(viewModel.serverOnline)

                        Button(action: { Task { await viewModel.stopServer() } }) {
                            Label("Stop", systemImage: "stop.fill")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(!viewModel.serverOnline)

                        Button(action: { Task { await viewModel.restartServer() } }) {
                            Label("Restart", systemImage: "arrow.clockwise")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Toggle(isOn: Binding(
                        get: { viewModel.autoRestart },
                        set: { viewModel.setAutoRestart($0) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-restart")
                                .font(.system(size: 12))
                            Text("Restart server if it goes down")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }

                Divider()

                // Launch at login
                VStack(alignment: .leading, spacing: 6) {
                    Text("Startup").font(.system(size: 13, weight: .semibold))

                    Toggle(isOn: Binding(
                        get: { viewModel.launchAtLogin },
                        set: { viewModel.setLaunchAtLogin($0) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start at Login")
                                .font(.system(size: 12))
                            Text("Also auto-starts the API server")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)

                    Toggle(isOn: Binding(
                        get: { viewModel.autoVikiSync },
                        set: { viewModel.setAutoVikiSync($0) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-sync with VIKI")
                                .font(.system(size: 12))
                            Text("Push expertise data on scan/import")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)

                    if let vikiStatus = viewModel.vikiSyncStatus {
                        HStack(spacing: 4) {
                            Image(systemName: vikiStatus.contains("complete") ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                                .font(.system(size: 9))
                                .foregroundColor(vikiStatus.contains("complete") ? .green : .orange)
                            Text(vikiStatus)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Divider()

                // Keyboard shortcuts reference
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shortcuts").font(.system(size: 13, weight: .semibold))
                    ShortcutRow(keys: "⌘T", action: "Toggle Search / Ask mode")
                    ShortcutRow(keys: "⌘K", action: "Clear search")
                    ShortcutRow(keys: "⌘R", action: "Re-run search")
                    ShortcutRow(keys: "⌘S", action: "Scan")
                    ShortcutRow(keys: "⌘I", action: "Import")
                    ShortcutRow(keys: "⌘⇧I", action: "Download images")
                    ShortcutRow(keys: "⌘,", action: "Toggle stats")
                    ShortcutRow(keys: "⌘⇧F", action: "Insights feed")
                    ShortcutRow(keys: "⌘⇧A", action: "Toggle AI Insights")
                    ShortcutRow(keys: "⌘⇧E", action: "Activate from anywhere*")
                    Text("* Requires Accessibility access")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }

    // MARK: - Ask result view

    @ViewBuilder
    private var askResultView: some View {
        if viewModel.isAsking {
            VStack(spacing: 12) {
                ProgressView()
                Text("Generating insights...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxHeight: .infinity)
        } else if let response = viewModel.askResponse {
            AskResultCard(response: response)
        } else if let error = viewModel.error {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                Text(error)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxHeight: .infinity)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.largeTitle)
                    .foregroundColor(.purple.opacity(0.5))
                Text("Ask anything about Claude Code")
                    .foregroundColor(.secondary)
                Text("AI synthesizes expert knowledge into a direct answer")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxHeight: .infinity)
        }
    }

    // MARK: - Search results view (with auto-insights)

    @ViewBuilder
    private var searchResultsView: some View {
        if let error = viewModel.error {
            VStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle).foregroundColor(.orange)
                Text(error).foregroundColor(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)
            }
            .frame(maxHeight: .infinity)
        } else if viewModel.results.isEmpty && !viewModel.query.isEmpty && !viewModel.isSearching {
            VStack {
                Image(systemName: "magnifyingglass")
                    .font(.largeTitle).foregroundColor(.secondary)
                Text("No results found").foregroundColor(.secondary)
            }
            .frame(maxHeight: .infinity)
        } else if viewModel.results.isEmpty {
            StartPageView(viewModel: viewModel)
                .transition(.opacity)
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    // AI Insights panel (auto-generated after 2s idle)
                    if viewModel.showInsights && (viewModel.insightResponse != nil || viewModel.isLoadingInsights) {
                        InsightsPanelCard(
                            response: viewModel.insightResponse,
                            isLoading: viewModel.isLoadingInsights,
                            isExpanded: $viewModel.showInsights
                        )
                    }
                    ForEach(viewModel.results) { result in
                        ResultCard(result: result) {
                            viewModel.trackResultClick(postId: result.postId)
                            if let url = result.url, let link = URL(string: url) {
                                NSWorkspace.shared.open(link)
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Keyboard shortcuts (hidden)

    @ViewBuilder
    private var keyboardShortcuts: some View {
        Group {
            Button("") { viewModel.query = ""; searchFocused = true }
                .keyboardShortcut("k", modifiers: .command)

            Button("") {
                Task {
                    if viewModel.mode == .ask { await viewModel.performAsk() }
                    else { await viewModel.performSearch() }
                }
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("") { Task { await viewModel.triggerScan() } }
                .keyboardShortcut("s", modifiers: .command)

            Button("") { Task { await viewModel.triggerImport() } }
                .keyboardShortcut("i", modifiers: .command)

            Button("") { Task { await viewModel.triggerImageScrape() } }
                .keyboardShortcut("i", modifiers: [.command, .shift])

            Button("") { viewModel.toggleMode() }
                .keyboardShortcut("t", modifiers: .command)

            Button("") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { viewModel.showingStats.toggle() }
                if viewModel.showingStats { Task { await viewModel.refreshStats() } }
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { viewModel.showInsights.toggle() }
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])

            Button("") { viewModel.toggleFeed() }
                .keyboardShortcut("f", modifiers: [.command, .shift])

            Button("") { viewModel.toggleAuthorities() }
                .keyboardShortcut("u", modifiers: [.command, .shift])
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .allowsHitTesting(false)
    }

    // MARK: - Authorities View

    @ViewBuilder
    private var authoritiesView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Authority Sources")
                    .font(.headline)
                Spacer()
                if let msg = viewModel.authorityAction {
                    Text(msg)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Button(action: { Task { await viewModel.loadAuthorities() } }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoadingAuthorities)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // LinkedIn Auth Banner
            LinkedInAuthBannerView(viewModel: viewModel)

            if viewModel.isLoadingAuthorities && viewModel.authorities.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading authorities…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else if viewModel.authorities.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.2.slash")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("No authorities registered")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.authorities) { authority in
                            AuthorityRowView(
                                authority: authority,
                                isSyncing: viewModel.syncingAuthority == authority.slug,
                                isLinkedInAuthenticated: viewModel.linkedInAuth?.valid == true,
                                onSync: { viewModel.syncAuthority(authority.slug) },
                                onLinkedInAuth: { viewModel.authenticateLinkedIn() }
                            )
                            Divider().padding(.leading, 44)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
    }

    // MARK: - Insights Feed View

    @ViewBuilder
    private var insightsFeedView: some View {
        if viewModel.isLoadingFeed && viewModel.insightsFeed == nil {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading insights...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxHeight: .infinity)
        } else if let feed = viewModel.insightsFeed {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {

                    // Trending topics
                    if !feed.trendingTopics.isEmpty {
                        FeedSection(title: "Trending Topics", icon: "flame.fill", tint: .orange) {
                            FlowLayout(spacing: 6) {
                                ForEach(feed.trendingTopics) { topic in
                                    HStack(spacing: 4) {
                                        Text(topic.tag)
                                            .font(.system(size: 11, weight: .medium))
                                        Text("\(topic.postCount)")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.orange.opacity(0.1))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.orange.opacity(0.2), lineWidth: 0.5))
                                }
                            }
                        }
                    }

                    // High-engagement highlights
                    if !feed.highlights.isEmpty {
                        FeedSection(title: "Top Posts", icon: "star.fill", tint: .yellow) {
                            ForEach(feed.highlights) { item in
                                HighlightCard(item: item) {
                                    if let url = item.url, let link = URL(string: url) {
                                        NSWorkspace.shared.open(link)
                                    }
                                }
                            }
                        }
                    }

                    // Recent submissions
                    if !feed.feed.isEmpty {
                        FeedSection(title: "Recent Submissions", icon: "tray.and.arrow.down.fill", tint: .blue) {
                            ForEach(feed.feed.prefix(8)) { item in
                                FeedItemCard(item: item) {
                                    if let url = item.url, let link = URL(string: url) {
                                        NSWorkspace.shared.open(link)
                                    }
                                }
                            }
                        }
                    }

                    // Resources discovered
                    if feed.resources.total > 0 {
                        FeedSection(title: "Resources Discovered", icon: "link.circle.fill", tint: .green) {
                            HStack(spacing: 8) {
                                ForEach(feed.resources.byType.prefix(5)) { res in
                                    VStack(spacing: 2) {
                                        Text("\(res.count)")
                                            .font(.system(size: 16, weight: .bold))
                                        Text(res.type)
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(.regularMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }

                    // Author breakdown
                    if !feed.authors.isEmpty {
                        FeedSection(title: "Contributors", icon: "person.2.fill", tint: .purple) {
                            ForEach(feed.authors) { author in
                                HStack {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(author.author)
                                            .font(.system(size: 12, weight: .medium))
                                        Text("\(author.posts) posts")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    HStack(spacing: 8) {
                                        Label("\(author.totalLikes)", systemImage: "heart.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(.pink)
                                        Label("\(author.totalComments)", systemImage: "bubble.left.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "newspaper")
                    .font(.largeTitle)
                    .foregroundColor(.orange.opacity(0.5))
                Text("No insights available")
                    .foregroundColor(.secondary)
                Text("Ingest posts to generate insights")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .frame(maxHeight: .infinity)
        }
    }
}

// MARK: - Feed Section + Cards

struct FeedSection<Content: View>: View {
    let title: String
    let icon: String
    let tint: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(tint)
            content()
        }
    }
}

struct HighlightCard: View {
    let item: HighlightItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.author)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.purple)
                    Spacer()
                    HStack(spacing: 6) {
                        Label("\(item.likes)", systemImage: "heart.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.pink)
                        Label("\(item.comments)", systemImage: "bubble.left.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.blue)
                    }
                }
                Text(item.excerpt)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(10)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.yellow.opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

struct FeedItemCard: View {
    let item: FeedItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.author)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.purple)
                    Text(item.platform)
                        .font(.system(size: 9))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                    Spacer()
                    HStack(spacing: 4) {
                        Label("\(item.likes)", systemImage: "heart")
                            .font(.system(size: 9))
                        Label("\(item.comments)", systemImage: "bubble.left")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.secondary)
                }
                Text(item.excerpt)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if !item.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(item.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 9))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(8)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AI Insights Panel

struct InsightsPanelCard: View {
    let response: AskResponse?
    let isLoading: Bool
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundColor(.purple)
                    Text("AI Insights")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.purple)
                    if let r = response {
                        ConfidenceBadge(confidence: r.confidence)
                    }
                    Spacer()
                    if isLoading {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                if isLoading && response == nil {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.mini)
                        Text("Synthesizing expert knowledge...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                } else if let r = response {
                    Text(r.answer)
                        .font(.system(size: 12))
                        .lineSpacing(3)
                        .textSelection(.enabled)

                    if !r.citations.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sources")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                            ForEach(r.citations.prefix(3)) { citation in
                                CitationRow(citation: citation)
                            }
                        }
                    }

                    if !r.relatedResources.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Resources")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                            ForEach(r.relatedResources.prefix(3)) { resource in
                                ResourceRow(resource: resource)
                            }
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.3), Color.white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .purple.opacity(0.08), radius: 4, y: 2)
    }
}

// MARK: - Ask Result Card (full Ask mode)

struct AskResultCard: View {
    let response: AskResponse
    @State private var showCitations = true
    @State private var showResources = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Confidence + tags
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                    ConfidenceBadge(confidence: response.confidence)
                    Spacer()
                    ForEach(response.taxonomyTags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.1))
                            .foregroundColor(.purple)
                            .cornerRadius(8)
                    }
                }

                // Answer
                Text(response.answer)
                    .font(.system(size: 13))
                    .lineSpacing(4)
                    .textSelection(.enabled)

                // Citations
                if !response.citations.isEmpty {
                    Divider()
                    DisclosureGroup(
                        isExpanded: $showCitations,
                        content: {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(response.citations) { citation in
                                    CitationRow(citation: citation)
                                }
                            }
                            .padding(.top, 4)
                        },
                        label: {
                            Text("Sources (\(response.citations.count))")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    )
                }

                // Related resources
                if !response.relatedResources.isEmpty {
                    Divider()
                    DisclosureGroup(
                        isExpanded: $showResources,
                        content: {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(response.relatedResources) { resource in
                                    ResourceRow(resource: resource)
                                }
                            }
                            .padding(.top, 4)
                        },
                        label: {
                            Text("Resources (\(response.relatedResources.count))")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - Reusable sub-components

struct ConfidenceBadge: View {
    let confidence: String

    var color: Color {
        switch confidence.lowercased() {
        case "high": return .green
        case "low": return .orange
        default: return .blue
        }
    }

    var body: some View {
        Text(confidence.capitalized)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}

struct CitationRow: View {
    let citation: Citation

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("›")
                .font(.system(size: 10))
                .foregroundColor(.purple)
            VStack(alignment: .leading, spacing: 2) {
                Text(citation.author)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                Text(String(citation.text.prefix(120)) + (citation.text.count > 120 ? "…" : ""))
                    .font(.system(size: 10))
                    .foregroundColor(.primary.opacity(0.8))
                if let url = citation.url, !url.isEmpty {
                    Button(action: {
                        if let link = URL(string: url) { NSWorkspace.shared.open(link) }
                    }) {
                        Text("Source")
                            .font(.system(size: 9))
                            .foregroundColor(.blue.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ResourceRow: View {
    let resource: RelatedResource

    var body: some View {
        Button(action: {
            if let link = URL(string: resource.url) { NSWorkspace.shared.open(link) }
        }) {
            HStack(spacing: 6) {
                Image(systemName: resource.type == "github" ? "chevron.left.forwardslash.chevron.right" : "link")
                    .font(.system(size: 9))
                    .foregroundColor(.blue.opacity(0.7))
                Text(resource.title ?? resource.url)
                    .font(.system(size: 10))
                    .foregroundColor(.blue.opacity(0.8))
                    .lineLimit(1)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

struct ShortcutRow: View {
    let keys: String
    let action: String

    var body: some View {
        HStack {
            Text(keys)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 56, alignment: .leading)
            Text(action)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Existing components (unchanged)

struct MenuButton: View {
    let title: String
    let icon: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 10))
                Text(title).font(.system(size: 10))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .opacity(isLoading ? 0.5 : 1.0)
    }
}

private func formatUptime(_ interval: TimeInterval) -> String {
    let total = Int(interval)
    if total < 60 { return "\(total)s" }
    let h = total / 3600
    let m = (total % 3600) / 60
    if h > 0 { return "\(h)h \(m)m" }
    return "\(m)m"
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 12, weight: .medium))
        }
    }
}

// MARK: - Start Page

struct StartPageView: View {
    @ObservedObject var viewModel: SearchViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isLoadingStartPage {
                    HStack {
                        Spacer()
                        ProgressView().controlSize(.small)
                        Text("Loading your feed...").font(.caption).foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.top, 20)
                }

                // For You section
                if !viewModel.recommendations.isEmpty {
                    StartPageSection(title: "For You", icon: "heart.fill", tint: .pink) {
                        ForEach(viewModel.recommendations.prefix(5)) { post in
                            RecommendedPostCard(post: post) {
                                viewModel.trackResultClick(postId: post.id)
                                if let url = post.url, let link = URL(string: url) {
                                    NSWorkspace.shared.open(link)
                                }
                            }
                        }
                    }
                }

                // Recent Searches section
                if !viewModel.topQueries.isEmpty {
                    StartPageSection(title: "Recent Searches", icon: "clock.arrow.circlepath", tint: .blue) {
                        FlowLayout(spacing: 6) {
                            ForEach(viewModel.topQueries.prefix(8)) { query in
                                Button(action: { viewModel.fireQuickAsk(query.query) }) {
                                    HStack(spacing: 4) {
                                        Text(query.query)
                                            .font(.system(size: 11))
                                            .lineLimit(1)
                                        Text("\(query.count)")
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.regularMaterial)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.blue.opacity(0.15), lineWidth: 0.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Discover section (random high-value from recommendations tail)
                if viewModel.recommendations.count > 5 {
                    StartPageSection(title: "Discover", icon: "sparkle.magnifyingglass", tint: .orange) {
                        ForEach(viewModel.recommendations.suffix(3)) { post in
                            RecommendedPostCard(post: post) {
                                viewModel.trackResultClick(postId: post.id)
                                if let url = post.url, let link = URL(string: url) {
                                    NSWorkspace.shared.open(link)
                                }
                            }
                        }
                    }
                }

                // Empty state when no data yet
                if viewModel.recommendations.isEmpty && viewModel.topQueries.isEmpty && !viewModel.isLoadingStartPage {
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.largeTitle).foregroundColor(.purple.opacity(0.5))
                        Text("Search Claude Code tips & patterns").foregroundColor(.secondary)
                        Text("Your personalized feed will appear as you search")
                            .font(.caption).foregroundColor(.secondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                }
            }
            .padding()
        }
    }
}

struct StartPageSection<Content: View>: View {
    let title: String
    let icon: String
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(tint)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            content
        }
    }
}

struct RecommendedPostCard: View {
    let post: RecommendedPost
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(post.author)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "hand.thumbsup")
                        Text("\(post.likes)")
                    }
                    .font(.system(size: 9)).foregroundColor(.secondary)
                    if let score = post.recommendationScore {
                        Text(String(format: "%.0f", score))
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.purple.opacity(0.15))
                            .foregroundColor(.purple)
                            .clipShape(Capsule())
                    }
                }
                Text(String(post.text.prefix(200)) + (post.text.count > 200 ? "..." : ""))
                    .font(.system(size: 11))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
        .padding(8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }
}

// MARK: - Flow Layout (for chips that wrap)

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}

struct ResultCard: View {
    let result: SearchResult
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.2)).frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.purple)
                                .frame(width: geo.size.width * result.score, height: 4)
                        }
                    }
                    .frame(width: 60, height: 4)

                    Text(String(format: "%.0f%%", result.score * 100))
                        .font(.caption2).foregroundColor(.purple)

                    Spacer()

                    Text(result.author).font(.caption).foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "hand.thumbsup")
                        Text("\(result.likes)")
                    }
                    .font(.caption2).foregroundColor(.secondary)
                }

                Text(String(result.text.prefix(300)) + (result.text.count > 300 ? "..." : ""))
                    .font(.system(size: 12))
                    .lineLimit(5)
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)

                if let images = result.images, !images.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "photo").font(.system(size: 9))
                        Text("\(images.count) image\(images.count == 1 ? "" : "s")").font(.system(size: 9))
                    }
                    .foregroundColor(.purple.opacity(0.7))
                }

                if let url = result.url, !url.isEmpty {
                    Button(action: {
                        if let link = URL(string: url) { NSWorkspace.shared.open(link) }
                    }) {
                        HStack(spacing: 2) {
                            Image(systemName: "link")
                            Text("Source")
                        }
                        .font(.system(size: 9))
                        .foregroundColor(.blue.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
    }
}

// MARK: - LinkedIn Auth Banner

struct LinkedInAuthBannerView: View {
    @ObservedObject var viewModel: SearchViewModel

    private var hasLinkedInAuthorities: Bool {
        viewModel.authorities.contains { $0.platform == "linkedin" }
    }

    var body: some View {
        if hasLinkedInAuthorities {
            HStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .font(.system(size: 11))
                    .foregroundColor(statusColor)

                VStack(alignment: .leading, spacing: 1) {
                    Text("LinkedIn")
                        .font(.system(size: 10, weight: .semibold))
                    Text(statusLabel)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if viewModel.isLinkedInAuthenticating {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Working...")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                } else {
                    Button(action: { viewModel.showLinkedInSettings = true }) {
                        HStack(spacing: 3) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 9))
                            Text("Settings")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.purple.opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Configure LinkedIn authentication")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.04))
            .sheet(isPresented: $viewModel.showLinkedInSettings) {
                LinkedInSettingsSheet(viewModel: viewModel)
            }

            Divider()
        }
    }

    private var isAuthenticated: Bool {
        viewModel.linkedInAuth?.valid == true
    }

    private var statusIcon: String {
        guard let auth = viewModel.linkedInAuth else { return "key.slash" }
        if auth.valid { return "checkmark.shield.fill" }
        if auth.status == "expired" { return "exclamationmark.shield" }
        return "key.slash"
    }

    private var statusColor: Color {
        guard let auth = viewModel.linkedInAuth else { return .secondary }
        if auth.valid { return .green }
        if auth.status == "expired" { return .orange }
        return .secondary
    }

    private var statusLabel: String {
        guard let auth = viewModel.linkedInAuth else { return "Not authenticated" }
        if auth.valid {
            let method = auth.method ?? "unknown"
            return "Authenticated via \(method)"
        }
        if auth.status == "expired" { return "Session expired" }
        return "Not authenticated"
    }
}

// MARK: - LinkedIn Settings Sheet

struct LinkedInSettingsSheet: View {
    @ObservedObject var viewModel: SearchViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "person.crop.square.fill")
                    .foregroundColor(.blue)
                Text("LinkedIn Authentication")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Status card
                    linkedInStatusCard

                    Divider()

                    // Browser login method
                    browserLoginSection

                    Divider()

                    // Manual cookie method
                    manualCookieSection

                    // Error display
                    if let error = viewModel.linkedInAuthError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 11))
                            Text(error)
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                        }
                        .padding(10)
                        .background(Color.orange.opacity(0.08))
                        .cornerRadius(8)
                    }

                    // Validate section
                    if viewModel.linkedInAuth?.valid == true {
                        Divider()
                        validateSection
                    }
                }
                .padding()
            }
        }
        .frame(width: 420, height: 520)
        .background(.ultraThinMaterial)
    }

    // MARK: - Status Card

    private var linkedInStatusCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: statusIcon)
                    .font(.system(size: 18))
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(statusTitle)
                    .font(.system(size: 13, weight: .semibold))

                if let auth = viewModel.linkedInAuth, auth.valid {
                    HStack(spacing: 8) {
                        if let method = auth.method {
                            Label(method, systemImage: "checkmark.circle")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                        }
                        if let count = auth.cookieCount {
                            Text("\(count) cookies")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }

                    if let expires = auth.liAtExpires {
                        Text("Expires: \(expires)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    if let validated = auth.lastValidated {
                        Text("Last validated: \(validated)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Authenticate to enable LinkedIn profile scraping")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(statusColor.opacity(0.04))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(statusColor.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Browser Login

    private var browserLoginSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .foregroundColor(.blue)
                    .font(.system(size: 12))
                Text("Browser Login")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("Recommended")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
            }

            Text("Opens a Playwright browser for you to log in. Handles 2FA and CAPTCHA naturally. Cookies are captured automatically after login.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineSpacing(2)

            Button(action: { viewModel.authenticateLinkedIn() }) {
                HStack(spacing: 6) {
                    if viewModel.isLinkedInAuthenticating {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11))
                    Text(viewModel.isLinkedInAuthenticating ? "Waiting for login..." : "Launch Browser Login")
                        .font(.system(size: 11, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.12))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLinkedInAuthenticating)
        }
    }

    // MARK: - Manual Cookie

    private var manualCookieSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "doc.on.clipboard")
                    .foregroundColor(.orange)
                    .font(.system(size: 12))
                Text("Manual Cookie Paste")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("Fallback")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }

            Text("Open LinkedIn in your browser, then DevTools (F12) → Application → Cookies → linkedin.com → copy the **li_at** value.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineSpacing(2)

            TextEditor(text: $viewModel.manualCookieInput)
                .font(.system(size: 10, design: .monospaced))
                .frame(height: 48)
                .padding(6)
                .background(Color.black.opacity(0.2))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
                .overlay(alignment: .topLeading) {
                    if viewModel.manualCookieInput.isEmpty {
                        Text("li_at=AQE... or full Cookie header")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(10)
                            .allowsHitTesting(false)
                    }
                }

            Button(action: { viewModel.authenticateLinkedInManual() }) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 11))
                    Text("Save Cookies")
                        .font(.system(size: 11, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLinkedInAuthenticating || viewModel.manualCookieInput.trimmingCharacters(in: .whitespacesAndNewlines).count < 10)
        }
    }

    // MARK: - Validate

    private var validateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield")
                    .foregroundColor(.green)
                    .font(.system(size: 12))
                Text("Cookie Validation")
                    .font(.system(size: 12, weight: .semibold))
            }

            Text("Test that saved cookies are still accepted by LinkedIn's API.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Button(action: { viewModel.validateLinkedInCookies() }) {
                HStack(spacing: 6) {
                    if viewModel.isLinkedInAuthenticating {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                    Text("Re-validate Now")
                        .font(.system(size: 11, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.12))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLinkedInAuthenticating)
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        guard let auth = viewModel.linkedInAuth else { return .secondary }
        if auth.valid { return .green }
        if auth.status == "expired" { return .orange }
        return .secondary
    }

    private var statusIcon: String {
        guard let auth = viewModel.linkedInAuth else { return "key.slash" }
        if auth.valid { return "checkmark.shield.fill" }
        if auth.status == "expired" { return "exclamationmark.shield" }
        return "key.slash"
    }

    private var statusTitle: String {
        guard let auth = viewModel.linkedInAuth else { return "Not Authenticated" }
        if auth.valid { return "Authenticated" }
        if auth.status == "expired" { return "Session Expired" }
        return "Not Authenticated"
    }
}

// MARK: - AuthorityRowView

struct AuthorityRowView: View {
    let authority: Authority
    let isSyncing: Bool
    let isLinkedInAuthenticated: Bool
    let onSync: () -> Void
    let onLinkedInAuth: () -> Void

    init(authority: Authority, isSyncing: Bool, isLinkedInAuthenticated: Bool = false, onSync: @escaping () -> Void, onLinkedInAuth: @escaping () -> Void = {}) {
        self.authority = authority
        self.isSyncing = isSyncing
        self.isLinkedInAuthenticated = isLinkedInAuthenticated
        self.onSync = onSync
        self.onLinkedInAuth = onLinkedInAuth
    }

    private var statusColor: Color {
        switch authority.status {
        case "active": return .green
        case "browser-only":
            // LinkedIn with cookies shows as upgradeable
            return (authority.platform == "linkedin" && isLinkedInAuthenticated) ? .blue : .orange
        case "paused": return .gray
        case "error": return .red
        default: return .secondary
        }
    }

    private var effectiveStatus: String {
        if authority.platform == "linkedin" && authority.status == "browser-only" && isLinkedInAuthenticated {
            return "cookie-auth"
        }
        return authority.status
    }

    private var platformIcon: String {
        switch authority.platform {
        case "github": return "chevron.left.forwardslash.chevron.right"
        case "linkedin": return "person.crop.square.fill"
        case "rss", "blog": return "dot.radiowaves.up.forward"
        case "youtube": return "play.rectangle.fill"
        case "x": return "at"
        default: return "globe"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: platformIcon)
                    .font(.system(size: 13))
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(authority.name)
                        .font(.system(size: 12, weight: .medium))

                    let label = effectiveStatus == "cookie-auth" ? "cookie-auth" : authority.status
                    Text(label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.12))
                        .clipShape(Capsule())
                }

                HStack(spacing: 8) {
                    Text("\(authority.postCount) posts")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if authority.newSinceLastSync > 0 {
                        Text("+\(authority.newSinceLastSync) new")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }

                    if let last = authority.lastSyncedAt {
                        Text("synced \(last.prefix(10))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                if !authority.expertiseTags.isEmpty {
                    Text(authority.expertiseTags.prefix(3).joined(separator: " · "))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isSyncing {
                ProgressView()
                    .scaleEffect(0.7)
            } else if authority.platform == "linkedin" && authority.status == "browser-only" && !isLinkedInAuthenticated {
                // LinkedIn not authenticated — show key icon
                Button(action: onLinkedInAuth) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
                .help("Authenticate LinkedIn to enable sync")
            } else if authority.status == "browser-only" && authority.platform != "linkedin" {
                Image(systemName: "safari")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
                    .help("Sync via Tampermonkey userscript")
            } else {
                Button(action: onSync) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help("Sync now")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
