# WWDC 2025-286: Meet the Foundation Models Framework

**Author:** Manus AI (JARVIS)
**Date:** March 09, 2026
**Source:** WWDC 2025, Session 286

## 1.0 Overview

This document summarizes the key features of the **Foundation Models framework**, which provides direct, on-device access to the Large Language Model (LLM) powering Apple Intelligence. The framework is available on macOS, iOS, iPadOS, and visionOS.

The on-device model is a 3-billion-parameter LLM optimized for tasks like summarization, extraction, classification, and content generation. It is not designed for world knowledge or advanced reasoning, which remain the domain of server-scale models. All processing is on-device, ensuring privacy and offline capability.

## 2.0 Core Components

### 2.1 Guided Generation

Guided Generation is the core of the framework, guaranteeing structurally correct, type-safe output from the model. It eliminates the need for prompt engineering to produce parsable formats like JSON.

-   **`@Generable` Macro:** Applied to a Swift `struct` or `class` to describe the desired output schema.
-   **`@Guide` Macro:** Provides natural language descriptions for properties and programmatically constrains the possible values the model can generate.
-   **Benefits:**
    -   Guarantees structural correctness via constrained decoding.
    -   Simplifies prompts to focus on behavior, not format.
    -   Improves model accuracy and inference speed.

### 2.2 Snapshot Streaming

Instead of streaming raw token deltas, the framework streams **snapshots**, which are partially generated instances of the `@Generable` type. This provides a robust and convenient way to handle structured data as it's being generated.

-   The `@Generable` macro automatically creates a `PartiallyGenerated` version of the type where all properties are optional.
-   The `streamResponse()` method returns an `AsyncSequence` of these `PartiallyGenerated` snapshots.
-   This model is ideal for declarative UI frameworks like SwiftUI, allowing the UI to update progressively as the snapshot is filled in.

### 2.3 Tool Calling

The framework allows the model to autonomously execute Swift code defined by the developer. This extends the model's capabilities to access real-time information, interact with system services, or perform actions.

-   **`Tool` Protocol:** Used to define a tool. Requires a `name`, a natural language `description`, and a `call()` method.
-   **Type-Safe Arguments:** The arguments for the `call()` method must be a `@Generable` type, ensuring the model can never produce an invalid tool call.
-   **Autonomous Execution:** The framework transparently handles the entire loop: the model requests a tool call, the framework executes the corresponding Swift code, and the output is fed back into the model's context to inform the final response.

### 2.4 Stateful Sessions

Interactions with the model occur within a `Session`. The session maintains a `transcript` of the entire conversation, allowing the model to understand multi-turn interactions.

-   **`SystemLanguageModel`:** The entry point to creating a session. Can be initialized with custom instructions, tools, and specialized adapters (e.g., for content tagging).
-   **Instructions vs. Prompts:** Instructions are developer-provided directives (style, role) that the model is trained to obey over user-provided prompts, offering a layer of protection against prompt injection.
-   **Availability:** Developers must check the `SystemLanguageModel.availability` property, as the on-device model is only available on Apple Intelligence-enabled devices in supported regions.

## 3.0 Developer Tooling

-   **Xcode Playgrounds:** The `#playground` macro allows for rapid iteration on prompts directly within any Swift file, with access to all types defined in the project.
-   **Instruments:** A new profiling template helps developers understand and optimize the latency of model requests.
-   **Adapter Training Toolkit:** For highly specialized use cases, developers can train custom adapters for the on-device model, though this requires significant maintenance.
