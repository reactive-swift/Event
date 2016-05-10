//
//  EventTests.swift
//  EventTests
//
//  Created by Daniel Leping on 22/04/2016.
//  Copyright © 2016 Crossroad Labs s.r.o. All rights reserved.
//

import XCTest
@testable import Event

import ExecutionContext

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
    let context: ExecutionContextType = ExecutionContext.current
    
    func on<E : EventProtocol>(groupedEvent: TestEventGroup<E>) -> EventConveyor<E.Payload> {
        return self.on(groupedEvent.event)
    }
    
    func emit<E : EventProtocol>(groupedEvent: TestEventGroup<E>, payload:E.Payload) {
        self.emit(groupedEvent.event, payload: payload)
    }
}

class EventTests: XCTestCase {
    
    func testExample() {
        let ec = ExecutionContext(kind: .parallel)
        
        let eventEmitter = EventEmitterTest()
        
        let _ = eventEmitter.on(.string).settle(in: ec).react { s in
            print("string:", s)
        }
        
        let _ = eventEmitter.on(.int).settle(in: global).react { i in
            print("int:", i)
        }
        
        let _ = eventEmitter.on(.complex).settle(in: immediate).react { (s, i) in
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
        
        eventEmitter.emit(.int, payload: 7)
        eventEmitter.emit(.string, payload: "something here")
        eventEmitter.emit(.complex, payload: ("whoo hoo", 7))
        eventEmitter.emit(.complex, payload: ("hey", 8))
        
        eventEmitter.emit(.error, payload: NSError(domain: "", code: 1, userInfo: nil))
        
        
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
}
