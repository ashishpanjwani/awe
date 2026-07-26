const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { GoogleGenAI } = require("@google/genai");
const { defineSecret } = require("firebase-functions/params");
const { google } = require("googleapis");

initializeApp();
const db = getFirestore();

const geminiApiKey = defineSecret("GEMINI_API_KEY");
const unsplashKey = defineSecret("UNSPLASH_ACCESS_KEY");

function getAI() {
  return new GoogleGenAI({ apiKey: geminiApiKey.value() });
}

function utcDayKey(date) {
  const d = date instanceof Date ? date : new Date(date);
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(d.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${dd}`;
}

// ── Scheduled: generate daily wonder at 00:05 UTC ──────────────────────────

exports.generateDailyWonder = onSchedule(
  {
    schedule: "5 10 * * *",
    timeZone: "UTC",
    secrets: [geminiApiKey, unsplashKey],
    timeoutSeconds: 120,
    memory: "512MiB",
    region: "us-central1",
  },
  async () => {
    // Generate for tomorrow's date so the wonder is ready before any timezone hits that midnight.
    const tomorrow = new Date();
    tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
    const key = utcDayKey(tomorrow);
    const docRef = db.collection("daily_wonders").doc(key);
    console.log(`[DailyWonder] Generating for ${key}`);

    // Check if already exists
    const existing = await docRef.get();
    if (existing.exists && existing.data()?.status === "ready") {
      console.log(`[DailyWonder] Already exists for ${key}, skipping`);
      return;
    }

    // Claim the slot
    await docRef.set(
      { status: "generating", createdAt: FieldValue.serverTimestamp() },
      { merge: true }
    );

    try {
      const collectionTitles = await getCollectionWonderTitles();

      // Generate wonder with conflict-check + fact-check retry loop
      let wonder, embedding, checked;
      let avoidHint = null;
      for (let attempt = 1; attempt <= 3; attempt++) {
        wonder = await generateWonder(collectionTitles, key, avoidHint, pickTitleFormat(), pickCategory(), pickEmotion());
        embedding = await getEmbedding(
          `${wonder.title}. ${wonder.subtitle}. ${wonder.curiositySpark}. ${(wonder.tags || []).join(", ")}`
        );
        const conflict =
          (await findSemanticConflict(wonder, embedding)) ||
          (await findConflict(wonder));
        if (conflict) {
          console.log(`[DailyWonder] Conflict on attempt ${attempt}: ${conflict}`);
          avoidHint = conflict;
          continue;
        }
        // Passed duplicate check — verify the core claim is real
        const factResult = await factCheck(wonder);
        if (factResult._shouldReject) {
          console.log(`[DailyWonder] FactCheck rejected on attempt ${attempt}: ${factResult._rejectionHint}`);
          avoidHint = `"${wonder.title}" was rejected — ${factResult._rejectionHint}`;
          continue;
        }
        checked = factResult;
        break;
      }
      if (!checked) checked = wonder; // fallback: use last generated wonder if all 3 attempts failed

      // Fetch image
      const image = await fetchUnsplashImage(checked.imageSearchQuery || "");
      if (image) {
        checked.imageUrl = image.url;
        checked.imageAttribution = image.attribution;
      }

      // Compute related wonder IDs
      checked.relatedWonderIds = await computeRelatedIds(checked);

      // Write to Firestore
      checked.id = key;
      checked.status = "ready";
      checked.createdAt = checked.createdAt || new Date().toISOString();
      checked.updatedAt = FieldValue.serverTimestamp();
      if (embedding) checked.embedding = FieldValue.vector(embedding);

      await docRef.set(checked, { merge: true });
      console.log(`[DailyWonder] Stored: ${checked.title}`);
    } catch (e) {
      console.error(`[DailyWonder] Generation failed:`, e);
      await docRef.set(
        { status: "failed", error: e.message, updatedAt: FieldValue.serverTimestamp() },
        { merge: true }
      );
    }
  }
);

// ── Wonder generation via Vertex AI ───────────────────────────────────────

const _TITLE_FORMATS = ['A', 'B', 'C', 'D', 'E', 'F'];
const _CATEGORIES = ['place', 'tradition', 'taste', 'story', 'sound', 'person'];
const _EMOTIONS = ['awe', 'mystery', 'serenity', 'lost_worlds', 'sacred', 'wild'];

function pickTitleFormat() { return _TITLE_FORMATS[Math.floor(Math.random() * _TITLE_FORMATS.length)]; }
function pickCategory() { return _CATEGORIES[Math.floor(Math.random() * _CATEGORIES.length)]; }
function pickEmotion() { return _EMOTIONS[Math.floor(Math.random() * _EMOTIONS.length)]; }

async function generateWonder(collectionTitles, dateKey, avoidHint = null, titleFormat = pickTitleFormat(), category = pickCategory(), emotion = pickEmotion()) {
  const ai = getAI();

  const avoidTopics = collectionTitles.length ? collectionTitles.join(", ") : "None";
  const hintLine = avoidHint
    ? `- CRITICAL: Do NOT write about ${avoidHint}. This subject was just generated. Choose something in a completely different country and subject.`
    : "";

  const prompt = `System: You are a world-class travel storyteller. Generate ONE extraordinary daily wonder about the world. Write like a storyteller, not a guidebook. Surprise the reader with something they have never heard of.

Rules:
- The category MUST be '${category}' — write a wonder that genuinely fits this category
- The emotion MUST be '${emotion}' — the story must evoke this specific feeling, not just default to wonder
- Avoid these topics (reserved for premium collections): ${avoidTopics}
${hintLine}
- The wonder MUST be tied to a specific real place on Earth (provide accurate lat/lon)
- CRITICAL: The phenomenon, discovery, or story MUST be real and independently documented by credible sources. Do NOT invent legends, myths, ghost stories, or unverifiable narratives. If you cannot cite a real source for the core claim, choose a different wonder.
- Story should be 500-800 words, narrative voice, evocative and specific
- CRITICAL: Break the story into 4-6 short paragraphs separated by \\n\\n. Each paragraph should be 3-5 sentences max. Never write one giant block of text. The first paragraph should hook the reader immediately.
- Include sensory details, historical context, and a sense of wonder
- The "curiositySpark" should be the ONE fact that makes someone want to share this
- Tags should be 3-5 specific keywords (not generic like "travel" or "beautiful")
- "imageSearchQuery": a 3-6 word search query optimized for finding a beautiful, relevant landscape photo on Unsplash. Be specific (e.g., "Lalibela rock hewn church Ethiopia" not just "Lalibela"). For traditions/people/sounds, describe the visual scene rather than the abstract concept.

TITLE — you MUST use Format ${titleFormat} below. No other format is acceptable.
  A) The actual name of the place or phenomenon as locals call it (e.g., "Kawah Ijen", "The Door to Hell", "Blood Falls")
  B) A short, punchy phrase — 2-4 words maximum, no "The [Adjective] [Noun] of" construction (e.g., "Salt and Fire", "One Hundred Years of Ice", "The Last Muezzin")
  C) A specific number or measurement that reframes everything (e.g., "432 Hertz", "Forty Thousand Years", "Seventeen Seconds")
  D) A question or provocation (e.g., "Why Does This Lake Sing?", "Who Built This Road?")
  E) A person's name or a direct quote (e.g., "Salim Ali's Birds", "They Call It the Weeping Wall")
  F) A place name + unexpected juxtaposition (e.g., "Tokyo's Last Rice Farmer", "Mumbai Keeps One Field")
