//
//  Executor.swift
//  FutureKit
//
//  Created by Michael Gray on 4/13/15.
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

import Foundation
import CoreData
import Dispatch

final public class Box<T> {
    public let value: T
    public init(_ v: T) { self.value = v }
}

/* public enum QosCompatible : Int {
    /* UserInteractive QoS is used for work directly involved in providing an interactive UI such as processing events or drawing to the screen. */
    case userInteractive
    
    /* UserInitiated QoS is used for performing work that has been explicitly requested by the user and for which results must be immediately presented in order to allow for further user interaction.  For example, loading an email after a user has selected it in a message list. */
    case userInitiated
    
    /* Utility QoS is used for performing work which the user is unlikely to be immediately waiting for the results.  This work may have been requested by the user or initiated automatically, does not prevent the user from further interaction, often operates at user-visible timescales and may have its progress indicated to the user by a non-modal progress indicator.  This work will run in an energy-efficient manner, in deference to higher QoS work when resources are constrained.  For example, periodic content updates or bulk file operations such as media import. */
    case utility
    
    /* Background QoS is used for work that is not user initiated or visible.  In general, a user is unaware that this work is even happening and it will run in the most efficient manner while giving the most deference to higher QoS work.  For example, pre-fetching content, search indexing, backups, and syncing of data with external systems. */
    case background
    
    /* Default QoS indicates the absence of QoS information.  Whenever possible QoS information will be inferred from other sources.  If such inference is not possible, a QoS between UserInitiated and Utility will be used. */
    case `default`
    
    
   var qos_class : qos_class_t {
        switch self {
        case .userInteractive:
            return DispatchQoS.QoSClass.userInteractive
        case .userInitiated:
            return DispatchQoS.QoSClass.userInitiated
        case .utility:
            return DispatchQoS.QoSClass.utility
        case .background:
            return DispatchQoS.QoSClass.background
        case .default:
            return DispatchQoS.QoSClass.default
        }

    }
    
    var queue : DispatchQueue {
        
        switch self {
        case .userInteractive:
            return DispatchQueue.global(qos: DispatchQoS.QoSClass.userInteractive)
        case .userInitiated:
            return DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated)
        case .utility:
            return DispatchQueue.global(qos: DispatchQoS.QoSClass.utility)
        case .background:
            return DispatchQueue.global(qos: DispatchQoS.QoSClass.background)
        case .default:
            return DispatchQueue.global(qos: DispatchQoS.QoSClass.default)
            
        }
    }
    
    public func createQueue(_ label: String?,
        q_attr : DispatchQueue.Attributes!,
        relative_priority: Int32 = 0) -> DispatchQueue {
            
            let qos_class = self.qos_class
            let nq_attr = dispatch_queue_attr_make_with_qos_class(q_attr,qos_class, relative_priority)
            let q : DispatchQueue
            if let l = label {
                q = DispatchQueue(label: l, attributes: nq_attr)
            }
            else {
                q = DispatchQueue(label: nil, attributes: nq_attr)
            }
            return q
    }

    
} */

private func make_dispatch_block<T>(_ q: DispatchQueue, _ block: @escaping (T) -> Void) -> ((T) -> Void) {
    
    let newblock = { (t:T) -> Void in
        q.async {
            block(t)
        }
    }
    return newblock
}

private func make_dispatch_block<T>(_ q: OperationQueue, _ block: @escaping (T) -> Void) -> ((T) -> Void) {
    
    let newblock = { (t:T) -> Void in
        q.addOperation({ () -> Void in
            block(t)
        })
    }
    return newblock
}

public enum SerialOrConcurrent: Int {
    case serial
    case concurrent
    
    public var q_attr : DispatchQueue.Attributes! {
        switch self {
        case .serial:
            return DispatchQueue.Attributes()
        case .concurrent:
            return DispatchQueue.Attributes.concurrent
        }
    }
    
}

// remove in Swift 2.0

extension qos_class_t {
    var rawValue : UInt32 {
        return self.rawValue
    }
}
public enum Executor {
    case primary                    // use the default configured executor.  Current set to Immediate.
                                    // There are deep philosphical arguments about Immediate vs Async.
                                    // So whenever we figure out what's better we will set the Primary to that!
    
    case main                       // will use MainAsync or MainImmediate based on MainStrategy

    case async                      // Always performs an Async Dispatch to some non-main q (usually Default)
                                    // If you want to put all of these in a custom queue, you can set AsyncStrategy to .Queue(q)

