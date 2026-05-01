# Contributing

Thank you for taking the time to contribute! ❤️

These guidelines help streamline the contribution process for everyone involved. By following them, you'll make it easier for maintainers to review your work and collaborate with you effectively.

You can contribute in many ways: writing code, improving documentation, reporting bugs, requesting features, or creating tutorials and blog posts. Every contribution, large or small, helps make Boring Notch better.

## Table of Contents

- [Localizations](#localizations)
- [Contributing Code](#contributing-code)
  - [Before You Start](#before-you-start)
  - [Setting Up Your Environment](#setting-up-your-environment)
  - [Making Changes](#making-changes)
  - [Pull Requests](#pull-requests)
- [Architectural Guidelines](#architectural-guidelines)
- [Reporting Bugs](#reporting-bugs)
- [Feature Requests](#feature-requests)
- [Getting Help](#getting-help)

## Localizations

Please submit all translations to [Crowdin](https://crowdin.com/project/boring-notch). New strings added to the `dev` branch from code changes will sync automatically to Crowdin, and Crowdin will automatically open a new PR with translations to allow us to integrate them.

## Contributing Code

### Before You Start

- **Check existing issues**: Before creating a new issue or starting work, search existing issues to avoid duplicates.
- **Discuss major changes**: For significant features or major changes, please open an issue first to discuss your approach with maintainers and the community.

> [!IMPORTANT]
> All code contributions must be based on the `dev` branch, not `main`. Documentation changes should be based on `main` instead.

### Setting Up Your Environment

1. **Fork the repository**: Click the "Fork" button at the top of the repository page to create your own copy.

2. **Clone your fork**:
   ```bash
   git clone https://github.com/{your-username}/boring.notch.git
   cd boring.notch
   ```
   Replace `{your-username}` with your GitHub username.

3. **Switch to the `dev` branch**:
   ```bash
   git checkout dev
   ```
   All code contributions must be based on the `dev` branch, not `main`. Documentation changes should be based on `main` instead.

5. **Create a new feature branch**:
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
   Regularly sync your branch with the latest changes from the `dev` branch to avoid conflicts.

5. **Push to your fork**:
   ```bash
   git push origin feature/{your-feature-name}
   ```

### Creating a New Plugin

Boring Notch uses a plugin-first architecture. Adding a new feature usually means creating a new plugin.

1.  **Create the Plugin File**: Add a new Swift file in `Plugins/BuiltIn/{YourFeature}Plugin/`.
2.  **Implement `NotchPlugin`**:
    ```swift
    struct YourFeaturePlugin: NotchPlugin {
        var metadata: PluginMetadata {
            PluginMetadata(
                name: "Your Feature",
                icon: "star.fill",
                id: "com.boringnotch.yourfeature"
            )
        }

        var view: AnyView {
            AnyView(YourFeatureView())
        }
    }
    ```
3.  **Register the Plugin**: Add your plugin instance to the `builtInPlugins` array in `AppDelegate.swift`.

For more details, see the [Architecture Guide](docs/ARCHITECTURE.md).

### Pull Requests

1. **Create a pull request**: Go to the original repository and click "New Pull Request." Select your feature branch and set the base branch to `dev`.

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
- Join our [community Discord server](https://discord.com/servers/boring-notch-1269588937320566815)

---

Thank you for contributing to Boring Notch! Your efforts help make this project better for everyone. 🎉