Your title MUST follow Format ${titleFormat}. Never use "The [Adjective/Participle] [Noun] of [Abstract/Place]".

SUBTITLE — one sentence that earns its place. Must NOT start with "Where" or "When". Options:
  - A surprising fact or statistic ("The trees here are older than writing")
  - A sensory hook ("The sand booms like distant thunder")
  - A contradiction ("A desert. But it floods every year.")
  - A specific detail that raises a question ("Locals avoid it after dark — and geologists now understand why")
  - The local name with a translation ("The Inuit call it Siku. The ice that thinks.")

The emotion field MUST be '${emotion}'.

Output ONLY this JSON:
{
  "category": string,
  "emotion": string,
  "title": string,
  "subtitle": string,
  "story": string,
  "curiositySpark": string,
  "place": {
    "name": string,
    "country": string,
    "region": string,
    "lat": number,
    "lon": number
  },
  "tags": [string],
  "imageSearchQuery": string
}`;

  const result = await ai.models.generateContent({
    model: "gemini-3.1-flash-lite",
    contents: prompt,
    config: { responseMimeType: "application/json", temperature: 0.85 },
  });

  const text = result.text;
  if (!text || !text.trim()) throw new Error("Empty response from Gemini");

  const json = tolerantJsonParse(text);
  json.id = dateKey;
  json.createdAt = new Date().toISOString();
  return json;
}

// ── Fact-check with Google Search grounding ────────────────────────────────

// Returns the wonder (with corrections applied) or wonder with _shouldReject=true.
async function factCheck(wonder) {
  try {
    const ai = getAI();

    const prompt = `You are a rigorous fact-checker for a wonder-of-the-world app. Use Google Search to verify this wonder.