    case current                    // Will try to use the current Executor.
                                    // If the current block isn't running in an Executor, will return Main if running in the main thread, otherwise .Async

    case currentAsync               // Will try to use the current Executor, but guarantees that the operation will always call a dispatch_async() before executing.
                                    // If the current block isn't running in an Executor, will return MainAsync if running in the main thread, otherwise .Async
    

    case immediate                  // Never performs an Async Dispatch, Ok for simple mappings. But use with care!
    // Blocks using the Immediate executor can run in ANY Block

    case stackCheckingImmediate     // Will try to perform immediate, but does some stack checking.  Safer than Immediate
                                    // But is less efficient.  
                                    // Maybe useful if an Immediate handler is somehow causing stack overflow issues
    
    
    case mainAsync                  // will always do a dispatch_async to the mainQ
    case mainImmediate              // will try to avoid dispatch_async if already on the MainQ
    
    case userInteractive            // QOS_CLASS_USER_INTERACTIVE
    case userInitiated              // QOS_CLASS_USER_INITIATED
    case `default`                    // QOS_CLASS_DEFAULT
    case utility                    // QOS_CLASS_UTILITY
    case background                 // QOS_CLASS_BACKGROUND
    
    case queue(DispatchQueue)    // Dispatch to a Queue of your choice!
                                    // Use this for your own custom queues
    
    
    case operationQueue(Foundation.OperationQueue)    // Dispatch to a Queue of your choice!
                                             // Use this for your own custom queues
    
    case managedObjectContext(NSManagedObjectContext)   // block will run inside the managed object's context via context.performBlock()
    
    case custom(((@escaping () -> Void) -> Void))         // Don't like any of these?  Bake your own Executor!
    
    
    public var description : String {
        switch self {
        case .primary:
            return "Primary"
        case .main:
            return "Main"
        case .async:
            return "Async"
        case .current:
            return "Current"
        case .currentAsync:
            return "CurrentAsync"
        case .immediate:
            return "Immediate"
        case .stackCheckingImmediate:
            return "StackCheckingImmediate"
        case .mainAsync:
            return "MainAsync"
        case .mainImmediate:
            return "MainImmediate"
        case .userInteractive:
            return "UserInteractive"
        case .userInitiated:
            return "UserInitiated"
        case .default:
            return "Default"
        case .utility:
            return "Utility"
        case .background:
            return "Background"
        case let .queue(q):
            return "Queue(\(q.label))"
        case let .operationQueue(oq):
            let name = oq.name ?? "??"
            return "OperationQueue(\(name))"
        case .managedObjectContext:
            return "ManagedObjectContext"
        case .custom:
            return "Custom"
        }
    }
    
    public typealias CustomCallBackBlock = ((_ block:() -> Void) -> Void)

    public static var PrimaryExecutor = Executor.current {
        willSet(newValue) {
            switch newValue {
            case .primary:
                assertionFailure("Nope.  Nope. Nope.")
            case .main,.mainAsync,mainImmediate:
                NSLog("it's probably a bad idea to set .Primary to the Main Queue. You have been warned")
            default:
                break
            }
        }
    }
    public static var MainExecutor = Executor.mainImmediate {
        willSet(newValue) {
            switch newValue {
            case .mainImmediate, .mainAsync, .custom:
                break
            default:
                assertionFailure("MainStrategy must be either .MainImmediate or .MainAsync or .Custom")
            }
        }
    }
    public static var AsyncExecutor = Executor.default {
        willSet(newValue) {
            switch newValue {
            case .immediate, .stackCheckingImmediate,.mainImmediate:
                assertionFailure("AsyncStrategy can't be Immediate!")
            case .async, .main, .primary, .current, .currentAsync:
                assertionFailure("Nope.  Nope. Nope. AsyncStrategy can't be .Async, .Main, .Primary, .Current!, .CurrentAsync")
            case .mainAsync:
                NSLog("it's probably a bad idea to set .Async to the Main Queue. You have been warned")
            case let .queue(q):
                assert(!(q !== DispatchQueue.main),"Async is not for the mainq")
            default:
                break
            }
        }
    }
    
    fileprivate static let mainQ            = DispatchQueue.main
    fileprivate static let userInteractiveQ = DispatchQueue.global(qos:.userInteractive)
    fileprivate static let userInitiatedQ   = DispatchQueue.global(qos:.userInitiated)
    fileprivate static let defaultQ         = DispatchQueue.global(qos:.default)
    fileprivate static let utilityQ         = DispatchQueue.global(qos:.utility)
    fileprivate static let backgroundQ      = DispatchQueue.global(qos:.background)
    
