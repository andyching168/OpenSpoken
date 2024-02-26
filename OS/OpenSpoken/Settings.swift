import Speech
import SwiftUI

class Settings: ObservableObject {
        
    @Published var translateLanguage: String = "en" // 將預設語言設為英語
        
    // 語言代碼到語言名稱的映射
    let languageNames: [String: String] = [
        "en": "English",
        "zh_tw": "中文(台灣)",
        "fr": "French",
        // 更多語言代碼和名稱...
    ]
    
    func getTranslateLanguageAsText() -> String {
            // 如果translateLanguage在字典中，直接返回對應的名稱
            if let languageName = languageNames[translateLanguage] {
                return languageName
            } else {
                // 嘗試從Locale構造一個更通用的語言名稱
                let locale = Locale(identifier: translateLanguage)
                if let languageCode = locale.languageCode, let displayName = Locale.current.localizedString(forLanguageCode: languageCode) {
                    return displayName
                }
            }
            // 如果以上方法都無法獲取語言名稱，返回一個預設值
            return "Unknown Language"
        }
    @Published var fontSize: CGFloat = 40.0 {
        didSet {
            UserDefaults.standard.set(fontSize, forKey: "fontSize")
        }
    }

    @Published var useLocale: Bool = true {
        didSet {
            UserDefaults.standard.set(useLocale, forKey: "useLocale")
        }
    }

    @Published var transcribeLanguage: String = "en-US" {
        didSet {
            UserDefaults.standard.set(transcribeLanguage, forKey: "locale")
        }
    }

    @Published var offlineTranscribe: Bool = false {
        didSet {
            UserDefaults.standard.set(offlineTranscribe, forKey: "offlineTranscribe")
        }
    }

    @Published var layoutDirection = LayoutDirection.leftToRight

    @ObservedObject static var instance: Settings = Settings()

    init() {
        load()
    }

    deinit {
        save()
    }

    private let fontStep = CGFloat(2)

    public func increaseFont() {
        fontSize = min(fontSize + fontStep, CGFloat(180.0))
    }

    public func decreaseFont() {
        fontSize = max(fontSize - fontStep, CGFloat(12.0))
    }

    public static func getLanguageIdentifierLocaleOrFallback(_ identifier: String?) -> String {
        let desiredLocale = Locale(identifier: identifier ?? Locale.current.identifier)
        if !SFSpeechRecognizer.supportedLocales().contains(desiredLocale) {
            return "en-US"
        } else {
            return desiredLocale.identifier
        }
    }

    public func currentLanguageAsText() -> String {
        let language = Locale(identifier: transcribeLanguage)
        return language.localizedString(forLanguageCode: language.languageCode ?? "en") ?? "Language"
    }

    public static func getDirectionForLocale(_ identifier: String) -> LayoutDirection {
        if Locale.characterDirection(forLanguage: identifier) == .rightToLeft {
            return .rightToLeft
        } else {
            return .leftToRight
        }
    }

    public func save() {
        let storage = UserDefaults.standard
        storage.set(fontSize, forKey: "fontSize")
        storage.set(useLocale, forKey: "useLocale")
        storage.set(transcribeLanguage, forKey: "locale")
        storage.set(offlineTranscribe, forKey: "offlineTranscribe")
    }

    private func load() {
        let storage = UserDefaults.standard
        fontSize = CGFloat(storage.optionalFloat(forKey: "fontSize") ?? 40.0)
        useLocale = storage.optionalBool(forKey: "useLocale") ?? true
        if useLocale {
            transcribeLanguage = Settings.getLanguageIdentifierLocaleOrFallback(nil)
        } else {
            transcribeLanguage = storage.string(forKey: "locale") ?? "en-US"
        }
        layoutDirection = Settings.getDirectionForLocale(transcribeLanguage)
        offlineTranscribe = storage.optionalBool(forKey: "offlineTranscribe") ?? false
    }
}

private func getLocaleString(_ locale: Locale) -> String {
    let language = locale.localizedString(forLanguageCode: locale.languageCode ?? "") ?? ""
    let country = locale.localizedString(forRegionCode: locale.regionCode ?? "") ?? ""
    if country.isEmpty { return language }
    else {
        return "\(language) (\(country))"
    }
}
struct TranslationLanguageView: View {
    var onLanguageSelected: (String) -> Void
    var onDismiss: () -> Void
    @State private var isVisible = false
    @ObservedObject private var settings = Settings.instance
    var selectedLanguage: String

