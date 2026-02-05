# ReadEng - Product Requirements Document (PRD)

## 📋 Document Info

| Field | Value |
|-------|-------|
| Product Name | ReadEng |
| Version | 1.0 |
| Last Updated | Ocak 2025 |
| Status | Draft |

---

## 1. Product Purpose

### 1.1 Vision Statement

ReadEng, K12 öğrencilerinin İngilizce okuma ve kelime becerilerini **etkileşimli hikaye kitapları** ve **gamification** ile geliştiren bir dijital öğrenme platformudur.

### 1.2 Mission

Okullardaki İngilizce eğitimini desteklemek için öğretmenlerin iş yükünü azaltan, öğrencilerin motivasyonunu artıran ve ölçülebilir öğrenme çıktıları sağlayan bir araç sunmak.

### 1.3 Core Value Proposition

| Stakeholder | Value |
|-------------|-------|
| **Öğrenciler** | Eğlenceli, oyunlaştırılmış okuma deneyimi; seviyeye uygun içerik; anlık geri bildirim |
| **Öğretmenler** | Otomatik takip ve raporlama; kolay görev atama; azaltılmış iş yükü |
| **Okullar** | Ölçülebilir öğrenme çıktıları; standartlaştırılmış İngilizce müfredatı desteği |
| **Veliler** | Çocuğun ilerlemesini takip edebilme (opsiyonel) |

---

## 2. Target Users

### 2.1 Primary Users

#### 2.1.1 Öğrenciler
- **Yaş Aralığı:** 6-18 (K12)
- **Segmentler:**
  - İlkokul (1-4. sınıf) — A1 başlangıç seviyesi
  - Ortaokul (5-8. sınıf) — A1-A2-B1 gelişim seviyesi
  - Lise (9-12. sınıf) — A2-B1-B2 ileri seviye
- **Karakteristikler:**
  - Dijital araçlara aşina
  - Kısa dikkat süresi
  - Oyunlaştırma ve ödüllere duyarlı
  - Akran rekabetinden motive olur

#### 2.1.2 Öğretmenler
- **Profil:** İngilizce öğretmenleri
- **Sınıf Sayısı:** Ortalama 2-6 sınıf
- **Öğrenci Sayısı:** 50-200 öğrenci
- **Pain Points:**
  - Her öğrencinin ilerlemesini takip etmek zor
  - Bireyselleştirilmiş geri bildirim vermeye zaman yok
  - Ödev kontrolü ve değerlendirme yükü
  - Pasif öğrencileri tespit etmek zor

### 2.2 Secondary Users

#### 2.2.1 Bölüm Başkanları
- **Profil:** İngilizce zümre başkanları
- **Sorumluluk:** Bölümdeki tüm öğretmen ve sınıfları koordine etmek
- **İhtiyaçlar:** Karşılaştırmalı raporlar, trend analizleri

#### 2.2.2 Platform Adminleri
- **Profil:** ReadEng ekibi
- **Sorumluluk:** İçerik yönetimi, okul/kullanıcı yönetimi, sistem bakımı

#### 2.2.3 Veliler (Opsiyonel/Gelecek)
- **İhtiyaç:** Çocuğun ilerlemesini görme, evde teşvik

---

## 3. Problems to Solve

### 3.1 Öğrenci Problemleri

| Problem | Etki | ReadEng Çözümü |
|---------|------|----------------|
| İngilizce okuma sıkıcı ve zorlu | Motivasyon düşüklüğü, kaçınma | Görsel + sesli + interaktif hikayeler |
| Seviyeye uygun materyal bulmak zor | Hayal kırıklığı, öğrenememe | CEFR bazlı seviyelendirme (A1-C2) |
| Bilinmeyen kelimeler okumayı durduruyor | Akış kesilmesi, bırakma | Anlık sözlük (tıkla → anlam + ses) |
| İlerleme görünmüyor | "Ne için çalışıyorum?" hissi | XP, rozetler, seviye sistemi, sıralama |
| Okuma dışında pratik yok | Kelimeler unutuluyor | Spaced repetition kelime egzersizleri |

### 3.2 Öğretmen Problemleri

