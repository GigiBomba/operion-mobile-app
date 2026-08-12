Core Stack Components

Framework: Flutter. Unlike React Native, which relies on a JavaScript bridge to talk to native components (causing subtle bottlenecks), Flutter compiles directly to machine code (ARM) using Google's Skia or Impeller graphics engines. It renders its UI on a hardware-accelerated canvas at a locked 60 FPS / 120 FPS.

Language: Dart A strongly-typed, object-oriented language that supports Ahead-Of-Time (AOT) compilation for fast startup times and highly optimized release binaries.

State Management: Bloc (Business Logic Component) or Riverpod These architectural patterns completely separate your UI from your data stream logic. They ensure the app only redraws the exact widget that changed (like a single truck coordinate updating on a map), keeping CPU and memory usage exceptionally low.

Networking client: Dio A powerful HTTP client for Dart that supports global interceptors, request cancellation, file downloading/uploading queues, and seamless JSON serialization back to your FastAPI backend.

High-Performance Libraries to Note

Mapping Engine: Flutter Map (with vector tiles) or Google Maps Flutter Utilizes native mobile GPU acceleration to draw maps, track paths, and handle marker clusters without UI stuttering.

Local Caching Database: Isar or Hive A blazing-fast, ultra-lightweight NoSQL local database written specifically for Flutter. This allows the app to load cached logistics data instantly on startup before even making an API request, preserving mobile data and battery.

Icons \& UI Layout: Lucide Icons Flutter \& Custom Painters Keeps asset sizes tiny while allowing you to draw custom tracking widgets natively on the screen container layer.



