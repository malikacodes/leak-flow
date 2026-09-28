import Foundation
import Combine

/// Downloads whisper models from HuggingFace
final class ModelDownloader: NSObject, ObservableObject {

    /// Available whisper models
    enum WhisperModel: String, CaseIterable, Identifiable {
        case baseEN = "base.en"
        case smallEN = "small.en"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .baseEN: return "Base English (~150MB)"
            case .smallEN: return "Small English (~500MB)"
            }
        }

        var fileName: String {
            switch self {
            case .baseEN: return "ggml-base.en.bin"
            case .smallEN: return "ggml-small.en.bin"
            }
        }

        var downloadURL: URL {
            URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(fileName)")!
        }
    }

    @Published var downloadProgress: [String: Double] = [:]
    @Published var isDownloading: [String: Bool] = [:]

    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var activeSession: URLSession?
    private var progressHandlers: [String: (Double) -> Void] = [:]
    private var completionHandlers: [String: (Result<URL, Error>) -> Void] = [:]

    static let modelsDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelsDir = appSupport.appendingPathComponent("LeakFlow/Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)

        return modelsDir
    }()

    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        activeSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    /// Check if a model file exists locally
    func isModelDownloaded(_ model: WhisperModel) -> Bool {
        let path = Self.modelsDirectory.appendingPathComponent(model.fileName)

        return FileManager.default.fileExists(atPath: path.path)
    }

    /// Get the local path for a model
    func modelPath(_ model: WhisperModel) -> String {
        return Self.modelsDirectory.appendingPathComponent(model.fileName).path
    }

    /// Download a model from HuggingFace
    func downloadModel(_ model: WhisperModel, completion: @escaping (Result<URL, Error>) -> Void) {
        guard isDownloading[model.rawValue] != true else { return }

        let destination = Self.modelsDirectory.appendingPathComponent(model.fileName)

        if FileManager.default.fileExists(atPath: destination.path) {
            completion(.success(destination))

            return
        }

        DispatchQueue.main.async {
            self.isDownloading[model.rawValue] = true
            self.downloadProgress[model.rawValue] = 0
        }

        completionHandlers[model.rawValue] = completion

        let task = activeSession!.downloadTask(with: model.downloadURL)
        task.taskDescription = model.rawValue
        downloadTasks[model.rawValue] = task
        task.resume()
    }

    /// Cancel a model download
    func cancelDownload(_ model: WhisperModel) {
        downloadTasks[model.rawValue]?.cancel()
        downloadTasks.removeValue(forKey: model.rawValue)

        DispatchQueue.main.async {
            self.isDownloading[model.rawValue] = false
            self.downloadProgress[model.rawValue] = 0
        }
    }
}

extension ModelDownloader: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let modelKey = downloadTask.taskDescription else { return }
        guard let model = WhisperModel(rawValue: modelKey) else { return }

        let destination = Self.modelsDirectory.appendingPathComponent(model.fileName)

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)

            DispatchQueue.main.async {
                self.isDownloading[modelKey] = false
                self.downloadProgress[modelKey] = 1.0
                self.completionHandlers[modelKey]?(.success(destination))
                self.completionHandlers.removeValue(forKey: modelKey)
            }
        } catch {
            DispatchQueue.main.async {
                self.isDownloading[modelKey] = false
                self.completionHandlers[modelKey]?(.failure(error))
                self.completionHandlers.removeValue(forKey: modelKey)
            }
        }

        downloadTasks.removeValue(forKey: modelKey)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let modelKey = downloadTask.taskDescription else { return }

        let progress = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0

        DispatchQueue.main.async {
            self.downloadProgress[modelKey] = progress
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let modelKey = task.taskDescription, let error = error else { return }

        if (error as NSError).code == NSURLErrorCancelled { return }

        DispatchQueue.main.async {
            self.isDownloading[modelKey] = false
            self.completionHandlers[modelKey]?(.failure(error))
            self.completionHandlers.removeValue(forKey: modelKey)
        }

        downloadTasks.removeValue(forKey: modelKey)
    }
}
