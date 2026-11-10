# Kasa: iPhone uygulaması kurulum rehberi

Kasa, iPhone'unuza kurulan gerçek (yerel) bir şifre yöneticisidir:

- **Face ID** ile açılır.
- Şifreleriniz yalnızca telefonda, **AES-256** ile şifrelenmiş olarak saklanır.
- İnternete hiçbir veri gönderilmez.

Kurulum üç aşamadan oluşuyor:

1. **GitHub uygulamayı derler.** Apple, iPhone uygulamalarının yalnızca Mac'te derlenmesine izin verdiği için GitHub'ın ücretsiz Mac sunucularını kullanıyoruz.
2. **Sideloadly** programı uygulamayı USB kablosuyla telefonunuza yükler.
3. Telefonda bir kerelik birkaç izin verirsiniz.

---

## Aşama 1: Uygulamayı GitHub'da derleyin (yaklaşık 10 dakika)

1. Masaüstündeki **Kasa-iPhone.zip** dosyasına sağ tıklayıp **Tümünü ayıkla**'yı seçin.
2. github.com'da sağ üstteki **+** düğmesine tıklayın ve **New repository**'yi seçin.
   - **Repository name:** `kasa-ios`
   - **Public** seçili kalsın. Public depolarda Mac derlemesi ücretsiz ve sınırsızdır. Kodda hiçbir şifreniz yok.
   - **Create repository**'ye tıklayın.
3. Açılan sayfada **uploading an existing file** bağlantısına tıklayın.
4. Ayıkladığınız **Kasa-iPhone** klasörünü açın. **Ctrl + A** ile her şeyi seçip GitHub sayfasına sürükleyin. Seçimde şunlar olmalı:
   `.github` klasörü, `Kasa` klasörü, `project.yml` ve `KURULUM.md`.
   Yükleme listesinde `.github/workflows/build.yml` satırını görünce alttaki yeşil **Commit changes** düğmesine tıklayın.
5. Deponun üstündeki **Actions** sekmesine tıklayın. **"iPhone uygulamasını derle"** işi kendiliğinden başlar (sarı daire). 5–10 dakika bekleyin.
   - **Yeşil tik ✅** çıkarsa işe tıklayın. Sayfanın altındaki **Artifacts** bölümünden **Kasa-ipa**'yı indirin. İnen zip'i ayıklayın, içinden **Kasa.ipa** çıkar.
   - **Kırmızı çarpı ❌** çıkarsa işe tıklayın ve sayfadaki **"Derleme hataları"** kutusunun ekran görüntüsünü Claude'a gönderin. Hatayı düzeltip yeni dosyayı veririm.

> Yüklemede `.github` klasörü görünmüyorsa: deponun ana sayfasında **Add file › Create new file**'ı seçin. Dosya adına `.github/workflows/build.yml` yazın, bu klasördeki aynı dosyanın içeriğini yapıştırın ve **Commit changes**'e tıklayın.

## Aşama 2: Bilgisayara gerekli programları kurun (bir kez)

Sideloadly, Apple'ın **web sürümü** iTunes ve iCloud programlarını ister. **Microsoft Store sürümleriyle çalışmaz.**

1. Bilgisayarda Microsoft Store'dan yüklenmiş **iTunes** veya **iCloud** varsa önce kaldırın: *Ayarlar › Uygulamalar*.
2. **https://sideloadly.io** adresine gidin. Sayfadaki **Web iTunes (64-bit)** ve **Web iCloud** bağlantılarıyla ikisini kurun.
3. Aynı sayfadan **Sideloadly**'yi indirin (*SideloadlySetup64.exe*) ve kurun.

## Aşama 3: Telefona yükleyin

1. iPhone'u USB kablosuyla bilgisayara bağlayın. Telefonda **"Bu bilgisayara güvenilsin mi?"** sorusu çıkarsa **Güven**'e dokunun ve telefon şifrenizi girin.
2. **Sideloadly**'yi açın.
   - Üstteki cihaz listesinde iPhone'unuzu seçin.
   - **Apple account** kutusuna Apple kimliğinizin (iCloud) e-posta adresini yazın.
   - **Kasa.ipa** dosyasını Sideloadly penceresindeki IPA simgesinin üzerine sürükleyin.
   - **Advanced options** bölümünde otomatik yenileme seçeneğini (**Automatic refresh**) açın.
   - **Start**'a tıklayın. İstendiğinde Apple şifrenizi ve telefonunuza gelen 6 haneli doğrulama kodunu girin.
   - Alt satırda **Done** yazınca yükleme tamamdır.
