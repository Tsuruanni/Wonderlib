import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface ContentBlock {
  id: string;
  text: string;
  order_index: number;
}

interface WordTiming {
  word: string;
  startIndex: number;
  endIndex: number;
  startMs: number;
  endMs: number;
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

interface BlockBoundary {
  startChar: number;
  endChar: number;
  startMs?: number;
  endMs?: number;
}

interface BlockResult {
  blockId: string;
  wordCount: number;
  audioStartMs: number;
  audioEndMs: number;
}

// Delimiter used to separate blocks in combined text
const DELIMITER = " ||| ";

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { chapterId, voiceId } = await req.json();

    if (!chapterId) {
      return new Response(
        JSON.stringify({ error: "chapterId is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // 1. Get all text blocks for this chapter
    console.log(`Fetching text blocks for chapter ${chapterId}...`);
    const { data: blocks, error: fetchError } = await supabase
      .from("content_blocks")
      .select("id, text, order_index")
      .eq("chapter_id", chapterId)
      .eq("type", "text")
      .not("text", "is", null)
      .order("order_index", { ascending: true });

    if (fetchError) {
      throw new Error(`Failed to fetch blocks: ${fetchError.message}`);
    }

    if (!blocks || blocks.length === 0) {
      return new Response(
        JSON.stringify({ error: "No text blocks found for this chapter" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`Found ${blocks.length} text blocks`);

    // 2. Combine all text with delimiter
    const combinedText = (blocks as ContentBlock[]).map(b => b.text).join(DELIMITER);
    console.log(`Combined text length: ${combinedText.length} characters`);

    // Calculate block boundaries (character positions)
    const blockBoundaries = calculateBlockBoundaries(blocks as ContentBlock[]);

    // 3. Call Fal AI with combined text - SINGLE API CALL
    const FAL_KEY = Deno.env.get("FAL_KEY") || "482f71ee-7bbb-4966-a021-e67f0ec3a4a4:173a09396d98fd54b75c8666f7698b84";

    console.log("Calling Fal AI for combined text...");
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
          voice: voiceId || "QngvLQR8bsLR5bzoa6Vv", // Michael voice
          timestamps: true,
          model: "eleven_multilingual_v2",
        }),
      }
    );

    if (!falResponse.ok) {
      const errorText = await falResponse.text();
      console.error("Fal AI error:", errorText);
      throw new Error(`Fal AI API error: ${falResponse.status} - ${errorText}`);
    }

    const falData: FalAIResponse = await falResponse.json();
    console.log("Fal AI response received, audio URL:", falData.audio?.url);

    if (!falData.audio?.url) {
      throw new Error("No audio URL in Fal AI response");
    }

    // 4. Merge all timestamp data
    let mergedTimestamps: TimestampData | null = null;
    if (falData.timestamps && falData.timestamps.length > 0) {
      mergedTimestamps = mergeTimestampData(falData.timestamps);
      console.log(`Merged ${mergedTimestamps.characters.length} character timestamps`);
    }

    // 5. Process each block - extract timings and update DB
    const results: BlockResult[] = [];

    for (let i = 0; i < blocks.length; i++) {
      const block = blocks[i] as ContentBlock;
      const boundary = blockBoundaries[i];

      // Extract word timings for this block
      let blockWordTimings: WordTiming[] = [];
      let audioStartMs = 0;
      let audioEndMs = 0;

      if (mergedTimestamps && mergedTimestamps.characters.length > 0) {
        // Get audio start/end times from first/last character of this block
        audioStartMs = Math.floor((mergedTimestamps.character_start_times_seconds[boundary.startChar] || 0) * 1000);

        // End time is from the last character of the block
        const lastCharIndex = Math.min(boundary.endChar - 1, mergedTimestamps.character_end_times_seconds.length - 1);
        audioEndMs = Math.floor((mergedTimestamps.character_end_times_seconds[lastCharIndex] || 0) * 1000);

        // Extract word timings for this block
        blockWordTimings = extractBlockTimings(
          block.text,
          mergedTimestamps,
          boundary.startChar
        );
      }

      // Update database for this block
      const { error: updateError } = await supabase
        .from("content_blocks")
        .update({
          audio_url: falData.audio.url,
          word_timings: blockWordTimings,
          audio_start_ms: audioStartMs,
          audio_end_ms: audioEndMs,
          updated_at: new Date().toISOString(),
        })
        .eq("id", block.id);

      if (updateError) {
        console.error(`Failed to update block ${block.id}:`, updateError);
        throw new Error(`Database update failed for block ${block.id}: ${updateError.message}`);
      }

      results.push({
        blockId: block.id,
        wordCount: blockWordTimings.length,
        audioStartMs,
        audioEndMs,
      });

      console.log(`Updated block ${i + 1}/${blocks.length}: ${block.id} (${blockWordTimings.length} words, ${audioStartMs}ms - ${audioEndMs}ms)`);
    }

    console.log(`Successfully processed ${results.length} blocks`);

    return new Response(
      JSON.stringify({
        success: true,
        audioUrl: falData.audio.url,
        blocksProcessed: results.length,
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

/**
 * Calculate character boundaries for each block in the combined text
 */
function calculateBlockBoundaries(blocks: ContentBlock[]): BlockBoundary[] {
  const boundaries: BlockBoundary[] = [];
  let currentChar = 0;

  for (let i = 0; i < blocks.length; i++) {
    const text = blocks[i].text;
    boundaries.push({
      startChar: currentChar,
      endChar: currentChar + text.length,
    });
    // Move past this block's text and the delimiter
    currentChar += text.length + DELIMITER.length;
  }

  return boundaries;
}

/**
 * Merge multiple timestamp data entries from Fal AI into one
 */
function mergeTimestampData(timestamps: TimestampData[]): TimestampData {
  const merged: TimestampData = {
    characters: [],
    character_start_times_seconds: [],
    character_end_times_seconds: [],
  };

  for (const entry of timestamps) {
    if (entry.characters && entry.characters.length > 0) {
      merged.characters.push(...entry.characters);
      merged.character_start_times_seconds.push(...entry.character_start_times_seconds);
      merged.character_end_times_seconds.push(...entry.character_end_times_seconds);
    }
  }

  return merged;
}

/**
 * Extract word timings for a specific block from the global timestamps
 * @param blockText - The text of this specific block
 * @param timestamps - Global merged timestamps
 * @param globalStartChar - Starting character index in the combined text
 */
function extractBlockTimings(
  blockText: string,
  timestamps: TimestampData,
  globalStartChar: number
): WordTiming[] {
  const timings: WordTiming[] = [];
  const charStarts = timestamps.character_start_times_seconds;
  const charEnds = timestamps.character_end_times_seconds;

  // Use regex to find word boundaries (non-whitespace sequences)
  const wordRegex = /\S+/g;
  let match: RegExpExecArray | null;

  while ((match = wordRegex.exec(blockText)) !== null) {
    const word = match[0];
    const localStartIndex = match.index;
    const localEndIndex = localStartIndex + word.length;

    // Convert to global indices
    const globalStart = globalStartChar + localStartIndex;
    const globalEnd = globalStartChar + localEndIndex;

    // Get timing from character arrays (with bounds checking)
    const startMs = Math.floor((charStarts[globalStart] || 0) * 1000);
    const endMs = Math.floor((charEnds[Math.min(globalEnd - 1, charEnds.length - 1)] || 0) * 1000);

    timings.push({
      word,
      startIndex: localStartIndex,  // Block-relative index
      endIndex: localEndIndex,      // Block-relative index
      startMs,                      // Global audio position
      endMs,                        // Global audio position
    });
  }

  return timings;
}
