# WWDC 2025-231: Meet WebKit for SwiftUI

**Author:** Manus AI
**Date:** March 09, 2026
**Source:** WWDC 2025, Session 231

## 1.0 Overview

This document summarizes the new **WebKit for SwiftUI** API, which provides a modern, powerful, and simplified way to integrate web content into apps across all Apple platforms. It introduces a new set of SwiftUI-native views and observable objects to replace older, more complex integration patterns.

## 2.0 Core Components

### 2.1 `WebView`

The `WebView` is a new SwiftUI `View` designed to display web content. It can be used in its simplest form by providing a URL, and it will automatically load and display the content.

### 2.2 `WebPage`

`WebPage` is a new `Observable` class that represents the web content itself. It is the primary mechanism for loading, controlling, and communicating with the content displayed in a `WebView`.

-   **Loading Content:** `WebPage` can load remote URLs, local HTML strings, or raw data (e.g., web archives).
-   **Observable Properties:** It exposes numerous observable properties that work seamlessly with SwiftUI, including:
    -   `title`: The title of the web page.
    -   `url`: The current URL.
    -   `estimatedLoadingProgress`: The loading progress from 0.0 to 1.0.
    -   `themeColor`: The theme color specified by the page.
    -   `currentNavigationEvent`: An `Observable` property that reflects the current state of a navigation (e.g., started, committed, finished, failed).

## 3.0 Key Features

### 3.1 Custom Scheme Handling

Developers can intercept and handle custom URL schemes (e.g., `lakes://`) to load bundled resources or local files. This is achieved by conforming to the `URLSchemeHandler` protocol and registering the handler with the `WebPage`'s configuration.

### 3.2 JavaScript Communication

The new `callJavaScript()` API on `WebPage` provides a simple and powerful way to execute JavaScript and receive results. It supports passing arguments from Swift to the JavaScript context, making it easy to create reusable scripts.

### 3.3 Navigation Policies

The `WebPage.NavigationDeciding` protocol allows for fine-grained control over navigation. Developers can implement this protocol to decide whether to allow, cancel, or redirect navigation actions based on the URL, scheme, or other factors. This is ideal for forcing external links to open in the default browser rather than within the app.

### 3.4 SwiftUI Integration

WebKit for SwiftUI is deeply integrated with standard SwiftUI modifiers and patterns:

-   **Scrolling:** The standard `scrollBounceBehavior` and the new `webViewScrollPosition` and `onScrollGeometryChange` modifiers provide full control over the scrolling experience.
-   **Find-in-Page:** The standard `findNavigator` modifier works out-of-the-box with `WebView`.
-   **Look to Scroll (visionOS):** The `webViewScrollInputBehavior` modifier enables hands-free scrolling on visionOS.
