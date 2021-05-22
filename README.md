# DrawAR

![banner](https://user-images.githubusercontent.com/8284016/119224364-f7ad0f80-baf5-11eb-97be-e242dac35935.png)

DrawAR is a proof of concept collaborative AR drawing app.  This code demonstrates a simple AR drawing app using [ARKit](https://developer.apple.com/documentation/arkit) to create lines in 3D space.  The [Multipeer Connectivity](https://developer.apple.com/documentation/multipeerconnectivity) framework is used to share drawings with nearby devices.  When an `ARWorldMap` is generated on one device and sent to others nearby, drawings will appear on other devices in the correct location.

This project was submitted in partial fulfillment of the requirements for the CS7GV4/CSU44054 Augmented Reality course at Trinity College Dublin.

## Usage
1. Clone or download this repository and open the `.xcodeproj` file in Xcode.
2. Run the application on a device with running iOS 14.1 or later and an A9 or later processor.
3. Look around to generate a world map, select a color from the color well and hold the "DRAW" button to draw lines in AR where the device is looking.
4. Optionally, run the application on two nearby devices and tap the globe button to share a world map between the two.  Drawings will then be synced between the devices and appear on both.


## Notes
While this project acts as a good proof of concept for a collaborative AR drawing app, there are limitations with the application.  Lines consist of cylinders, meaning there are gaps after sharp turns.  For a more complete discussion of the limitations and results of this project, see the academic report [here](https://github.com/Finnvoor/DrawAR/blob/main/AR%20Project%20Report.pdf).  The main AR renderer and drawing generation code can be found in `ARViewController.swift`.

> `MultipeerSession.swift` adapted from Apple's [Creating a Multiuser AR Experience](https://developer.apple.com/documentation/arkit/creating_a_multiuser_ar_experience) sample code.
