# Reading Module

Dijital kütüphane ve okuma deneyimi modülü.

## Amaç

Öğrencilerin seviyelerine uygun İngilizce kitapları interaktif şekilde okumasını sağlamak.

## Hedef Kullanıcı

- **Primary**: Öğrenciler (K-12)
- **Secondary**: Öğretmenler (görev atama için)

## Kullanıcı Akışı

```
1. Kütüphane Ekranı
   └── Kitap listesi (filtrelenebilir: seviye, tür, durum)
       └── Kitap kartı tıkla
           └── Kitap Detay
               └── "Okumaya Başla" tıkla
                   └── Okuma Ekranı
                       └── Sayfa oku
                           └── Kelimeye tıkla → Sözlük popup
                           └── Sonraki sayfa
                               └── Bölüm sonu → Aktiviteler
                                   └── Aktiviteleri tamamla
                                       └── XP kazan, sonraki bölüm
```

## Temel Özellikler

### Kütüphane
- CEFR seviyesine göre filtreleme (A1-C2)
- Türe göre filtreleme (macera, bilim kurgu, vb.)
- Duruma göre filtreleme (atanan, başladım, bitirdim)
- İlerleme göstergesi (% okundu)

### Okuma Ekranı
- Sayfa görüntüleme (metin + görsel)
- Anlık sözlük (kelimeye tıkla → anlam + telaffuz)
- Seslendirme (her bölüm için audio)
- Ayarlar: font boyutu, gece modu, ses hızı

### Bölüm Sonu Aktiviteleri
- Çoktan seçmeli sorular
- Doğru/Yanlış
- Eşleştirme
- Sıralama
- Boşluk doldurma

## İlgili API Endpoints

```
GET  /books                    # Kitap listesi
GET  /books/:id                # Kitap detayı
GET  /books/:id/chapters       # Bölümler
GET  /chapters/:id             # Bölüm içeriği
GET  /chapters/:id/activities  # Aktiviteler
POST /reading-progress         # İlerleme kaydet
POST /activity-results         # Aktivite sonucu kaydet
```

## İlgili Tablolar

- `books` - Kitap metadata
- `chapters` - Bölüm içerikleri
- `activities` - Aktivite soruları
- `reading_progress` - Okuma ilerlemesi
- `activity_results` - Aktivite sonuçları
- `vocabulary_words` - Sözlük kelimeleri

## Env Değişkenleri

Özel env yok, standart Supabase bağlantısı kullanılır.

## Edge Cases

1. **Offline okuma**: Kitap önceden indirilmişse, internet olmadan okunabilir
2. **Yarım kalan kitap**: Kaldığı yerden devam eder
3. **Tekrar okuma**: Bitmiş kitap tekrar okunabilir, XP yarı verilir
4. **Aktivite tekrarı**: Başarısız aktivite tekrarlanabilir

## Bilinen Limitler

- MVP'de sesli okuma (karaoke modu) yok
- MVP'de offline indirme yok
- Aktivite tipleri: ilk 3 tip (çoktan seçmeli, D/Y, eşleştirme)

## İlgili Dosyalar

```
lib/
├── domain/
│   ├── entities/book.dart
│   ├── entities/chapter.dart
│   └── usecases/library/
├── data/
│   ├── models/book_model.dart
│   ├── datasources/remote/book_remote_ds.dart
│   └── repositories/book_repository_impl.dart
└── presentation/
    ├── screens/library/
    ├── screens/reader/
    └── widgets/book/
```