3. **iPhone'da Geliştirici Modu'nu açın (iOS 16 ve üstü, bir kez):** *Ayarlar › Gizlilik ve Güvenlik › Geliştirici Modu*'nu açın. Telefon yeniden başlar; açılınca **Aç**'a dokunun.
4. **Uygulamaya güvenin (bir kez):** *Ayarlar › Genel › VPN ve Cihaz Yönetimi*'ne girin. Apple kimliğinizin e-postasına dokunun, ardından **Güven**'e dokunun.
5. Ana ekranda **Kasa** simgesi oluştu. Açıp ana şifrenizi oluşturun. Ardından **Ayarlar › Face ID ile aç**'ı etkinleştirin.

---

## ⚠️ Ücretsiz Apple kimliği: 7 günlük süre

Ücretsiz Apple kimliğiyle yüklenen uygulamalar **7 gün** çalışır. Sonra yeniden imzalanmaları gerekir.

- Sideloadly'nin **otomatik yenileme** özelliği açıksa, bilgisayar açıkken ve telefon USB ya da aynı Wi-Fi ile bağlıyken uygulamayı süresi dolmadan kendisi yeniler.
- Süre dolarsa uygulama açılmaz ama **verileriniz silinmez**. Sideloadly'de aynı Apple kimliği ve aynı `Kasa.ipa` ile yeniden **Start**'a tıklamanız yeterli.
- Yıllık ücretli Apple Developer hesabıyla bu süre 1 yıla çıkar.

## Düzenli yedek alın

**Ayarlar › Şifreli yedek al** › **Dosyalar'a Kaydet** › **iCloud Drive** yolunu izleyin.

- Yedek dosyası yalnızca ana şifrenizle açılır.
- Uygulamayı silerseniz ya da telefon değiştirirseniz kurulum ekranındaki **"Yedekten geri yükle"** ile her şeyi geri alırsınız.

## Özellikler

- **Face ID / Touch ID** ile açma; şifre hatalı girilirse giderek artan bekleme süresi.
- **Şifreleme:** AES-256-GCM. Anahtar, ana şifreden PBKDF2-SHA256 ile 600.000 turda türetilir.
- **Face ID anahtarı** iPhone'un Anahtar Zinciri'nde, yalnızca bu cihazda saklanır.
- **Kayıtlar:** başlık, kullanıcı adı, şifre, web sitesi, notlar, kategori, favori.
- **Şifre geçmişi:** her kaydın son 10 eski şifresi saklanır.
- **2FA kodları:** Google Authenticator gibi 6 haneli kodlar, geri sayım halkasıyla.
- **Şifre üretici:** 8–64 karakter, entropi ve kırılma süresi gösterimi.
- **Güvenlik raporu:** zayıf, tekrar kullanılan ve eski şifreler; 100 üzerinden puan.
- **Liste:** arama, kategori filtreleri, A–Z veya son değişene göre sıralama.
- **Liste hareketleri:** sağa ya da sola kaydırarak kopyalama, favori ve silme; uzun basınca hızlı menü.
- **Akıllı pano:** kopyalanan şifre belirlediğiniz sürede kendiliğinden silinir ve diğer Apple cihazlarınıza aktarılmaz.
- **Otomatik kilit:** hemen, 30 saniye … 1 saat ya da asla. Uygulama değiştiricide içerik gizlenir.
- **Yedekleme:** şifreli yedek alma ve geri yükleme.
- **CSV:** iCloud Anahtar Zinciri, Chrome, Bitwarden vb.'den içe aktarma; dışa aktarma.
- **Tema:** koyu, açık veya sistem.

## Uygulamayı güncellemek

Claude'dan yeni bir sürüm aldığınızda:

1. Değişen dosyaları GitHub'a aynı şekilde yükleyin (**Add file › Upload files**). Derleme kendiliğinden yeniden başlar.
2. Yeni **Kasa.ipa**'yı Sideloadly ile aynı Apple kimliğiyle yükleyin.

Uygulama güncellenir, verileriniz yerinde kalır.
