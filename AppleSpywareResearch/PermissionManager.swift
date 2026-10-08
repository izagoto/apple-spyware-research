
import AVFoundation
import Combine
import Contacts
import CoreLocation
import EventKit
import Photos
import SwiftUI

@MainActor
final class PermissionManager: NSObject, ObservableObject {

    // MARK: - Permission Status

    @Published var cameraStatus = "Not Requested"
    @Published var microphoneStatus = "Not Requested"
    @Published var photosStatus = "Not Requested"
    @Published var contactsStatus = "Not Requested"
    @Published var locationStatus = "Not Requested"
    @Published var calendarStatus = "Not Requested"

    // MARK: - Contacts Research

    @Published var contactResults: [String] = []
    @Published var contactsReadStatus = "Not Tested"

    // MARK: - Photos Research

    @Published var photoResults: [String] = []
    @Published var photosReadStatus = "Not Tested"

    // MARK: - Location Research

    @Published var locationResults: [String] = []
    @Published var locationReadStatus = "Not Tested"
    
    // MARK: - Calendar Research

    @Published var calendarResults: [String] = []
    @Published var calendarReadStatus = "Not Tested"

    // MARK: - Managers

    private let locationManager = CLLocationManager()
    private let eventStore = EKEventStore()
    private let contactStore = CNContactStore()

    // MARK: - Initialization

    override init() {
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest

        refreshStatuses()
    }

    // MARK: - Permission Requests

    func requestCamera() {
        Task {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraStatus = granted ? "Granted" : "Denied"
        }
    }

    func requestMicrophone() {
        Task {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            microphoneStatus = granted ? "Granted" : "Denied"
        }
    }

