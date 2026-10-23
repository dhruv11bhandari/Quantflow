# QuantFlow

QuantFlow is an offline-first SwiftUI app for practicing quantitative finance and probability. It is packaged as an iOS Swift Playground and targets iOS 17 or later.

## What it includes

- Adaptive practice questions with answer validation and scoring
- Quantitative reasoning lessons and concept guides
- Interview-style simulations, expected-value games, and market-making exercises
- Progress tracking and a local learner profile
- A sample demo profile for exploring the app

QuantFlow is an educational practice tool. It does not connect to financial markets, provide investment advice, or require a network connection.

## Open the project


Open `QuantFlow.swiftpm` in Swift Playgrounds on iPad or Mac. The project uses SwiftUI and Apple’s Swift Playgrounds package format; it has no third-party package dependencies.

## Requirements

- Swift Playgrounds
- iOS 17 or later for the app

## Project layout

- `App/` — application entry point and root flow
- `Views/` — practice, learning, simulation, profile, and progress screens
- `Components/` — reusable SwiftUI interface elements
- `Engine/` — question validation, scoring, adaptation, and simulation logic
- `Data/` — question bank and learning content
- `Models/` — questions, concepts, and progress records
- `Services/` — app state, sessions, and game logic
- `Assets.xcassets/` — app icon and accent color

## Privacy and data

The app is designed to work offline. Progress is stored locally on the device. No backend or account is required.

## License

QuantFlow is licensed under the MIT License. See [LICENSE](LICENSE) for details.
