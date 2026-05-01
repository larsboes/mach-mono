import XCTest
@testable import boringNotch

final class APIRouterTests: XCTestCase {
    var router: APIRouter!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        router = APIRouter()
    }
    
    func testDynamicRouteRegistration() async {
        await router.register(method: .get, path: "/test") { _ in
            return .json(["msg": "hello"])
        }
        
        let request = APIRequest(method: .get, path: "/test", headers: [:], body: Data())
        let response = await router.route(request)
        
        XCTAssertEqual(response.statusCode, 200)
    }
    
    func testPathParameterExtraction() async {
        await router.register(method: .get, path: "/plugins/{id}") { request in
            let id = request.pathParam("id") ?? "missing"
            return .json(["id": id])
        }
        
        let request = APIRequest(method: .get, path: "/plugins/music", headers: [:], body: Data())
        let response = await router.route(request)
        
        XCTAssertEqual(response.statusCode, 200)
    }
    
    func test404NotFound() async {
        let request = APIRequest(method: .get, path: "/invalid", headers: [:], body: Data())
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 404)
    }
    
    func test405MethodNotAllowed() async {
        await router.register(method: .get, path: "/test") { _ in .json(["ok": true]) }
        
        let request = APIRequest(method: .post, path: "/test", headers: [:], body: Data())
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 405)
    }
}
