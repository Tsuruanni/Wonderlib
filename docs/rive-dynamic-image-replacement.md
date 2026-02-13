# Rive Dynamic Image Replacement (Flutter)

Rive animasyonlarındaki embedded image asset'lerini runtime'da network görselleriyle değiştirme rehberi.

> **Status:** Araştırma tamamlandı, API doğrulandı. Henüz uygulanmadı.
> **Rive version:** `rive: ^0.13.17` (test edilen: 0.13.20)

---

## Neden?

Pack opening sırasında açılan 3 kartın görselleri, `cards.riv` dosyasındaki placeholder resimler (C_K.png, C_Q.png, C_J.png) yerine gerçek kart artwork'leriyle değiştirilecek.

## cards.riv Dosya Yapısı

```
Artboard: "New Artboard" (500x500)
├── Root (group)
│   ├── hit (shape — tıklama alanı)
│   ├── king (group)  → C_K.png + DeckBack.png
│   ├── queen (group) → C_Q.png + DeckBack.png
│   └── jack (group)  → C_J.png + DeckBack.png

Embedded Images (4):
  DeckBack.png  — kart arkası (değişmeyecek)
  C_K.png       — 1. kart placeholder
  C_Q.png       — 2. kart placeholder
  C_J.png       — 3. kart placeholder

State Machine: "State Machine 1"
  Inputs:
    - next     (trigger) — sonraki kart geçişi
    - flipped  (bool)    — kartı çevir
    - holding  (bool)    — basılı tutma

Animations (9):
  charge, flipBack, flipCard, flipIdle,
  jack2King, queen2Jack, king2Queen,
  waitingLong, waiting
```

---

## API Doğrulaması

Rive 0.13.20 kaynak kodundan doğrulandı:

### Kritik Dosyalar (pub cache)

| Dosya | Açıklama |
|-------|----------|
| `rive/src/asset_loader.dart` | `FileAssetLoader`, `CallbackAssetLoader`, `LocalAssetLoader` |
| `rive/src/rive_core/assets/image_asset.dart` | `ImageAsset.decode(Uint8List bytes)` |
| `rive/src/core/importers/file_asset_importer.dart` | Asset loading akışı |

### Asset Loading Akışı

```
RiveFile.asset('cards.riv', assetLoader: CallbackAssetLoader(...))
  │
  ▼ (her asset için)
FileAssetImporter.resolve()
  │
  ├── assetLoader.load(fileAsset, embeddedBytes) çağrılır
  │   │
  │   ├── callback true dönerse  → Custom image kullanılır ✓
  │   │
  │   └── callback false dönerse
  │       ├── embeddedBytes != null → Embedded PNG decode edilir (fallback) ✓
  │       └── embeddedBytes == null → Hata loglanır ✗
  │
  └── resolve() return
```

### ImageAsset.decode()

```dart
// rive/src/rive_core/assets/image_asset.dart
class ImageAsset extends ImageAssetBase {
  ui.Image? _image;

  @override
  Future<void> decode(Uint8List bytes) async {
    image = await parseBytes(bytes);
  }

  static Future<ui.Image?> parseBytes(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }
}
```

PNG, JPEG, WebP formatları destekleniyor (`ui.instantiateImageCodec` tarafından).

---

## Entegrasyon Kodu

### 1. Image Mapping

```dart
/// Rive asset adı → pack kart index'i
const imageSlots = {
  'C_K.png': 0,  // 1. kart
  'C_Q.png': 1,  // 2. kart
  'C_J.png': 2,  // 3. kart
};
```

### 2. Network Image Download (Dio)

```dart
Future<Map<String, Uint8List>> downloadCardImages(List<PackCard> cards) async {
  final results = <String, Uint8List>{};
  final dio = Dio();

  try {
    await Future.wait(
      imageSlots.entries.map((slot) async {
        final index = slot.value;
        if (index >= cards.length) return;

        final imageUrl = cards[index].card.imageUrl;
        if (imageUrl == null || imageUrl.isEmpty) return;

        try {
          final response = await dio.get<List<int>>(
            imageUrl,
            options: Options(responseType: ResponseType.bytes),
          );
          if (response.data != null) {
            results[slot.key] = Uint8List.fromList(response.data!);
          }
        } catch (_) {
          // Fallback: Rive embedded placeholder kullanılır
          debugPrint('Failed to download ${slot.key}');
        }
      }),
    );
  } finally {
    dio.close();
  }

  return results;
}
```

