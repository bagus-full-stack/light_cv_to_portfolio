// supabase/functions/chat-resume/index.ts
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

// 1. Headers CORS complets
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// 2. Liste de priorité des modèles (Copiée de ta demande)
// Le script essaiera le premier, puis le second si le premier échoue, etc.
const MODELS = [
  "gemini-2.5-flash",
  "gemini-2.5-pro",
  "gemini-2.0-flash-exp",
  "gemini-2.0-flash",
  "gemini-2.0-flash-001",
  "gemini-2.0-flash-lite-001",
  "gemini-2.0-flash-lite",
  "gemini-2.0-flash-lite-preview-02-05",
  "gemini-2.0-flash-lite-preview",
  "gemini-exp-1206",
  "gemini-2.5-flash-preview-tts",
  "gemini-2.5-pro-preview-tts",
  "gemma-3-1b-it",
  "gemma-3-4b-it",
  "gemma-3-12b-it",
  "gemma-3-27b-it",
  "gemma-3n-e4b-it",
  "gemma-3n-e2b-it",
  "gemini-flash-latest",
  "gemini-flash-lite-latest",
  "gemini-pro-latest",
  "gemini-2.5-flash-lite",
  "gemini-2.5-flash-image-preview",
  "gemini-2.5-flash-image",
  "gemini-2.5-flash-preview-09-2025",
  "gemini-2.5-flash-lite-preview-09-2025",
  "gemini-3-pro-preview",
  "gemini-3-flash-preview",
  "gemini-3-pro-image-preview",
  "nano-banana-pro-preview",
  // Sécurité ultime : le modèle standard stable si tout le reste échoue
  "gemini-1.5-flash" 
];

Deno.serve(async (req) => {
  
  // === GESTION DU PREFLIGHT (CORS) ===
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // === 1. RECUPERATION DU BODY ===
    let body;
    try {
        body = await req.json();
    } catch (e) {
        throw new Error("Le corps de la requête (Body) est vide ou mal formé.");
    }

    const { question, context } = body;

    // === 2. VÉRIFICATION CLÉ API ===
    const apiKey = Deno.env.get('GEMINI_API_KEY');
    if (!apiKey) {
        console.error("ERREUR CRITIQUE: Clé GEMINI_API_KEY introuvable.");
        throw new Error("Configuration serveur manquante (API Key).");
    }

    // === 3. PRÉPARATION DU PROMPT ===
    const promptText = `
      Tu es un assistant pour le portfolio d'Assami Baga.
      Utilise ce contexte JSON pour répondre de façon courte et professionnelle.
      CONTEXTE : ${JSON.stringify(context)}
      QUESTION : ${question}
    `;

    // === 4. BOUCLE DE TENTATIVES (FALLBACK) ===
    let lastError = null;
    let successData = null;
    let usedModel = "";

    // On boucle sur chaque modèle de la liste
    for (const modelName of MODELS) {
        try {
            console.log(`Tentative avec le modèle : ${modelName}...`);

            const response = await fetch(
              `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${apiKey}`,
              {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                  contents: [{
                    parts: [{ text: promptText }]
                  }]
                })
              }
            );

            const data = await response.json();

            // Si Google renvoie une erreur explicite (ex: 404 Not Found, 429 Quota)
            if (data.error) {
                console.warn(`Échec ${modelName} : ${data.error.message}`);
                lastError = data.error.message;
                // On continue à la prochaine itération de la boucle (modèle suivant)
                continue; 
            }

            // Si on arrive ici, c'est que ça a marché !
            successData = data;
            usedModel = modelName;
            break; // On sort de la boucle, pas besoin de tester les autres

        } catch (err) {
            console.warn(`Erreur réseau avec ${modelName} : ${err.message}`);
            lastError = err.message;
            continue; // On essaie le suivant
        }
    }

    // === 5. RÉSULTAT FINAL ===
    
    // Si après avoir tout testé, on n'a rien
    if (!successData) {
        throw new Error(`Tous les modèles ont échoué. Dernière erreur : ${lastError}`);
    }

    const reply = successData.candidates?.[0]?.content?.parts?.[0]?.text || "Désolé, aucune réponse générée.";
    
    // On ajoute un petit log console pour savoir quel modèle a sauvé la mise
    console.log(`SUCCÈS : Réponse générée avec ${usedModel}`);

    return new Response(JSON.stringify({ reply, model: usedModel }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    console.error("Erreur fatale Edge Function:", error.message);
    
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})