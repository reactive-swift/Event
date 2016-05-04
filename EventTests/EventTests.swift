//
//  EventTests.swift
//  EventTests
//
//  Created by Daniel Leping on 22/04/2016.
//  Copyright © 2016 Crossroad Labs s.r.o. All rights reserved.
//

import XCTest
@testable import Event

enum TestEventString : EventProtocol {
    typealias Payload = String
    case event
}

enum TestEventInt : EventProtocol {
    typealias Payload = Int
    case event
}

enum TestEventComplex : EventProtocol {
    typealias Payload = (String, Int)
    case event
}

struct TestEventGroup<E : EventProtocol> {
    internal let event:E
    
    private init(_ event:E) {
        self.event = event
    }
    
    static var string:TestEventGroup<TestEventString> {
        return TestEventGroup<TestEventString>(.event)
    }
    
    static var int:TestEventGroup<TestEventInt> {
        return TestEventGroup<TestEventInt>(.event)
    }
    
    static var complex:TestEventGroup<TestEventComplex> {
        return TestEventGroup<TestEventComplex>(.event)
    }
}

class EventEmitterTest : EventEmitterProtocol {
    let dispatcher:EventDispatcher = EventDispatcher()
    
    func on<E : EventProtocol>(groupedEvent: TestEventGroup<E>, handler:E.Payload->Void) -> Off {
        return self.on(groupedEvent.event, handler: handler)
    }
    
    func on<E : EventProtocol>(groupedEvent: TestEventGroup<E>) -> EventConveyor<E.Payload> {
        return self.on(groupedEvent.event)
    }
    
    func emit<E : EventProtocol>(groupedEvent: TestEventGroup<E>, payload:E.Payload) {
        dispatcher.dispatch(groupedEvent.event, payload: payload)
    }
}

class EventTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        let eventEmitter = EventEmitterTest()
        
        let _ = eventEmitter.on(.string) { s in
            print("string:", s)
        }
        
        let _ = eventEmitter.on(.int) { i in
            print("int:", i)
        }
        
        let _ = eventEmitter.on(.complex) { (s, i) in
            print("complex: string:", s, "int:", i)
        }
        
        let off = eventEmitter.on(.int).map({$0 * 2}).react { i in
            
        }
        
        off()
        
        let semitter = eventEmitter.on(.complex).filter { (s, i) in
            i % 2 == 0
        }.map { (s, i) in
            s + String(i*100)
        }
        
        let _ = semitter.react { string in
            print(string)
        }
        
        eventEmitter.emit(.complex, payload: ("whoo hoo", 7))
        eventEmitter.emit(.complex, payload: ("hey", 8))
        
        eventEmitter.emit(.error, payload: NSError(domain: "", code: 1, userInfo: nil))
        
        
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}
