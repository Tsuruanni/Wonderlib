# Kelime Seti Öğrenme Seansı — Final Tasarım v2

**Set büyüklüğü:** 5-10 kelime
**Seans süresi:** ~3-4 dakika
**Toplam soru sayısı:** 16-20 soru (8 kelimelik set için)

---

## Genel Felsefe

- Bölüm/level yok. Tek bir akışta farklı soru tipleri art arda gelir.
- Kelimeler önce kısaca tanıtılır, sonra test içinde öğrenilir.
- Zorluk sıralaması korunur: bir kelime tanıma aşamasını geçmeden üretme sorusuna geçmez.
- Yanlış bilinen kelimeler hemen telafi edilir ve birkaç soru sonra tekrar döner.
- Akış kullanıcı performansına göre dinamik olarak adapte olur.

---

## Soru Tipi Zorluk Sıralaması

```
Tanıma             →  Köprü              →  Üretme
Çoktan Seçmeli        Eşleştirme            Scrambled Letters → Spelling → Cümle Boşluk
Dinleme (seç)                                Dinleme (yaz)
```

Her kelime bu sıralamaya uygun ilerler. Kullanıcı bir kelimeyi çoktan seçmelide doğru bilmediyse, o kelimenin spelling sorusu henüz gelmez.

**Adaptive zorluk:** Kullanıcı çok iyi gidiyorsa (ilk 4-5 soruyu hatasız geçerse) tanıma soruları atlanıp direkt köprü/üretme sorularına geçilir. Kötü gidiyorsa daha fazla tanıma sorusu verilir, üretme soruları ertelenir.

---

## Akış

### Faz 1 — Keşfet (~1 dakika)

Kelimeler **ikişerli gruplar** halinde tanıtılır.

Her kelime kartında:
- İngilizce kelime
- Türkçe anlam
- Küçük görsel
- Kısa örnek cümle (kelimenin bağlamını ve kullanımını netleştirir)
- Hoparlör ikonu (telaffuz)

Örnek kart:
```
┌─────────────────────────┐
│  🔊  bark               │
│  havlamak                │
│  🐕 [görsel]             │
│                          │
│  "The dog barks at       │
│   strangers."            │
└─────────────────────────┘
```

Kullanıcı kartları inceler, sağa kaydırarak ilerler.

Her 2 kelimeden sonra **hemen 1 kolay soru** gelir:
- Sadece o an tanıtılan 2 kelime arasından sorulur
- Hafif varyasyon: ilk gruplarda görsel seçme, son gruplarda ses seçme
- Hata yapılırsa doğru cevap gösterilir, ceza yok

```
🃏 Kelime 1-2 tanıtım
❓ Kolay soru (bu 2 kelime arasından)
🃏 Kelime 3-4 tanıtım
❓ Kolay soru (bu 2 kelime arasından)
🃏 Kelime 5-6 tanıtım
❓ Kolay soru
🃏 Kelime 7-8 tanıtım
❓ Kolay soru
```

---

### Faz 2 — Pekiştir (~2 dakika)

Tüm kelimeler tanıtılmış durumda. Sorular havuzdan çekiliyor, zorluk sıralamasına uygun.

**Tanıma soruları (kolay)**
- Çoktan seçmeli: İngilizce → 4 Türkçe şık
- Çoktan seçmeli ters: Türkçe → 4 İngilizce şık
- Eşleştirme: 4 kelimeyi 4 anlamla eşle (süre bazlı yıldız: ne kadar hızlı → o kadar yüksek puan)
- Dinleme seçmeli: Ses çalınır, doğru kelimeyi seç

**Köprü soruları (orta)**
- Scrambled Letters: Kelimenin harfleri karışık butonlar halinde verilir, kullanıcı doğru sırayla basar

**Üretme soruları (zor)**
- Spelling: Türkçe anlam verilir, İngilizce kelimeyi yaz
- Dinleme yazma: Kelime sesli okunur, kullanıcı yazar
- Cümle boşluk: "I bought a red ___ from the market" → yaz veya seç

**İlerleyen sorularda görsel desteği kaldırılır.** Önce görsel + kelime birlikte, sonra sadece kelime.

---

### Faz 3 — Final (~30 saniye)

Son 2-3 soru, seans boyunca **en çok hata yapılan kelimelerden** gelir.

Ardından **özet ekranı** (detaylar aşağıda).

---

## Hata Yönetimi — Hızlı Telafi Sistemi

1. Yanlış cevap verilir
2. Doğru cevap ekranda gösterilir + kelime sesli okunur
3. Kullanıcı "Anladım" basarak devam eder
4. **Hemen 1-2 soru sonra** aynı kelime en kolay haliyle tekrar sorulur (2 şıklı görsel seçme gibi)
5. Kelime doğru bilinene kadar havuzda kalmaya devam eder
6. Yanlışta combo sıfırlanır ama başka ceza yok

---

## Oyunlaştırma Sistemi

### Streak / Combo
- Art arda doğru cevaplarda combo sayacı: ×2, ×3, ×4...
- Combo sırasında ilerleme çubuğu daha hızlı dolar
- Hafif görsel efekt (küçük parıltı, abartısız)
- Yanlış cevapta combo sıfırlanır, başka ceza yok

### XP / Puan
Her soru tipine farklı puan:

