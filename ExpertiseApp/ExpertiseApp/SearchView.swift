import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            searchBar
            Divider().padding(.top, 8)
            resultsArea
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var headerBar: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .foregroundColor(.purple)
                .font(.title2)
            Text("Claude Expertise")
                .font(.headline)
            Spacer()
            Button(action: viewModel.openInBrowser) {
                Image(systemName: "safari")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open in Browser")

            Circle()
                .fill(viewModel.serverOnline ? Color.green : Color.red)
                .frame(width: 8, height: 8)
                .help(viewModel.serverOnline ? "Server online" : "Server offline")
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search expertise...", text: $viewModel.query)
                .textFieldStyle(.plain)
                .onSubmit { Task { await viewModel.performSearch() } }
                .onChange(of: viewModel.query) { viewModel.onQueryChanged() }
            if viewModel.isSearching {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var resultsArea: some View {
        if let error = viewModel.error {
            VStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                Text(error)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxHeight: .infinity)
        } else if viewModel.results.isEmpty && !viewModel.query.isEmpty && !viewModel.isSearching {
            VStack {
                Image(systemName: "magnifyingglass")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("No results found")
                    .foregroundColor(.secondary)
            }
            .frame(maxHeight: .infinity)
        } else if viewModel.results.isEmpty {
            VStack {
                Image(systemName: "sparkles")
                    .font(.largeTitle)
                    .foregroundColor(.purple.opacity(0.5))
                Text("Search Claude Code tips & patterns")
                    .foregroundColor(.secondary)
            }
            .frame(maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.results) { result in
                        ResultCard(result: result)
                    }
                }
                .padding()
            }
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
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.purple)
                            .frame(width: geo.size.width * result.score, height: 4)
                    }
                }
                .frame(width: 60, height: 4)

                Text(String(format: "%.0f%%", result.score * 100))
                    .font(.caption2)
                    .foregroundColor(.purple)

                Spacer()

                Text(result.author)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "hand.thumbsup")
                    Text("\(result.likes)")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }

            Text(String(result.text.prefix(300)) + (result.text.count > 300 ? "..." : ""))
                .font(.system(size: 12))
                .lineLimit(5)
                .foregroundColor(.primary)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}
