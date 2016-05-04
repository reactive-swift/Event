//===--- EventEmitter.swift ----------------------------------------------===//
//Copyright (c) 2016 Crossroad Labs s.r.o.
//
//Licensed under the Apache License, Version 2.0 (the "License");
//you may not use this file except in compliance with the License.
//You may obtain a copy of the License at
//
//http://www.apache.org/licenses/LICENSE-2.0
//
//Unless required by applicable law or agreed to in writing, software
//distributed under the License is distributed on an "AS IS" BASIS,
//WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//See the License for the specific language governing permissions and
//limitations under the License.
//===----------------------------------------------------------------------===//

import Foundation

public struct Listener {
    private let _id:NSUUID
    internal let listener:Any->Void
    internal let event:HashableContainer
    
    internal init<Payload>(event:HashableContainer, listener:Payload->Void) {
        self._id = NSUUID()
        self.event = event
        self.listener = { payload in
            guard let payload = payload as? Payload else {
                return
            }
            
            listener(payload)
        }
    }
}

extension Listener : Hashable {
    public var hashValue: Int {
        get {
            return self._id.hashValue
        }
    }
}

public func ==(lhs:Listener, rhs:Listener) -> Bool {
    return lhs._id == rhs._id
}

public protocol EventEmitterProtocol {
    var dispatcher:EventDispatcher {get}
}

public extension EventEmitterProtocol {
    public func on<E : EventProtocol>(event: E, handler:E.Payload->Void) -> Listener {
        return dispatcher.addListener(event, handler: handler)
    }
    
    public func on<E : EventProtocol>(groupedEvent: CommonEventGroup<E>, handler:E.Payload->Void) -> Listener {
        return self.on(groupedEvent.event, handler: handler)
    }
    
    public func off(listener:Listener) {
        dispatcher.removeListener(listener)
    }
    
    public func emit<E : EventProtocol>(event: E, payload:E.Payload) {
        dispatcher.dispatch(event, payload: payload)
    }
    
    public func emit<E : EventProtocol>(groupedEvent: CommonEventGroup<E>, payload:E.Payload) {
        dispatcher.dispatch(groupedEvent.event, payload: payload)
    }
}

public struct HashableContainer : Hashable {
    private let _hash:Int
    private let _equator:(Any)->Bool
    public let value:Any
    
    public init<T: Hashable>(hashable:T) {
        self._hash = hashable.hashValue
        self._equator = { other in
            guard let other = other as? T else {
                return false
            }
            return hashable == other
        }
        self.value = hashable
    }
    
    public var hashValue: Int {
        get {
            return self._hash
        }
    }
}

public func ==(lhs:HashableContainer, rhs:HashableContainer) -> Bool {
    return lhs._equator(rhs.value)
}

public class EventDispatcher {
    private var registry:Dictionary<HashableContainer,Set<Listener>> = [:]
    
    internal func addListener<E : EventProtocol>(event: E, handler:E.Payload->Void) -> Listener {
        let container = HashableContainer(hashable: event)
        let listener = Listener(event: container, listener: handler)
        
        if registry[container] == nil {
           registry[container] = Set()
        }
        
        registry[container]?.insert(listener)
        
        return listener
    }
    
    internal func removeListener(listener:Listener) {
        registry[listener.event]?.remove(listener)
    }
    
    internal func dispatch<E : EventProtocol>(event:E, payload:E.Payload) {
        let container = HashableContainer(hashable: event)
        
        if let listeners = registry[container] {
            for listener in listeners {
                listener.listener(payload)
            }
        }
    }
}