| Soru Tipi | Baz XP |
|-----------|--------|
| Çoktan seçmeli | 10 XP |
| Eşleştirme | 15 XP |
| Scrambled Letters | 20 XP |
| Spelling | 25 XP |
| Dinleme (yazma) | 25 XP |
| Cümle boşluk | 30 XP |

Combo çarpanı XP'ye uygulanır: ×2 combo = çift XP.

### "İlk Seferde Doğru" Bonusu
Bir kelimeyi seans boyunca hiç hata yapmadan tüm aşamalardan geçirmek seans sonunda küçük bir yıldız kazandırır. Bu seans içinde gösterilmez (baskı yaratmamak için), sadece özet ekranında sessizce sunulur.

---

## Seans Sonu Özet Ekranı

- Toplam XP
- Doğruluk yüzdesi
- En uzun combo serisi
- Her kelimenin durumu (yeşil = güçlü, sarı = orta, kırmızı = tekrar gerekli)
- İlk seferde doğru bilinen kelimeler varsa yıldızla işaretlenir
- Seans süresi
- "Tekrar Çalış" butonu (sadece kırmızı/sarı kelimeleri tekrar seansa alır)

**Sürpriz element (rastgele):** Bazı seanslarda kişiselleştirilmiş bir istatistik gösterilir: "Bu hafta en çok zorlandığın kelime: 'necessary' — ama bugün ilk seferde bildin 🔥". Her seansta değil, beklenmedik zamanlarda gelir.

---

## Seans Boyunca Sabit Mekanikler

**İlerleme çubuğu** — En üstte, tek çubuk. Her doğru cevapta ilerler. Combo sırasında hızlanır.

**Anlık geri bildirim** — Doğruysa yeşil animasyon + pozitif mikro mesaj. Yanlışsa doğru cevap gösterilir.

**Audio-Visual Sync** — Her doğru cevapta kelime otomatik seslenir. Görme + doğrulama + duyma döngüsü tamamlanır.

**Hoparlör ikonu** — Her soruda erişilebilir. Kullanıcı istediği an telaffuzu dinleyebilir.

**Haptic feedback (mobil)** — Doğru cevapta hafif kısa titreşim, yanlış cevapta farklı pattern'de titreşim.

**Çeldirici mantığı** — Çoktan seçmeli sorularda yanlış şıklar aynı setteki diğer kelimelerden seçilir.

---

## Soru Dağılımı (8 kelimelik set için)

| Faz | Soru Sayısı | Soru Tipleri |
|-----|-------------|--------------|
| Faz 1 — Keşfet | 4 | Kolay çoktan seçmeli / ses seçme |
| Faz 2 — Pekiştir | 10-12 | Karışık (tanıma → köprü → üretme, adaptive) |
| Faz 3 — Final | 2-3 | Hatalı kelimelerden tekrar |
| **Toplam** | **16-19** | |

Tip bazında dağılım (adaptive olmadığı varsayılırsa):
- %25 çoktan seçmeli
- %15 eşleştirme
- %15 scrambled letters
- %20 spelling
- %10 dinleme
- %10 cümle boşluk
- %5 hızlı telafi soruları

---

## Opsiyonel: Challenge Mode

Faz 3'e opsiyonel süre sınırı (soru başına 5-7 saniye). Varsayılan olarak kapalı. Kullanıcı isterse açar.

---

## Spaced Repetition — Seans Sonrası Tekrar Mantığı

Seans içi tekrarlar (hızlı telafi) anlık pekiştirme içindir. Uzun vadeli hatırlama için seans sonrası spaced repetition sistemi çalışır:

**Seans sonunda her kelime iki kategoriden birine düşer:**

| Durum | Kriter | Sonraki Tekrar |
|-------|--------|----------------|
| ✅ Güçlü (yeşil) | Seans boyunca hiç hata yapılmadı veya hatalar telafi edildi | İlk tekrar **yarın** |
| ❌ Zayıf (kırmızı/sarı) | Seans sonunda hâlâ hatalı veya çok zorlanıldı | **Bugünün tekrar kuyruğuna** eklenir |

**Bugünün tekrar kuyruğu:** Zayıf kelimeler ayrı bir mini seans olarak aynı gün içinde tekrar sunulur. Bu mini seans daha kısadır (sadece zayıf kelimeler, 5-8 soru). Kullanıcıya bildirim veya ana ekranda "Tekrar bekleyen kelimeler var" şeklinde hatırlatılır.

**Sonraki günlerdeki tekrar aralıkları (güçlü kelimeler için):**
zaten olan sisteme göre yapılır.

Her tekrarda kelime doğru bilinirse bir sonraki aralığa geçer. Yanlış bilinirse aralık sıfırlanır ve kelime tekrar bugünün kuyruğuna düşer.

---

## Set Oluşturma Kuralları (İçerik Notu)

- Anlam olarak çok yakın kelimeler (big/large, fast/quick) aynı sete konulmamalı. Konulacaksa fark ettirici bağlam cümleleri ve bilinçli çeldirici eşleştirmesi yapılmalı.
- Her kelimenin en az 1 kısa örnek cümlesi olmalı.
- Görseller net ve ayırt edici olmalı, soyut kelimelerde (örn. "freedom") görsel yerine güçlü bir örnek cümle öne çıkarılmalı.
- Aynı setteki kelimelerin yazımları birbirine çok benzememeli (başlangıç seviyesi için).
