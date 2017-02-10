//
//  EventTests.swift
//  EventTests
//
//  Created by Daniel Leping on 22/04/2016.
//  Copyright © 2016 Crossroad Labs s.r.o. All rights reserved.
//

import XCTest
import Event

import ExecutionContext

enum TestEventString : Event {
    typealias Payload = String
    case event
}

enum TestEventInt : Event {
    typealias Payload = Int
    case event
}

enum TestEventComplex : Event {
    typealias Payload = (String, Int)
    case event
}

struct TestEventGroup<E : Event> {
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

class EventEmitterTest : EventEmitter {
    let dispatcher:EventDispatcher = EventDispatcher()
    let context: ExecutionContextProtocol = ExecutionContext.current
    
    func on<E : Event>(_ groupedEvent: TestEventGroup<E>) -> SignalStream<E.Payload> {
        return self.on(groupedEvent.event)
    }
    
    func emit<E : Event>(_ groupedEvent: TestEventGroup<E>, payload:E.Payload) {
        self.emit(groupedEvent.event, payload: payload)
    }
}

class EventTests: XCTestCase {
    
    let bucket = DisposalBucket()
    
    func testExample() {
        let node = SignalNode<String>()
        let node2 = SignalNode<String>()
        let nodeSource = SignalNode<String>()
        let nodeFork = SignalNode<String>()
        
        nodeSource.fork(to: nodeFork, bucket.put).pour(to: node2) => bucket
        
        node.bind(to: node2) => bucket
        
        let nodeReactOff = node.react { s in
            print("from node:", s)
        }
        
        nodeFork.react { string in
            print("~!!!I WAS FORKED!!!~", string)
        } => bucket
        
        nodeSource <= "external signal"
        
        let ec = ExecutionContext(kind: .parallel)
        
        let eventEmitter = EventEmitterTest()
        
        let emitterSignature = eventEmitter.signature
        let dispatcherSignature = eventEmitter.dispatcher.signature
        
        XCTAssertEqual(emitterSignature, dispatcherSignature)
        
        let _ = eventEmitter.on(.string).settle(in: ec).react { s in
            print("string:", s)
        }
        
        node <= "some"
        
        let nodeOff = eventEmitter.on(.string).map {s in return s + "wtf"}.pour(to: node)
        
        let _ = eventEmitter.on(.int).settle(in: global).react { i in
            print("int:", i)
        }
        
        eventEmitter.on(.complex).settle(in: immediate).react { (s, i) in
            print("complex: string:", s, "int:", i)
        } => bucket
        
        bucket <= eventEmitter.on(.int).map({$0 * 2}).react { i in
            
        }
        
        let semitter = eventEmitter.on(.complex).filter { (s, i) in
            i % 2 == 0
        }.map { (s, i) in
            s + String(i*100)
        }
        
        let _ = semitter.react { string in
            print(string)
        }
        
        eventEmitter.on(.string).flatMap {Int($0)}.react { i in
            print("!@#$%$#@#$%MyINT:", i)
        } => bucket
        
        let expectation = self.expectation(description: "OK")
        let expectation2 = self.expectation(description: "OK")
        
        var one = true
        
        eventEmitter.on(.string).debounce(timeout: 3, leading: true).react { s in
            print("@@@@@@@@@@@@@@@@:", s)
            if one {
                expectation.fulfill()
                one = false
            } else {
                expectation2.fulfill()
            }
        } => bucket
        
        let ezip1 = self.expectation(description: "ezip1")
        let ezip2 = self.expectation(description: "ezip2")
        
        var zipCounter = 0
        
        eventEmitter.on(.string).zip(eventEmitter.on(.complex)).react { s, c in
            if s == "something here" && c == ("whoo hoo", 7) {
                XCTAssertEqual(zipCounter, 0)
                zipCounter += 1
                ezip1.fulfill()
            } else {
                XCTAssertEqual(zipCounter, 1)
                zipCounter += 1
                ezip2.fulfill()
            }
        } => bucket
        
        let ezipLatest1 = self.expectation(description: "ezipLatest1")
        let ezipLatest2 = self.expectation(description: "ezipLatest2")
        
        var zipLatestCounter = 0
        
        eventEmitter.on(.string).zipLatest(eventEmitter.on(.complex)).react { s, c in
            if zipLatestCounter > 1 {
                XCTFail("Can not reach this path")
            }
            
            if s == "19" && c == ("whoo hoo", 7) {
                XCTAssertEqual(zipLatestCounter, 0)
                zipLatestCounter += 1
                ezipLatest1.fulfill()
            } else if s == "19" && c == ("hey", 8) {
                XCTAssertEqual(zipLatestCounter, 1)
                zipLatestCounter += 1
                ezipLatest2.fulfill()
            } else {
                XCTFail("Can not reach this path")
            }
        } => bucket
        
        let ezipLatest01 = self.expectation(description: "ezipLatest1")
        let ezipLatest02 = self.expectation(description: "ezipLatest2")
        let ezipLatest03 = self.expectation(description: "ezipLatest3")
        let ezipLatest04 = self.expectation(description: "ezipLatest4")
        
        var zipLatest0Counter = 0
        
        eventEmitter.on(.string).zipLatest0(eventEmitter.on(.complex)).react { s, c in
            if zipLatest0Counter > 3 {
                XCTFail("Can not reach this path")
            }
            
            if (s.map {$0 == "something here"} ?? false) && c == nil {
                XCTAssertEqual(zipLatest0Counter, 0)
                zipLatest0Counter += 1
                ezipLatest01.fulfill()
            } else if (s.map {$0 == "19"} ?? false) && c == nil {
                XCTAssertEqual(zipLatest0Counter, 1)
                zipLatest0Counter += 1
                ezipLatest02.fulfill()
            } else if (s.map {$0 == "19"} ?? false) && (c.map {$0 == ("whoo hoo", 7)} ?? false) {
                XCTAssertEqual(zipLatest0Counter, 2)
                zipLatest0Counter += 1
                ezipLatest03.fulfill()
            } else if (s.map {$0 == "19"} ?? false) && (c.map {$0 == ("hey", 8)} ?? false) {
                XCTAssertEqual(zipLatest0Counter, 3)
                zipLatest0Counter += 1
                ezipLatest04.fulfill()
            } else {
                XCTFail("Can not reach this path")
            }
        } => bucket
        
        eventEmitter.emit(.int, payload: 7)
        eventEmitter.emit(.string, payload: "something here")
        eventEmitter.emit(.string, payload: "19")
        eventEmitter.emit(.complex, payload: ("whoo hoo", 7))
        eventEmitter.emit(.complex, payload: ("hey", 8))
        
        eventEmitter.emit(.error, payload: NSError(domain: "", code: 1, userInfo: nil))
        
        nodeReactOff()
        nodeOff()
        
        self.waitForExpectations(timeout: 4, handler: nil)
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
}

#if os(Linux)
extension EventTests {
	static var allTests : [(String, (EventTests) -> () throws -> Void)] {
		return [
			("testExample", testExample),
		]
	}
}
#endif
