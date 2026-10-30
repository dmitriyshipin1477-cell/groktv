# GrokTV — Grok chat for Apple TV

A native tvOS 17+ SwiftUI app for chatting with xAI's Grok on Apple TV 4K. It's dark and readable from the couch, and you can drive it with the Siri Remote.

## Requirements
- A Mac with Xcode 15 or later (tvOS 17 SDK)
- An Apple Developer account (free works for the simulator; you need a team to sign for a real device)
- An xAI API key from https://console.x.ai

## Setup
1. Open `GrokTV.xcodeproj` in Xcode.
2. Add your API key:
   ```sh
   cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
   # edit Config/Secrets.xcconfig:  XAI_API_KEY = xai-...
   ```
   `Secrets.xcconfig` is git-ignored. Never commit a real key.
3. Signing: select the **GrokTV** target → *Signing & Capabilities*, pick your Team, and change the bundle ID from `com.example.GrokTV` to one you own.
4. Pick the **Apple TV 4K** simulator (or a paired Apple TV device), then Run (⌘R).

## How the key reaches the app
`Secrets.xcconfig` → optional `#include?` in `Config/GrokTV.xcconfig` → build setting `XAI_API_KEY` → `Info.plist` (`$(XAI_API_KEY)`) → `Bundle.main.infoDictionary` in `APIConfig.apiKey`. You can also set an `XAI_API_KEY` environment variable in the scheme for debugging. Note: the key is embedded in the app bundle, so this setup is for personal or dev use. Use a backend proxy for anything you distribute.

## Architecture
- `Models/`: `ChatMessage`, request/response/chunk Codable types, and `APIConfig` (endpoint, model `grok-4.7`, system prompt)
- `Services/XAIClient.swift`: POST `https://api.x.ai/v1/chat/completions` with Bearer auth; streaming through `URLSession.bytes` plus a non-stream `complete()`
- `Services/SSEParser.swift`: parses `data:` lines and `[DONE]`, and decodes `choices[].delta.content`
- `ViewModels/ChatViewModel.swift`: `@MainActor` ObservableObject holding the session history, draft, loading and error state. It streams first and falls back to a non-stream request if streaming fails before any text arrives. Stop and New Chat are supported.
- `Views/`: chat list (user on the right, Grok on the left, focusable bubbles so you can scroll with the remote), composer (TextField + Send/Stop), empty state with suggestion cards, and an error banner

## Notes
- The AppIcon set is a placeholder. For App Store builds, tvOS needs a layered "App Icon & Top Shelf Image" brand asset.
- Optional: `xcodegen generate` rebuilds the project from `project.yml`.
