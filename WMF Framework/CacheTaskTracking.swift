
import Foundation

struct IdentifiedTask {
    let untrackKey: String
    let task: URLSessionTask
}

// TODO: less of a sledgehammer here
let CacheTaskTrackingSemaphore = DispatchSemaphore(value: 1)

protocol CacheTaskTracking: class {
    var groupedTasks: [String: [IdentifiedTask]] { get set }
    
    func cancelTasks(for groupKey: String)
    func untrackTask(untrackKey: String, from groupKey: String)
    func trackTask(untrackKey: String, task: URLSessionTask, to groupKey: String)
}

extension CacheTaskTracking {
    func cancelTasks(for groupKey: String) {
        CacheTaskTrackingSemaphore.wait()
        if let identifiedTasks = groupedTasks[groupKey] {
            for identifiedTask in identifiedTasks {
                identifiedTask.task.cancel()
            }
        }
        CacheTaskTrackingSemaphore.signal()
    }
    
    func untrackTask(untrackKey: String, from groupKey: String) {
        CacheTaskTrackingSemaphore.wait()
        if let identifiedTasks = groupedTasks[groupKey] {
            groupedTasks[groupKey] = identifiedTasks.filter { $0.untrackKey == untrackKey }
        }
        CacheTaskTrackingSemaphore.signal()
    }
    
    func trackTask(untrackKey: String, task: URLSessionTask, to groupKey: String) {
        CacheTaskTrackingSemaphore.wait()
        let identifiedTask = IdentifiedTask(untrackKey: untrackKey, task: task)
        groupedTasks[groupKey]?.append(identifiedTask)
        CacheTaskTrackingSemaphore.signal()
    }
}
