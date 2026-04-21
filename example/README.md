# Conferbot Flutter SDK - Example App

Demonstrates how to integrate the Conferbot Flutter SDK into an app.

## Setup

The example ships without platform directories (android/, ios/, etc.) to keep the
repository lightweight. Run the setup script once before building:

```bash
chmod +x setup.sh
./setup.sh
```

This will:
1. Run `flutter create --org com.conferbot .` to generate platform scaffolding.
2. Run `flutter pub get` to fetch all dependencies.

## Running

After setup, open `lib/main.dart` and replace the placeholder API key and bot ID
with your own values, then:

```bash
flutter run
```

## What's Inside

- **Option 1 (Drop-in Widget)** - Full chat UI in a modal via `ChatWidget`.
- **Option 2 (Headless SDK)** - Build your own UI using `ConferBotProvider`.
- **Option 3 (Mix & Match)** - Combine SDK widgets with custom components.

Session persistence is enabled by default; conversations resume after an app
restart (within the configured timeout).
