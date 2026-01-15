import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Le modèle exact que tu as demandé.
// Si cela échoue (erreur 404), essaie "gemini-1.5-flash" ou "gemini-2.0-flash-exp"
const MODEL_NAME = "gemini-2.5-flash-lite-preview-06-17"; 

serve(async (req) => {
  // 1. Gérer le CORS (Navigateur)
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { question, context } = await req.json();
    
    // 2. Récupérer la clé Gemini
    const apiKey = Deno.env.get('GEMINI_API_KEY');
    if (!apiKey) throw new Error("Clé API Gemini manquante dans Supabase");

    // 3. Préparer le prompt (Gemini préfère que le contexte soit dans le message ou system instruction)
    const prompt = `
    Rôle : Tu es l'assistant IA du portfolio d'Assami Baga.
    Objectif : Répondre aux recruteurs de manière professionnelle, courte et amicale.
    
    Règles strictes :
    1. Utilise UNIQUEMENT le contexte JSON ci-dessous pour répondre.
    2. Si l'information n'est pas dans le JSON, dis simplement que tu ne sais pas et propose de contacter Assami.
    3. Ne pas inventer d'expériences.

    CONTEXTE JSON :
    ${JSON.stringify(context)}

    QUESTION DU RECRUTEUR :
    ${question}
    `;

    // 4. Appeler l'API Google Gemini
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
            temperature: 0.4, // Créativité modérée pour rester factuel
            maxOutputTokens: 500,
        }
      })
    });

    const data = await response.json();

    // 5. Gestion des erreurs spécifiques à Gemini
    if (data.error) {
        console.error("Erreur Gemini:", data.error);
        throw new Error(data.error.message || "Erreur API Gemini");
    }

    // 6. Extraction de la réponse (Structure spécifique à Google)
    const reply = data.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!reply) {
        throw new Error("Pas de réponse générée par Gemini");
    }

    return new Response(JSON.stringify({ reply }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});