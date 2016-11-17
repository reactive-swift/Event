//===--- EventEndpoint.swift ----------------------------------------------===//
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

public protocol EventEndpoint {
    associatedtype Payload
    
    func consume(payload:Payload)
}

public extension EventConveyor {
    func pour<EE : EventEndpoint>(to endpoint: EE) -> Off where EE.Payload == T {
        return self.react(endpoint.consume)
    }
}