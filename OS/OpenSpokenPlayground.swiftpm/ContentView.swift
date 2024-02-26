
import SwiftUI

struct ContentView: View {
    @ObservedObject var settings = Settings.instance
    @ObservedObject var transcriber = SpeechCore()
    @State private var result = 0

    @State var shouldScroll = false

    var body: some View {
            VStack(spacing: 0) {
                
                // 使用 VStack 分隔兩個 ScrollView
                VStack {
                    SelectableTextView(text: $transcriber.transcribedText, isEditable: true, isRunning: $transcriber.isRunning)
                        .onChange(of: transcriber.transcribedText) { newText in
                            // 當文本改變且不在進行聽寫時觸發翻譯
                            if !transcriber.isRunning {
                                transcriber.translateText()
                            }
                        }
                            .font(.system(size: settings.fontSize)) // 可能需要調整，因為SelectableTextView中需要另外設置字體
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom) // 添加一些內邊距

                    Divider() // 可選的，如果您想要視覺上分隔這兩個部分
                    if(transcriber.isTranslateEnabled)
                    {
                        SelectableTextView(text: $transcriber.translatedText, isEditable: true, isRunning: $transcriber.isRunning)
                                .font(.system(size: settings.fontSize)) // 同上，需要在SelectableTextView中調整字體設置
                                .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                }
                
                .frame(maxHeight: .infinity)
                
                Text(transcriber.error ?? "").font(.system(size: 25)).foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)

            Spacer()
            HStack {
                FontToolbar().padding()
                Spacer()
                if transcriber.isRunning {
                    HStack {
                        Button(action: { transcriber.restart() }, label: {
                            Image(systemName: "clear.fill").foregroundColor(.yellow)
                        })
                        .padding()
                        Button(action: { transcriber.tryStop() }, label: {
                            Image(systemName: "stop.fill").foregroundColor(.red)
                        })
                        .padding()
                        Spacer()
                        ProgressView()
                    }
                } else {
                    Button(action: { transcriber.restart() }, label: {
                        Image(systemName: "mic.fill")
                    }).disabled(transcriber.error != nil)
                    .padding()
                }
                Spacer()
                Toggle("Translate", isOn: $transcriber.isTranslateEnabled)
                    .frame(width: 137.255)
                LanguageMenu(notifyLanguageChanged: {
                    if !self.transcriber.isRunning { return }
                    self.transcriber.restart()
                }).padding()
                TranslationLanguageView(
                    selectedLanguage: Settings.instance.translateLanguage, // 使用當前選擇的翻譯語言
                    onLanguageSelected: { newLanguage in
                        // 更新選擇的翻譯語言
                        Settings.instance.translateLanguage = newLanguage
                        // 當翻譯語言改變時的處理，例如重啟transcriber或其他邏輯
                        // 可以在這裡加入重啟transcriber的代碼
                    },
                    onDismiss: {
                        // 用戶點擊了完成按鈕或其他方式關閉了視圖的處理
                        // 這裡可以放空，或者加入需要的UI邏輯
                    }
                ).padding()

            }
        }
        
    }
}
struct SelectableTextView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    @ObservedObject var transcriber = SpeechCore()
    @ObservedObject var settings = Settings.instance
    @Binding var text: String // 讓文本成為綁定變量以支持雙向數據綁定
    var isEditable: Bool
    @Binding var isRunning: Bool // 根據語音聽寫狀態動態設置是否可編輯

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator // 設置delegate
        textView.isEditable = !isRunning && isEditable
        textView.font = UIFont.systemFont(ofSize: CGFloat(settings.fontSize)) // 根據需要調整字體大小
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
        uiView.delegate = context.coordinator
        uiView.isEditable = !isRunning && isEditable
        uiView.font = UIFont.systemFont(ofSize: CGFloat(settings.fontSize)) // 根據需要調整字體大小
        // 根據需要進行進一步的配置，比如字體、顏色等
    }
    class Coordinator: NSObject, UITextViewDelegate {
            var parent: SelectableTextView

            init(_ textView: SelectableTextView) {
                self.parent = textView
            }

            func textViewDidChange(_ textView: UITextView) {
                parent.text = textView.text
                // 正確地通過parent屬性訪問transcriber來調用translateText()
                if(parent.transcriber.isTranslateEnabled)
                {
                    parent.transcriber.translateText()
                }
                
            }
        }
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
