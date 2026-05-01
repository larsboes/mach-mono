# Dependency Injection in Swift

Patterns for dependency injection without singletons.

## Protocol-Based DI

### 1. Define Service Protocol
```swift
protocol DataService: Sendable {
    func fetch() async throws -> Data
}
```

### 2. Create Implementation
```swift
@MainActor
final class DataServiceImpl: DataService {
    func fetch() async throws -> Data {
        // Implementation
    }
}
```

### 3. Inject via Init
```swift
@MainActor
@Observable
final class ViewModel {
    private let service: DataService
    
    init(service: DataService) {
        self.service = service
    }
}
```

### 4. Service Container
```swift
@MainActor
final class ServiceContainer {
    let dataService: DataService
    let settings: SettingsService
    
    init(
        dataService: DataService = DataServiceImpl(),
        settings: SettingsService = SettingsServiceImpl()
    ) {
        self.dataService = dataService
        self.settings = settings
    }
}
```

### 5. Environment Injection (SwiftUI)
```swift
private struct ServiceContainerKey: EnvironmentKey {
    static let defaultValue: ServiceContainer? = nil
}

extension EnvironmentValues {
    var services: ServiceContainer? {
        get { self[ServiceContainerKey.self] }
        set { self[ServiceContainerKey.self] = newValue }
    }
}

// Root view
ContentView()
    .environment(\.services, container)

// Child view
@Environment(\.services) private var services
```

## Eliminating Singletons

### Before
```swift
class MyViewModel: ObservableObject {
    func load() {
        let data = DataService.shared.fetch()
        // ...
    }
}
```

### After
```swift
@MainActor
@Observable
final class MyViewModel {
    private let service: DataService
    
    init(service: DataService) {
        self.service = service
    }
    
    func load() async {
        let data = try? await service.fetch()
        // ...
    }
}
```

## Factory Pattern

For creating objects with dependencies:

```swift
protocol ViewModelFactory {
    func makeHomeViewModel() -> HomeViewModel
    func makeSettingsViewModel() -> SettingsViewModel
}

@MainActor
final class DefaultViewModelFactory: ViewModelFactory {
    private let container: ServiceContainer
    
    init(container: ServiceContainer) {
        self.container = container
    }
    
    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(dataService: container.dataService)
    }
}
```

## Testing with DI

### Mock Implementation
```swift
final class MockDataService: DataService {
    var mockData: Data?
    var shouldThrow: Error?
    
    func fetch() async throws -> Data {
        if let error = shouldThrow { throw error }
        return mockData ?? Data()
    }
}
```

### Inject in Tests
```swift
func testViewModel() async {
    let mock = MockDataService()
    mock.mockData = testData
    
    let vm = ViewModel(service: mock)
    await vm.load()
    
    XCTAssertEqual(vm.data, testData)
}
```