| Problem | Etki | ReadEng Çözümü |
|---------|------|----------------|
| Her öğrenciyi takip edememe | Riskli öğrenciler gözden kaçıyor | Otomatik "dikkat gerektiren" uyarıları |
| Ödev verme/kontrol yükü | Zaman kaybı | Tek tıkla görev atama, otomatik değerlendirme |
| Hangi konular zayıf bilmeme | Etkisiz müdahale | Detaylı zayıf alan raporları |
| Bireysel geri bildirim verme zorluğu | Öğrenci gelişemez | Platform bazında otomatik geri bildirim |
| Sınıflar arası karşılaştırma yapamama | Standardizasyon eksikliği | Sınıf karşılaştırma raporları |

### 3.3 Okul/Kurum Problemleri

| Problem | Etki | ReadEng Çözümü |
|---------|------|----------------|
| İngilizce başarısını ölçmek zor | ROI gösterilemiyor | Okul geneli CEFR seviye dağılımı raporları |
| Öğretmenler arası tutarsızlık | Standart yok | Tüm öğretmenler aynı platformu kullanır |
| Ek materyal maliyeti | Bütçe yükü | Dijital kütüphane ile tek platform |

---

## 4. Product Functionality

### 4.1 Module 1: Digital Library (Dijital Kütüphane)

#### 4.1.1 Kitap Organizasyonu
- **Seviyelendirme:** CEFR (A1, A2, B1, B2, C1, C2)
- **Türler:** Macera, bilim kurgu, klasikler, biyografi, günlük hayat
- **Yaş Grupları:** İlkokul, ortaokul, lise
- **Tema Etiketleri:** Dostluk, cesaret, doğa, aile, teknoloji...

#### 4.1.2 Okuma Deneyimi
```
Temel Özellikler:
├── Sayfa sayfa görsel tasarım
├── Kelimelere tıklayınca anlık sözlük + telaffuz
├── Profesyonel seslendirme (her bölüm)
├── Karaoke modu (metin takibi)
├── Hız ayarı (0.75x, 1x, 1.25x)
├── Gece modu / font boyutu ayarları
└── Arka plan müziği (opsiyonel)
```

#### 4.1.3 Bölüm Sonu Aktiviteleri
| Aktivite Tipi | Açıklama | Ölçtüğü Beceri |
|---------------|----------|----------------|
| Çoktan seçmeli | 4 seçenekli sorular | Anlama |
| Doğru/Yanlış | İfade doğruluğu | Detay hatırlama |
| Sıralama | Olayları doğru sıraya koy | Kronolojik anlama |
| Eşleştirme | Karakter-özellik, neden-sonuç | İlişkilendirme |
| Boşluk doldurma | Cümledeki eksik kelime | Kelime + gramer |
| Tahmin sorusu | "Sence sonra ne olacak?" | Çıkarım yapma |

#### 4.1.4 Değerlendirme
- **Puanlama:** Doğru/yanlış bazlı
- **Anında Geri Bildirim:** Her soruda doğru cevap açıklaması
- **Minimum Geçme Notu:** Öğretmen tarafından ayarlanabilir (varsayılan %60)

---

### 4.2 Module 2: Vocabulary Exercises (Kelime Egzersizleri)

#### 4.2.1 Kelime Kaynakları
```
Kaynak Seçenekleri:
├── Okunan kitaplardan (otomatik çıkarım)
├── Öğretmenin atadığı özel listeler
├── Seviyeye göre genel kelime havuzu
├── Tematik listeler (yiyecekler, duygular, seyahat...)
└── Zayıf kelimeler (spaced repetition)
```

#### 4.2.2 Egzersiz Tipleri (Duolingo-style)
| Egzersiz | Açıklama | Zorluk |
|----------|----------|--------|
| Flashcard | Görsel + ses + anlam | ⭐ |
| Dinle ve seç | Sesi duy, 4 seçenekten bul | ⭐⭐ |
| Harf sıralama | Harfleri sürükle, kelimeyi oluştur | ⭐⭐ |
| Cümle boşluğu | "The cat is very ___" | ⭐⭐⭐ |
| Görsel eşleştirme | Resim-kelime eşle | ⭐ |
| Yazarak pratik | Kelimeyi klavyeden yaz | ⭐⭐⭐ |
| Telaffuz kaydı | Sesini kaydet, AI değerlendirme | ⭐⭐⭐⭐ |

