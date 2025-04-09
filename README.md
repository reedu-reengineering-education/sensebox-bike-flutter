# sensebox Bike Flutter App

## Overview

This Flutter app connects to a [senseBox device](https://sensebox.de/en/products-bike) on a bike. It collects valuable data about surroundings while riding and allows user to upload gathered data to the [openSenseMap](https://opensensemap.org/), contributing to urban environmental monitoring and citizen science projects. The app is available for both iOS and Android.

## Getting Started

### Prerequisites

*   Flutter SDK: Make sure you have the Flutter SDK installed on your machine. You can download it from [https://flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install).
*   Android Studio, Xcode and code editor of your choice.
*   senseBox Device: You need a senseBox device configured to collect the desired sensor data.

### Installation

1.  **Clone the repository:**

    ```
    git clone https://github.com/reedu-reengineering-education/sensebox-bike-flutter.git
    cd sensebox-bike-flutter
    ```

2.  **Get dependencies:**

    ```
    flutter pub get
    ```

### Running the App

1.  **Connect your device:** Connect your Android or iOS device to your computer, or use an emulator.

2.  **Run the app:**

    ```
    flutter run
    ```

    This command will build and install the app on your connected device or emulator.

## Troubleshooting

If you run into issues while running the app, you can take the following troubleshooting steps:
*   Make sure you are running the most recent versions of Flutter, Android Studio, and Xcode as we try to keep the current project up-to-date. You can review your current configuration by running the following command:

    ```
    flutter doctor -v
    ```

*   If you encounter issues while running the app on Android, please try running a Gradle sync in Android Studio. To do so:

    1.  Open `/sensebox-bike-flutter/android/` folder in Android Studio.
    2.  Gradle sync should start automatically.

*   You can clean the project and reinstall the dependencies.

    ```
    flutter clean
    flutter pub get
    ```

    ## GitHub Actions & Contribution Guidelines

*   **Automated Testing on Pull Requests:**
    *   When you create a new pull request (PR), our GitHub Actions workflows automatically run a suite of tests. This ensures that your contributions maintain code quality and don't introduce regressions.

*   **Updating Dart/Flutter and GitHub Actions:**
    *   Whenever you update Dart or Flutter dependencies within the project, it's **crucial** that you also review and update the relevant GitHub Actions workflow files. This ensures compatibility and prevents build failures. Look for workflows that involve Dart or Flutter setup and adjust versions accordingly.

 ## Add location tag

 **Without App Rebuild**
 - Add new location in the `/assets/locations.json` file and ensure it is available on the main branch..
 - Verify that you can view this location when creating a new box. The new location should appear when you open the CreateBikeBoxDialog next time. If the new location is unavailable, try restarting the app.

  **Requires Releasing a New Version of the App**
  - Ensure you add the necessary translations and update `lib/extensions/app_localizations_extensions.dart'.
