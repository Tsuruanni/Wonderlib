import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  ImageMagick,
  initializeImageMagick,
  MagickFormat,
  MagickGeometry,
} from "npm:@imagemagick/magick-wasm@0.0.38";

// --- Constants ---

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const STORAGE_BUCKET = "word-images";
const GRID_COLS = 2;
const GRID_ROWS = 3;
const BATCH_SIZE = GRID_COLS * GRID_ROWS; // 6

const STYLE_PRESETS: Record<string, string> = {
  flat: "simple flat vector illustration, minimal, clean lines, solid colors",
  cartoon:
    "cute cartoon style, colorful, playful, rounded shapes, child-friendly",
  watercolor: "soft watercolor painting, gentle pastel colors, artistic",
  realistic: "realistic illustration, detailed, natural colors",
  pixel: "pixel art, 8-bit retro style, crisp pixels",
};

const CELL_POSITIONS = [
  "top-left",
  "top-right",
  "middle-left",
  "middle-right",
  "bottom-left",
  "bottom-right",
];

// --- Interfaces ---

interface WordItem {
  word_id: string;
  word: string;
  meaning_tr: string;
}

interface FalImageResponse {
  images: Array<{
    url: string;
    content_type: string;
    file_size: number;
    width: number;
    height: number;
  }>;
}

interface WordResult {
  wordId: string;
  word: string;
  imageUrl: string;
}

// --- ImageMagick WASM Initialization ---

const wasmBytes = await Deno.readFile(
  new URL(
    "magick.wasm",
    import.meta.resolve("npm:@imagemagick/magick-wasm@0.0.38")
  )
);
await initializeImageMagick(wasmBytes);

// --- Grid Splitting ---