#### 4.2.3 Akıllı Tekrar Sistemi (Spaced Repetition)
- Yanlış cevaplanan kelimeler otomatik olarak "zayıf" listesine eklenir
- Algoritma, unutulmadan önce tekrar zamanını hesaplar
- Günlük kelime hedefi belirlenir (varsayılan: 20 kelime)

---

### 4.3 Module 3: Gamification & Achievement System

#### 4.3.1 Puan Sistemi (XP)
| Eylem | XP |
|-------|-----|
| Sayfa okuma | +2 XP |
| Bölüm tamamlama | +20 XP |
| Aktivite (doğru cevap başına) | +5 XP |
| Kitap bitirme | +100 XP |
| Kelime egzersizi (kelime başına) | +3 XP |
| Günlük giriş | +10 XP |
| Streak bonusu (7 gün) | +50 XP |
| Mükemmel skor bonusu (%100) | +30 XP |

#### 4.3.2 Seviye Sistemi
```
Seviye 1-5:   Bronze Reader     (0 - 500 XP)
Seviye 6-10:  Silver Reader     (500 - 2000 XP)
Seviye 11-15: Gold Reader       (2000 - 5000 XP)
Seviye 16-20: Platinum Reader   (5000 - 10000 XP)
Seviye 21+:   Diamond Reader    (10000+ XP)
```

#### 4.3.3 Rozetler
| Rozet | Koşul |
|-------|-------|
| 📖 İlk Kitap | İlk kitabı tamamla |
| 🔥 7 Gün Streak | 7 gün üst üste giriş |
| 💯 100 Kelime | 100 kelime öğren |
| 🎯 A1 Ustası | Tüm A1 kitapları tamamla |
| ⚡ Hız Okuyucu | 1 kitabı 1 günde bitir |
| 🏆 Mükemmeliyetçi | 5 aktivitede %100 al |
| 📚 Kitap Kurdu | 10 kitap oku |
| 🌟 Kelime Ustası | 500 kelime öğren |

#### 4.3.4 Sıralamalar (Leaderboards)
- **Sınıf içi:** Haftalık, aylık
- **Okul geneli:** Aylık
- **Kategoriler:** En çok XP, en çok kitap, en yüksek doğruluk

---

### 4.4 Module 4: Teacher Dashboard

#### 4.4.1 Görev Atama
```
Görev Atama Akışı:
1. Görev tipi seç (Kitap / Kelime / Karma)
2. İçerik seç (kitap + bölümler veya kelime listesi)
3. Öğrenci seç (tüm sınıf / seviyeye göre / manuel)
4. Detaylar belirle:
   ├── Başlangıç tarihi
   ├── Bitiş tarihi
   ├── Minimum başarı oranı
   ├── Öğrenci notu
   └── Hatırlatma ayarları
5. Görevi oluştur
```

#### 4.4.2 İzleme & Uyarılar
| Uyarı Tipi | Tetikleyici |
|------------|-------------|
| 🔴 Riskli Öğrenci | 2 hafta üst üste %50 altı başarı |
| ⚫ Pasif Öğrenci | 5+ gündür giriş yok |
| 📉 Düşüş Trendi | Son 3 haftada sürekli düşüş |
| ⏰ Görev Uyarısı | Bitiş tarihine 2 gün kala tamamlanmamış |

#### 4.4.3 Raporlama
```
Rapor Türleri:
├── Sınıf Genel Raporu
│   ├── Aktif öğrenci oranı
│   ├── Ortalama başarı
│   ├── Seviye dağılımı
│   ├── Zayıf alanlar
│   └── Riskli öğrenci listesi
│
├── Öğrenci Detay Raporu
│   ├── Okuma geçmişi
│   ├── Zayıf alanlar
│   ├── Haftalık trend
│   └── Kelime istatistikleri
│
├── Görev Raporu
│   ├── Tamamlama oranı
│   ├── Ortalama başarı
│   └── Tamamlamayan öğrenciler
│
└── Dışa Aktarım
    ├── PDF
    └── Excel
```

---

### 4.5 Module 5: Department Head Dashboard

#### 4.5.1 Karşılaştırma Görünümleri
- Öğretmen bazlı performans karşılaştırma
- Sınıf bazlı performans karşılaştırma
- Dönemsel trend analizi