Title: ${wonder.title}
Story: ${wonder.story}
Curiosity Spark: ${wonder.curiositySpark}

Step 1 — CORE CLAIM (most important):
Search for the central phenomenon described. Is it independently documented by credible sources (scientific papers, reputable news, museum records, historical archives)?
- A real location with an AI-invented legend = FABRICATED. Reject it.
- A phenomenon that cannot be found in any credible source = FABRICATED. Reject it.
- If search returns nothing supporting the core claim, set shouldReject=true.

Step 2 — ACCURACY (only if core claim is real):
- Are people mentioned still alive / in the role described? Use past tense if uncertain.
- Are claims like "last living", "only remaining", "still exists" still accurate?
- Are key dates, statistics, or historical facts correct?

Output ONLY this JSON (no markdown):
{
  "coreClaimVerifiable": boolean,
  "shouldReject": boolean,
  "rejectionHint": string,
  "story": string,
  "curiositySpark": string,
  "corrections": string
}

- "shouldReject": true if the core phenomenon is fabricated or unverifiable
- "rejectionHint": if shouldReject=true, one sentence on what was wrong and what to avoid
- "story"/"curiositySpark": corrected text, or unchanged if accurate
- "corrections": "none" or brief description of what was fixed`;

    const result = await ai.models.generateContent({
      model: "gemini-3.1-flash-lite",
      contents: prompt,
      config: {
        tools: [{ googleSearch: {} }],
        temperature: 0.1,
      },
    });

    const text = result.text;
    if (!text || !text.trim()) return wonder;

    const checked = tolerantJsonParse(text);
    console.log(`[FactCheck] coreClaimVerifiable: ${checked.coreClaimVerifiable}, shouldReject: ${checked.shouldReject}, corrections: ${checked.corrections || "none"}`);

    if (checked.shouldReject) {
      return { ...wonder, _shouldReject: true, _rejectionHint: checked.rejectionHint || "core phenomenon is unverifiable" };
    }

    if (checked.corrections && checked.corrections.toLowerCase() !== "none") {
      if (checked.story) wonder.story = checked.story;
      if (checked.curiositySpark) wonder.curiositySpark = checked.curiositySpark;
    }
  } catch (e) {
    console.warn(`[FactCheck] Non-fatal error:`, e.message);
  }
  return wonder;
}

// ── Unsplash image fetch ───────────────────────────────────────────────────

async function fetchUnsplashImage(query) {
  if (!query.trim()) { console.warn("[Unsplash] No search query provided"); return null; }
  if (!unsplashKey.value()) { console.warn("[Unsplash] UNSPLASH_ACCESS_KEY secret not set"); return null; }

  try {
    const url = `https://api.unsplash.com/search/photos?query=${encodeURIComponent(query)}&per_page=1&orientation=landscape&content_filter=high`;
    const resp = await fetch(url, {
      headers: { Authorization: `Client-ID ${unsplashKey.value()}` },
    });

    if (!resp.ok) {
      console.warn(`[Unsplash] HTTP ${resp.status} for query "${query}"`);
      return null;
    }
    const data = await resp.json();
    const results = data.results;
    if (!results || !results.length) return null;

    const photo = results[0];
    const imageUrl = photo.urls?.regular || "";
    if (!imageUrl) return null;

    const userName = photo.user?.name || "Unknown";

    // Trigger download tracking
    const downloadLink = photo.links?.download_location;
    if (downloadLink) {
      fetch(downloadLink, {
        headers: { Authorization: `Client-ID ${unsplashKey.value()}` },
      }).catch(() => {});
    }

    console.log(`[Unsplash] Image fetched: ${imageUrl}`);
    return { url: imageUrl, attribution: `Photo by ${userName} on Unsplash` };
  } catch (e) {
    console.warn(`[Unsplash] Error:`, e.message);
    return null;
  }
}

// ── Compute related wonder IDs ─────────────────────────────────────────────

