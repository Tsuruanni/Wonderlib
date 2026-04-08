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

    const prompt = `You are an English vocabulary assistant for a children's English learning app (ages 6-12, Turkish students).

Given the English word or phrase "${word}", provide the following data in JSON format:

{
  "phonetic": "IPA phonetic transcription (e.g. /ˈæp.əl/)",
  "part_of_speech": "one of: noun, verb, adjective, adverb, pronoun, preposition, conjunction, interjection, article, determiner, phrase",
  "meaning_tr": "Turkish meaning (1-2 words, e.g. 'elma', 'koşmak', 'büyük')",
  "meaning_en": "Ultra-short hint-style definition (3-6 words max, like a clue, e.g. 'a flying vehicle', 'the opposite of right', 'close in distance', 'a place to buy things', 'the season after winter')",
  "example_sentences": ["3 simple example sentences a child would understand"]
}

Rules:
- Use the MOST COMMON meaning of the word
- meaning_tr: 1-2 words MAX (e.g. "dudak" not "ağzın kenarındaki etli kısım")
- meaning_en: Write like a hint or clue, NOT a dictionary definition. Maximum 6 words. Think "what is it?" style answers.
- Example sentences: short, natural, age-appropriate
- Phonetic: proper IPA notation
- If the input contains spaces (it's a phrase), set part_of_speech to "phrase"
- Return ONLY valid JSON, no markdown`;

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
