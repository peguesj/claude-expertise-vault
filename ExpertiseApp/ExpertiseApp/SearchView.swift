import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            toolBar
            searchBar
            if viewModel.query.isEmpty && !viewModel.showingStats {
                quickAskChips
            }
            if let status = viewModel.pipelineStatus {
                statusBanner(status)
            }
            Divider().padding(.top, 4)
            if viewModel.showingStats {
                statsPanel
            } else if viewModel.mode == .ask {
                askResultView
            } else {
                searchResultsView
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .background(keyboardShortcuts)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .foregroundColor(.purple)
                .font(.title2)
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

                // Stats toggle
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) { viewModel.showingStats.toggle() }
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
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
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
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
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
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.largeTitle).foregroundColor(.purple.opacity(0.5))
                Text("Search Claude Code tips & patterns").foregroundColor(.secondary)
                Text("Supports natural language queries")
                    .font(.caption).foregroundColor(.secondary.opacity(0.7))
            }
            .frame(maxHeight: .infinity)
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
                        ResultCard(result: result)
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
                withAnimation(.easeInOut(duration: 0.2)) { viewModel.showingStats.toggle() }
                if viewModel.showingStats { Task { await viewModel.refreshStats() } }
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("") {
                withAnimation(.easeInOut(duration: 0.2)) { viewModel.showInsights.toggle() }
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .allowsHitTesting(false)
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
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.purple.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                )
        )
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
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .opacity(isLoading ? 0.5 : 1.0)
    }
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

struct ResultCard: View {
    let result: SearchResult

    var body: some View {
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
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}