#### 4.5.2 Okul Geneli Metrikler
- Toplam aktif öğrenci sayısı
- Okul geneli CEFR seviye dağılımı
- Dönem hedefleri vs. gerçekleşen

---

### 4.6 Module 6: Admin Panel

#### 4.6.1 Okul Yönetimi
- Okul ekleme/düzenleme
- Okul kodu oluşturma
- Lisans yönetimi

#### 4.6.2 Kullanıcı Yönetimi
- Toplu kullanıcı import (Excel)
- Rol atama
- Şifre sıfırlama

#### 4.6.3 İçerik Yönetimi
```
İçerik Pipeline:
├── Kitap Ekleme
│   ├── Genel bilgiler (başlık, seviye, tür)
│   ├── Kapak görseli
│   └── Bölümler
│       ├── Metin
│       ├── Görseller
│       ├── Seslendirme
│       └── Aktiviteler
│
├── Kelime Listesi Ekleme
│   ├── Liste adı
│   ├── Seviye
│   └── Kelimeler (kelime, anlam, örnek cümle, ses)
│
└── Durum: Taslak → İnceleme → Yayında
```

---

## 5. Jobs to Be Done (JTBD)

### 5.1 Öğrenci JTBD

| Job | Functional | Emotional | Social |
|-----|------------|-----------|--------|
| İngilizce okuma pratiği yapmak istiyorum | Seviyeme uygun kitap bul, oku, anla | Sıkılmadan, eğlenerek öğren | -- |
| Bilmediğim kelimeleri öğrenmek istiyorum | Tıkla → anlam gör, tekrar et | Kendimi akıllı hisset | -- |
| İngilizce'de geliştiğimi görmek istiyorum | XP kazan, seviye atla, rozet al | Başarı hissi | Arkadaşlarıma göster |
| Sınıfta iyi olmak istiyorum | Görevleri tamamla, yüksek puan al | Gurur | Sıralamada üstte ol |

### 5.2 Öğretmen JTBD

| Job | Functional | Emotional | Social |
|-----|------------|-----------|--------|
| Öğrencilerime okuma ödevi vermek istiyorum | Tek tıkla görev ata | Zaman kazandım | -- |
| Kim geride bilmek istiyorum | Otomatik uyarılar al | Kontrolde hisset | -- |
| Sınıfımın durumunu raporlamak istiyorum | Rapor oluştur, indir | Profesyonel görün | Yöneticilere sun |
| Zayıf alanları tespit etmek istiyorum | Detaylı analiz gör | Etkili müdahale yap | -- |

### 5.3 Bölüm Başkanı JTBD

| Job | Functional | Emotional | Social |
|-----|------------|-----------|--------|
| Bölümün performansını görmek istiyorum | Karşılaştırmalı dashboard | Kontrol | Müdüre raporla |
| Hangi sınıf/öğretmen zayıf bilmek istiyorum | Otomatik sıralama | Proaktif ol | Müdahale et |

---

## 6. User Stories

### 6.1 Öğrenci User Stories

```
ÖNCELİK: YÜKSEK (P0)
─────────────────────
US-S01: Öğrenci olarak, seviyeme uygun kitapları filtreleyebilmek istiyorum ki 
        bana uygun içeriği kolayca bulabileyim.

US-S02: Öğrenci olarak, okurken bilmediğim kelimelere tıklayıp anlamını 
        görebilmek istiyorum ki okumayı bırakmak zorunda kalmayayım.

US-S03: Öğrenci olarak, bölüm sonunda sorular çözebilmek istiyorum ki 
        ne kadar anladığımı test edebileyim.

US-S04: Öğrenci olarak, XP kazanıp seviye atlayabilmek istiyorum ki 
        motive olayım.

US-S05: Öğrenci olarak, öğretmenin bana atadığı görevleri görebilmek istiyorum ki 
        ne yapmam gerektiğini bileyim.

ÖNCELİK: ORTA (P1)
─────────────────────
US-S06: Öğrenci olarak, sınıf sıralamasını görebilmek istiyorum ki 
        nerede olduğumu bileyim.

US-S07: Öğrenci olarak, kelime egzersizleri yapabilmek istiyorum ki 
        öğrendiğim kelimeleri pekiştirebileyim.

US-S08: Öğrenci olarak, kitabı sesli dinleyebilmek istiyorum ki 
        telaffuzu da öğrenebileyim.

US-S09: Öğrenci olarak, rozetler kazanabilmek istiyorum ki 
        başarılarımı toplayabileyim.

ÖNCELİK: DÜŞÜK (P2)
─────────────────────
US-S10: Öğrenci olarak, gece modunda okuyabilmek istiyorum ki 
        gözlerim yorulmasın.

US-S11: Öğrenci olarak, kaldığım yerden devam edebilmek istiyorum ki 
        zaman kaybetmeyeyim.
```

