# Word List Image Generation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate AI images for all words in a word list with a single batched API call per 6 words, using fal.ai nano-banana-pro (Gemini) to create a 2x3 grid image, then crop into 6 individual images using magick-wasm.

**Architecture:** A Supabase Edge Function (`generate-wordlist-images`) receives a word list ID + prompt/style config, fetches words, batches them in groups of 6, generates a 2x3 grid image per batch via fal.ai, crops it into tiles with `@imagemagick/magick-wasm`, uploads each tile to Supabase Storage, and updates `vocabulary_words.image_url`. The admin panel adds a "Görselleri Üret" button with an editable prompt field and preset style selector.

**Tech Stack:** Deno (Supabase Edge Function), fal.ai nano-banana-pro API, @imagemagick/magick-wasm, Supabase Storage, Flutter/Riverpod (admin panel)

---

## File Structure

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `supabase/functions/generate-wordlist-images/index.ts` | Edge Function: orchestrate batch image generation, cropping, upload |
| Modify | `owlio_admin/lib/features/wordlists/screens/wordlist_edit_screen.dart` | Add "Görselleri Üret" button + prompt/style dialog |

---

### Task 1: Edge Function — Core Structure & Word Fetching

**Files:**
- Create: `supabase/functions/generate-wordlist-images/index.ts`

- [ ] **Step 1: Create the Edge Function with CORS, input parsing, and word fetching**

```typescript
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  ImageMagick,
  initializeImageMagick,
  MagickFormat,
  MagickGeometry,
} from "npm:@imagemagick/magick-wasm@0.0.38";

// Initialize ImageMagick WASM
const wasmBytes = await Deno.readFile(
  new URL(
    "magick.wasm",
    import.meta.resolve("npm:@imagemagick/magick-wasm@0.0.38"),
  ),
);
await initializeImageMagick(wasmBytes);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const STORAGE_BUCKET = "word-images";
const GRID_COLS = 2;
const GRID_ROWS = 3;
const BATCH_SIZE = GRID_COLS * GRID_ROWS; // 6

interface WordItem {
  word_id: string;
  word: string;
  meaning_tr: string;
}

interface ImageResult {
  wordId: string;
  word: string;
  imageUrl: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { wordListId, prompt, style } = await req.json();

    if (!wordListId) {
      return new Response(
        JSON.stringify({ error: "wordListId is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const FAL_KEY = Deno.env.get("FAL_KEY");
    if (!FAL_KEY) {
      return new Response(
        JSON.stringify({ error: "FAL_KEY not configured" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // 1. Fetch words for the list
    console.log(`Fetching words for list ${wordListId}...`);
    const { data: items, error: fetchError } = await supabase
      .from("word_list_items")
      .select("word_id, vocabulary_words(id, word, meaning_tr)")
      .eq("word_list_id", wordListId)
      .order("order_index", { ascending: true });

    if (fetchError) {
      throw new Error(`Failed to fetch words: ${fetchError.message}`);
    }
    if (!items || items.length === 0) {
      return new Response(
        JSON.stringify({ error: "No words found in this list" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const words: WordItem[] = items
      .map((item: any) => ({
        word_id: item.vocabulary_words?.id,
        word: item.vocabulary_words?.word,
        meaning_tr: item.vocabulary_words?.meaning_tr,
      }))
      .filter((w: WordItem) => w.word_id && w.word);

    console.log(`Found ${words.length} words`);

    // 2. Ensure storage bucket exists
    await supabase.storage
      .createBucket(STORAGE_BUCKET, {
        public: true,
        fileSizeLimit: 52428800,
      })
      .catch(() => {}); // Ignore if exists

    // 3. Split into batches of 6
    const batches: WordItem[][] = [];
    for (let i = 0; i < words.length; i += BATCH_SIZE) {
      batches.push(words.slice(i, i + BATCH_SIZE));
    }

    console.log(`Processing ${batches.length} batch(es)...`);

    // 4. Process each batch
    const allResults: ImageResult[] = [];

    for (let batchIdx = 0; batchIdx < batches.length; batchIdx++) {
      const batch = batches[batchIdx];
      console.log(
        `Batch ${batchIdx + 1}/${batches.length}: ${batch.length} words`,
      );

      const results = await processBatch(
        batch,
        batchIdx,
        wordListId,
        prompt || "",
        style || "flat",
        FAL_KEY,
        supabase,
      );
      allResults.push(...results);
    }

    console.log(`Done! ${allResults.length} images generated`);

    return new Response(
      JSON.stringify({
        success: true,
        imagesGenerated: allResults.length,
        results: allResults,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
```

