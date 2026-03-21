import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface GenerateWordDataRequest {
  word: string;
}

interface GeneratedWordData {
  phonetic: string;
  part_of_speech: string;
  meaning_tr: string;
  meaning_en: string;
  example_sentences: string[];
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body: GenerateWordDataRequest = await req.json();

    if (!body.word?.trim()) {
      return new Response(
        JSON.stringify({ error: "word is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const word = body.word.trim().toLowerCase();

    const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
    if (!GEMINI_API_KEY) {
      return new Response(
        JSON.stringify({ error: "GEMINI_API_KEY not configured" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const prompt = `You are an English language dictionary assistant for Turkish students learning English (K-12).

Given the English word "${word}", provide the following data in JSON format:

{
  "phonetic": "IPA phonetic transcription (e.g. /ˈæp.əl/)",
  "part_of_speech": "one of: noun, verb, adjective, adverb, pronoun, preposition, conjunction, interjection, article, determiner",
  "meaning_tr": "Turkish meaning (concise, 1-2 words preferred, max 1 sentence)",
  "meaning_en": "English definition (simple, clear, suitable for language learners)",
  "example_sentences": ["3 example sentences using the word in natural context, suitable for K-12 students"]
}

Rules:
- Use the MOST COMMON meaning/usage of the word
- Keep Turkish meaning concise (e.g. "elma" not "yuvarlak, kırmızı veya yeşil kabuklu meyve")
- Example sentences should be simple, natural, and educational
- Phonetic must be proper IPA notation
- Return ONLY valid JSON, no markdown or explanation`;

    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GEMINI_API_KEY}`;

    const geminiResponse = await fetch(geminiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.3,
          maxOutputTokens: 1024,
          responseMimeType: "application/json",
        },
      }),
    });

    if (!geminiResponse.ok) {
      const errorText = await geminiResponse.text();
      return new Response(
        JSON.stringify({ error: `Gemini API error: ${errorText}` }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const geminiData = await geminiResponse.json();

    const rawText =
      geminiData?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";

    if (!rawText) {
      return new Response(
        JSON.stringify({ error: "Empty response from Gemini" }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Parse JSON (strip markdown fences if present)
    const jsonStr = rawText.replace(/```json\s*/g, "").replace(/```\s*/g, "").trim();
    const parsed: GeneratedWordData = JSON.parse(jsonStr);

    // Validate required fields
    const result: GeneratedWordData = {
      phonetic: parsed.phonetic || "",
      part_of_speech: parsed.part_of_speech || "noun",
      meaning_tr: parsed.meaning_tr || "",
      meaning_en: parsed.meaning_en || "",
      example_sentences: Array.isArray(parsed.example_sentences)
        ? parsed.example_sentences.filter((s) => typeof s === "string" && s.trim())
        : [],
    };

    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message || "Unknown error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