async function computeRelatedIds(wonder) {
  try {
    const snap = await db
      .collection("daily_wonders")
      .where("status", "==", "ready")
      .orderBy("__name__", "desc")
      .limit(60)
      .get();

    const scored = [];
    for (const doc of snap.docs) {
      if (doc.id === wonder.id) continue;
      const d = doc.data();
      let score = 0;
      if (d.category === wonder.category) score += 3;
      if (d.emotion === wonder.emotion) score += 2;
      if (d.place?.country === wonder.place?.country) score += 3;
      if (d.place?.region === wonder.place?.region) score += 2;
      const tags = d.tags || [];
      const wTags = wonder.tags || [];
      for (const t of tags) {
        if (wTags.includes(t)) score += 1;
      }
      if (score > 0) scored.push({ id: doc.id, score });
    }

    scored.sort((a, b) => b.score - a.score);
    return scored.slice(0, 5).map((s) => s.id);
  } catch (e) {
    console.warn(`[Related] Error:`, e.message);
    return [];
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────

const _STOP_WORDS = new Set(["the", "of", "a", "an", "in", "at", "on", "and", "or", "is", "its", "this", "to", "by", "with", "from"]);
function _titleKeywords(title) {
  return (title || "").toLowerCase().split(/\W+/).filter(w => w.length > 3 && !_STOP_WORDS.has(w));
}

async function findConflict(wonder) {
  try {
    const snap = await db.collection("daily_wonders")
      .where("status", "==", "ready")
      .select("place", "tags", "title")
      .get();

    const newCountry = wonder.place?.country;
    const newPlace = wonder.place?.name;
    const newTags = wonder.tags || [];
    const newWords = _titleKeywords(wonder.title);

    for (const doc of snap.docs) {
      if (doc.id === wonder.id) continue;
      const d = doc.data();
      const existingPlace = d.place?.name;
      const existingCountry = d.place?.country;
      const existingTags = d.tags || [];
      const existingWords = _titleKeywords(d.title);

      if (newPlace && existingPlace && newPlace === existingPlace) {
        return `the place "${newPlace}" (already covered in ${doc.id})`;
      }
      // ≥2 significant title words shared = same subject, different framing
      const titleOverlap = newWords.filter(w => existingWords.includes(w));
      if (titleOverlap.length >= 2) {
        return `title too similar to "${d.title}" — shared keywords: ${titleOverlap.join(", ")}`;
      }
      if (newCountry && newCountry === existingCountry) {
        const overlap = newTags.filter(t => existingTags.includes(t));
        if (overlap.length >= 1) {
          return `${newCountry} with topic overlap on: ${overlap.join(", ")}`;
        }
      }
    }
    return null;
  } catch (e) {
    console.warn("[Conflict] Check failed (non-fatal):", e.message);
    return null;
  }
}

// ── Semantic embedding helpers ─────────────────────────────────────────────

function getEmbeddingAI() {
  return new GoogleGenAI({ apiKey: geminiApiKey.value(), apiVersion: "v1" });
}

async function getEmbedding(text) {
  const ai = getEmbeddingAI();
  const result = await ai.models.embedContent({
    model: "gemini-embedding-001",
    contents: text,
    config: { outputDimensionality: 768 },
  });
  return result.embeddings[0].values;
}

const SEMANTIC_THRESHOLD = 0.10;

function cosineDist(a, b) {
  let dot = 0, normA = 0, normB = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  const denom = Math.sqrt(normA) * Math.sqrt(normB);
  return denom === 0 ? 1 : 1 - dot / denom;
}

async function findSemanticConflict(wonder, embedding) {
  const vector = FieldValue.vector(embedding);
  for (const collName of ["daily_wonders", "wonders"]) {
    try {
      const snap = await db
        .collection(collName)
        .findNearest("embedding", vector, {
          limit: 3,
          distanceMeasure: "COSINE",
          distanceResultField: "_dist",
        })
        .get();
      for (const doc of snap.docs) {
        if (doc.id === wonder.id) continue;
        const dist = doc.get("_dist") ?? 1;
        if (dist < SEMANTIC_THRESHOLD) {
          return `topic too similar to "${doc.data().title}" (distance ${dist.toFixed(3)})`;
        }
      }
    } catch (e) {
      console.error(`[SemanticConflict] ${collName} check FAILED — semantic guard skipped:`, e.message, e.stack);
    }
  }
  return null;
}

// ── Callable: Backfill embeddings for existing wonders ────────────────────

exports.backfillEmbeddings = onCall(
  {
    secrets: [geminiApiKey],
    timeoutSeconds: 540,
    memory: "512MiB",
    region: "us-central1",
  },
  async () => {
    let count = 0;
    for (const collName of ["daily_wonders", "wonders"]) {
      const snap = await db.collection(collName).where("status", "==", "ready").get();
      for (const doc of snap.docs) {
        if (doc.data().embedding) continue;
        const d = doc.data();
        const text = `${d.title}. ${d.subtitle}. ${d.curiositySpark}. ${(d.tags || []).join(", ")}`;
        try {
          const emb = await getEmbedding(text);
          await doc.ref.update({ embedding: FieldValue.vector(emb) });
          count++;
          console.log(`[Backfill] ${collName}/${doc.id}: embedded`);
        } catch (e) {
          console.error(`[Backfill] ${collName}/${doc.id} failed:`, e.message, e.stack);
        }
      }
    }
    console.log(`[Backfill] Done. Total embedded: ${count}`);
    return { backfilled: count };
  }
);

async function getAllTitles() {
  try {
    const snap = await db.collection("daily_wonders")
      .where("status", "==", "ready")
      .select("title")
      .get();
    return snap.docs.map(doc => (doc.data().title || "").trim()).filter(t => t.length > 0);
  } catch (e) {
    console.warn("[AllTitles] Error:", e.message);
    return [];
  }
}

async function getCollectionWonderTitles() {
  try {
    const snap = await db.collection("wonders").get();
    return snap.docs
      .map((doc) => (doc.data().title || "").trim())
      .filter((t) => t.length > 0);
  } catch (e) {
    console.warn("[CollectionTitles] Error:", e.message);
    return [];
  }
}

function titleToId(title, placeName) {
  const slug = (s) => s
    .toLowerCase()
    .replace(/^(the|a|an)\s+/i, "")
    .replace(/[^a-z0-9\s]/g, "")
    .trim()
    .replace(/\s+/g, "_");

  // "The Marble Caves of Patagonia" → "marble_caves" + "patagonia"
  const withoutArticle = title.replace(/^the\s+/i, "");
  const ofMatch = withoutArticle.match(/^(.+?)\s+of\s+(the\s+)?(.+)$/i);
  if (ofMatch) {
    return (slug(ofMatch[1]) + "_" + slug(ofMatch[3])).substring(0, 60);
  }

  // No "of" — fall back to title slug + place name
  return (slug(title) + "_" + slug(placeName || "")).replace(/_+$/, "").substring(0, 60);
}

function tolerantJsonParse(raw) {
  let cleaned = raw.replace(/```json/g, "").replace(/```/g, "").trim();
  const start = cleaned.indexOf("{");
  const end = cleaned.lastIndexOf("}");
  if (start !== -1 && end > start) {
    cleaned = cleaned.substring(start, end + 1);
  }
  cleaned = cleaned.replace(/,\s*([}\]])/g, "$1");
  return JSON.parse(cleaned);
}

