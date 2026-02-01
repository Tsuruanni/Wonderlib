import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

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
  // Fal AI returns timestamps as an array (usually 2 elements, second one has data)
  timestamps?: TimestampData[];
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { blockId, text, voiceId } = await req.json();

    if (!blockId || !text) {
      return new Response(
        JSON.stringify({ error: "blockId and text are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Fal AI credentials (ElevenLabs key format: key_id:key_secret)
    const FAL_KEY = Deno.env.get("FAL_KEY") || "482f71ee-7bbb-4966-a021-e67f0ec3a4a4:173a09396d98fd54b75c8666f7698b84";

    // 1. Call Fal AI ElevenLabs TTS with timestamps
    console.log(`Generating audio for block ${blockId}...`);

    const falResponse = await fetch(
      "https://fal.run/fal-ai/elevenlabs/tts/eleven-v3",
      {
        method: "POST",
        headers: {
          "Authorization": `Key ${FAL_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          text: text,
          voice: voiceId || "JBFqnCBsd6RMkjVDRZzb", // George voice
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

    // 2. Convert character timestamps to word timestamps
    let wordTimings: WordTiming[] = [];

    // Fal AI returns timestamps as an array - one entry per sentence/chunk
    // We need to merge all non-empty entries
    if (falData.timestamps && falData.timestamps.length > 0) {
      const mergedTimestamps = mergeTimestampData(falData.timestamps);

      if (mergedTimestamps.characters.length > 0) {
        wordTimings = convertToWordTimings(text, mergedTimestamps);
        console.log(`Generated ${wordTimings.length} word timings from ${mergedTimestamps.characters.length} characters`);
      } else {
        console.warn("No character data found in timestamps");
      }
    } else {
      console.warn("No timestamp data in response, word timings will be empty");
    }

    // 3. Update database with audio URL and word timings
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    const { error: updateError } = await supabase
      .from("content_blocks")
      .update({
        audio_url: falData.audio.url,
        word_timings: wordTimings,
        updated_at: new Date().toISOString(),
      })
      .eq("id", blockId);

    if (updateError) {
      console.error("Database update error:", updateError);
      throw new Error(`Database update failed: ${updateError.message}`);
    }

    console.log(`Successfully updated block ${blockId}`);

    return new Response(
      JSON.stringify({
        success: true,
        audioUrl: falData.audio.url,
        wordTimings: wordTimings,
        wordCount: wordTimings.length,
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
 * Merge multiple timestamp data entries from Fal AI into one
 * Fal AI returns separate entries for each sentence/chunk
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
 * Convert character-level timestamps to word-level timestamps
 */
function convertToWordTimings(
  text: string,
  timestampData: TimestampData
): WordTiming[] {
  const timings: WordTiming[] = [];
  const charStarts = timestampData.character_start_times_seconds;
  const charEnds = timestampData.character_end_times_seconds;

  // Use regex to find word boundaries (non-whitespace sequences)
  const wordRegex = /\S+/g;
  let match: RegExpExecArray | null;

  while ((match = wordRegex.exec(text)) !== null) {
    const word = match[0];
    const startIndex = match.index;
    const endIndex = startIndex + word.length;

    // Get timing from character arrays
    // Handle edge cases where indices might be out of bounds
    const startMs = Math.floor((charStarts[startIndex] || 0) * 1000);
    const endMs = Math.floor((charEnds[Math.min(endIndex - 1, charEnds.length - 1)] || 0) * 1000);

    timings.push({
      word,
      startIndex,
      endIndex,
      startMs,
      endMs,
    });
  }

  return timings;
}
