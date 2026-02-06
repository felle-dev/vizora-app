  # Vizora

  [![Latest release](https://img.shields.io/github/v/release/felle-dev/vizora-app?style=for-the-badge)](https://github.com/felle-dev/vizora-app/releases)
  [![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
  [![License](https://img.shields.io/github/license/felle-dev/vizora-app?style=for-the-badge)](LICENSE)

  **Vizora** is a comprehensive screen time management app that helps you understand and control your digital habits. Track app usage, set timers, and take control of your time.

  Monitor every app, understand your usage patterns, and make informed decisions about your digital wellbeing. Whether you're managing daily screen time or building healthier habits, Vizora keeps your usage data organized and actionable.

  [![Get it on GitHub](https://img.shields.io/badge/Get%20it%20on-GitHub-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/felle-dev/vizora-app/releases)

  ## Features

  ### **Usage Tracking**
  - Real-time app usage statistics
  - Detailed session tracking with start times
  - Hourly usage breakdown charts
  - Daily, weekly, and custom date range views

  ### **App Timers**
  - Set daily time limits for any app (Digital Wellbeing style)
  - Visual timer indicators on app icons
  - Usage progress tracking
  - Flexible limits from 5 to 300 minutes

  ### **Home Screen Widget**
  - Compact 1x1 widget - Quick glance at total screen time
  - Detailed 2x2 widget - See top 3 apps and total time
  - Real-time updates with refresh button
  - Tap to open app

  ### **Smart Filtering**
  - Ignore apps you don't want tracked
  - Automatic launcher app filtering
  - Minimum 3-minute usage threshold
  - Custom ignored apps list management

  ### **Beautiful Analytics**
  - Pie charts showing usage distribution
  - Line charts for hourly patterns
  - Total screen time overview
  - Session count tracking

  ### **Privacy & Security**
  - All data stays on your device
  - No internet connection required
  - No ads or tracking
  - Full control over your data

  ### **Advanced Permissions**
  - Usage Stats access
  - Accessibility Service (for app blocking)
  - Display Overlay (for timer notifications)
  - Device Admin (anti-uninstall protection)
  
  ## Screenshots
  <div style="display: flex; justify-content: space-around; gap: 10px; flex-wrap: wrap;">
    <img src="./screenshots/ss1.png" width="200">
    <img src="./screenshots/ss2.png" width="200">
    <img src="./screenshots/ss3.png" width="200">
  </div>

  ## Tech Stack

  - **Language:** Dart & Kotlin
  - **Framework:** Flutter 3.24+
  - **UI:** Material Design 3
  - **Charts:** fl_chart
  - **Platform:** Android (Minimum API 24 / Android 7.0)
  - **Target SDK:** API 36

  ### Key Components
  - **Usage Stats Manager** - Android system API integration
  - **Accessibility Service** - For app blocking features
  - **App Widgets** - Home screen integration
  - **Device Admin** - Anti-uninstall protection
  - **SharedPreferences** - Local data persistence

  ## Getting Started

  ### Prerequisites

  - [Flutter SDK](https://flutter.dev/docs/get-started/install) (latest stable version)
  - Android Studio / VS Code with Flutter extensions
  - Android device or emulator (API 24+)
  - Android SDK with API 36

  ### Installation

  1. **Clone the repository**
  ```bash
  git clone https://github.com/felle-dev/vizora-app.git
  cd vizora-app
  ```

  2. **Install dependencies**
  ```bash
  flutter pub get
  ```

  3. **Run the app**
  ```bash
  flutter run
  ```

  ### Build APK

  ```bash
  # Debug APK
  flutter build apk

  # Release APK
  flutter build apk --release

  # Split APKs by architecture
  flutter build apk --split-per-abi
  ```

  The APK will be available in `build/app/outputs/flutter-apk/`

  ## Required Permissions

  Vizora requires the following permissions to function properly:

  1. **Usage Access** - Track app usage statistics
  2. **Accessibility Service** - Monitor app activity and enforce timers
  3. **Display Over Other Apps** - Show timer notifications
  4. **Device Administrator** - Prevent unauthorized app removal

  All permissions are requested on first launch with clear explanations.

  ## Contributing

  Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

  1. Fork the Project
  2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
  3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
  4. Push to the Branch (`git push origin feature/AmazingFeature`)
  5. Open a Pull Request

  ### Development Guidelines

  - Follow Flutter/Dart style guidelines
  - Write clear commit messages
  - Test on multiple Android versions
  - Update documentation as needed

  Feel free to open issues for:
  - Bug reports
  - Feature requests
  - Questions or discussions
  - Documentation improvements

  ## FAQ

  **Q: Why does Vizora need so many permissions?**
  A: Each permission serves a specific purpose:
  - Usage Stats: Track app usage
  - Accessibility: Monitor and block apps
  - Overlay: Show timer alerts
  - Device Admin: Prevent accidental uninstall

  **Q: Does Vizora collect my data?**
  A: No! All data stays on your device. Vizora has no internet permission and cannot send data anywhere.

  **Q: Why isn't my launcher app showing?**
  A: Vizora automatically filters out your default launcher to show only meaningful usage data.

  **Q: What's the minimum usage time threshold?**
  A: Apps must be used for at least 3 minutes to appear in statistics. This filters out accidental opens.

  ## Support

  If you find Vizora useful, please consider:

  - Starring the repository
  - Reporting bugs or suggesting features
  - Sharing Vizora with friends and family
  - Contributing to the codebase
  - [Buying me a coffee](https://buymeacoffee.com/felle) (optional)

  ## License

  This project is licensed under the **GNU General Public License v3.0** - see the [LICENSE](LICENSE) file for details.

  This means you are free to:
  - Use the software for any purpose
  - Study and modify the source code
  - Distribute copies
  - Distribute modified versions

  Under the condition that:
  - Derivative works must use the same license
  - Source code must be disclosed
  - Changes must be documented

  ## Author

  **Felle**
  - GitHub: [@felle-dev](https://github.com/felle-dev)
  - Email: realfelle@proton.me

  ## Acknowledgments

  - Built with [Flutter](https://flutter.dev)
  - Charts by [fl_chart](https://pub.dev/packages/fl_chart)
  - Inspired by Digital Wellbeing and similar screen time apps
  - Thanks to all contributors!

  ---

  <p align="center">
    <a href="https://github.com/felle-dev/vizora-app">Star this repo</a> •
    <a href="https://github.com/felle-dev/vizora-app/issues"> sReport Bug</a> •
    <a href="https://github.com/felle-dev/vizora-app/issues">Request Feature</a>
  </p>
