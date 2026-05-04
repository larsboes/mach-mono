# Contributing

Thank you for taking the time to contribute! ❤️

These guidelines help streamline the contribution process for everyone involved. By following them, you'll make it easier for maintainers to review your work and collaborate with you effectively.

You can contribute in many ways: writing code, improving documentation, reporting bugs, requesting features, or creating tutorials and blog posts. Every contribution, large or small, helps make machNotch better.

## Table of Contents

- [Contributing Code](#contributing-code)
  - [Before You Start](#before-you-start)
  - [Setting Up Your Environment](#setting-up-your-environment)
  - [Making Changes](#making-changes)
  - [Pull Requests](#pull-requests)
- [Architectural Guidelines](#architectural-guidelines)
- [Reporting Bugs](#reporting-bugs)
- [Feature Requests](#feature-requests)
- [Getting Help](#getting-help)

## Contributing Code

### Before You Start

- **Check existing issues**: Before creating a new issue or starting work, search existing issues to avoid duplicates.
- **Discuss major changes**: For significant features or major changes, please open an issue first to discuss your approach with maintainers and the community.

> [!IMPORTANT]
> This repository uses `main` as the canonical integration branch unless a maintainer explicitly asks you to target another branch.

### Setting Up Your Environment

1. **Fork the repository**: Click the "Fork" button at the top of the repository page to create your own copy.

2. **Clone your fork**:
   ```bash
   git clone https://github.com/{your-username}/mach-mono.git
   cd mach-mono
   ```
   Replace `{your-username}` with your GitHub username.

3. **Make sure `main` is up to date**:
   ```bash
   git checkout main
   git pull origin main
   ```

4. **Create a new feature branch**:
   ```bash
   git checkout -b feature/{your-feature-name}
   ```
   Replace `{your-feature-name}` with a descriptive name. Use lowercase letters, numbers, and hyphens only (e.g., `feature/add-dark-mode` or `fix/notification-crash`).

### Making Changes

1. **Make your changes**: Implement your feature or bug fix. Write clean, well-documented code.
2. **Test your changes**: Ensure your changes work as expected and don't break existing functionality.
3. **Commit your changes**:
   ```bash
   git add .
   git commit -m "Add descriptive commit message"
   ```
   Write clear, concise commit messages that explain what your changes do and why.

4. **Keep your branch up to date**:
   Regularly sync your branch with the latest changes from `main` to avoid conflicts.

5. **Push to your fork**:
   ```bash
   git push origin feature/{your-feature-name}
   ```

### Creating a New Plugin

machNotch uses a plugin-first architecture. Adding a new feature usually means creating a new plugin.

1.  **Create the Plugin File**: Add a new Swift file in `Plugins/BuiltIn/{YourFeature}Plugin/`.
2.  **Implement `NotchPlugin`**:
    ```swift
    struct YourFeaturePlugin: NotchPlugin {
        var metadata: PluginMetadata {
            PluginMetadata(
                name: "Your Feature",
                icon: "star.fill",
                id: "com.machnotch.yourfeature"
            )
        }

        var view: AnyView {
            AnyView(YourFeatureView())
        }
    }
    ```
3.  **Register the Plugin**: Add your plugin instance to `PluginRegistry.makeBuiltInPlugins()` in `Apps/machNotch/machNotch/Plugins/Core/PluginRegistry.swift`.

For more details, see the [Architecture Guide](docs/architecture/overview.md) and [Plugin Development Guide](docs/guides/plugin-development.md).

### Pull Requests

1. **Create a pull request**: Go to the original repository and click "New Pull Request." Select your feature branch and set the base branch to `main` unless a maintainer asks otherwise.

2. **Write a detailed description**: Your PR should include:
   - A clear title summarizing the changes
   - A detailed description of what was changed and why
   - Reference to any related issues (e.g., "Fixes #123" or "Relates to #456")
   - Screenshots or screen recordings for UI changes

3. **Respond to feedback**: Maintainers may request changes.

4. **Be patient**: Reviews take time. Maintainers will get to your PR as soon as they can.

## Architectural Guidelines

The project has recently undergone a major refactoring. Please adhere to these guidelines for all new code:

### 1. No Singletons in Views
❌ **Don't** use `.shared` instances directly in SwiftUI views.
```swift
// Avoid this
struct MyView: View {
    @ObservedObject var music = MusicManager.shared 
}
```

✅ **Do** inject dependencies via `@Environment` or initialization.
```swift
// Do this
struct MyView: View {
    @Environment(PluginManager.self) var pluginManager
    
    var body: some View {
        let music = pluginManager.services.music
        // ...
    }
}
```

### 2. Use the Service Container
All core logic (Music, Calendar, Shelf, etc.) interacts with the system via the `ServiceContainer`.
*   If you need a system service, access it via `context.services` in your Plugin or `pluginManager.services` in Views.
*   If you need a new system capability, define a protocol for it (e.g., `BluetoothServiceProtocol`), implement it, and add it to the container.

### 3. Use `@Observable`
We are migrating to Swift 5.9's `@Observable` macro.
❌ **Avoid** `ObservableObject` and `@Published` for new models.
✅ **Use** `@Observable` for all new state objects.

## Reporting Bugs

When reporting bugs, please include:

- A clear, descriptive title
- Steps to reproduce the issue
- Expected behavior vs. actual behavior
- Screenshots or error messages if applicable
- Your environment details (OS version, app version, etc.)

## Feature Requests

Feature requests are welcome! Please:

- Check if the feature has already been requested
- Clearly describe the feature and its use case
- Explain why this feature would be valuable to users
- Be open to discussion and alternative approaches

## Getting Help

If you need help or have questions:

- Check the project documentation
- Search existing issues for similar questions
- Open a new issue with the "question" label
- Join our [community Discord server](https://discord.com/servers/mach-notch-1269588937320566815)

---

Thank you for contributing to machNotch! Your efforts help make this project better for everyone. 🎉