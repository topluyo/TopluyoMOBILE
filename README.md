# Topluyo Mobile Client

Topluyo platformunun mobil cihazlarda bir uygulama (client) gibi çalışmasını sağlayan, arka plan ses desteğine ve derin bağlantı (deeplink) entegrasyonuna sahip Flutter tabanlı mobil uygulamasıdır.

---

## 🚀 Temel Özellikler

- **Gelişmiş WebView Entegrasyonu:** `topluyo.com` platformunu uygulama içinde tam ekran ve yüksek performansla çalıştırır.
- **Arka Planda Sesli Sohbet (Foreground Service):** Sesli sohbet kanallarına girildiğinde uygulamanın arka planda da çalışmaya devam etmesi için kalıcı (persistent) bildirim açar ve mikrofon bağlantısını aktif tutar. Bildirim üzerinden mikrofonu kapatma veya kanaldan çıkma gibi hızlı kontroller sunar.
- **Dış Bağlantı Yönetimi:** Uygulama içerisinden `topluyo.com` dışındaki bir web sitesine yönlendiren linklere tıklanırsa, uygulama dışına çıkmak yerine cihazın varsayılan tarayıcısı (Chrome, Safari vb.) üzerinden açılması sağlanır.
- **Deep Linking (Derin Bağlantılar):** `topluyo://Destek` gibi özel bağlantılar yardımıyla doğrudan uygulamanın açılması ve içerideki WebView'ın `https://topluyo.com/Destek` sayfasına yönlendirilmesi sağlanır.
- **Detaylı Hata Raporlama:** WebView veya yerel platformda oluşan hataları, cihaz ve işletim sistemi sürümü bilgileri (örneğin `[Android 13 (SDK 33)]`) ile birlikte web tarafına raporlar.

---

## 🛠️ Proje Kurulumu ve Geliştirme

### Gereksinimler
- **Flutter SDK:** `^3.12.2` veya üzeri
- **Dart SDK:** Projede belirtilen uyumlu sürüm
- **Android Studio / Xcode:** Platforma göre derleme araçları

### Kurulum

1. Projeyi bilgisayarınıza indirin ve proje dizinine geçin:
   ```bash
   cd topluyo
   ```

2. Gerekli paketleri indirin:
   ```bash
   flutter pub get
   ```

### Uygulamayı Çalıştırma (Geliştirme Modu)

Cihazınızı veya emülatörünüzü bağladıktan sonra şu komutla çalıştırabilirsiniz:
```bash
flutter run
```

---

## 📦 Derleme (Build) İşlemleri

### 🤖 Android İçin Derleme

1. **APK Çıktısı (Testler İçin):**
   ```bash
   flutter build apk --release
   ```
   *Çıktı konumu: `build/app/outputs/flutter-apk/app-release.apk`*

2. **Google Play İçin App Bundle (AAB):**
   ```bash
   flutter build appbundle --release
   ```
   *Çıktı konumu: `build/app/outputs/bundle/release/app-release.aab`*

### 🍎 iOS İçin Derleme

1. **iOS Dosyalarını Hazırlama:**
   ```bash
   flutter build ios --release
   ```

2. **App Store Connect / TestFlight İçin IPA Çıkarma:**
   - Mac bilgisayarınızda `ios/Runner.xcworkspace` dosyasını Xcode ile açın.
   - Gerekli "Signing & Capabilities" (Sertifika ve Profil) ayarlarını yapılandırın.
   - **Product > Archive** adımlarını izleyerek arşiv oluşturun ve App Store'a yükleyin.

---

## 📁 Dosya Yapısı ve Önemli Bileşenler

- `lib/main.dart` - Uygulamanın başlangıç noktası ve servis başlatıcıları.
- `lib/screens/webview_screen.dart` - WebView katmanı, deeplink dinleyicileri, izin yönetimleri ve hata yönlendirme mantığı.
- `lib/services/foreground_service.dart` - Sesli sohbetin arka planda kalmasını sağlayan Foreground Service ayarları.
- `lib/services/js_bridge.dart` - WebView ile web sayfası arasında iletişim kuran Javascript köprüsü.