### 6.2 Öğretmen User Stories

```
ÖNCELİK: YÜKSEK (P0)
─────────────────────
US-T01: Öğretmen olarak, sınıfıma toplu görev atayabilmek istiyorum ki 
        tek tek uğraşmayayım.

US-T02: Öğretmen olarak, hangi öğrencilerin görevi tamamladığını görebilmek 
        istiyorum ki takip edebileyim.

US-T03: Öğretmen olarak, riskli öğrenciler için otomatik uyarı almak istiyorum ki 
        erken müdahale edebileyim.

US-T04: Öğretmen olarak, sınıfımın genel başarı raporunu görebilmek istiyorum ki 
        durumu değerlendirebeyim.

ÖNCELİK: ORTA (P1)
─────────────────────
US-T05: Öğretmen olarak, bir öğrencinin detaylı geçmişini görebilmek istiyorum ki 
        bireysel geri bildirim verebleyim.

US-T06: Öğretmen olarak, sınıfın zayıf alanlarını görebilmek istiyorum ki 
        dersimi ona göre planlayabileyim.

US-T07: Öğretmen olarak, raporu PDF olarak indirebilmek istiyorum ki 
        yönetime sunabileyim.

US-T08: Öğretmen olarak, görev için hatırlatma ayarlayabilmek istiyorum ki 
        öğrenciler unutmasın.
```

---

## 7. Technical Requirements

### 7.1 Platform

| Platform | Öncelik | Notlar |
|----------|---------|--------|
| Web (Desktop) | P0 | Ana platform, tüm özellikler |
| Web (Tablet) | P0 | Responsive, dokunmatik optimize |
| iOS App | P1 | Native veya PWA |
| Android App | P1 | Native veya PWA |
| Offline Mode | P2 | Kitap indirme, sonra senkronizasyon |

### 7.2 Performans Gereksinimleri

| Metrik | Hedef |
|--------|-------|
| Sayfa yüklenme süresi | < 2 saniye |
| API yanıt süresi | < 500ms |
| Eşzamanlı kullanıcı | 10,000+ |
| Uptime | %99.5 |

### 7.3 Güvenlik

- Okul bazlı veri izolasyonu
- KVKK uyumluluğu (çocuk verileri)
- Şifreli veri iletimi (HTTPS)
- Güçlü şifre politikası

### 7.4 Entegrasyonlar (Gelecek)

- Google Classroom
- Microsoft Teams
- E-okul (MEB)
- SSO (LDAP/SAML)

---

## 8. Success Metrics (KPIs)

### 8.1 Engagement Metrics

| Metrik | Hedef |
|--------|-------|
| DAU / MAU | > %40 |
| Haftalık aktif öğrenci oranı | > %70 |
| Ortalama oturum süresi | > 15 dakika |
| Kitap tamamlama oranı | > %60 |
| 7-gün retention | > %50 |

### 8.2 Learning Metrics

| Metrik | Hedef |
|--------|-------|
| Ortalama aktivite başarısı | > %70 |
| Dönemlik seviye atlama oranı | > %30 |
| Öğrenilen kelime (öğrenci/ay) | > 50 |

### 8.3 Teacher Metrics

| Metrik | Hedef |
|--------|-------|
| Öğretmen platformu kullanım oranı | > %80 |
| Aylık atanan görev sayısı | > 4 / öğretmen |
| Rapor indirme sıklığı | > 2 / ay |

---

## 9. MVP Scope (Faz 1)

### 9.1 MVP'de Olacaklar ✅

