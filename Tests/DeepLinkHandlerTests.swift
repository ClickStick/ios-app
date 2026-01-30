
import Testing
import Foundation
@testable import ClickStick
import ClickStickKit

@MainActor
final class MockURLOpener: URLOpening {
    var openedURL: URL?
    var completionResult: Bool = true
    
    func open(_ url: URL, completion: ((Bool) -> Void)?) {
        openedURL = url
        completion?(completionResult)
    }
}

@MainActor
struct DeepLinkHandlerTests {
    
    let handler: DeepLinkHandler
    let mockOpener: MockURLOpener
    
    init() {
        self.mockOpener = MockURLOpener()
        self.handler = DeepLinkHandler(urlOpener: mockOpener)
    }
    
    @Test
    func validTypeRequest() {
        let url = URL(string: "clickstick://x-callback-url/type?text=Hello")!
        let result = handler.handle(url: url)
        
        #expect(result)
        #expect(handler.pendingTypeRequest != nil)
        #expect(handler.pendingTypeRequest?.text == "Hello")
        #expect(handler.parsingError == nil)
    }
    
    @Test
    func encodingHandling() {
        let url = URL(string: "clickstick://x-callback-url/type?text=Hello%20World")!
        handler.handle(url: url)
        
        #expect(handler.pendingTypeRequest?.text == "Hello World")
    }
    
    @Test
    func specialCharacterEncoding() {
        // "100%25" -> "100%"
        let url = URL(string: "clickstick://x-callback-url/type?text=100%25")!
        handler.handle(url: url)
        
        #expect(handler.pendingTypeRequest?.text == "100%")
    }
    
    @Test
    func duplicateParameters() {
        // Should use the last value
        let url = URL(string: "clickstick://x-callback-url/type?text=First&text=Second")!
        handler.handle(url: url)
        
        #expect(handler.pendingTypeRequest?.text == "Second")
    }
    
    @Test
    func missingText() {
        let url = URL(string: "clickstick://x-callback-url/type?layout=us")!
        let result = handler.handle(url: url)
        
        #expect(!result)
        #expect(handler.pendingTypeRequest == nil)
        #expect(handler.parsingError?.code == .missingText)
    }
    
    @Test
    func emptyText() {
        let url = URL(string: "clickstick://x-callback-url/type?text=")!
        let result = handler.handle(url: url)
        
        #expect(!result)
        #expect(handler.pendingTypeRequest == nil)
        #expect(handler.parsingError?.code == .emptyText)
    }
    
    @Test
    func emptyTextCallsErrorURL() {
        let errorURL = "myapp://error"
        let url = URL(string: "clickstick://x-callback-url/type?text=&x-error=\(errorURL)")!
        handler.handle(url: url)
        
        guard let opened = mockOpener.openedURL,
              let components = URLComponents(url: opened, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            Issue.record("Error URL not called")
            return
        }
        
        #expect(queryItems.contains { $0.name == "errorCode" && $0.value == "empty_text" })
    }
    
    @Test
    func missingTextCallsErrorURL() {
        let errorURL = "myapp://error"
        let url = URL(string: "clickstick://x-callback-url/type?layout=us&x-error=\(errorURL)")!
        handler.handle(url: url)
        
        guard let opened = mockOpener.openedURL,
              let components = URLComponents(url: opened, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            Issue.record("Error URL not called")
            return
        }
        
        #expect(queryItems.contains { $0.name == "errorCode" && $0.value == "missing_text" })
    }
    
    @Test
    func sourceAppParsing() {
        let url = URL(string: "clickstick://x-callback-url/type?text=Hi&x-source=KeePassium")!
        handler.handle(url: url)
        
        #expect(handler.pendingTypeRequest?.sourceApp == "KeePassium")
    }
    
    @Test
    func callbackURLs() {
        let success = "myapp://success"
        let error = "myapp://error"
        let cancel = "myapp://cancel"
        
        let url = URL(string: "clickstick://x-callback-url/type?text=Hi&x-success=\(success)&x-error=\(error)&x-cancel=\(cancel)")!
        
        // 1. Test Success Callback & Cleanup
        handler.handle(url: url)
        
        guard let request = handler.pendingTypeRequest else {
            Issue.record("Request not parsed")
            return
        }
        
        #expect(request.successURL?.absoluteString == success)
        #expect(request.errorURL?.absoluteString == error)
        #expect(request.cancelURL?.absoluteString == cancel)
        
        // Test callbacks
        handler.callSuccessURL(for: request)
        #expect(mockOpener.openedURL?.absoluteString == success)
        #expect(handler.pendingTypeRequest == nil, "Pending request should be cleared after success callback")
        
        // 2. Test Cancel Callback & Cleanup
        // Re-parse to get a fresh request since the previous one was cleared
        handler.handle(url: url)
        guard let request2 = handler.pendingTypeRequest else {
            Issue.record("Request not parsed 2")
            return
        }
        
        handler.callCancelURL(for: request2)
        #expect(mockOpener.openedURL?.absoluteString == cancel)
        #expect(handler.pendingTypeRequest == nil, "Pending request should be cleared after cancel callback")
    }
    
    @Test
    func errorCallbackWithCode() {
        let errorBase = "myapp://error"
        let url = URL(string: "clickstick://x-callback-url/type?text=Hi&x-error=\(errorBase)")!
        handler.handle(url: url)
        
        guard let request = handler.pendingTypeRequest else { return }
        
        handler.callErrorURL(for: request, errorCode: .typingFailed)
        
        guard let opened = mockOpener.openedURL,
              let components = URLComponents(url: opened, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            Issue.record("Invalid error URL")
            return
        }
        
        #expect(opened.host == "error")
        #expect(queryItems.contains { $0.name == "errorCode" && $0.value == DeepLinkErrorCode.typingFailed.rawValue })
    }
}
