//===--- SignalStream.swift ----------------------------------------------===//
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

import ExecutionContext

public typealias Signal<T> = (Set<Int>, T)

fileprivate func signature<T: AnyObject>(_ o: T) -> Int {
    return unsafeBitCast(o, to: Int.self)
}

internal struct UniqueContainer<T> {
    internal let _id:NSUUID
    
    let content:T
    
    init(content:T) {
        self._id = NSUUID()
        self.content = content
    }
}

extension UniqueContainer : Hashable {
    internal var hashValue: Int {
        get {
            return self._id.hashValue
        }
    }
}

internal func ==<T>(lhs:UniqueContainer<T>, rhs:UniqueContainer<T>) -> Bool {
    return lhs._id == rhs._id
}

public protocol SignalStreamProtocol : ExecutionContextTenantProtocol, AnyObject {
    associatedtype Payload
    typealias Handler = (Payload)->Void
    typealias Chainer = (Signal<Payload>)->Void
    
    func chain(_ f:@escaping Chainer) -> Off
    func react(_ f:@escaping Handler) -> Off
}

public extension SignalStreamProtocol {
    public func react(_ f:@escaping Handler) -> Off {
        return chain { _, payload in
            f(payload)
        }
    }
}

open class SignalStream<T> : SignalStreamProtocol, MovableExecutionContextTenantProtocol {
    public typealias Payload = T
    public typealias Handler = (Signal<Payload>)->Void
    public typealias SettledTenant = SignalStream<T>
    
    public let context: ExecutionContextProtocol
    private var _signature:Int
    
    public func settle(in context: ExecutionContextProtocol) -> SignalStream<T> {
        return SignalStream<Payload>(context: context) { fun in
            self.chain { signal in
                fun(signal)
            }
        }
    }
    
    private let _recycle:Off
    private var _handlers:Set<UniqueContainer<(Handler, SignalStream)>>
    
    internal init(context:ExecutionContextProtocol, recycle:@escaping Off) {
        self._recycle = recycle
        self._handlers = []
        self.context = context
        self._signature = 0
        self._signature = signature(self)
    }
    
    internal convenience init(context:ExecutionContextProtocol, advise:(@escaping Handler)->Off) {
        var emit:(Signal<Payload>)->Void = {_ in}
        
        let off = advise { signal in
            emit(signal)
        }
        self.init(context:context, recycle:off)
        
        emit = { [unowned self](signal) in
            self.emit(signal: signal)
        }
    }
    
    deinit {
        _recycle()
    }
    
    //returns nil if current ID is already there. Otherwise signs the signal
    private func sign(signal:Signal<Payload>) -> Signal<Payload>? {
        var sig = signal.0
        
        if sig.contains(_signature) {
            return nil
        }
        
        sig.insert(_signature)
        
        return (sig, signal.1)
    }
    
    internal func emit(signal:Signal<Payload>) {
        guard let signal = sign(signal: signal) else {
            return
        }

        context.immediateIfCurrent {
            for handler in self._handlers {
                handler.content.0(signal)
            }
        }
    }
    
    public func chain(_ f:@escaping Handler) -> Off {
        return context.sync {
            let container = UniqueContainer(content: (f, self))
            
            self._handlers.insert(container)
            
            return {
                self._handlers.remove(container)
            }
        }
    }
}

public extension SignalStreamProtocol {
    public func map<A>(_ f:@escaping (Payload)->A) -> SignalStream<A> {
        return SignalStream<A>(context: self.context) { fun in
            self.chain { sig, payload in
                fun((sig, f(payload)))
            }
        }
    }
    
    public func filter(_ f:@escaping (Payload)->Bool) -> SignalStream<Payload> {
        return SignalStream<Payload>(context: self.context, advise: { fun in
            self.chain { sig, payload in
                if f(payload) {
                    fun((sig, payload))
                }
            }
        })
    }
}

public extension EventEmitter {
    public func on<E : Event>(_ event: E) -> SignalStream<E.Payload> {
        let sig:Set<Int> = [signature(self)]
        
        return SignalStream<E.Payload>(context: self.context, advise: { fun in
            self.on(event) { payload in
                fun((sig, payload))
            }
        })
    }
}