// ── Callable: Generate Collection Wonders ─────────────────────────────────

exports.generateCollectionWonders = onCall(
  {
    secrets: [geminiApiKey, unsplashKey],
    timeoutSeconds: 540,
    memory: "512MiB",
    region: "us-central1",
  },
  async (request) => {
    const countPerCollection = request.data?.count ?? 3;

    // Gather all titles to avoid (daily + existing collection wonders)
    const [dailyTitles, collectionTitles] = await Promise.all([
      getAllTitles(),
      getCollectionWonderTitles(),
    ]);
    // Running set updated as we add each new wonder during this run
    const usedTitles = new Set([...dailyTitles, ...collectionTitles]);

    const collectionsSnap = await db.collection("collections").get();
    const summary = [];
    const runEmbeddings = []; // in-memory check — catches same-run duplicates before Firestore indexes them

    for (const collectionDoc of collectionsSnap.docs) {
      const col = collectionDoc.data();
      const colId = collectionDoc.id;
      const colTitle = col.title || colId;
      const colDescription = col.description || "";

      console.log(`[CollGen] Processing collection: ${colTitle}`);
      const newIds = [];

      for (let i = 0; i < countPerCollection; i++) {
        let wonder = null;
        let embedding = null;
        let avoidHint = null;

        let accepted = false;
        for (let attempt = 1; attempt <= 3; attempt++) {
          try {
            wonder = await generateCollectionWonder(
              colTitle,
              colDescription,
              [...usedTitles],
              avoidHint,
              pickTitleFormat(),
              pickCategory(),
              pickEmotion()
            );
          } catch (e) {
            console.warn(`[CollGen] Generation error attempt ${attempt}:`, e.message);
            break;
          }

          embedding = await getEmbedding(
            `${wonder.title}. ${wonder.subtitle}. ${wonder.curiositySpark}. ${(wonder.tags || []).join(", ")}`
          );

          // In-memory check against wonders generated earlier in this same run
          // (Firestore indexing delay means findNearest won't find them yet)
          let inRunConflict = null;
          for (const prev of runEmbeddings) {
            const dist = cosineDist(embedding, prev.embedding);
            if (dist < SEMANTIC_THRESHOLD) {
              inRunConflict = `too similar to "${prev.title}" (distance ${dist.toFixed(3)}) — use a completely different metaphor and title structure, not just a different location`;
              break;
            }
          }

          // Semantic check (Firestore) + structural check + in-memory check
          const conflict =
            inRunConflict ||
            (await findSemanticConflict(wonder, embedding)) ||
            (await findConflict(wonder)) ||
            (await findConflictInWonders(wonder));

          if (conflict) {
            console.log(`[CollGen] Conflict attempt ${attempt}: ${conflict}`);
            avoidHint = conflict;
            continue;
          }
          // Passed duplicate check — verify the core claim is real
          const factResult = await factCheck(wonder);
          if (factResult._shouldReject) {
            console.log(`[CollGen] FactCheck rejected on attempt ${attempt}: ${factResult._rejectionHint}`);
            avoidHint = `"${wonder.title}" was rejected — ${factResult._rejectionHint}`;
            continue;
          }
          wonder = factResult;
          accepted = true;
          break;
        }

        if (!wonder || !accepted) {
          console.warn(`[CollGen] Skipping wonder after 3 failed attempts`);
          continue;
        }

        // Fetch image
        const image = await fetchUnsplashImage(wonder.imageSearchQuery || "");
        if (image) {
          wonder.imageUrl = image.url;
          wonder.imageAttribution = image.attribution;
        }

        const wonderRef = db.collection("wonders").doc(titleToId(wonder.title, wonder.place?.name));
        wonder.id = wonderRef.id;
        wonder.status = "ready";
        wonder.collectionId = colId;
        wonder.createdAt = new Date().toISOString();
        wonder.updatedAt = FieldValue.serverTimestamp();
        if (embedding) wonder.embedding = FieldValue.vector(embedding);
        delete wonder.imageSearchQuery;

        await wonderRef.set(wonder);
        newIds.push(wonderRef.id);
        usedTitles.add(wonder.title);
        if (embedding) runEmbeddings.push({ title: wonder.title, embedding });
        console.log(`[CollGen] Added wonder: ${wonder.title}`);
      }

      if (newIds.length > 0) {
        await collectionDoc.ref.update({
          wonderIds: FieldValue.arrayUnion(...newIds),
        });
      }

      summary.push({ collection: colTitle, added: newIds.length });
    }

    console.log(`[CollGen] Done:`, JSON.stringify(summary));
    return { success: true, summary };
  }
);

