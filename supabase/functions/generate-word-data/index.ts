import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { getApiConfig } from '../_shared/api_config.ts'

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface GeneratedWordData {
  word: string;
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
    const body = await req.json();

    // Support both single word and batch: { word: "apple" } or { words: ["apple", "run"] }
    const words: string[] = body.words
      ? (body.words as string[]).map((w: string) => w.trim().toLowerCase()).filter((w: string) => w.length > 0)
      : body.word?.trim()
        ? [body.word.trim().toLowerCase()]
        : [];

    if (words.length === 0) {
      return new Response(
        JSON.stringify({ error: "word or words is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const GEMINI_API_KEY = await getApiConfig("gemini_api_key", "GEMINI_API_KEY");
    if (!GEMINI_API_KEY) {
      return new Response(
        JSON.stringify({ error: "Gemini API key not configured (env or system_settings)" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const isBatch = words.length > 1;

    const prompt = isBatch
      ? `You are an English vocabulary assistant for a children's English learning app (ages 6-12, Turkish students).

Given these English words/phrases, provide data for EACH one as a JSON array:

Words: ${JSON.stringify(words)}

For each word, return an object with these fields:
{
  "word": "the original word",
  "phonetic": "IPA phonetic transcription (e.g. /ˈæp.əl/)",
  "part_of_speech": "one of: noun, verb, adjective, adverb, pronoun, preposition, conjunction, interjection, article, determiner, phrase",
  "meaning_tr": "Turkish meaning (1-2 words)",
  "meaning_en": "Ultra-short hint-style definition (3-6 words max)",
  "example_sentences": ["3 simple example sentences"]
}

Rules:
- Return a JSON ARRAY with one object per word, in the same order as the input
- Use the MOST COMMON meaning of each word
- meaning_tr: 1-3 words MAX. For verbs use infinitive with -mek/-mak (e.g. "koşmak" not "koş"). For phrases containing verbs, include the infinitive form (e.g. "bahçede oynamak" not "bahçede oyna")
- meaning_en: Write like a hint or clue, NOT a dictionary definition. Maximum 6 words.
- Example sentences: short, natural, age-appropriate
- Phonetic: proper IPA notation
- If a word contains spaces (it's a phrase), set part_of_speech to "phrase"
- Return ONLY valid JSON array, no markdown`
      : `You are an English vocabulary assistant for a children's English learning app (ages 6-12, Turkish students).

Given the English word or phrase "${words[0]}", provide the following data in JSON format:

{
  "phonetic": "IPA phonetic transcription (e.g. /ˈæp.əl/)",
  "part_of_speech": "one of: noun, verb, adjective, adverb, pronoun, preposition, conjunction, interjection, article, determiner, phrase",
  "meaning_tr": "Turkish meaning (1-2 words, e.g. 'elma', 'koşmak', 'büyük')",
  "meaning_en": "Ultra-short hint-style definition (3-6 words max, like a clue, e.g. 'a flying vehicle', 'the opposite of right', 'close in distance', 'a place to buy things', 'the season after winter')",
  "example_sentences": ["3 simple example sentences a child would understand"]
}

Rules:
- Use the MOST COMMON meaning of the word
- meaning_tr: 1-3 words MAX. For verbs use infinitive with -mek/-mak (e.g. "koşmak" not "koş", "bahçede oynamak" not "bahçede oyna")
- meaning_en: Write like a hint or clue, NOT a dictionary definition. Maximum 6 words. Think "what is it?" style answers.
- Example sentences: short, natural, age-appropriate
- Phonetic: proper IPA notation
- If the input contains spaces (it's a phrase), set part_of_speech to "phrase"
- Return ONLY valid JSON, no markdown`;

    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GEMINI_API_KEY}`;

    console.log(`Generating data for ${words.length} word(s): ${words.join(", ")}`);

    const geminiResponse = await fetch(geminiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.3,
          maxOutputTokens: isBatch ? 4096 : 1024,
          responseMimeType: "application/json",
        },
      }),
    });

    if (!geminiResponse.ok) {
      const errorText = await geminiResponse.text();
      console.error(`Gemini API error: ${geminiResponse.status} - ${errorText}`);
      return new Response(
        JSON.stringify({ error: `Gemini API error: ${geminiResponse.status}` }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const geminiData = await geminiResponse.json();
    const rawText = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";

    if (!rawText) {
      console.error("Empty Gemini response");
      return new Response(
        JSON.stringify({ error: "Empty response from Gemini" }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const jsonStr = rawText.replace(/```json\s*/g, "").replace(/```\s*/g, "").trim();
    const parsed = JSON.parse(jsonStr);

    if (isBatch) {
      // Batch: return array of results
      const results: GeneratedWordData[] = (Array.isArray(parsed) ? parsed : [parsed]).map(
        (item: any, index: number) => ({
          word: item.word || words[index] || "",
          phonetic: item.phonetic || "",
          part_of_speech: item.part_of_speech || "noun",
          meaning_tr: item.meaning_tr || "",
          meaning_en: item.meaning_en || "",
          example_sentences: Array.isArray(item.example_sentences)
            ? item.example_sentences.filter((s: string) => typeof s === "string" && s.trim())
            : [],
        })
      );

      console.log(`Generated data for ${results.length} words`);

      return new Response(JSON.stringify({ results }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    } else {
      // Single word: return flat object (backwards compatible)
      const result = {
        phonetic: parsed.phonetic || "",
        part_of_speech: parsed.part_of_speech || "noun",
        meaning_tr: parsed.meaning_tr || "",
        meaning_en: parsed.meaning_en || "",
        example_sentences: Array.isArray(parsed.example_sentences)
          ? parsed.example_sentences.filter((s: string) => typeof s === "string" && s.trim())
          : [],
      };

      return new Response(JSON.stringify(result), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
  } catch (error) {
    console.error(`generate-word-data error: ${error.message}`);
    return new Response(
      JSON.stringify({ error: error.message || "Unknown error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
