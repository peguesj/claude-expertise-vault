import Foundation
import SwiftUI

@MainActor
class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var results: [SearchResult] = []
    @Published var isSearching: Bool = false
    @Published var error: String? = nil
    @Published var serverOnline: Bool = false

    private var searchTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?

    init() {
        Task { await checkServer() }
    }

    func onQueryChanged() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            if query.trimmingCharacters(in: .whitespaces).count >= 2 {
                await performSearch()
            } else if query.trimmingCharacters(in: .whitespaces).isEmpty {
                results = []
                error = nil
            }
        }
    }

    func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        searchTask?.cancel()
        isSearching = true
        error = nil

        searchTask = Task {
            do {
                let fetchedResults = try await APIClient.shared.search(query: trimmed)
                guard !Task.isCancelled else { return }
                self.results = fetchedResults
            } catch {
                guard !Task.isCancelled else { return }
                self.error = error.localizedDescription
                self.results = []
            }
            self.isSearching = false
        }
    }

    func checkServer() async {
        serverOnline = await APIClient.shared.healthCheck()
    }

    func openInBrowser() {
        if let url = URL(string: "http://localhost:8645") {
            NSWorkspace.shared.open(url)
        }
    }
}
