import SwiftUI

struct ListView: View {
    var body: some View {
        Text("List")
    }
}

extension ListView {
    func listId() -> some View {
        id("List")
    }
}

struct DetailsView: View {
    var body: some View {
        Text("Details")
    }
}

extension DetailsView {
    func detailsId() -> some View {
        id("Details")
    }
}

extension View {
    func anyId() -> some View {
        return id(UUID().uuidString)
    }
}