async function generateCollectionWonder(collectionTitle, collectionDescription, avoidTitles, avoidHint = null, titleFormat = pickTitleFormat(), category = pickCategory(), emotion = pickEmotion()) {
  const ai = getAI();
  const avoidLine = avoidTitles.length ? avoidTitles.join("; ") : "None";
  const hintLine = avoidHint
    ? `- CRITICAL: Your last attempt was REJECTED because it was ${avoidHint}. You MUST change the METAPHOR and TITLE STRUCTURE entirely — do not just swap the location. If the rejected title used a word like "Veins", "Caves", "Lake" etc., avoid that word completely. Pick a different category of wonder altogether.`
    : "";

  const prompt = `System: You are a world-class travel storyteller creating premium content for the curated collection "${collectionTitle}".

Collection theme: ${collectionDescription}

Generate ONE extraordinary wonder that fits this collection's theme perfectly. Write like a storyteller, not a guidebook. This is premium content — go deeper than a surface-level story.

Rules:
- The wonder MUST perfectly match the collection theme: "${collectionTitle}"
- The category MUST be '${category}' — write a wonder that genuinely fits this category
- The emotion MUST be '${emotion}' — the story must evoke this specific feeling, not just default to wonder
- Do NOT repeat or closely paraphrase any of these existing stories: ${avoidLine}
${hintLine}
- The wonder MUST be tied to a specific real place on Earth (provide accurate lat/lon)
- CRITICAL: The phenomenon, discovery, or story MUST be real and independently documented. Do NOT invent legends, myths, or unverifiable narratives.
- Story should be 600-900 words, narrative voice, richly evocative and specific
- CRITICAL: Break the story into 4-6 short paragraphs separated by \\n\\n. Never write one giant block.
- Include deep sensory details, historical context, and a profound sense of wonder
- The "curiositySpark" should be the ONE fact that makes someone want to share this
- Tags should be 3-5 specific keywords (not generic like "travel" or "beautiful")
- "imageSearchQuery": a 3-6 word search query optimized for Unsplash

TITLE — you MUST use Format ${titleFormat} below. No other format is acceptable.
  A) The actual name of the place or phenomenon as locals call it (e.g., "Kawah Ijen", "Blood Falls", "The Door to Hell")
  B) A short punchy phrase — 2-4 words, no "The [Adjective] [Noun] of" construction (e.g., "Salt and Fire", "The Last Muezzin", "One Hundred Years of Ice")
  C) A specific number or measurement (e.g., "432 Hertz", "Forty Thousand Years", "Seventeen Seconds")
  D) A question or provocation (e.g., "Why Does This Lake Sing?", "Who Built This Road?")
  E) A person's name or direct quote (e.g., "Salim Ali's Birds", "They Call It the Weeping Wall")
  F) A place + unexpected juxtaposition (e.g., "Tokyo's Last Rice Farmer", "Mumbai Keeps One Field")
Your title MUST follow Format ${titleFormat}. Never use "The [Adjective/Participle] [Noun] of [Abstract/Place]".

SUBTITLE — one sentence that earns its place. Must NOT start with "Where" or "When". Options:
  - A surprising fact or statistic ("The trees here are older than writing")
  - A sensory hook ("The sand booms like distant thunder")
  - A contradiction ("A desert. But it floods every year.")
  - A specific detail that raises a question ("Locals avoid it after dark — and geologists now understand why")
  - The local name with a translation ("The Inuit call it Siku. The ice that thinks.")

The emotion field MUST be '${emotion}'.

Output ONLY this JSON:
{
  "category": string,
  "emotion": string,
  "title": string,
  "subtitle": string,
  "story": string,
  "curiositySpark": string,
  "place": {
    "name": string,
    "country": string,
    "region": string,
    "lat": number,
    "lon": number
  },
  "tags": [string],
  "imageSearchQuery": string
}`;

  const result = await ai.models.generateContent({
    model: "gemini-3.1-flash-lite",
    contents: prompt,
    config: { responseMimeType: "application/json", temperature: 0.9 },
  });

  const text = result.text;
  if (!text || !text.trim()) throw new Error("Empty response from Gemini");
  return tolerantJsonParse(text);
}

