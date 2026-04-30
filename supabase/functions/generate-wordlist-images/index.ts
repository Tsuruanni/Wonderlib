import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  ImageMagick,
  initializeImageMagick,
  MagickFormat,
  MagickGeometry,
} from "npm:@imagemagick/magick-wasm@0.0.38";
import { getApiConfig } from "../_shared/api_config.ts";

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
  cartoon: "cute cartoon style, colorful, playful, rounded shapes, child-friendly",
  watercolor: "soft watercolor painting, gentle pastel colors, artistic",
  realistic: "realistic photograph, studio lighting, natural colors, high detail",
  pixel: "pixel art, 8-bit retro style, crisp pixels",
  clay: "3D clay render, claymation style, soft shadows, matte texture, pastel tones",
  sticker: "die-cut sticker design, thick white outline, vibrant colors, glossy finish",
  pencil: "hand-drawn pencil sketch, graphite on white paper, detailed line work, cross-hatching",
  isometric: "isometric 3D illustration, geometric shapes, clean angles, soft gradient colors",
  pop: "pop art style, bold outlines, halftone dots, bright contrasting colors, comic book aesthetic",
  minimal: "ultra-minimalist single line drawing, one continuous stroke, black on white, elegant simplicity",
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
  example_sentence?: string;
  has_image: boolean;
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
          clone.write(MagickFormat.Png, (data) => {
            tiles.push(new Uint8Array(data));
          });
        });
      }
    }
  });

  return tiles;
}

// --- Filler mascots for empty grid cells ---

const FILLER_MASCOTS = [
  "a cute owl mascot waving",
  "a friendly fox mascot reading a book",
  "a happy penguin mascot with a backpack",
  "a cheerful rabbit mascot holding a star",
  "a playful cat mascot sitting",
  "a smiling bear mascot giving a thumbs up",
];

// --- Prompt Building ---

function buildGridPrompt(
  batch: (WordItem | null)[],
  style?: string,
  customPrompt?: string,
  includeExamples?: boolean,
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
      `No borders, no frames, no dividing lines between cells. Seamless white background. ` +
      `IMPORTANT: Do NOT include any text, letters, words, labels, or typography anywhere in the image. Only illustrations.`;
  }

  let fillerIdx = 0;
  const cellDescriptions = batch.map((item, index) => {
    const position = CELL_POSITIONS[index];
    if (item) {
      let desc = `Cell ${index + 1} (${position}): "${item.word}" (${item.meaning_tr})`;
      if (includeExamples && item.example_sentence) {
        desc += ` — context: "${item.example_sentence}"`;
      }
      return desc;
    }
    // Fill empty cells with mascot illustrations for grid consistency
    const mascot = FILLER_MASCOTS[fillerIdx % FILLER_MASCOTS.length];
    fillerIdx++;
    return `Cell ${index + 1} (${position}): ${mascot}`;
  });

  return `${basePrompt}\n\n${cellDescriptions.join("\n")}`;
}

// --- Batch Processing ---

async function processBatch(
  batch: (WordItem | null)[],
  falKey: string,
  supabase: ReturnType<typeof createClient>,
  style?: string,
  customPrompt?: string,
  includeExamples?: boolean,
): Promise<WordResult[]> {
  const prompt = buildGridPrompt(batch, style, customPrompt, includeExamples);
  console.log(`Grid prompt:\n${prompt}`);

  // 1. Call fal.ai image generation (with 120s timeout)
  console.log("Calling fal.ai image generation...");
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 120000);

  let falResponse: Response;
  try {
    falResponse = await fetch(
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
        signal: controller.signal,
      }
    );
  } catch (e) {
    clearTimeout(timeout);
    throw new Error(`fal.ai request failed (timeout or network): ${e.message}`);
  }
  clearTimeout(timeout);

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

  // 4. Upload tiles and update DB (parallel)
  console.log("Uploading tiles in parallel...");
  const timestamp = Date.now();

  const uploadPromises = batch.map(async (item, i) => {
    if (!item) return null;
    if (i >= tiles.length) {
      console.warn(`No tile for word "${item.word}" at index ${i}, skipping`);
      return null;
    }

    const tileData = tiles[i];
    const storagePath = `words/${item.word_id}/${timestamp}_${i}.png`;

    const { error: uploadError } = await supabase.storage
      .from(STORAGE_BUCKET)
      .upload(storagePath, tileData, {
        contentType: "image/png",
        upsert: true,
      });

    if (uploadError) {
      throw new Error(`Storage upload failed for "${item.word}": ${uploadError.message}`);
    }

    const { data: publicUrlData } = supabase.storage
      .from(STORAGE_BUCKET)
      .getPublicUrl(storagePath);
    const imageUrl = publicUrlData.publicUrl;

    const { error: updateError } = await supabase
      .from("vocabulary_words")
      .update({ image_url: imageUrl })
      .eq("id", item.word_id);

    if (updateError) {
      throw new Error(`DB update failed for "${item.word}": ${updateError.message}`);
    }

    console.log(`"${item.word}" → ${imageUrl}`);
    return { wordId: item.word_id, word: item.word, imageUrl } as WordResult;
  });

  const settled = await Promise.all(uploadPromises);
  const results = settled.filter((r): r is WordResult => r !== null);

  return results;
}

// --- Main Handler ---

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { wordListId, prompt, style, includeExamples, overwrite } = await req.json();

    if (!wordListId) {
      return new Response(
        JSON.stringify({ error: "wordListId is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const FAL_KEY = await getApiConfig("fal_api_key", "FAL_KEY");
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
      .select("word_id, vocabulary_words(id, word, meaning_tr, example_sentences, image_url)")
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

    const allWords: WordItem[] = items
      .map((item: any) => {
        const v = item.vocabulary_words;
        const examples = v?.example_sentences as string[] | null;
        return {
          word_id: v?.id,
          word: v?.word,
          meaning_tr: v?.meaning_tr,
          example_sentence: examples && examples.length > 0 ? examples[0] : undefined,
          has_image: !!(v?.image_url && (v.image_url as string).trim().length > 0),
        };
      })
      .filter(
        (w: WordItem) => w.word_id && w.word && w.meaning_tr
      );

    // Filter: skip words that already have images (unless overwrite)
    const words = overwrite !== true
      ? allWords.filter((w) => !w.has_image)
      : allWords;

    if (words.length === 0) {
      const msg = overwrite !== true
        ? "All words already have images. Use overwrite to regenerate."
        : "No valid words found (missing word or meaning_tr)";
      return new Response(
        JSON.stringify({ error: msg, allHaveImages: overwrite !== true }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    console.log(`Found ${words.length} words to process (${allWords.length} total, overwrite=${overwrite ?? false})`);

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
        prompt,
        includeExamples,
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