function splitImageGrid(
  imageBuffer: Uint8Array,
  cols: number,
  rows: number
): Uint8Array[] {
  const tiles: Uint8Array[] = [];

  ImageMagick.read(imageBuffer, (img) => {
    const tileWidth = Math.floor(img.width / cols);
    const tileHeight = Math.floor(img.height / rows);

    for (let row = 0; row < rows; row++) {
      for (let col = 0; col < cols; col++) {
        img.clone((clone) => {
          clone.crop(
            new MagickGeometry(
              col * tileWidth,
              row * tileHeight,
              tileWidth,
              tileHeight
            )
          );
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

// --- Prompt Building ---

function buildGridPrompt(
  batch: (WordItem | null)[],
  style?: string,
  customPrompt?: string
): string {
  const styleDescription = style && STYLE_PRESETS[style]
    ? STYLE_PRESETS[style]
    : STYLE_PRESETS["cartoon"];

  let basePrompt: string;
  if (customPrompt) {
    basePrompt = customPrompt;
  } else {
    basePrompt =
      `Create a 2x3 grid image for a children's vocabulary learning app. ` +
      `Each cell should contain a single clear illustration of the word described. ` +
      `Style: ${styleDescription}. ` +
      `The grid should have thin white dividing lines between cells. ` +
      `No text or labels in the image.`;
  }

  const cellDescriptions = batch.map((item, index) => {
    const position = CELL_POSITIONS[index];
    if (item) {
      return `Cell ${index + 1} (${position}): "${item.word}" (${item.meaning_tr})`;
    }
    return `Cell ${index + 1} (${position}): empty white cell`;
  });

  return `${basePrompt}\n\n${cellDescriptions.join("\n")}`;
}

// --- Batch Processing ---

async function processBatch(
  batch: (WordItem | null)[],
  falKey: string,
  supabase: ReturnType<typeof createClient>,
  style?: string,
  customPrompt?: string
): Promise<WordResult[]> {
  const prompt = buildGridPrompt(batch, style, customPrompt);
  console.log(`Grid prompt:\n${prompt}`);

  // 1. Call fal.ai image generation
  console.log("Calling fal.ai image generation...");
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
    }
  );

  if (!falResponse.ok) {
    const errorText = await falResponse.text();
    throw new Error(
      `fal.ai API error: ${falResponse.status} - ${errorText}`
    );
  }

  const falData: FalImageResponse = await falResponse.json();
  if (!falData.images || falData.images.length === 0 || !falData.images[0].url) {
    throw new Error("No image URL in fal.ai response");
  }

  const gridImageUrl = falData.images[0].url;
  console.log(`Grid image URL: ${gridImageUrl}`);

  // 2. Download grid image
  console.log("Downloading grid image...");
  const imageResponse = await fetch(gridImageUrl);
  if (!imageResponse.ok) {
    throw new Error(
      `Failed to download grid image: ${imageResponse.status}`
    );
  }
  const imageBuffer = new Uint8Array(await imageResponse.arrayBuffer());
  console.log(`Downloaded grid image: ${imageBuffer.length} bytes`);

  // 3. Split into tiles
  console.log("Splitting grid into tiles...");
  const tiles = splitImageGrid(imageBuffer, GRID_COLS, GRID_ROWS);
  console.log(`Split into ${tiles.length} tiles`);

  // 4. Upload tiles and update DB
  const results: WordResult[] = [];

  for (let i = 0; i < batch.length; i++) {
    const item = batch[i];
    if (!item) continue; // Skip padding cells

    if (i >= tiles.length) {
      console.warn(
        `No tile for word "${item.word}" at index ${i}, skipping`
      );
      continue;
    }

    const tileData = tiles[i];
    const storagePath = `words/${item.word_id}.png`;

    // Upload tile to storage
    const { error: uploadError } = await supabase.storage
      .from(STORAGE_BUCKET)
      .upload(storagePath, tileData, {
        contentType: "image/png",
        upsert: true,
      });

    if (uploadError) {
      console.error(
        `Failed to upload tile for "${item.word}": ${uploadError.message}`
      );
      throw new Error(
        `Storage upload failed for "${item.word}": ${uploadError.message}`
      );
    }

    // Get public URL
    const { data: publicUrlData } = supabase.storage
      .from(STORAGE_BUCKET)
      .getPublicUrl(storagePath);
    const imageUrl = publicUrlData.publicUrl;

    // Update vocabulary_words with image URL
    const { error: updateError } = await supabase
      .from("vocabulary_words")
      .update({ image_url: imageUrl })
      .eq("id", item.word_id);

    if (updateError) {
      throw new Error(
        `DB update failed for "${item.word}": ${updateError.message}`
      );
    }

    results.push({
      wordId: item.word_id,
      word: item.word,
      imageUrl,
    });

    console.log(`Uploaded tile for "${item.word}": ${imageUrl}`);
  }

  return results;
}

// --- Main Handler ---

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
        }
      );
    }

    const FAL_KEY = Deno.env.get("FAL_KEY");
    if (!FAL_KEY) {
      return new Response(
        JSON.stringify({ error: "FAL_KEY not configured" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // 1. Fetch words from word_list_items joined with vocabulary_words
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
        }
      );
    }

    const words: WordItem[] = items
      .map((item: any) => ({
        word_id: item.vocabulary_words?.id,
        word: item.vocabulary_words?.word,
        meaning_tr: item.vocabulary_words?.meaning_tr,
      }))
      .filter(
        (w: WordItem) => w.word_id && w.word && w.meaning_tr
      );

    if (words.length === 0) {
      return new Response(
        JSON.stringify({ error: "No valid words found (missing word or meaning_tr)" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    console.log(`Found ${words.length} words`);

    // 2. Ensure storage bucket exists
    await supabase.storage
      .createBucket(STORAGE_BUCKET, {
        public: true,
        fileSizeLimit: 52428800, // 50MB
      })
      .catch(() => {}); // Ignore if already exists

    // 3. Split words into batches of 6 and process each
    const allResults: WordResult[] = [];

    for (let i = 0; i < words.length; i += BATCH_SIZE) {
      const batchWords = words.slice(i, i + BATCH_SIZE);
      const batchNumber = Math.floor(i / BATCH_SIZE) + 1;
      const totalBatches = Math.ceil(words.length / BATCH_SIZE);

      console.log(
        `Processing batch ${batchNumber}/${totalBatches} (${batchWords.length} words)...`
      );

      // Pad batch to BATCH_SIZE with nulls for empty cells
      const paddedBatch: (WordItem | null)[] = [...batchWords];
      while (paddedBatch.length < BATCH_SIZE) {
        paddedBatch.push(null);
      }

      const batchResults = await processBatch(
        paddedBatch,
        FAL_KEY,
        supabase,
        style,
        prompt
      );
      allResults.push(...batchResults);
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
      }
    );
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
