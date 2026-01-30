# Update Docs and Commit

Kod değişikliklerini analiz edip ilgili dökümanları güncelle ve commit oluştur.

## Input
$ARGUMENTS - Opsiyonel commit mesajı veya değişiklik açıklaması

## Instructions

### 1. Değişiklikleri Analiz Et

```bash
git status
git diff --staged
git diff
```

Değişiklikleri kategorize et:
- **Feature**: Yeni özellik eklendi
- **Fix**: Bug düzeltildi
- **Refactor**: Kod yapısı değişti
- **Docs**: Döküman güncellendi
- **Chore**: Bakım işleri (deps, config)

### 2. changelog.md Güncelle

`docs/changelog.md` dosyasında `[Unreleased]` bölümüne ekle:

- Yeni feature'lar → `### Added`
- Değişiklikler → `### Changed`
- Bug fix'ler → `### Fixed`
- Kaldırılanlar → `### Removed`

Format:
```markdown
### Added
- Kısa açıklama (hangi dosya/modül etkilendi)
```

### 3. architecture.md Güncelle (Sadece Gerekirse)

`docs/architecture.md` dosyasını SADECE şu durumlarda güncelle:
- Yeni modül/klasör eklendi
- Veri akışı değişti
- Yeni servis entegre edildi
- Veritabanı şeması değişti

Küçük kod değişikliklerinde DOKUNMA.

### 4. project_status.md Güncelle

`docs/project_status.md` dosyasında:

- Tamamlanan task'ları `Recently Completed` tablosuna taşı
- `In Progress` tablosunu güncelle
- Roadmap'te checkbox'ları işaretle (`- [x]`)
- Varsa yeni blocker'ları ekle
- `Son güncelleme` tarihini güncelle

### 5. Stage ve Commit

```bash
git add docs/
git add <değişen-dosyalar>
git commit -m "<commit-message>"
```

Commit mesajı formatı:
- Kullanıcı mesaj verdiyse: onu kullan
- Vermediyse: değişiklik türüne göre otomatik oluştur
  - `feat: <açıklama>` - yeni özellik
  - `fix: <açıklama>` - bug fix
  - `docs: <açıklama>` - döküman
  - `refactor: <açıklama>` - refactoring
  - `chore: <açıklama>` - bakım

### 6. Özet Göster

```markdown
## Changes Summary

### Güncellenen Dosyalar
- `docs/changelog.md` - X yeni entry
- `docs/project_status.md` - Y task güncellendi
- `docs/architecture.md` - (güncellendi/değişmedi)

### Commit
- Hash: <short-hash>
- Message: <commit-message>
```

## Önemli Kurallar

1. **Konservatif ol**: Sadece gerçekten değişmesi gereken dökümanları güncelle
2. **Tutarlılık**: Mevcut format ve stile uy
3. **Kısa tut**: Changelog entry'leri 1-2 cümle
4. **Tarih ekle**: project_status.md'de her değişiklikte tarih güncelle