async function findConflictInWonders(wonder) {
  try {
    const snap = await db.collection("wonders")
      .where("status", "==", "ready")
      .select("place", "tags", "title")
      .get();

    const newCountry = wonder.place?.country;
    const newPlace = wonder.place?.name;
    const newTags = wonder.tags || [];
    const newWords = _titleKeywords(wonder.title);

    for (const doc of snap.docs) {
      const d = doc.data();
      const existingPlace = d.place?.name;
      const existingCountry = d.place?.country;
      const existingTags = d.tags || [];
      const existingWords = _titleKeywords(d.title);

      if (newPlace && existingPlace && newPlace === existingPlace) {
        return `the place "${newPlace}" (already in collections)`;
      }
      const titleOverlap = newWords.filter(w => existingWords.includes(w));
      if (titleOverlap.length >= 2) {
        return `title too similar to "${d.title}" — shared keywords: ${titleOverlap.join(", ")}`;
      }
      if (newCountry && newCountry === existingCountry) {
        const overlap = newTags.filter(t => existingTags.includes(t));
        if (overlap.length >= 1) {
          return `${newCountry} with topic overlap on: ${overlap.join(", ")}`;
        }
      }
    }
    return null;
  } catch (e) {
    console.warn("[WonderConflict] Check failed:", e.message);
    return null;
  }
}

// ── On-demand daily wonder generation (Flutter fallback) ─────────────────────
// Called by the Flutter client when the scheduled CF hasn't generated today's wonder yet.
// Runs the exact same pipeline: prompt → embedding → semantic conflict → factcheck → store.

