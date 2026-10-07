import SwiftUI

struct ContentView: View {
    @StateObject private var permissions = PermissionManager()

    var body: some View {
        NavigationStack {
            List {

                // MARK: - Permission Status

                Section("Permissions") {
                    PermissionRow(
                        name: "Camera",
                        status: permissions.cameraStatus,
                        action: permissions.requestCamera
                    )

                    PermissionRow(
                        name: "Microphone",
                        status: permissions.microphoneStatus,
                        action: permissions.requestMicrophone
                    )

                    PermissionRow(
                        name: "Photos",
                        status: permissions.photosStatus,
                        action: permissions.requestPhotos
                    )

                    PermissionRow(
                        name: "Contacts",
                        status: permissions.contactsStatus,
                        action: permissions.requestContacts
                    )

                    PermissionRow(
                        name: "Location",
                        status: permissions.locationStatus,
                        action: permissions.requestLocation
                    )

                    PermissionRow(
                        name: "Calendar",
                        status: permissions.calendarStatus,
                        action: permissions.requestCalendar
                    )
                }

                // MARK: - Contacts Data Access

                Section("Contacts Data Access") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Contacts Read Test")
                                .font(.headline)

                            Text(permissions.contactsReadStatus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Read Contacts") {
                            permissions.readContacts()
                        }
                    }

                    if !permissions.contactResults.isEmpty {
                        ForEach(
                            Array(permissions.contactResults.enumerated()),
                            id: \.offset
                        ) { _, contact in
                            Text(contact)
                                .font(.callout)
                                .textSelection(.enabled)
                                .padding(.vertical, 4)
                        }
                    }
                }

                // MARK: - Photos Data Access

                Section("Photos Data Access") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Photos Read Test")
                                .font(.headline)

                            Text(permissions.photosReadStatus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Read Photos") {
                            permissions.readPhotos()
                        }
                    }

                    if !permissions.photoResults.isEmpty {
                        ForEach(
                            Array(permissions.photoResults.enumerated()),
                            id: \.offset
                        ) { _, photo in
                            Text(photo)
                                .font(.callout)
                                .textSelection(.enabled)
                                .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Permission Research")
            .toolbar {
                Button("Refresh") {
                    permissions.refreshStatuses()
                }
            }
        }
    }
}

// MARK: - Permission Row

struct PermissionRow: View {
    let name: String
    let status: String
    let action: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)

                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Request") {
                action()
            }
        }
    }
}

#Preview {
    ContentView()
}