```
Öğrenci:
├── Giriş / şifre belirleme
├── Ana sayfa (dashboard)
├── Kütüphane (filtreleme, kitap listesi)
├── Okuma ekranı (metin + görsel)
├── Anlık sözlük (tıkla → anlam)
├── Bölüm sonu aktiviteleri (3 tip: çoktan seçmeli, D/Y, eşleştirme)
├── XP ve seviye sistemi
├── Basit profil sayfası
└── Sınıf içi sıralama

Öğretmen:
├── Giriş
├── Dashboard (özet + uyarılar)
├── Sınıf listesi
├── Öğrenci listesi (temel metrikler)
├── Görev atama (kitap okuma)
├── Temel sınıf raporu
└── Görev takibi

Admin:
├── Okul ekleme
├── Kullanıcı ekleme (tek tek + Excel)
├── Kitap ekleme (temel)
└── Bölüm ekleme
```

### 9.2 MVP'de Olmayacaklar ❌ (Sonraki Fazlar)

```
Faz 2:
├── Kelime egzersizi modülü
├── Sesli okuma / karaoke modu
├── Rozet sistemi
├── Bölüm başkanı dashboard
├── Detaylı raporlama
└── PDF/Excel export

Faz 3:
├── Mobil uygulama
├── Offline mod
├── Veli portalı
├── AI tabanlı öneri sistemi
├── Telaffuz değerlendirme
└── Okul arası sıralama

Faz 4:
├── Google Classroom entegrasyonu
├── Özel içerik oluşturma (öğretmen)
├── Çoklu dil desteği
└── Adaptif öğrenme patikası
```

---

## 10. Risks & Mitigations

| Risk | Olasılık | Etki | Azaltma Stratejisi |
|------|----------|------|---------------------|
| Öğretmenler kullanmaz | Orta | Yüksek | Öğretmen eğitimi, basit UI, hızlı değer gösterimi |
| Öğrenciler sıkılır | Orta | Yüksek | Gamification, çeşitli içerik, kısa aktiviteler |
| İçerik üretimi yavaş kalır | Yüksek | Orta | İçerik pipeline'ı, açık kaynak klasikler, şablon sistemi |
| Teknik sorunlar (sunucu) | Düşük | Yüksek | Cloud altyapı, auto-scaling, monitoring |
| KVKK/güvenlik ihlali | Düşük | Çok Yüksek | Security audit, veri şifreleme, erişim kontrolü |

---

## 11. Appendix

### A. Seviyelendirme Formülü (CEFR Mapping)

| Seviye | Kelime Sayısı | Cümle Uzunluğu | Gramer Yapıları |
|--------|---------------|----------------|-----------------|
| A1 | < 500 | < 8 kelime | Present simple, basic nouns |
| A2 | 500-1000 | 8-12 kelime | Past simple, comparatives |
| B1 | 1000-2000 | 12-18 kelime | Present perfect, conditionals |
| B2 | 2000-4000 | 18-25 kelime | Passive voice, reported speech |
| C1 | 4000-8000 | 25+ kelime | Complex structures |
| C2 | 8000+ | Unlimited | Native-level complexity |

### B. Rozet Listesi (Tam)

| Rozet | İkon | Koşul |
|-------|------|-------|
| First Steps | 📖 | İlk kitabı başlat |
| Bookworm | 📚 | 5 kitap tamamla |
| Library Master | 🏛️ | 20 kitap tamamla |
| Streak Starter | 🔥 | 3 gün üst üste |
| Week Warrior | 💪 | 7 gün üst üste |
| Month Champion | 🏆 | 30 gün üst üste |
| Word Learner | 💬 | 50 kelime öğren |
| Vocabulary Pro | 🎓 | 200 kelime öğren |
| Word Master | 🧠 | 500 kelime öğren |
| Perfect Score | 💯 | Bir aktivitede %100 |
| Perfectionist | ⭐ | 10 aktivitede %100 |
| Speed Reader | ⚡ | 1 kitabı 1 günde bitir |
| A1 Graduate | 🥉 | A1 seviyesini tamamla |
| A2 Graduate | 🥈 | A2 seviyesini tamamla |
| B1 Graduate | 🥇 | B1 seviyesini tamamla |

---

## Document History

| Versiyon | Tarih | Değişiklik | Yazar |
|----------|-------|------------|-------|
| 1.0 | Ocak 2025 | İlk taslak | - |
