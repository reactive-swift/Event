//===--- Event.swift ----------------------------------------------===//
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
import Boilerplate

public protocol Event : Hashable {
    associatedtype Payload
}

public enum ErrorEvent : Event {
    public typealias Payload = Error
    case event
}

public struct CommonEventGroup<E : Event> {
    public let event:E
    
    private init(_ event:E) {
        self.event = event
    }
    
    public static var error:CommonEventGroup<ErrorEvent> {
        return CommonEventGroup<ErrorEvent>(.event)
    }
}

public extension EventEmitter {
    public func on<E : Event>(_ groupedEvent: CommonEventGroup<E>) -> SignalStream<E.Payload> {
        return self.on(groupedEvent.event)
    }
    
    public func emit<E : Event>(_ groupedEvent: CommonEventGroup<E>, payload:E.Payload, signature:Set<Int> = []) {
        dispatcher.dispatch(groupedEvent.event, context: context, payload: payload, signature: signature)
    }
}
