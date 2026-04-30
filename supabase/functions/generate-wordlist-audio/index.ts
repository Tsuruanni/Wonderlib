import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { getApiConfig } from "../_shared/api_config.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface WordItem {
  word_id: string;
  word: string;
}

interface TimestampData {
  characters: string[];
  character_start_times_seconds: number[];
  character_end_times_seconds: number[];
}

interface FalAIResponse {
  audio: {
    url: string;
    content_type: string;
    file_name: string;
    file_size: number;
  };
  timestamps?: TimestampData[];
}

interface WordResult {
  wordId: string;
  word: string;
  audioStartMs: number;
  audioEndMs: number;
  audioUrl: string;
}

const DELIMITER = "... ";
const STORAGE_BUCKET = "word-audio";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { wordListId, voiceId } = await req.json();

    if (!wordListId) {
      return new Response(
        JSON.stringify({ error: "wordListId is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // 1. Fetch words
    console.log(`Fetching words for list ${wordListId}...`);
    const { data: items, error: fetchError } = await supabase
      .from("word_list_items")
      .select("word_id, vocabulary_words(id, word)")
      .eq("word_list_id", wordListId)
      .order("order_index", { ascending: true });

    if (fetchError) throw new Error(`Failed to fetch words: ${fetchError.message}`);
    if (!items || items.length === 0) {
      return new Response(
        JSON.stringify({ error: "No words found in this list" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const words: WordItem[] = items
      .map((item: any) => ({
        word_id: item.vocabulary_words?.id,
        word: item.vocabulary_words?.word,
      }))
      .filter((w: WordItem) => w.word_id && w.word);

    if (words.length === 0) {
      return new Response(
        JSON.stringify({ error: "No valid words found" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`Found ${words.length} words`);

    // 2. Combine words
    const combinedText = words.map(w => w.word).join(DELIMITER);
    console.log(`Combined: "${combinedText}"`);

    // 3. Call Fal.ai TTS
    const FAL_KEY = await getApiConfig("fal_api_key", "FAL_KEY");
    if (!FAL_KEY) {
      return new Response(
        JSON.stringify({ error: "FAL_KEY not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log("Calling Fal.ai TTS...");
    const falResponse = await fetch(
      "https://fal.run/fal-ai/elevenlabs/tts/eleven-v3",
      {
        method: "POST",
        headers: {
          "Authorization": `Key ${FAL_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          text: combinedText,
          voice: voiceId || "QngvLQR8bsLR5bzoa6Vv",
          timestamps: true,
          model: "eleven_multilingual_v2",
        }),
      }
    );

    if (!falResponse.ok) {
      const errorText = await falResponse.text();
      throw new Error(`Fal.ai API error: ${falResponse.status} - ${errorText}`);
    }

    const falData: FalAIResponse = await falResponse.json();
    if (!falData.audio?.url) throw new Error("No audio URL in Fal.ai response");

    console.log("Audio URL from Fal.ai:", falData.audio.url);

    // 4. Download audio and upload to Supabase Storage
    console.log("Downloading audio from Fal.ai...");
    const audioResponse = await fetch(falData.audio.url);
    const audioBlob = await audioResponse.arrayBuffer();
    const audioBytes = new Uint8Array(audioBlob);

    // Ensure bucket exists
    await supabase.storage.createBucket(STORAGE_BUCKET, {
      public: true,
      fileSizeLimit: 52428800, // 50MB
    }).catch(() => {}); // Ignore if exists

    // Upload combined audio with list ID
    const listFileName = `lists/${wordListId}.mp3`;
    const { error: uploadError } = await supabase.storage
      .from(STORAGE_BUCKET)
      .upload(listFileName, audioBytes, {
        contentType: "audio/mpeg",
        upsert: true,
      });

    if (uploadError) {
      console.error("Storage upload error:", uploadError);
      throw new Error(`Failed to upload audio: ${uploadError.message}`);
    }

    const { data: publicUrlData } = supabase.storage
      .from(STORAGE_BUCKET)
      .getPublicUrl(listFileName);
    const combinedAudioUrl = publicUrlData.publicUrl;
    console.log("Uploaded combined audio:", combinedAudioUrl);

    // 5. Extract word segments from timestamps
    let mergedTimestamps: TimestampData | null = null;
    if (falData.timestamps && falData.timestamps.length > 0) {
      mergedTimestamps = mergeTimestampData(falData.timestamps);
      console.log(`Merged ${mergedTimestamps.characters.length} character timestamps`);
    }

    const wordSegments = mergedTimestamps
      ? extractEntrySegments(mergedTimestamps, words, DELIMITER)
      : [];
    console.log(`Extracted ${wordSegments.length} word segments`);

    // 6. Update each word in DB
    const results: WordResult[] = [];

    for (let i = 0; i < words.length; i++) {
      const w = words[i];
      let audioStartMs = 0;
      let audioEndMs = 0;

      if (i < wordSegments.length) {
        audioStartMs = wordSegments[i].startMs;
        audioEndMs = wordSegments[i].endMs;
      }

      // Build descriptive audio URL with word name as query param
      const wordAudioUrl = `${combinedAudioUrl}?word=${encodeURIComponent(w.word)}`;

      const { error: updateError } = await supabase
        .from("vocabulary_words")
        .update({
          audio_url: wordAudioUrl,
          audio_start_ms: audioStartMs,
          audio_end_ms: audioEndMs,
        })
        .eq("id", w.word_id);

      if (updateError) {
        throw new Error(`DB update failed for "${w.word}": ${updateError.message}`);
      }

      results.push({
        wordId: w.word_id,
        word: w.word,
        audioStartMs,
        audioEndMs,
        audioUrl: wordAudioUrl,
      });

      console.log(`"${w.word}": ${audioStartMs}ms - ${audioEndMs}ms`);
    }

    console.log(`Done! ${results.length} words processed`);

    return new Response(
      JSON.stringify({
        success: true,
        audioUrl: combinedAudioUrl,
        wordsProcessed: results.length,
        results,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

function extractEntrySegments(
  timestamps: TimestampData,
  words: WordItem[],
  delimiter: string
): { word: string; startMs: number; endMs: number }[] {
  const chars = timestamps.characters;
  const starts = timestamps.character_start_times_seconds;
  const ends = timestamps.character_end_times_seconds;

  // Reconstruct the combined text to find entry boundaries
  const combinedText = words.map(w => w.word).join(delimiter);

  const segments: { word: string; startMs: number; endMs: number }[] = [];
  let charOffset = 0;

  for (let i = 0; i < words.length; i++) {
    const entryText = words[i].word;
    const entryStart = charOffset;
    const entryEnd = charOffset + entryText.length;

    // Find first and last non-silent character timestamps within this entry range
    let startMs = 0;
    let endMs = 0;
    let foundStart = false;

    for (let ci = entryStart; ci < entryEnd && ci < chars.length; ci++) {
      if (starts[ci] !== undefined && ends[ci] !== undefined) {
        if (!foundStart) {
          startMs = Math.floor(starts[ci] * 1000);
          foundStart = true;
        }
        endMs = Math.floor(ends[ci] * 1000);
      }
    }

    segments.push({
      word: entryText,
      startMs,
      endMs,
    });

    // Advance past this entry + delimiter
    charOffset = entryEnd + delimiter.length;
  }

  return segments;
}

function mergeTimestampData(timestamps: TimestampData[]): TimestampData {
  const merged: TimestampData = {
    characters: [],
    character_start_times_seconds: [],
    character_end_times_seconds: [],
  };

  for (const entry of timestamps) {
    if (entry.characters && entry.characters.length > 0) {
      merged.characters.push(...entry.characters);
      merged.character_start_times_seconds.push(
        ...entry.character_start_times_seconds
      );
      merged.character_end_times_seconds.push(
        ...entry.character_end_times_seconds
      );
    }
  }

  return merged;
}
