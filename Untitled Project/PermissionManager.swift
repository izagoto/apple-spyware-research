import AVFoundation
import Contacts
import CoreLocation
import EventKit
import Photos

@MainActor
final class PermissionManager: NSObject, ObservableObject {
    @Published var cameraStatus = "Not Requested"
    @Published var microphoneStatus = "Not Requested"
    @Published var photosStatus = "Not Requested"
    @Published var contactsStatus = "Not Requested"
    @Published var locationStatus = "Not Requested"
    @Published var calendarStatus = "Not Requested"

    private let locationManager = CLLocationManager()
    private let eventStore = EKEventStore()

    override init() {
        super.init()

        locationManager.delegate = self

        refreshStatuses()
    }

    func requestCamera() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            Task { @MainActor in
                self?.cameraStatus = granted ? "Granted" : "Denied"
            }
        }
    }

    func requestMicrophone() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            Task { @MainActor in
                self?.microphoneStatus = granted ? "Granted" : "Denied"
            }
        }
    }

    func requestPhotos() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            Task { @MainActor in
                self?.photosStatus = self?.photoStatusText(status) ?? "Unknown"
            }
        }
    }

    func requestContacts() {
        CNContactStore().requestAccess(for: .contacts) { [weak self] granted, _ in
            Task { @MainActor in
                self?.contactsStatus = granted ? "Granted" : "Denied"
            }
        }
    }

    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestCalendar() {
        eventStore.requestFullAccessToEvents { [weak self] granted, _ in
            Task { @MainActor in
                self?.calendarStatus = granted ? "Granted" : "Denied"
            }
        }
    }

    func refreshStatuses() {
        cameraStatus = cameraStatusText(
            AVCaptureDevice.authorizationStatus(for: .video)
        )

        microphoneStatus = microphoneStatusText(
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

    private func microphoneStatusText(
        _ status: AVAuthorizationStatus
    ) -> String {
        cameraStatusText(status)
    }

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
        @unknown default:
            return "Unknown"
        }
    }

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

extension PermissionManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        Task { @MainActor in
            locationStatus = locationStatusText(
                manager.authorizationStatus
            )
        }
    }
}
