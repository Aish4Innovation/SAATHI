# Saathi App: Your Personal Medicine Reminder
*Saathi App* is a cross-platform medicine reminder application built with Flutter. It helps users manage their medication schedule with intelligent reminders, voice notes, and caregiver alerts for missed doses, ensuring they never miss a dose again.

<img width="638" height="1027" alt="image" src="https://github.com/user-attachments/assets/a0646cb9-6028-41f2-a293-39afe7ed3c2f" />


<img width="626" height="1019" alt="image" src="https://github.com/user-attachments/assets/de65af4e-fd62-4bb5-8ceb-b426423e7561" />


<img width="634" height="1027" alt="image" src="https://github.com/user-attachments/assets/8c1f4135-b64c-4a9e-98c3-7870aaca368f" />


<img width="626" height="898" alt="image" src="https://github.com/user-attachments/assets/bb2ef48b-72a7-4f6e-93ba-219dbdf0873c" />


<img width="572" height="849" alt="image" src="https://github.com/user-attachments/assets/98f9a403-ee18-44d3-825f-85085394236f" />


<img width="596" height="887" alt="image" src="https://github.com/user-attachments/assets/959ed88a-dd53-4ae0-8f71-7d4de67cb1ea" />


<img width="595" height="846" alt="image" src="https://github.com/user-attachments/assets/d1d1afdf-27b5-4ee2-a8a9-e9a47e348874" />




## ✨ Features

- **Personalized Reminders:** Set custom schedules for all your medicines, with notifications that remind you exactly when to take them.
- **Voice Notes:** Record and attach a personal voice note to each medicine, providing spoken instructions or reminders in your own voice.
- **Caregiver Alerts:** The app can be configured to alert a caregiver via a backend service if a dose is marked as missed, ensuring peace of mind for both the user and their family. (Mobile-only feature).
- **Cross-Platform Support:** Built with a single codebase for Android, iOS, and Web.
- **Photo Upload:** Upload a photo of your medicine to easily identify it at a glance.
- **User-Specific Data:** Integrates with a backend API to manage user accounts and medication data securely.

## 🚀 Technology Stack

- **Framework:** [Flutter](https://flutter.dev/)
- **Backend Communication:** `http` for API requests.
- **Local Notifications:** `flutter_local_notifications` for scheduling and displaying reminders.
- **Background Tasks:** `workmanager` for running background processes like the missed dose check on mobile platforms.
- **Audio Recording & Playback:** `record` for voice note recording and `just_audio` for playback.
- **Text-to-Speech:** `flutter_tts` for potential future voice-based features.
- **File & Storage:** `image_picker` for photo uploads and `path_provider` for local file storage (on mobile).
- **Permissions:** `permission_handler` to manage microphone and storage access.
- **State Management:** `shared_preferences` for managing user settings and preferences locally.

## ⚠️ Important Note on Platform Differences

This application is primarily designed for mobile use (Android/iOS). While the web version is functional for scheduling and displaying data, certain key features are not available due to browser limitations:

- **Background Tasks:** The `workmanager` plugin is not supported on the web, meaning the "missed dose check" and caregiver alerts will **not** work.
- **Notifications:** Web notifications can only be displayed when the browser tab is open. They will not be delivered if the browser is closed.
- **Local Storage:** The voice notes are stored as local files on mobile devices, but on the web, they are handled as temporary URLs (blobs).

