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

public protocol EventProtocol : Hashable {
    associatedtype Payload
}

public enum ErrorEvent : EventProtocol {
    public typealias Payload = ErrorProtocol
    case event
}

public struct CommonEventGroup<E : EventProtocol> {
    internal let event:E
    
    private init(_ event:E) {
        self.event = event
    }
    
    public static var error:CommonEventGroup<ErrorEvent> {
        return CommonEventGroup<ErrorEvent>(.event)
    }
}

public extension EventEmitterProtocol {
    public func on<E : EventProtocol>(groupedEvent: CommonEventGroup<E>) -> EventConveyor<E.Payload> {
        return self.on(groupedEvent.event)
    }
    
    public func emit<E : EventProtocol>(groupedEvent: CommonEventGroup<E>, payload:E.Payload) {
        dispatcher.dispatch(groupedEvent.event, context: context, payload: payload)
    }
}