    init(qos: DispatchQoS.QoSClass) {
        switch qos {
        case .userInteractive:
            self = .userInteractive
        case .userInitiated:
            self = .userInitiated
        case .default:
            self = .default
        case .utility:
            self = .utility
        case .background:
            self = .background
        case .unspecified:
            self = .default
        }
    }
    
    init(queue: DispatchQueue) {
        self = .queue(queue)
    }
    init(opqueue: Foundation.OperationQueue) {
        self = .operationQueue(opqueue)
    }

    public static func createQueue(label : String = "futurekit-q",
        type : SerialOrConcurrent,
        qos : DispatchQoS = DispatchQoS.default,
        attributes: DispatchQueue.Attributes = DispatchQueue.Attributes(rawValue:0),
        autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency = .inherit
        ) -> Executor {
        
            let q = DispatchQueue(label: label, qos: qos, attributes: attributes, autoreleaseFrequency: autoreleaseFrequency, target: nil)
            return .queue(q)
    }
    
    public static func createOperationQueue(_ name: String?,
        maxConcurrentOperationCount : Int) -> Executor {
            
            let oq = Foundation.OperationQueue()
            oq.name = name
            return .operationQueue(oq)
            
    }
    
    public static func createConcurrentQueue(label : String = "futurekit-concurrentq",qos : DispatchQoS = DispatchQoS.default) -> Executor  {
        return self.createQueue(label: label, type: .concurrent, qos: qos)
    }
    public static func createConcurrentQueue() -> Executor  {
        return self.createQueue(label : "futurekit-concurrentq", type: .concurrent, qos: .default)
    }
    public static func createSerialQueue(label : String = "futurekit-serialq", qos : DispatchQoS = DispatchQoS.default) -> Executor  {
        return self.createQueue(label : label, type: .serial, qos: qos)
    }
    public static func createSerialQueue() -> Executor  {
        return self.createQueue(label: "futurekit-serialq", type: .serial, qos: .default)
    }

    // immediately 'dispatches' and executes a block on an Executor
    // example:
    //
    //    Executor.Background.execute {
    //          // insert code to run in the QOS_CLASS_BACKGROUND queue!
    //     }
    //
    public func executeBlock(block b: @escaping ()->()) {
        let executionBlock = self.callbackBlockFor(b)
        executionBlock()
    }

    @discardableResult public func execute<__Type>(_ block: @escaping () throws -> __Type) -> Future<__Type> {
        let p = Promise<__Type>()
        self.executeBlock { () -> Void in
            do {
                let s = try block()
                p.completeWithSuccess(s)
            }
            catch {
                p.completeWithFail(error)
            }
        }
        return p.future
    }
    
    @discardableResult public func execute<C:CompletionType>(_ block: @escaping () throws -> C) -> Future<C.T> {
        let p = Promise<C.T>()
        self.executeBlock { () -> Void in
            do {
                let c = try block()
                p.complete(c)
            }
            catch {
                p.completeWithFail(error)
            }
        }
        return p.future
    }
    
    
    private func wallTime(date: NSDate, offset_nanosecs: Int64 = 0) -> DispatchWallTime {
        
        let (seconds, frac) = modf(date.timeIntervalSince1970)
        let nsec: Double = frac * Double(NSEC_PER_SEC)
        let walltime = timespec(tv_sec: Int(seconds), tv_nsec: Int(nsec) + Int(offset_nanosecs))
        
        return DispatchWallTime(timespec: walltime)
    }
    
    
    internal func _executeAt<C:CompletionType>(date:NSDate, block: @escaping () throws -> C) -> Future<C.T> {
        let p = Promise<C.T>()
        let popTime = wallTime(date: date)
        let q = self.underlyingQueue ?? Executor.defaultQ
        q.asyncAfter(wallDeadline: popTime, execute: {
            p.completeWithBlock {
                return try block()
            }
        })
        return p.future
    }
    
    internal func _executeAfterDelay<C:CompletionType>(secs : TimeInterval, block: @escaping () throws -> C) -> Future<C.T> {
        let nanosecsDouble = secs * TimeInterval(NSEC_PER_SEC)
        let nanosecs = UInt64(nanosecsDouble)
        let p = Promise<C.T>()
        let popTime = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + nanosecs)
        let q = self.underlyingQueue ?? Executor.defaultQ
        
