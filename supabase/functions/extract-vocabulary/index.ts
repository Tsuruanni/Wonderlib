import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type CEFRLevel = "a1" | "a2" | "b1" | "b2" | "c1" | "c2";

interface ExtractVocabularyRequest {
  text: string;
  chapterId?: string;
  bookId?: string;
  difficulty?: CEFRLevel;
  maxWords?: number;
  saveToDb?: boolean;
  extractAll?: boolean; // Extract ALL unique words (context-aware)
}

interface ExtractedWord {
  word: string;
  partOfSpeech: string;
  meaningEn: string;
  meaningTr: string;
  exampleSentence?: string;
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body: ExtractVocabularyRequest = await req.json();

    // Input validation
    if (!body.text?.trim()) {
      return new Response(
        JSON.stringify({ error: "text is required and cannot be empty" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Text length limit (prevent token abuse)
    if (body.text.length > 50000) {
      return new Response(
        JSON.stringify({
          error: "text exceeds maximum length of 50000 characters",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const difficulty = body.difficulty || "b1";
    const maxWords = Math.min(body.maxWords || 20, 50); // Cap at 50
    const saveToDb = body.saveToDb || false;
    const extractAll = body.extractAll || false;

    // Gemini API call
    const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
    if (!GEMINI_API_KEY) {
      throw new Error("GEMINI_API_KEY not configured");
    }

    let words: ExtractedWord[];

    if (extractAll) {
      // EXTRACT ALL MODE: Get all unique words with context-aware definitions
      console.log("Extract All mode: analyzing all unique words...");

      const uniqueWords = extractUniqueWords(body.text);
      console.log(`Found ${uniqueWords.length} unique words (stopwords filtered)`);

      if (uniqueWords.length === 0) {
        words = [];
      } else {
        // Process in batches of 25 words
        const batches = chunkArray(uniqueWords, 25);
        console.log(`Processing ${batches.length} batches...`);

        const allResults: ExtractedWord[] = [];

        for (let i = 0; i < batches.length; i++) {
          const batch = batches[i];
          console.log(`Processing batch ${i + 1}/${batches.length} (${batch.length} words)...`);

          const prompt = buildContextAwarePrompt(batch, body.text);
          const result = await callGemini(GEMINI_API_KEY, prompt);

          if (result && result.length > 0) {
            allResults.push(...result);
          }

          // Small delay between batches to avoid rate limiting
          if (i < batches.length - 1) {
            await new Promise(resolve => setTimeout(resolve, 500));
          }
        }

        words = allResults;
        console.log(`Total extracted: ${words.length} words`);
      }
    } else {
      // STANDARD MODE: Extract top N important words
      const prompt = buildPrompt(body.text, difficulty, maxWords);
      console.log(`Extracting ${maxWords} words at ${difficulty} level...`);

      words = await callGemini(GEMINI_API_KEY, prompt) || [];
      console.log(`Extracted ${words.length} words`);
    }

    // Optional: Save to DB
    let savedCount = 0;
    let skippedCount = 0;
    if (saveToDb && words.length > 0) {
      const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
      const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
      const supabase = createClient(supabaseUrl, supabaseKey);

      // Multi-meaning support: Insert each word-meaning pair as separate row
      // UNIQUE(word, meaning_tr) constraint prevents exact duplicates
      // Same word with different meaning = new row (merge, not override)
      for (const word of words) {
        try {
          // Check if exact same word+meaning combo already exists
          const { data: existing } = await supabase
            .from("vocabulary_words")
            .select("id")
            .eq("word", word.word.toLowerCase())
            .eq("meaning_tr", word.meaningTr)
            .maybeSingle();

          if (existing) {
            // Same word with same meaning already exists - skip
            skippedCount++;
            continue;
          }

          // Insert new word-meaning row (allows same word with different meanings)
          const { error } = await supabase
            .from("vocabulary_words")
            .insert({
              word: word.word.toLowerCase(),
              part_of_speech: word.partOfSpeech,
              meaning_tr: word.meaningTr,
              meaning_en: word.meaningEn,
              source_book_id: body.bookId || null,
              example_sentences: word.exampleSentence ? [word.exampleSentence] : [],
            });

          if (!error) savedCount++;
          else console.warn(`Insert failed for "${word.word}":`, error.message);
        } catch (e) {
          console.warn(`Error processing "${word.word}":`, e);
        }
      }

      console.log(`Saved ${savedCount}/${words.length} words to DB (${skippedCount} duplicates skipped)`);
    }

    return new Response(
      JSON.stringify({ success: true, words, savedCount }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
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

// Common English stopwords to filter out
const STOPWORDS = new Set([
  // Articles
  "a", "an", "the",
  // Pronouns
  "i", "you", "he", "she", "it", "we", "they", "me", "him", "her", "us", "them",
  "my", "your", "his", "its", "our", "their", "mine", "yours", "hers", "ours", "theirs",
  "this", "that", "these", "those", "who", "whom", "which", "what", "whose",
  // Common verbs
  "be", "is", "am", "are", "was", "were", "been", "being",
  "have", "has", "had", "having",
  "do", "does", "did", "doing", "done",
  "will", "would", "shall", "should", "may", "might", "must", "can", "could",
  "get", "got", "getting", "go", "goes", "went", "going", "gone",
  "come", "comes", "came", "coming", "make", "makes", "made", "making",
  "take", "takes", "took", "taking", "taken", "say", "says", "said", "saying",
  "see", "sees", "saw", "seeing", "seen", "know", "knows", "knew", "knowing", "known",
  // Prepositions
  "in", "on", "at", "to", "for", "of", "with", "by", "from", "up", "down",
  "into", "onto", "out", "over", "under", "about", "through", "between", "after", "before",
  // Conjunctions
  "and", "but", "or", "nor", "so", "yet", "because", "although", "if", "when", "while",
  // Adverbs
  "not", "no", "yes", "very", "just", "only", "also", "too", "then", "now", "here", "there",
  "always", "never", "often", "sometimes", "still", "already", "again",
  // Other common words
  "all", "some", "any", "many", "much", "more", "most", "few", "less", "least",
  "other", "another", "such", "same", "different", "each", "every", "both", "either", "neither",
  "one", "two", "three", "first", "last", "new", "old", "good", "bad", "great", "little", "big",
  "own", "right", "left", "back", "long", "way", "thing", "things", "time", "year", "day",
  "man", "woman", "people", "person", "hand", "part", "place", "case", "week", "work",
  // Contractions (base forms)
  "don", "doesn", "didn", "won", "wouldn", "can", "couldn", "shouldn", "isn", "aren", "wasn", "weren",
]);

/**
 * Extract unique words from text, filtering stopwords
 */
function extractUniqueWords(text: string): string[] {
  // Extract words (letters only, at least 3 chars)
  const wordPattern = /\b[a-zA-Z]{3,}\b/g;
  const matches = text.match(wordPattern) || [];

  // Lowercase and filter stopwords
  const uniqueWords = new Set<string>();
  for (const word of matches) {
    const lower = word.toLowerCase();
    if (!STOPWORDS.has(lower)) {
      uniqueWords.add(lower);
    }
  }

  return Array.from(uniqueWords).sort();
}

/**
 * Split array into chunks
 */
function chunkArray<T>(array: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < array.length; i += size) {
    chunks.push(array.slice(i, i + size));
  }
  return chunks;
}

/**
 * Build context-aware prompt for batch of words
 */
function buildContextAwarePrompt(words: string[], fullText: string): string {
  // Truncate text if too long (keep first 8000 chars for context)
  const contextText = fullText.length > 8000 ? fullText.substring(0, 8000) + "..." : fullText;

  return `You are a vocabulary assistant for English learners (native Turkish speakers).

Below is a text and a list of words extracted from that text. For EACH word, provide its meaning AS USED IN THIS SPECIFIC CONTEXT.

CRITICAL RULES:
- The definition MUST match how the word is used in the text
- If "bank" appears near a river, define as "river edge/shore", NOT "financial institution"
- If "run" is in "run a business", define as "manage/operate", NOT "move quickly on foot"
- Look at the surrounding context to determine the correct meaning

For each word provide:
1. word: The exact word (lowercase)
2. partOfSpeech: noun, verb, adjective, adverb, etc.
3. meaningEn: Clear English definition (as used in this context)
4. meaningTr: Turkish translation (as used in this context)
5. exampleSentence: The sentence from the text where this word appears

TEXT (for context):
${contextText}

WORDS TO DEFINE (provide definition for ALL of these):
${words.join(", ")}

Return ONLY valid JSON array, no markdown:
[{"word": "...", "partOfSpeech": "...", "meaningEn": "...", "meaningTr": "...", "exampleSentence": "..."}]`;
}

/**
 * Call Gemini API and parse response
 */
async function callGemini(apiKey: string, prompt: string): Promise<ExtractedWord[] | null> {
  try {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.2,
            maxOutputTokens: 8192,
          },
        }),
      }
    );

    if (!response.ok) {
      const errorText = await response.text();
      console.error("Gemini API error:", errorText);
      return null;
    }

    const data = await response.json();
    const responseText = data.candidates?.[0]?.content?.parts?.[0]?.text || "";

    // Parse JSON (handle markdown code blocks)
    const jsonStr = responseText.replace(/```json\n?|\n?```/g, "").trim();

    try {
      return JSON.parse(jsonStr);
    } catch (parseError) {
      console.error("JSON parse error:", parseError);
      console.error("Raw response:", jsonStr.substring(0, 300));
      return null;
    }
  } catch (error) {
    console.error("Gemini call failed:", error);
    return null;
  }
}

function buildPrompt(
  text: string,
  difficulty: string,
  maxWords: number
): string {
  return `You are a vocabulary extraction assistant for English learners (native Turkish speakers).

Analyze the following text and extract the ${maxWords} most important vocabulary words for a ${difficulty.toUpperCase()} level learner.

For each word, provide:
1. word: The base form (lemma)
2. partOfSpeech: noun, verb, adjective, adverb, preposition, conjunction, pronoun, interjection
3. meaningEn: Clear, simple English definition
4. meaningTr: Turkish translation
5. exampleSentence: A sentence from the text containing this word

Rules:
- Extract exactly ${maxWords} words (or fewer if text is short)
- Prioritize words that a Turkish speaker might not know
- Skip very common words (the, is, are, have, do, make, go, come, get, etc.)
- Include phrasal verbs as single entries (e.g., "look after")
- For verbs, use infinitive form without "to"

Return ONLY valid JSON array, no markdown or explanation:
[{"word": "example", "partOfSpeech": "noun", "meaningEn": "...", "meaningTr": "...", "exampleSentence": "..."}]

TEXT:
${text}`;
}