- [ ] **Step 2: Verify the file compiles**

Run: `cd /Users/wonderelt/Desktop/Owlio && supabase functions serve generate-wordlist-images --no-verify-jwt`
Expected: Function starts serving (Ctrl+C to stop). No import errors.

---

### Task 2: Edge Function — Prompt Building, fal.ai Call, Grid Cropping & Upload

**Files:**
- Modify: `supabase/functions/generate-wordlist-images/index.ts`

- [ ] **Step 1: Add style presets and prompt builder**

Add the following **above** `Deno.serve(...)`:

```typescript
const STYLE_PRESETS: Record<string, string> = {
  flat: "simple flat vector illustration, minimal, clean lines, solid colors",
  cartoon:
    "cute cartoon style, colorful, playful, rounded shapes, child-friendly",
  watercolor: "soft watercolor painting, gentle pastel colors, artistic",
  realistic: "realistic illustration, detailed, natural colors",
  pixel: "pixel art, 8-bit retro style, crisp pixels",
};

function buildGridPrompt(
  words: WordItem[],
  customPrompt: string,
  style: string,
): string {
  const styleDesc = STYLE_PRESETS[style] || STYLE_PRESETS["flat"];

  // Build cell descriptions — always 6 cells
  const cellDescriptions: string[] = [];
  const positions = [
    "top-left",
    "top-right",
    "middle-left",
    "middle-right",
    "bottom-left",
    "bottom-right",
  ];

  for (let i = 0; i < BATCH_SIZE; i++) {
    if (i < words.length) {
      cellDescriptions.push(
        `Cell ${i + 1} (${positions[i]}): "${words[i].word}" (${words[i].meaning_tr})`,
      );
    } else {
      // Padding cell for incomplete batches
      cellDescriptions.push(
        `Cell ${i + 1} (${positions[i]}): empty white cell`,
      );
    }
  }

  const basePrompt =
    customPrompt ||
    `A 2x3 grid of 6 separate illustrations for a children's English learning app. ` +
      `Each cell contains exactly one object/concept illustration, clearly separated with visible borders. ` +
      `All cells are equal size. ${styleDesc}. White background for each cell. ` +
      `No text or labels inside the cells.`;

  return `${basePrompt}\n\n${cellDescriptions.join("\n")}`;
}
```

- [ ] **Step 2: Add the batch processing function (fal.ai call + crop + upload)**

Add the following **above** `Deno.serve(...)`:

```typescript
async function processBatch(
  batch: WordItem[],
  batchIdx: number,
  wordListId: string,
  customPrompt: string,
  style: string,
  falKey: string,
  supabase: any,
): Promise<ImageResult[]> {
  // 1. Build prompt
  const prompt = buildGridPrompt(batch, customPrompt, style);
  console.log(`Prompt for batch ${batchIdx}:\n${prompt}`);

  // 2. Call fal.ai nano-banana-pro
  console.log("Calling fal.ai nano-banana-pro...");
  const falResponse = await fetch(
    "https://fal.run/fal-ai/nano-banana-pro",
    {
      method: "POST",
      headers: {
        Authorization: `Key ${falKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        prompt,
        num_images: 1,
        aspect_ratio: "2:3",
        output_format: "png",
        safety_tolerance: "6",
      }),
    },
  );

  if (!falResponse.ok) {
    const errorText = await falResponse.text();
    throw new Error(
      `fal.ai API error: ${falResponse.status} - ${errorText}`,
    );
  }

  const falData = await falResponse.json();
  const gridImageUrl = falData.images?.[0]?.url;
  if (!gridImageUrl) {
    throw new Error("No image URL in fal.ai response");
  }

  console.log("Grid image URL:", gridImageUrl);

  // 3. Download grid image
  console.log("Downloading grid image...");
  const imageResponse = await fetch(gridImageUrl);
  const imageBuffer = new Uint8Array(await imageResponse.arrayBuffer());
  console.log(`Downloaded ${imageBuffer.length} bytes`);

  // 4. Crop into tiles using ImageMagick
  console.log("Cropping grid into tiles...");
  const tiles = splitImageGrid(imageBuffer, GRID_COLS, GRID_ROWS);
  console.log(`Cropped into ${tiles.length} tiles`);

  // 5. Upload each tile and update DB
  const results: ImageResult[] = [];

  for (let i = 0; i < batch.length; i++) {
    const word = batch[i];
    const tile = tiles[i];
    const fileName = `words/${word.word_id}.png`;

    // Upload to storage
    const { error: uploadError } = await supabase.storage
      .from(STORAGE_BUCKET)
      .upload(fileName, tile, {
        contentType: "image/png",
        upsert: true,
      });

    if (uploadError) {
      throw new Error(
        `Failed to upload image for "${word.word}": ${uploadError.message}`,
      );
    }

    // Get public URL
    const { data: publicUrlData } = supabase.storage
      .from(STORAGE_BUCKET)
      .getPublicUrl(fileName);
    const imageUrl = publicUrlData.publicUrl;

    // Update vocabulary_words
    const { error: updateError } = await supabase
      .from("vocabulary_words")
      .update({ image_url: imageUrl })
      .eq("id", word.word_id);

    if (updateError) {
      throw new Error(
        `DB update failed for "${word.word}": ${updateError.message}`,
      );
    }

    results.push({
      wordId: word.word_id,
      word: word.word,
      imageUrl,
    });

    console.log(`"${word.word}" → ${imageUrl}`);
  }

  return results;
}
```

- [ ] **Step 3: Add the grid splitting function**

Add the following **above** `Deno.serve(...)`:

```typescript
function splitImageGrid(
  imageBuffer: Uint8Array,
  cols: number,
  rows: number,
): Uint8Array[] {
  const tiles: Uint8Array[] = [];

  ImageMagick.read(imageBuffer, (img) => {
    const tileWidth = Math.floor(img.width / cols);
    const tileHeight = Math.floor(img.height / rows);

    console.log(
      `Grid image: ${img.width}x${img.height}, tile size: ${tileWidth}x${tileHeight}`,
    );

    for (let row = 0; row < rows; row++) {
      for (let col = 0; col < cols; col++) {
        const x = col * tileWidth;
        const y = row * tileHeight;

        img.clone((clone) => {
          clone.crop(new MagickGeometry(x, y, tileWidth, tileHeight));
          clone.rePage();
          clone.write(MagickFormat.Png, (data) => {
            tiles.push(new Uint8Array(data));
          });
        });
      }
    }
  });

  return tiles;
}
```

- [ ] **Step 4: Commit Edge Function**

```bash
git add supabase/functions/generate-wordlist-images/index.ts
git commit -m "feat: add generate-wordlist-images edge function

Batched AI image generation using fal.ai nano-banana-pro.
Generates 2x3 grid per batch, crops with magick-wasm,
uploads tiles to Supabase Storage."
```

---

### Task 3: Admin Panel — Image Generation Button & Dialog

**Files:**
- Modify: `owlio_admin/lib/features/wordlists/screens/wordlist_edit_screen.dart`

- [ ] **Step 1: Add image generation state variables**

In `_WordlistEditScreenState`, add after `_isGeneratingAudio`:

```dart
bool _isGeneratingImages = false;
```

- [ ] **Step 2: Add the image generation dialog and handler method**

Add the following method in `_WordlistEditScreenState`, after `_generateWordlistAudio()`:

```dart
Future<void> _showImageGenerationDialog() async {
  final promptController = TextEditingController(
    text: 'A 2x3 grid of 6 separate illustrations for a children\'s '
        'English learning app. Each cell contains exactly one object/concept '
        'illustration, clearly separated with visible borders. '
        'All cells are equal size. White background for each cell. '
        'No text or labels inside the cells.',
  );
  String selectedStyle = 'flat';

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Görsel Üretimi'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Style selector
              Text(
                'Stil',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _styleChip('flat', 'Flat', selectedStyle, (v) {
                    setDialogState(() => selectedStyle = v);
                  }),
                  _styleChip('cartoon', 'Cartoon', selectedStyle, (v) {
                    setDialogState(() => selectedStyle = v);
                  }),
                  _styleChip('watercolor', 'Watercolor', selectedStyle, (v) {
                    setDialogState(() => selectedStyle = v);
                  }),
                  _styleChip('realistic', 'Realistic', selectedStyle, (v) {
                    setDialogState(() => selectedStyle = v);
                  }),
                  _styleChip('pixel', 'Pixel Art', selectedStyle, (v) {
                    setDialogState(() => selectedStyle = v);
                  }),
                ],
              ),
              const SizedBox(height: 20),

              // Prompt editor
              Text(
                'Prompt (düzenlenebilir)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: promptController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Görsel üretim prompt\'unu yazın...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_wordItems.length} kelime için '
                        '${(_wordItems.length / 6).ceil()} görsel çağrısı yapılacak. '
                        'Her çağrı 2x3 grid üretir.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Üret'),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true) return;

  setState(() => _isGeneratingImages = true);

  try {
    final supabase = ref.read(supabaseClientProvider);
    final response = await supabase.functions.invoke(
      'generate-wordlist-images',
      body: {
        'wordListId': widget.listId,
        'prompt': promptController.text.trim(),
        'style': selectedStyle,
      },
    );

    if (response.status != 200) {
      throw Exception(
          response.data?['error'] ?? 'Failed to generate images');
    }

    final imagesGenerated = response.data?['imagesGenerated'] ?? 0;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$imagesGenerated kelime için görsel üretildi!'),
          backgroundColor: Colors.green,
        ),
      );
      ref.invalidate(wordlistDetailProvider(widget.listId!));
      ref.invalidate(wordlistsProvider);
      _loadWordList(); // Refresh content table
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Görsel üretme hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) setState(() => _isGeneratingImages = false);
  }

  promptController.dispose();
}

Widget _styleChip(
  String value,
  String label,
  String selected,
  ValueChanged<String> onSelected,
) {
  final isSelected = value == selected;
  return ChoiceChip(
    label: Text(label),
    selected: isSelected,
    onSelected: (_) => onSelected(value),
    selectedColor: const Color(0xFF4F46E5).withValues(alpha: 0.15),
    labelStyle: TextStyle(
      color: isSelected ? const Color(0xFF4F46E5) : null,
      fontWeight: isSelected ? FontWeight.w600 : null,
    ),
  );
}
```

- [ ] **Step 3: Add the "Görselleri Üret" button in the AppBar**

In the `actions` list of the `AppBar`, add after the existing audio button block (after the `SizedBox(width: 8)` that follows it):

```dart
if (!isNewList && _wordItems.isNotEmpty)
  OutlinedButton.icon(
    onPressed: _isGeneratingImages ? null : _showImageGenerationDialog,
    icon: _isGeneratingImages
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.image, size: 18),
    label: Text(_isGeneratingImages ? 'Üretiliyor...' : 'Görselleri Üret'),
  ),
const SizedBox(width: 8),
```

- [ ] **Step 4: Run analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/features/wordlists/`
Expected: No errors.

- [ ] **Step 5: Commit admin panel changes**

```bash
git add owlio_admin/lib/features/wordlists/screens/wordlist_edit_screen.dart
git commit -m "feat: add image generation button to word list editor

Adds 'Görselleri Üret' button with style presets and editable
prompt. Calls generate-wordlist-images edge function."
```

---

### Task 4: Deploy & Test

- [ ] **Step 1: Deploy the Edge Function**

Run: `cd /Users/wonderelt/Desktop/Owlio && supabase functions deploy generate-wordlist-images`
Expected: Function deployed successfully.

- [ ] **Step 2: Test in admin panel**

1. Open admin panel at localhost
2. Navigate to a word list with words
3. Click "Görselleri Üret"
4. Select a style, optionally edit prompt
5. Click "Üret"
6. Verify: progress indicator shows, then success snackbar
7. Verify: content table now shows green check for `image_url` on each word
8. Verify: images are visible in Supabase Storage under `word-images/words/`

- [ ] **Step 3: Commit final state if any adjustments were needed**

```bash
git add -A
git commit -m "fix: adjustments from image generation testing"
```