exports.generateDailyWonderOnDemand = onCall(
  {
    secrets: [geminiApiKey, unsplashKey],
    timeoutSeconds: 300,
    memory: "512MiB",
    region: "us-central1",
  },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Must be signed in");
    const { dateKey } = request.data;
    if (!dateKey || typeof dateKey !== "string") throw new HttpsError("invalid-argument", "dateKey required");

    const docRef = db.collection("daily_wonders").doc(dateKey);

    // If already generated (race between client call and scheduled CF), return immediately.
    const existing = await docRef.get();
    if (existing.exists && existing.data()?.status === "ready") {
      console.log(`[OnDemand] Already exists for ${dateKey}, skipping`);
      return { status: "exists" };
    }

    await docRef.set(
      { status: "generating", createdAt: FieldValue.serverTimestamp() },
      { merge: true }
    );

    try {
      const collectionTitles = await getCollectionWonderTitles();

      let wonder, embedding, checked;
      let avoidHint = null;
      for (let attempt = 1; attempt <= 3; attempt++) {
        wonder = await generateWonder(collectionTitles, dateKey, avoidHint, pickTitleFormat());
        embedding = await getEmbedding(
          `${wonder.title}. ${wonder.subtitle}. ${wonder.curiositySpark}. ${(wonder.tags || []).join(", ")}`
        );
        const conflict =
          (await findSemanticConflict(wonder, embedding)) ||
          (await findConflict(wonder));
        if (conflict) {
          console.log(`[OnDemand] Conflict on attempt ${attempt}: ${conflict}`);
          avoidHint = conflict;
          continue;
        }
        const factResult = await factCheck(wonder);
        if (factResult._shouldReject) {
          console.log(`[OnDemand] FactCheck rejected on attempt ${attempt}: ${factResult._rejectionHint}`);
          avoidHint = `"${wonder.title}" was rejected — ${factResult._rejectionHint}`;
          continue;
        }
        checked = factResult;
        break;
      }
      if (!checked) checked = wonder;

      const image = await fetchUnsplashImage(checked.imageSearchQuery || "");
      if (image) {
        checked.imageUrl = image.url;
        checked.imageAttribution = image.attribution;
      }

      checked.relatedWonderIds = await computeRelatedIds(checked);
      checked.id = dateKey;
      checked.status = "ready";
      checked.createdAt = checked.createdAt || new Date().toISOString();
      checked.updatedAt = FieldValue.serverTimestamp();
      if (embedding) checked.embedding = FieldValue.vector(embedding);

      await docRef.set(checked, { merge: true });
      console.log(`[OnDemand] Stored: ${checked.title}`);
      return { status: "generated", title: checked.title };
    } catch (e) {
      console.error(`[OnDemand] Generation failed:`, e);
      await docRef.set(
        { status: "failed", error: e.message, updatedAt: FieldValue.serverTimestamp() },
        { merge: true }
      );
      throw new HttpsError("internal", `Generation failed: ${e.message}`);
    }
  }
);

// ── Verify Play subscription & write accurate dates to Firestore ────────────

exports.verifyPlaySubscription = onCall(
  {},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in");
    }
    const uid = request.auth.uid;
    const { productId, purchaseToken } = request.data;

    if (!productId || !purchaseToken) {
      throw new HttpsError("invalid-argument", "productId and purchaseToken required");
    }

    console.log(`[PlayVerify] uid=${uid}, productId=${productId}`);

    // Uses Application Default Credentials — no JSON key needed.
    // The Cloud Functions runtime service account must be granted
    // Android Publisher API access in Play Console → Setup → API access.
    const auth = new google.auth.GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/androidpublisher"],
    });

    const publisher = google.androidpublisher({ version: "v3", auth });

    let sub;
    try {
      const res = await publisher.purchases.subscriptions.get({
        packageName: "com.feelsgood.awe",
        subscriptionId: productId,
        token: purchaseToken,
      });
      sub = res.data;
    } catch (e) {
      console.error("[PlayVerify] Play API error:", e.message);
      throw new HttpsError("internal", "Failed to fetch subscription from Play");
    }

    const expiryMs = parseInt(sub.expiryTimeMillis, 10);
    const paymentState = sub.paymentState ?? 1;
    const isInTrial = paymentState === 2;
    const type = productId === "awe_premium_annual" ? "annual" : "monthly";

    console.log(`[PlayVerify] expiryMs=${expiryMs}, paymentState=${paymentState}, isInTrial=${isInTrial}, type=${type}`);

    await db.collection("users").doc(uid).set({
      isPremium: true,
      subscriptionType: type,
      purchaseToken,
      subscriptionExpiry: Timestamp.fromMillis(expiryMs),
      isOnTrial: isInTrial,
    }, { merge: true });

    console.log(`[PlayVerify] Firestore updated — uid=${uid}`);

    return { expiryTimeMillis: expiryMs, isInTrial, subscriptionType: type };
  }
);
