//===--- EventConveyor.swift ----------------------------------------------===//
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

public class EventConveyor<T> {
    public typealias Payload = T
    public typealias Handler = Payload->Void
    private typealias Recycle = ()->Void
    
    private let _recycle:Recycle
    private var _handlers:[Handler]
    
    private init(recycle:Recycle = {}) {
        self._recycle = recycle
        self._handlers = []
    }
    
    deinit {
        _recycle()
    }
    
    private func emit(payload:Payload) {
        for handler in _handlers {
            handler(payload)
        }
    }
    
    public func on(f:Handler) -> EventConveyor<T> {
        _handlers.append(f)
        return self
    }
}

public extension EventConveyor {
    public func map<A>(f:Payload->A) -> EventConveyor<A> {
        let conveyor = EventConveyor<A>()
        
        self.on { payload in
            conveyor.emit(f(payload))
        }
        
        return conveyor
    }
    
    public func filter(f:Payload->Bool) -> EventConveyor<Payload> {
        let conveyor = EventConveyor<Payload>()
        
        self.on { payload in
            if f(payload) {
                conveyor.emit(payload)
            }
        }
        
        return conveyor
    }
}

public extension EventEmitterProtocol {
    public func on<E : EventProtocol>(event: E) -> EventConveyor<E.Payload> {
        var conveyor:EventConveyor<E.Payload>? = nil
        let listener = self.on(event) { (payload:E.Payload)->Void in
            conveyor?.emit(payload)
        }
        conveyor = EventConveyor<E.Payload>() {
            self.off(event, listener: listener)
        }
        return conveyor!
    }
    
    public func on<E : EventProtocol>(groupedEvent: CommonEventGroup<E>) -> EventConveyor<E.Payload> {
        return self.on(groupedEvent.event)
    }
}