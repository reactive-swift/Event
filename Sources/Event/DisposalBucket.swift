//===--- DisposableBucket.swift ----------------------------------------------===//
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

//private let _current = try! ThreadLocal<DisposalBucket>()

//TODO: move to Boilerplate???
public class DisposalBucket {
    private var offs = [Off]()
    
    private var off:Off {
        get {
            return {
                for off in self.offs {
                    off()
                }
            }
        }
    }
    
    public init() {
    }
    
    deinit {
        off()
    }
    
    public func put(off:@escaping Off) {
        self.offs.append(off)
    }
}

/* for the better times
//Current bucket
public extension DisposalBucket {
    public static var current:DisposalBucket? {
        get {
            return _current.value
        }
    }
    
    public func use(in f: (DisposalBucket)->Void) {
        _current.value = self
        
        f(self)
    }
    
    public func use(in f: ()->Void) {
        use { (_:DisposalBucket) in
            f()
        }
    }
}*/

//Operators
public extension DisposalBucket {
    public static func <=(bucket:DisposalBucket, off:Off?) {
        if let off = off {
            bucket.put(off: off)
        }
    }
    
    public static func =>(off:Off?, bucket:DisposalBucket) {
        bucket <= off
    }
}