    func requestPhotos() {
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(
                for: .readWrite
            )
            photosStatus = photoStatusText(status)
        }
    }

    func requestContacts() {
        Task {
            do {
                let granted = try await contactStore.requestAccess(
                    for: .contacts
                )
                contactsStatus = granted ? "Granted" : "Denied"
            } catch {
                contactsStatus = "Failed"
            }
        }
    }

    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestCalendar() {
        Task {
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                calendarStatus = granted ? "Granted" : "Denied"
            } catch {
                calendarStatus = "Failed"
            }
        }
    }

    // MARK: - Contacts Data Access Test

    func readContacts() {
        let authorizationStatus =
            CNContactStore.authorizationStatus(for: .contacts)

        guard authorizationStatus == .authorized else {
            contactsReadStatus = "Permission Not Granted"
            contactResults = []
            return
        }

        contactsReadStatus = "Reading..."

        Task {
            do {
                let results = try await Self.fetchContacts()

                contactResults = results
                contactsReadStatus =
                    "Success - \(results.count) contact(s)"
            } catch {
                contactResults = []
                contactsReadStatus =
                    "Failed: \(error.localizedDescription)"
            }
        }
    }

    private nonisolated static func fetchContacts() async throws -> [String] {
        try await Task.detached(priority: .userInitiated) {
            let store = CNContactStore()

            let keysToFetch: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor
            ]

            let request = CNContactFetchRequest(
                keysToFetch: keysToFetch
            )

            var results: [String] = []

            try store.enumerateContacts(with: request) { contact, _ in
                let fullName =
                    "\(contact.givenName) \(contact.familyName)"
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                let phoneNumbers = contact.phoneNumbers.map {
                    $0.value.stringValue
                }

                let emailAddresses = contact.emailAddresses.map {
                    String($0.value)
                }

                var details =
                    fullName.isEmpty ? "(No Name)" : fullName

                if !phoneNumbers.isEmpty {
                    details +=
                        "\nPhone: \(phoneNumbers.joined(separator: ", "))"
                }

                if !emailAddresses.isEmpty {
                    details +=
                        "\nEmail: \(emailAddresses.joined(separator: ", "))"
                }

                results.append(details)
            }

            return results
        }.value
    }

    // MARK: - Photos Data Access Test

    func readPhotos() {
        let authorizationStatus =
            PHPhotoLibrary.authorizationStatus(for: .readWrite)

        guard authorizationStatus == .authorized ||
              authorizationStatus == .limited else {
            photosReadStatus = "Permission Not Granted"
            photoResults = []
            return
        }

        let assets = PHAsset.fetchAssets(with: nil)
        var results: [String] = []

        assets.enumerateObjects { asset, _, _ in
            let mediaType: String

            switch asset.mediaType {
            case .image:
                mediaType = "Image"
            case .video:
                mediaType = "Video"
            case .audio:
                mediaType = "Audio"
            case .unknown:
                mediaType = "Unknown"
            @unknown default:
                mediaType = "Unknown"
            }

            var details = mediaType

            details +=
                "\nDimensions: \(asset.pixelWidth) × \(asset.pixelHeight)"

            if let creationDate = asset.creationDate {
                details +=
                    "\nCreated: \(creationDate.formatted())"
            }

            results.append(details)
        }

        photoResults = results
        photosReadStatus =
            "Success - \(results.count) asset(s)"
    }

    // MARK: - Location Data Access Test

    func readLocation() {
        let authorizationStatus = locationManager.authorizationStatus

        guard authorizationStatus == .authorizedWhenInUse ||
              authorizationStatus == .authorizedAlways else {
            locationReadStatus = "Permission Not Granted"
            locationResults = [
                "Grant Location permission before reading."
            ]
            return
        }

        locationReadStatus = "Reading..."
        locationResults = []

        locationManager.requestLocation()
    }
    
    // MARK: - Calendar Data Access Test

    func readCalendar() {
        let authorizationStatus =
            EKEventStore.authorizationStatus(for: .event)

        guard authorizationStatus == .fullAccess else {
            calendarReadStatus = "Permission Not Granted"
            calendarResults = [
                "Grant full Calendar access before reading."
            ]
            return
        }

        calendarReadStatus = "Reading..."
        calendarResults = []

        let calendar = Calendar.current

        guard
            let startDate = calendar.date(
                byAdding: .day,
                value: -1,
                to: Date()
            ),
            let endDate = calendar.date(
                byAdding: .day,
                value: 30,
                to: Date()
            )
        else {
            calendarReadStatus = "Failed"
            calendarResults = [
                "Unable to create research date range."
            ]
            return
        }

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )

        let events = eventStore.events(matching: predicate)

        calendarResults = events.map { event in
            var details = event.title ?? "(No Title)"

            details += "\nStart: \(event.startDate.formatted())"
            details += "\nEnd: \(event.endDate.formatted())"

            if let calendarTitle = event.calendar?.title {
                details += "\nCalendar: \(calendarTitle)"
            }

            return details
        }

        calendarReadStatus =
            "Success - \(events.count) event(s)"
    }

    // MARK: - Refresh Permission Status

    func refreshStatuses() {
        cameraStatus = cameraStatusText(
            AVCaptureDevice.authorizationStatus(for: .video)
        )

        microphoneStatus = cameraStatusText(
            AVCaptureDevice.authorizationStatus(for: .audio)
        )

        photosStatus = photoStatusText(
            PHPhotoLibrary.authorizationStatus(for: .readWrite)
        )

        contactsStatus = contactStatusText(
            CNContactStore.authorizationStatus(for: .contacts)
        )

        locationStatus = locationStatusText(
            locationManager.authorizationStatus
        )

        calendarStatus = calendarStatusText(
            EKEventStore.authorizationStatus(for: .event)
        )
    }

    // MARK: - Camera & Microphone Status

    private func cameraStatusText(
        _ status: AVAuthorizationStatus
    ) -> String {
        switch status {
        case .authorized:
            return "Granted"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Requested"
        @unknown default:
            return "Unknown"
        }
    }

    // MARK: - Photos Status

    private func photoStatusText(
        _ status: PHAuthorizationStatus
    ) -> String {
        switch status {
        case .authorized:
            return "Granted"
        case .limited:
            return "Limited"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Requested"
        @unknown default:
            return "Unknown"
        }
    }

    // MARK: - Contacts Status

    private func contactStatusText(
        _ status: CNAuthorizationStatus
    ) -> String {
        switch status {
        case .authorized:
            return "Granted"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Requested"
        case .limited:
            return "Limited"
        @unknown default:
            return "Unknown"
        }
    }

    // MARK: - Location Status

    private func locationStatusText(
        _ status: CLAuthorizationStatus
    ) -> String {
        switch status {
        case .authorizedWhenInUse:
            return "When In Use"
        case .authorizedAlways:
            return "Always"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Requested"
        @unknown default:
            return "Unknown"
        }
    }

    // MARK: - Calendar Status

    private func calendarStatusText(
        _ status: EKAuthorizationStatus
    ) -> String {
        switch status {
        case .fullAccess:
            return "Granted"
        case .writeOnly:
            return "Write Only"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Requested"
        @unknown default:
            return "Unknown"
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension PermissionManager: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        locationStatus = locationStatusText(
            manager.authorizationStatus
        )
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else {
            locationReadStatus = "No Location Available"
            locationResults = []
            return
        }

        locationReadStatus = "Success"

        locationResults = [
            "Latitude: \(location.coordinate.latitude)",
            "Longitude: \(location.coordinate.longitude)",
            "Accuracy: \(location.horizontalAccuracy) meters",
            "Timestamp: \(location.timestamp.formatted())"
        ]
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        locationReadStatus = "Failed"
        locationResults = [
            error.localizedDescription
        ]
    }
}
