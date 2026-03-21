import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Ensure buckets exist
    await supabase.storage.createBucket("chapter-audio", {
      public: true,
      fileSizeLimit: 104857600,
    }).catch(() => {});

    await supabase.storage.createBucket("word-audio", {
      public: true,
      fileSizeLimit: 52428800,
    }).catch(() => {});

    const results: { table: string; id: string; oldUrl: string; newUrl: string }[] = [];
    const errors: { table: string; id: string; error: string }[] = [];

    // Track already-migrated URLs to avoid re-downloading the same file
    const migratedUrls = new Map<string, string>(); // oldUrl → newStorageUrl

    // ========================================
    // 1. Migrate content_blocks (chapter audio)
    // ========================================
    console.log("Fetching content_blocks with fal.media URLs...");
    const { data: blocks, error: blocksError } = await supabase
      .from("content_blocks")
      .select("id, chapter_id, audio_url")
      .like("audio_url", "%fal.media%");

    if (blocksError) throw new Error(`Failed to fetch blocks: ${blocksError.message}`);

    console.log(`Found ${blocks?.length ?? 0} content_blocks to migrate`);

    for (const block of (blocks ?? [])) {
      const oldUrl = block.audio_url as string;

      try {
        let newUrl: string;

        if (migratedUrls.has(oldUrl)) {
          // Same audio file already uploaded — just update DB reference
          newUrl = migratedUrls.get(oldUrl)!;
        } else {
          // Download and upload
          console.log(`Downloading: ${oldUrl.substring(0, 80)}...`);
          const audioResponse = await fetch(oldUrl);
          if (!audioResponse.ok) throw new Error(`HTTP ${audioResponse.status}`);

          const audioBytes = new Uint8Array(await audioResponse.arrayBuffer());
          const fileName = `${block.chapter_id}.mp3`;

          const { error: uploadError } = await supabase.storage
            .from("chapter-audio")
            .upload(fileName, audioBytes, {
              contentType: "audio/mpeg",
              upsert: true,
            });

          if (uploadError) throw new Error(uploadError.message);

          const { data: publicUrlData } = supabase.storage
            .from("chapter-audio")
            .getPublicUrl(fileName);
          newUrl = publicUrlData.publicUrl;

          migratedUrls.set(oldUrl, newUrl);
          console.log(`Uploaded: ${fileName}`);
        }

        // Update DB
        const { error: updateError } = await supabase
          .from("content_blocks")
          .update({ audio_url: newUrl })
          .eq("id", block.id);

        if (updateError) throw new Error(updateError.message);

        results.push({ table: "content_blocks", id: block.id, oldUrl, newUrl });
      } catch (e) {
        console.error(`Failed block ${block.id}: ${e.message}`);
        errors.push({ table: "content_blocks", id: block.id, error: e.message });
      }
    }

    // ========================================
    // 2. Migrate vocabulary_words
    // ========================================
    console.log("Fetching vocabulary_words with fal.media URLs...");
    const { data: words, error: wordsError } = await supabase
      .from("vocabulary_words")
      .select("id, word, audio_url, audio_start_ms, audio_end_ms")
      .like("audio_url", "%fal.media%");

    if (wordsError) throw new Error(`Failed to fetch words: ${wordsError.message}`);

    console.log(`Found ${words?.length ?? 0} vocabulary_words to migrate`);

    for (const word of (words ?? [])) {
      const oldUrl = word.audio_url as string;

      try {
        let newUrl: string;

        if (migratedUrls.has(oldUrl)) {
          newUrl = migratedUrls.get(oldUrl)!;
        } else {
          console.log(`Downloading word audio: ${oldUrl.substring(0, 80)}...`);
          const audioResponse = await fetch(oldUrl);
          if (!audioResponse.ok) throw new Error(`HTTP ${audioResponse.status}`);

          const audioBytes = new Uint8Array(await audioResponse.arrayBuffer());
          // Use a hash-based filename since multiple words share one file
          const hash = oldUrl.split("/").pop()?.replace("_output.mp3", "") ?? word.id;
          const fileName = `lists/${hash}.mp3`;

          const { error: uploadError } = await supabase.storage
            .from("word-audio")
            .upload(fileName, audioBytes, {
              contentType: "audio/mpeg",
              upsert: true,
            });

          if (uploadError) throw new Error(uploadError.message);

          const { data: publicUrlData } = supabase.storage
            .from("word-audio")
            .getPublicUrl(fileName);
          newUrl = publicUrlData.publicUrl;

          migratedUrls.set(oldUrl, newUrl);
          console.log(`Uploaded: ${fileName}`);
        }

        // Preserve ?word= query param for descriptive URL
        const wordParam = word.word ? `?word=${encodeURIComponent(word.word)}` : "";
        const finalUrl = `${newUrl}${wordParam}`;

        const { error: updateError } = await supabase
          .from("vocabulary_words")
          .update({ audio_url: finalUrl })
          .eq("id", word.id);

        if (updateError) throw new Error(updateError.message);

        results.push({ table: "vocabulary_words", id: word.id, oldUrl, newUrl: finalUrl });
      } catch (e) {
        console.error(`Failed word ${word.id}: ${e.message}`);
        errors.push({ table: "vocabulary_words", id: word.id, error: e.message });
      }
    }

    console.log(`Migration complete: ${results.length} migrated, ${errors.length} errors`);

    return new Response(
      JSON.stringify({
        success: true,
        migrated: results.length,
        errors: errors.length,
        uniqueFilesUploaded: migratedUrls.size,
        details: { results, errors },
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