        q.asyncAfter(deadline: popTime){
            p.completeWithBlock {
                return try block()
            }
        }
        return p.future
    }
    
    public func executeAfterDelay<C:CompletionType>(secs : TimeInterval,  block: @escaping () throws -> C) -> Future<C.T> {
        return self._executeAfterDelay(secs: secs,block:block)
    }
    
    @discardableResult public func executeAfterDelay<__Type>(_ secs : TimeInterval,  block: @escaping () throws -> __Type) -> Future<__Type> {
        return self.executeAfterDelay(secs: secs) { () -> Completion<__Type> in
            return .success(try block())
        }
    }
    

    public func executeAt<C:CompletionType>(date : NSDate,  block: @escaping () throws -> C) -> Future<C.T> {
        return self._executeAt(date: date,block:block)
    }

    public func executeAt<__Type>(date : NSDate,  block: @escaping () throws -> __Type) -> Future<__Type> {
        return self.executeAt(date: date) { () -> Completion<__Type> in
            return .success(try block())
        }
    }
    
    /**
     repeatExecution
     
     - parameter date:           time to start repeating
     - parameter repeatingEvery: interval to repeat
     - parameter action:         action to execute
     
     - returns: CancellationToken
     */
    public func repeatExecution(date: NSDate, repeatingEvery: TimeInterval, action: @escaping () -> Void) -> CancellationToken {
        return self.repeatExecution(date: date, repeatingEvery: repeatingEvery, withLeeway: repeatingEvery * 0.1, action: action)
    }


    /**
     schedule to repeat execution inside this executor
     
     - parameter date:           time to start repeatin
     - parameter repeatingEvery: interval to repeat
     - parameter leeway:         the 'leeway' execution is allowed. default is 10% of repeatingEvery
     - parameter action:         action to execute
     
     - returns: CancellationToken that can be used to stop the execution
     */
    public func repeatExecution(date: NSDate, repeatingEvery: TimeInterval, withLeeway leeway: TimeInterval, action: @escaping () -> Void) -> CancellationToken {
        precondition(repeatingEvery >= 0)
        precondition(leeway >= 0)
        
        let nsecInterval = repeatingEvery * Double(NSEC_PER_SEC)
        let nsecLeeway = leeway * Double(NSEC_PER_SEC)
        
        let timer = DispatchSource.makeTimerSource(queue: self.relatedQueue)
        timer.scheduleRepeating(wallDeadline: wallTime(date: date), interval: nsecInterval, leeway: DispatchTimeInterval.nanoseconds(Int(nsecLeeway)))
        timer.setEventHandler {
            () -> Void in
            self.execute(action)
        }
        timer.resume()
        
        let p = Promise<Void>()
        
        p.onRequestCancel { (options) -> CancelRequestResponse<Void> in
            timer.cancel()
            return .complete(.cancelled)
        }
        
        return p.future.getCancelToken()
        
    }


    // This returns the underlyingQueue (if there is one).
    // Not all executors have an underlyingQueue.
    // .Custom will always return nil, even if the implementation may include one.
    //
    var underlyingQueue: DispatchQueue? {
        get {
            switch self {
            case .primary:
                return Executor.PrimaryExecutor.underlyingQueue
            case .main, .mainImmediate, .mainAsync:
                return Executor.mainQ
            case .async:
                return Executor.AsyncExecutor.underlyingQueue
            case .userInteractive:
                return Executor.userInteractiveQ
            case .userInitiated:
                return Executor.userInitiatedQ
            case .default:
                return Executor.defaultQ
            case .utility:
                return Executor.utilityQ
            case .background:
                return Executor.backgroundQ
            case let .queue(q):
                return q
            case let .operationQueue(opQueue):
                return opQueue.underlyingQueue
            case let .managedObjectContext(context):
                if (context.concurrencyType == .mainQueueConcurrencyType) {
                    return Executor.mainQ
                }
                else {
                    return nil
                }
            default:
                return nil
            }
        }
    }
    
    public var relatedQueue: DispatchQueue {
        return self.underlyingQueue ?? Executor.defaultQ
    }

    static var SmartCurrent : Executor {  // should always return a 'real` executor, never a virtual one, like Main, Current, Immediate
        get {
            if let current = getCurrentExecutor() {
                return current
            }
            if (Thread.isMainThread) {
                return self.MainExecutor.real_executor
            }
            return .async
        }
    }
    
    /**
        So this will try and find the if the current code is running inside of an executor block.
        It uses a Thread dictionary to maintain the current running Executor.
        Will never return .Immediate, instead it will return the actual running Executor if known
    */
    public static func getCurrentExecutor() -> Executor? {
        let threadDict = Thread.current.threadDictionary
        let r = threadDict[GLOBAL_PARMS.CURRENT_EXECUTOR_PROPERTY] as? Box<Executor>
        return r?.value
    }
    
    public static func getCurrentQueue() -> DispatchQueue? {
        return getCurrentExecutor()?.underlyingQueue
    }
    
    
    
    /**
        Will compare to Executors.
        warning: .Custom Executors can't be compared and will always return 'false' when compared.
    */
    public func isEqualTo(_ e:Executor) -> Bool {
        switch self {
        case .primary:
            if case .primary = e { return true } else { return false }
        case .main:
            if case .main = e { return true } else { return false }
        case .async:
            if case .async = e { return true } else { return false }
        case .current:
            if case .current = e { return true } else { return false }
        case .currentAsync:
            if case .currentAsync = e { return true } else { return false }
        case .mainImmediate:
            if case .mainImmediate = e { return true } else { return false }
        case .mainAsync:
            if case .mainAsync = e { return true } else { return false }
        case .userInteractive:
            if case .userInteractive = e { return true } else { return false }
        case .userInitiated:
            if case .userInitiated = e { return true } else { return false }
        case .default:
            if case .default = e { return true } else { return false }
        case .utility:
            if case .utility = e { return true } else { return false }
        case .background:
            if case .background = e { return true } else { return false }
        case let .queue(q):
            if case let .queue(q2) = e {
                return q === q2
            }
            return false
        case let .operationQueue(opQueue):
            if case let .operationQueue(opQueue2) = e {
                return opQueue === opQueue2
            }
            return false
        case let .managedObjectContext(context):
            if case let .managedObjectContext(context2) = e {
                return context === context2
            }
            return false
        case .immediate:
            if case .immediate = e { return true } else { return false }
        case .stackCheckingImmediate:
            if case .stackCheckingImmediate = e { return true } else { return false }
        case .custom:
            // anyone know a good way to compare closures?
            return false
        }
        
    }
    
    var isTheCurrentlyRunningExecutor : Bool {
        if case .custom = self {
            NSLog("we can't compare Custom Executors!  isTheCurrentlyRunningExecutor will always return false when executing .Custom")
            return false
        }
        if let e = Executor.getCurrentExecutor() {
            return self.isEqualTo(e)
        }
        return false
    }
    // returns the previous Executor
    @discardableResult fileprivate static func setCurrentExecutor(_ e:Executor?) -> Executor? {
        let threadDict = Thread.current.threadDictionary
        let key = GLOBAL_PARMS.CURRENT_EXECUTOR_PROPERTY
        let current = threadDict[key] as? Box<Executor>
        if let ex = e {
            threadDict.setObject(Box<Executor>(ex), forKey: key as NSCopying)
        }
        else {
            threadDict.removeObject(forKey: key)
        }
        return current?.value
    }

    public func callbackBlockFor<T>(_ block: @escaping (T) -> Void) -> ((T) -> Void) {
        
        let currentExecutor = self.real_executor
        
        switch currentExecutor {
        case .immediate,.stackCheckingImmediate:
            return currentExecutor.getblock_for_callbackBlockFor(block)
        default:
            let wrappedBlock = { (t:T) -> Void in
                let previous = Executor.setCurrentExecutor(currentExecutor)
                block(t)
                Executor.setCurrentExecutor(previous)
            }
            return currentExecutor.getblock_for_callbackBlockFor(wrappedBlock)
        }
    }

    
    /*  
        we need to figure out what the real executor we need to guarantee that execution will happen asyncronously.
        This maps the 'best' executor to guarantee a dispatch_async() to use given the current executor
    
        Most executors are already async, and in that case this will return 'self'
    */
    fileprivate var asyncExecutor : Executor {
        
        switch self {
        case .primary:
            return Executor.PrimaryExecutor.asyncExecutor
        case .main, .mainImmediate:
            return .mainAsync
        case .current, .currentAsync:
            return Executor.SmartCurrent.asyncExecutor
        case .immediate, .stackCheckingImmediate:
            return Executor.AsyncExecutor
            
        case let .managedObjectContext(context):
            if (context.concurrencyType == .mainQueueConcurrencyType) {
                return .mainAsync
            }
            else {
                return self
            }
        default:
            return self
        }
    }
    
    /*  we need to figure out what the real executor will be used
        'unwraps' the virtual Executors like .Primary,.Main,.Async,.Current
    */
    fileprivate var real_executor : Executor {
        
        switch self {
        case .primary:
            return Executor.PrimaryExecutor.real_executor
        case .main:
            return Executor.MainExecutor.real_executor
        case .async:
            return Executor.AsyncExecutor.real_executor
        case .current:
            return Executor.SmartCurrent
        case .currentAsync:
            return Executor.SmartCurrent.asyncExecutor
        case let .managedObjectContext(context):
            if (context.concurrencyType == .mainQueueConcurrencyType) {
                return Executor.MainExecutor.real_executor
            }
            else {
                return self
            }
        default:
            return self
        }
    }
    
    fileprivate func getblock_for_callbackBlockFor<T>(_ block: @escaping (T) -> Void) -> ((T) -> Void) {
        
        switch self {
        case .primary:
            return Executor.PrimaryExecutor.getblock_for_callbackBlockFor(block)
        case .main:
            return Executor.MainExecutor.getblock_for_callbackBlockFor(block)
        case .async:
            return Executor.AsyncExecutor.getblock_for_callbackBlockFor(block)
            
        case .current:
            return Executor.SmartCurrent.getblock_for_callbackBlockFor(block)

        case .currentAsync:
            return Executor.SmartCurrent.asyncExecutor.getblock_for_callbackBlockFor(block)

        case .mainImmediate:
            let newblock = { (t:T) -> Void in
                if (Thread.isMainThread) {
                    block(t)
                }
                else {
                    Executor.mainQ.async {
                        block(t)
                    }
                }
            }
            return newblock
        case .mainAsync:
            return make_dispatch_block(Executor.mainQ,block)
            
        case .userInteractive:
            return make_dispatch_block(Executor.userInteractiveQ,block)
        case .userInitiated:
            return make_dispatch_block(Executor.userInitiatedQ,block)
        case .default:
            return make_dispatch_block(Executor.defaultQ,block)
        case .utility:
            return make_dispatch_block(Executor.utilityQ,block)
        case .background:
            return make_dispatch_block(Executor.backgroundQ,block)
            
        case let .queue(q):
            return make_dispatch_block(q,block)
            
        case let .operationQueue(opQueue):
            return make_dispatch_block(opQueue,block)
            
        case let .managedObjectContext(context):
            if (context.concurrencyType == .mainQueueConcurrencyType) {
                return Executor.MainExecutor.getblock_for_callbackBlockFor(block)
            }
            else {
                let newblock = { (t:T) -> Void in
                    context.perform {
                        block(t)
                    }
                }
                return newblock
            }
            
            
        case .immediate:
            return block
        case .stackCheckingImmediate:
            let b  = { (t:T) -> Void in
                var currentDepth : NSNumber
                let threadDict = Thread.current.threadDictionary
                if let c = threadDict[GLOBAL_PARMS.STACK_CHECKING_PROPERTY] as? NSNumber {
                    currentDepth = c
                }
                else {
                    currentDepth = 0
                }
                if (currentDepth.intValue > GLOBAL_PARMS.STACK_CHECKING_MAX_DEPTH) {
                    let b = Executor.AsyncExecutor.callbackBlockFor(block)
                    b(t)
                }
                else {
                    let newDepth = NSNumber(value: currentDepth.intValue+1 as Int32)
                    threadDict[GLOBAL_PARMS.STACK_CHECKING_PROPERTY] = newDepth
                    block(t)
                    threadDict[GLOBAL_PARMS.STACK_CHECKING_PROPERTY] = currentDepth
                }
            }
            return b
            
        case let .custom(customCallBack):
            
            let b = { (t:T) -> Void in
                customCallBack { () -> Void in
                    block(t)
                }
            }
            
            return b
        }
    }
    
}

let example_of_a_Custom_Executor_That_Is_The_Same_As_MainAsync = Executor.custom { (callback) -> Void in
    DispatchQueue.main.async {
        callback()
    }
}

let example_Of_a_Custom_Executor_That_Is_The_Same_As_Immediate = Executor.custom { (callback) -> Void in
    callback()
}

let example_Of_A_Custom_Executor_That_has_unneeded_dispatches = Executor.custom { (callback) -> Void in
    
    Executor.background.execute {
        Executor.async.execute {
            Executor.background.execute {
                callback()
            }
        }
    }
}

let example_Of_A_Custom_Executor_Where_everthing_takes_5_seconds = Executor.custom { (callback) -> Void in
    
    Executor.primary.executeAfterDelay(5.0) { () -> Void in
        callback()
    }
    
}




