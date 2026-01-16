// supabase/functions/chat-resume/index.ts

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  
  // 1. GESTION DU PREFLIGHT (CORS)
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 2. RECUPERATION DONNÉES
    let body;
    try {
        body = await req.json();
    } catch (e) {
        throw new Error("Body vide ou invalide.");
    }
    const { question, context } = body;

    // 3. RECUPERATION CLÉ API
    const apiKey = Deno.env.get('GEMINI_API_KEY');
    if (!apiKey) {
        throw new Error("Clé API manquante (GEMINI_API_KEY).");
    }

    // 4. PRÉPARATION DU PROMPT
    const promptText = `
      Tu es l'assistant IA du portfolio d'Assami Baga.
      Rôle : Répondre aux questions des recruteurs de manière professionnelle, courte et dynamique.
      
      RÈGLES STRICTES :
      1. Tes réponses doivent être basées UNIQUEMENT sur le contexte JSON ci-dessous.
      2. Si l'information n'est pas dans le CV, dis poliment que tu ne sais pas.
      
      CONTEXTE DU CV : ${JSON.stringify(context)}
      
      QUESTION : ${question}
    `;

    // 5. APPEL GEMINI 2.0 FLASH
    // Utilisation du modèle rapide et économique que tu as choisi
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`,
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

    // 6. GESTION ERREUR GOOGLE
    if (data.error) {
        console.error("Erreur Gemini:", data.error);
        throw new Error(`Erreur Modèle (${data.error.code}): ${data.error.message}`);
    }

    // Extraction de la réponse
    const reply = data.candidates?.[0]?.content?.parts?.[0]?.text || "Désolé, je n'ai pas pu générer de réponse.";

    return new Response(JSON.stringify({ reply }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    console.error("Erreur Serveur:", error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})