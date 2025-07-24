import Testing
import LocalLLMClientCore

@Suite
struct PauseHandlerRobustnessTests {
    @Test
    func testMultiplePauseCalls() async {
        let pauseHandler = PauseHandler(disableAutoPause: true)
        
        // Call pause multiple times in succession
        await pauseHandler.pause()
        await pauseHandler.pause()
        await pauseHandler.pause()
        
        // Should still be paused
        #expect(await pauseHandler.isPaused == true)
        
        // Resume once
        await pauseHandler.resume()
        
        // Should be resumed
        #expect(await pauseHandler.isPaused == false)
    }
    
    @Test
    func testMultipleResumeCalls() async {
        let pauseHandler = PauseHandler(disableAutoPause: true)
        
        // Resume without pausing first
        await pauseHandler.resume()
        await pauseHandler.resume()
        
        #expect(await pauseHandler.isPaused == false)
        
        // Pause once
        await pauseHandler.pause()
        #expect(await pauseHandler.isPaused == true)
        
        // Resume multiple times
        await pauseHandler.resume()
        await pauseHandler.resume()
        await pauseHandler.resume()
        
        // Should remain resumed
        #expect(await pauseHandler.isPaused == false)
    }
    
    @Test
    func testAlternatingPauseResume() async {
        let pauseHandler = PauseHandler(disableAutoPause: true)
        
        // Rapid alternation
        for _ in 0..<10 {
            await pauseHandler.pause()
            #expect(await pauseHandler.isPaused == true)
            await pauseHandler.resume()
            #expect(await pauseHandler.isPaused == false)
        }
        
        // Final state should be resumed
        #expect(await pauseHandler.isPaused == false)
    }
    
    @Test
    func testConcurrentPauseResume() async {
        let pauseHandler = PauseHandler(disableAutoPause: true)
        
        // Create multiple concurrent tasks that pause and resume
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    if i % 2 == 0 {
                        await pauseHandler.pause()
                    } else {
                        await pauseHandler.resume()
                    }
                }
            }
        }
        
        // The final state depends on which operation completed last
        // Just verify it doesn't crash and has a valid state
        let isPaused = await pauseHandler.isPaused
        #expect(isPaused == true || isPaused == false)
    }
    
    @Test
    func testCheckPauseStateWithMultipleWaiters() async {
        let pauseHandler = PauseHandler(disableAutoPause: true)
        
        // Pause the handler
        await pauseHandler.pause()
        
        // Create multiple tasks that will wait
        let expectation = TestExpectation()
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    await pauseHandler.checkPauseState()
                    await expectation.fulfill()
                }
            }
            
            // Give tasks time to start waiting
            try? await Task.sleep(for: .milliseconds(100))
            
            // Resume should unblock all waiting tasks
            await pauseHandler.resume()
        }
        
        // All tasks should have completed
        await expectation.wait(for: 5)
    }
    
    @Test
    func testPauseResumeWithoutWaiters() async {
        let pauseHandler = PauseHandler(disableAutoPause: true)
        
        // Pause and resume without any tasks waiting
        await pauseHandler.pause()
        #expect(await pauseHandler.isPaused == true)
        
        await pauseHandler.resume()
        #expect(await pauseHandler.isPaused == false)
        
        // Multiple resume calls without waiters
        await pauseHandler.resume()
        await pauseHandler.resume()
        #expect(await pauseHandler.isPaused == false)
    }
    
    @Test
    func testDisableAutoPauseInitialization() async {
        // Test with auto pause disabled
        let pauseHandler1 = PauseHandler(disableAutoPause: true)
        #expect(await pauseHandler1.isPaused == false)
        
        // Test with auto pause enabled (default)
        let pauseHandler2 = PauseHandler(disableAutoPause: false)
        #expect(await pauseHandler2.isPaused == false)
        
        // Test default initialization
        let pauseHandler3 = PauseHandler()
        #expect(await pauseHandler3.isPaused == false)
    }
}

// Helper for managing test expectations
actor TestExpectation {
    private var count = 0
    
    func fulfill() {
        count += 1
    }
    
    func wait(for expected: Int) async {
        while count < expected {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}