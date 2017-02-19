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

import Boilerplate
import ExecutionContext

public typealias Signal<T> = (Set<Int>, T)

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

public protocol SignalStreamProtocol : ExecutionContextTenantProtocol, AnyObject, SignatureProvider {
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
    
    public init(context:ExecutionContextProtocol, recycle:@escaping Off) {
        self._recycle = recycle
        self._handlers = []
        self.context = context
        self._signature = 0
        self._signature = signature
    }
    
    public convenience init(context:ExecutionContextProtocol, advise:(@escaping Handler)->Off) {
        var buffer = [Signal<T>]()
        var emit:(Signal<Payload>)->Void = { payload in
            buffer.append(payload)
        }
        
        let off = advise { signal in
            emit(signal)
        }
        
        self.init(context:context, recycle:off)
        
        emit = { [unowned self](signal) in
            self.emit(signal: signal)
        }
        
        for signal in buffer {
            self.context.async {
                emit(signal)
            }
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
    public func flatMap<A>(_ f:@escaping (Payload)->A?) -> SignalStream<A> {
        return SignalStream<A>(context: self.context, advise: { fun in
            self.chain { sig, payload in
                if let payload = f(payload) {
                    fun((sig, payload))
                }
            }
        })
    }
    
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
    
    public func debounce(timeout:Timeout, leading:Bool = false) -> SignalStream<Payload> {
        var firstFired = false
        let context = self.context
        var stored:Signal<Payload>? = nil
        var lastFinish = Date()
        
        return SignalStream<Payload>(context: self.context, advise: { fun in
            self.chain { signal in
                if !firstFired && leading {
                    firstFired = true
                    fun(signal)
                    lastFinish = Date()
                    return
                }
                
                if nil == stored {
                    let tm = Timeout(timeout: timeout.timeInterval - Date().timeIntervalSince(lastFinish))
                    context.async(after: tm) {
                        fun(stored!)
                        stored = nil
                        lastFinish = Date()
                    }
                }
                
                stored = signal
            }
        })
    }
    
    //all values will go in pairs. Non-paired values are buffered until paired
    public func zip<SS : SignalStreamProtocol>(_ ss:SS) -> SignalStream<(Payload, SS.Payload)> where SS :MovableExecutionContextTenantProtocol, SS.SettledTenant == SS {
        let zipped = ss.settle(in: self.context)
        
        var own = Array<(Set<Int>, Payload)>()
        var zip = Array<(Set<Int>, SS.Payload)>()
        
        typealias Fun = (Set<Int>, (Payload, SS.Payload)) -> Void
        
        let handle = { (fun:Fun) -> Void in
            guard let ownSignal = own.first else {
                return
            }
            
            guard let zipSignal = zip.first else {
                return
            }
            
            fun(ownSignal.0.union(zipSignal.0), (ownSignal.1, zipSignal.1))
            
            own.removeFirst()
            zip.removeFirst()
        }
        
        return SignalStream<(Payload, SS.Payload)>(context: self.context, advise: { fun in
            let soff = self.chain { signal in
                own.append(signal)
                handle(fun)
            }
            
            let zoff = zipped.chain { signal in
                zip.append(signal)
                handle(fun)
            }
            
            return {
                soff()
                zoff()
            }
        })
    }
    
    //Zipped values are emmitted every time either stream signals. No signals are emitted until both signaled at least ones. If you need to have signals emitted from the very first occurance (not both) see zipLatest0
    public func zipLatest<SS : SignalStreamProtocol>(_ ss:SS) -> SignalStream<(Payload, SS.Payload)> where SS :MovableExecutionContextTenantProtocol, SS.SettledTenant == SS {
        let zipped = ss.settle(in: self.context)
        
        var own:(Set<Int>, Payload)? = nil
        var zip:(Set<Int>, SS.Payload)? = nil
        
        typealias Fun = (Set<Int>, (Payload, SS.Payload)) -> Void
        
        let handle = { (fun:Fun) -> Void in
            guard let own = own else {
                return
            }
            
            guard let zip = zip else {
                return
            }
            
            fun(own.0.union(zip.0), (own.1, zip.1))
        }
        
        return SignalStream<(Payload, SS.Payload)>(context: self.context, advise: { fun in
            let soff = self.chain { signal in
                own = signal
                handle(fun)
            }
            
            let zoff = zipped.chain { signal in
                zip = signal
                handle(fun)
            }
            
            return {
                soff()
                zoff()
            }
        })
    }
    
    //Zipped values are emmitted every time either stream signals. Signals are emitted since first stream has signaled at least ones
    public func zipLatest0<SS : SignalStreamProtocol>(_ ss:SS) -> SignalStream<(Payload?, SS.Payload?)> where SS :MovableExecutionContextTenantProtocol, SS.SettledTenant == SS {
        let zipped = ss.settle(in: self.context)
        
        var own:(Set<Int>, Payload)? = nil
        var zip:(Set<Int>, SS.Payload)? = nil
        
        typealias Fun = (Set<Int>, (Payload?, SS.Payload?)) -> Void
        
        let handle = { (fun:Fun) -> Void in
            let sigOpt = own.flatMap { own in
                zip.map { zip in
                    zip.0.union(own.0)
                }.or(else: own.0)
            }.or { zip?.0 }
            
            guard let sig = sigOpt else {
                fatalError("How can it fire if neither isn't nil?")
            }
            
            fun(sig, (own?.1, zip?.1))
        }
        
        return SignalStream<(Payload?, SS.Payload?)>(context: self.context, advise: { fun in
            let soff = self.chain { signal in
                own = signal
                handle(fun)
            }
            
            let zoff = zipped.chain { signal in
                zip = signal
                handle(fun)
            }
            
            return {
                soff()
                zoff()
            }
        })
    }
    
    public func fork<SE : SignalEndpoint>(to endpoint: SE, _ f:(@escaping Off)->Void) -> Self where SE.Payload == Payload {
        f(pour(to: endpoint))
        return self
    }
}

public extension EventEmitter {
    public func on<E : Event>(_ event: E) -> SignalStream<E.Payload> {
        return SignalStream<E.Payload>(context: self.context, advise: { fun in
            self.on(event) { signal in
                fun(signal)
            }
        })
    }
}
