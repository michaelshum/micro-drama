import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Profile",
                systemImage: "person.crop.circle",
                description: Text("Profile will be added later.")
            )
            .navigationTitle("Profile")
        }
    }
}
