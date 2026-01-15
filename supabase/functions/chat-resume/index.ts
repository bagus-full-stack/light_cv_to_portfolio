// supabase/functions/chat-resume/index.ts
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// J'ai mis "gemini-1.5-flash" car c'est la version stable, rapide et gratuite actuelle.
// Si tu veux absolument tester la 2.0, remplace par "gemini-2.0-flash-exp"
const MODEL_NAME = "gemini-1.5-flash"; 

Deno.serve(async (req) => {
  // 1. Gérer le Preflight CORS (Navigateur)
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 2. Récupérer les données du Frontend
    const { question, context } = await req.json();

    // 3. Récupérer la clé API Gemini
    // Assure-toi d'avoir fait : supabase secrets set GEMINI_API_KEY=ta_cle
    const apiKey = Deno.env.get('GEMINI_API_KEY');
    if (!apiKey) {
      throw new Error("Clé API Gemini manquante dans les secrets Supabase (GEMINI_API_KEY)");
    }

    // 4. Préparer le prompt optimisé
    const prompt = `
    Rôle : Tu es l'assistant IA du portfolio d'Assami Baga.
    Ton job : Répondre aux recruteurs.
    Ton ton : Professionnel, enthousiaste, concis (max 3 phrases si possible).
    
    RÈGLES STRICTES :
    1. Base-toi UNIQUEMENT sur le CONTEXTE JSON fourni ci-dessous.
    2. Si l'info n'est pas dans le contexte, dis poliment : "Je ne trouve pas cette info dans le CV, mais vous pouvez contacter Assami directement."
    3. Ne pas inventer (halluciner) de compétences.
    4. Réponds dans la même langue que la question (Français par défaut).

    CONTEXTE DU CV (JSON) :
    ${JSON.stringify(context)}

    QUESTION UTILISATEUR :
    ${question}
    `;

    // 5. Appeler l'API Google Gemini
    // Documentation : https://ai.google.dev/api/rest/v1beta/models/generateContent
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL_NAME}:generateContent?key=${apiKey}`;
    
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        contents: [{
          parts: [{ text: prompt }]
        }],
        generationConfig: {
            temperature: 0.3, // Bas pour éviter les hallucinations
            maxOutputTokens: 500,
        }
      })
    });

    const data = await response.json();

    // 6. Gestion des erreurs renvoyées par Google
    if (data.error) {
        console.error("Erreur API Gemini:", data.error);
        throw new Error(`Erreur Gemini: ${data.error.message}`);
    }

    // 7. Extraction de la réponse
    const reply = data.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!reply) {
        throw new Error("Gemini a répondu mais n'a généré aucun texte.");
    }

    // 8. Succès
    return new Response(JSON.stringify({ reply }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200
    });

  } catch (error) {
    console.error("Erreur Backend:", error);
    // On renvoie l'erreur au format JSON avec les bons headers CORS
    // pour que le frontend puisse l'afficher proprement
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});