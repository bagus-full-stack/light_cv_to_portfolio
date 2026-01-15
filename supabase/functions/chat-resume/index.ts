// supabase/functions/chat-resume/index.ts

// 1. Headers CORS complets (Indispensable)
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// 2. Utilisation de Deno.serve (Natif, pas d'import nécessaire)
Deno.serve(async (req) => {
  
  // === GESTION DU PREFLIGHT (CORS) ===
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // === VÉRIFICATION DU BODY ===
    // Si le frontend n'envoie pas de JSON valide, ça plante ici
    let body;
    try {
        body = await req.json();
    } catch (e) {
        throw new Error("Le corps de la requête (Body) est vide ou mal formé.");
    }

    const { question, context } = body;

    // === VÉRIFICATION CLÉ API ===
    const apiKey = Deno.env.get('GEMINI_API_KEY');
    if (!apiKey) {
        // On loggue l'erreur pour la voir dans le dashboard Supabase
        console.error("ERREUR CRITIQUE: La clé GEMINI_API_KEY est introuvable.");
        throw new Error("Configuration serveur manquante (API Key).");
    }

    // === APPEL GEMINI (Google) ===
    // Utilisation du modèle stable 1.5-flash
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{
            parts: [{ 
                text: `Tu es un assistant pour le portfolio d'Assami Baga. Utilise ce contexte JSON pour répondre : ${JSON.stringify(context)}. Question : ${question}` 
            }]
          }]
        })
      }
    );

    const data = await response.json();

    // Vérification d'erreur Google
    if (data.error) {
        console.error("Erreur Google API:", data.error);
        throw new Error(`Erreur IA: ${data.error.message}`);
    }

    const reply = data.candidates?.[0]?.content?.parts?.[0]?.text || "Désolé, je n'ai pas de réponse.";

    // === SUCCÈS ===
    return new Response(JSON.stringify({ reply }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    // === GESTION D'ERREUR GLOBALE ===
    // On capture TOUT pour éviter le crash serveur et renvoyer du JSON au frontend
    console.error("Erreur dans la fonction:", error.message);
    
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500, // Erreur serveur, mais gérée proprement
    })
  }
})