    // 假設的翻譯語言列表
    let languages = [
        ("English", "en"),
        ("中文(台灣)", "zh_tw"),
        ("French", "fr"),
        // 添加更多支持的語言
    ]

    var body: some View {
        Button(settings.getTranslateLanguageAsText(), action: { isVisible = true })
            .sheet(isPresented: $isVisible) {
                NavigationView {
                    List(languages, id: \.1) { language in
                        Button(action: {
                            self.onLanguageSelected(language.1)
                            self.isVisible = false
                        }) {
                            HStack {
                                Text(language.0)
                                Spacer()
                                if selectedLanguage == language.1 {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    .navigationBarTitle(Text("Select Translation Language"), displayMode: .inline)
                    .navigationBarItems(trailing: Button("Done") {
                        self.onDismiss()
                        self.isVisible = false
                    })
                }
            }
    }
    
    // 初始化方法現在包括了所有提供的參數
    init(selectedLanguage: String, onLanguageSelected: @escaping (String) -> Void, onDismiss: @escaping () -> Void) {
        self.selectedLanguage = selectedLanguage
        self.onLanguageSelected = onLanguageSelected
        self.onDismiss = onDismiss
    }
}



struct LanguageView: View {
    let onLanguageSelected: (_ language: String?) -> Void
    let onDismiss: () -> Void
    @State var selectedLanguage: String
    private let supportedLocale = SFSpeechRecognizer.supportedLocales()
    var body: some View {
        NavigationView {
            List {
                Button("Use Locale", action: {
                    Settings.instance.useLocale = true
                    onLanguageSelected(nil)
                })
                Section {
                    ForEach(supportedLocale.sorted { $0.identifier < $1.identifier }, id: \.self.identifier) {
                        locale in
                        let isSelected = Settings.instance.transcribeLanguage == locale.identifier
                        HStack {
                            Text(getLocaleString(locale))
                            if isSelected {
                                Spacer()
                                Image(systemName: "mic")
                            }
                        }
                        .foregroundColor(isSelected ? Color.accentColor : Color.primary)
                        .onTapGesture {
                            onLanguageSelected(locale.identifier)
                        }
                    }
                }
                Section {
                    Toggle("On-Device Only", isOn: Settings.$instance.offlineTranscribe)
                }
            }
            .navigationBarItems(leading: Button(action: {
                self.onDismiss()
            }) {
                HStack {
                    Image(systemName: "chevron.backward")
                    Text("Cancel")
                }
            })
        }
    }
}

struct LanguageMenu: View {
    var notifyLanguageChanged: () -> Void
    @State private var isVisible = false
    @ObservedObject private var settings = Settings.instance
    func onSelected(_ newLanguage: String?) {
        settings.useLocale = newLanguage == nil
        settings.transcribeLanguage = Settings.getLanguageIdentifierLocaleOrFallback(newLanguage)
        settings.layoutDirection = Settings.getDirectionForLocale(settings.transcribeLanguage)
        isVisible = false
        notifyLanguageChanged()
    }

    var body: some View {
        Button(Settings.instance.currentLanguageAsText(), action: { isVisible = true }).sheet(isPresented: $isVisible) {
            LanguageView(onLanguageSelected: onSelected, onDismiss: { self.isVisible = false }, selectedLanguage: Settings.instance.transcribeLanguage)
        }
    }
}

struct FontToolbar: View {
    func increase() {
        Settings.instance.increaseFont()
    }

    func decrease() {
        Settings.instance.decreaseFont()
    }

    var body: some View {
        Group {
            HStack {
                Button("-", action: { Settings.instance.decreaseFont() })
                Image(systemName: "textformat.size")
                Button("+", action: { Settings.instance.increaseFont() })
            }.buttonStyle(.plain)
        }
        .frame(width: 120)
    }
}

// https://stackoverflow.com/a/53127813
extension UserDefaults {
    public func optionalFloat(forKey defaultName: String) -> Float? {
        let defaults = self
        if let value = defaults.value(forKey: defaultName) {
            return value as? Float
        }
        return nil
    }

    public func optionalBool(forKey defaultName: String) -> Bool? {
        let defaults = self
        if let value = defaults.value(forKey: defaultName) {
            return value as? Bool
        }
        return nil
    }
}