### 3. Rive File Loading (CallbackAssetLoader)

```dart
final riveFile = await RiveFile.asset(
  'assets/animations/cards.riv',
  assetLoader: CallbackAssetLoader(
    (asset, embeddedBytes) async {
      if (asset is ImageAsset && imageMap.containsKey(asset.name)) {
        await asset.decode(imageMap[asset.name]!);
        return true;  // Custom image yüklendi
      }
      return false;   // DeckBack.png → embedded kalır
    },
  ),
);
```

> **Not:** Callback parametresinde `FileAsset` tipini açıkça yazmayın.
> `FileAsset` rive.dart'tan doğrudan export edilmiyor. Dart type inference
> `CallbackAssetLoader`'ın beklediği callback signature'ından tipi otomatik çıkarır.

### 4. State Machine Setup

```dart
final artboard = riveFile.mainArtboard.instance();
final controller = StateMachineController.fromArtboard(
  artboard,
  'State Machine 1',
);
if (controller != null) {
  artboard.addController(controller);
}

// Input'lara erişim
final nextTrigger = controller?.getTriggerInput('next');
final flippedBool = controller?.getBoolInput('flipped');
final holdingBool = controller?.getBoolInput('holding');

// Kullanım
nextTrigger?.fire();           // Sonraki kart
flippedBool?.value = true;     // Kartı çevir
```

### 5. Widget'da Kullanım

```dart
Rive(
  artboard: artboard,
  fit: BoxFit.contain,
  enablePointerEvents: true,  // Rive listener'ları aktif
)
```

---

## Fallback Stratejisi

| Durum | Davranış |
|-------|----------|
| Network image indirilemedi | `CallbackAssetLoader` `false` döner → embedded placeholder |
| imageUrl null/boş | Download atlanır → embedded placeholder |
| Rive file yüklenemedi | try/catch ile hata yakalanır → loading/error state |

---

## Dikkat Edilecekler

1. **Asenkron loading**: `FileAssetImporter.resolve()` içinde `assetLoader.load()` bir `.then()` ile çağrılıyor, yani image decode async olarak gerçekleşir. **Image'ları önceden indirip callback'te hazır byte'ları vermek** en güvenli yaklaşımdır.

2. **Glow phase pre-loading**: Pack glow animasyonu ~1.5 saniye sürüyor. Bu sürede image'lar indirilebilir, Rive yüklemesinden önce hazır olur.

3. **State machine keşfi**: `next`, `flipped`, `holding` input'larının tam animasyon akışı test edilerek belirlenmeli. Animasyon adları ipucu veriyor:
   - `jack2King`, `queen2Jack`, `king2Queen` → kart geçiş animasyonları
   - `flipCard` / `flipBack` → çevirme
   - `waiting` / `waitingLong` → bekleme
   - `charge` → başlangıç/hazırlanma

4. **Tap alanı**: Tek artboard'da 3 kart var. Hangi karta tıklandığını belirlemek için:
   - Sıralı reveal (her tap sonraki kartı açar) — en basit
   - Rive'ın kendi hit test'i (`enablePointerEvents: true`) — Rive listener varsa
   - Pozisyon hesaplama (kart pozisyonlarına göre) — en hassas

5. **Memory**: Her pack açılışında yeni `RiveFile` + 3 network image yükleniyor. `dispose()`'da `StateMachineController.dispose()` çağrılmalı.

---

## İlgili Dosyalar

| Dosya | Açıklama |
|-------|----------|
| `assets/animations/cards.riv` | Rive animasyon dosyası |
| `lib/domain/entities/card.dart` | `PackResult`, `PackCard`, `MythCard.imageUrl` |
| `lib/presentation/screens/cards/pack_opening_screen.dart` | Entegrasyon noktası (`_buildRevealPhase`) |
| `lib/presentation/widgets/cards/card_flip_widget.dart` | Mevcut Flutter flip widget (korunacak, fallback) |
| `lib/presentation/widgets/common/vocabulary_mascot_overlay.dart` | Rive kullanım pattern referansı |
