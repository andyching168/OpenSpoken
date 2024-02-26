    import Speech
    import SwiftUI

    // ugly workaround for a delegate without fancy ViewController
    class SpeechChangeDelegate: NSObject, UISceneDelegate, SFSpeechRecognizerDelegate {
        var onSpeechChange: ((_ available: Bool) -> Void)?
        public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
            onSpeechChange?(available)
        }
    }

    public class SpeechCore: ObservableObject {
        @ObservedObject var settings = Settings.instance
        let delegate = SpeechChangeDelegate()

        private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "he-IL"))!
        private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
        private var recognitionTask: SFSpeechRecognitionTask?
        private let audioEngine = AVAudioEngine()

        @Published var isRunning = false
        @Published var error: String?

        @Published var transcribedText = "Tap the start below to begin"
        @Published var translatedText = "此處顯示翻譯後的結果"

        init() {
            // Asynchronously make the authorization request.
            SFSpeechRecognizer.requestAuthorization { authStatus in

                // Divert to the app's main thread so that the UI
                // can be updated.
                OperationQueue.main.addOperation {
                    switch authStatus {
                    case .authorized:
                        self.error = nil
                    case .denied:
                        self.error = "User denied access to speech recognition"

                    case .restricted:
                        self.error = "Speech recognition restricted on this device"

                    case .notDetermined:
                        self.error = "Speech recognition not yet authorized"

                    default:
                        self.error = "Speech unavailble due to unknown reason"
                    }
                }
            }
            delegate.onSpeechChange = {
                available in
                self.isRunning = available
            }
            speechRecognizer.delegate = delegate
        }
        func translateText() {
            let targetLanguage = Settings.instance.translateLanguage // 獲取用戶選擇的翻譯目標語言
            let apiUrl = "https://clients5.google.com/translate_a/t"
            let params = "?client=dict-chrome-ex&sl=auto&tl=\(targetLanguage)&q=\(transcribedText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            
            guard let url = URL(string: apiUrl + params) else {
                print("Invalid URL")
                return
            }
            
            var request = URLRequest(url: url)
            // 設置自定義User-Agent
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36 Edg/122.0.0.0", forHTTPHeaderField: "User-Agent")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let data = data {
                    if let decodedResponse = try? JSONDecoder().decode([[String]].self, from: data) {
                        // Main thread
                        DispatchQueue.main.async {
                            // 假定API返回的格式是 [["translatedText", "sourceLanguage"]]
                            if !decodedResponse.isEmpty && !decodedResponse[0].isEmpty {
                                self.translatedText = decodedResponse[0][0]
                            }
                        }
                    }
                }
            }.resume()
        }
        private func tryToStart() throws {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: settings.transcribeLanguage))!

            // Cancel the previous task if it's running.
            recognitionTask?.cancel()
            recognitionTask = nil

            clear()

            // Configure the audio session for the app.
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            let inputNode = audioEngine.inputNode

            // Create and configure the speech recognition request.
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object") }
            recognitionRequest.shouldReportPartialResults = true
            //        recognitionRequest.taskHint = .dictation

            if #available(iOS 13, *) {
                recognitionRequest.requiresOnDeviceRecognition = self.settings.offlineTranscribe
            }

            // Create a recognition task for the speech recognition session.
            // Keep a reference to the task so that it can be canceled.
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
                var isFinal = false

                guard let result = result else { return }
                // Update the text view with the results.
                self.transcribedText = result.bestTranscription.formattedString
                self.translateText()
                isFinal = result.isFinal
                #if DEBUG
                print(self.transcribedText)
                #endif

                if error != nil {
                    // Stop recognizing speech if there is a problem.
                    self.audioEngine.stop()
                    inputNode.removeTap(onBus: 0)

                    self.recognitionRequest = nil
                    self.recognitionTask = nil

                    self.isRunning = false
                    self.error = "Recognition stopped due to a problem \(error.debugDescription) isFinal: \(isFinal)"
                }
            }

            // Configure the microphone input.
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, _: AVAudioTime) in
                self.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            print("Finished initializing speech recognition")
        }

        public func tryStop() {
            if audioEngine.isRunning {
                audioEngine.stop()
                audioEngine.inputNode.removeTap(onBus: 0)
                recognitionRequest?.endAudio()
                isRunning = false
            }
        }

        public func clear() {
            transcribedText = ""
        }

        public func restart() {
            tryStop()
            do {
                try tryToStart()
            } catch {
                isRunning = false
            }
            isRunning = true
        }
    }
