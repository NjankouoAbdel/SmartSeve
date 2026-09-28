/**
 * Serveur du systeme multi-agent "conseiller financier" de SmartSave.
 *
 * Pourquoi un serveur (Cloud Function) et pas juste du code dans l'app
 * Flutter directement ? Parce que l'appel a l'IA (Groq) a besoin d'une cle
 * secrete, et une cle secrete ne doit JAMAIS etre mise dans une app mobile
 * (n'importe qui pourrait la recuperer et l'utiliser a la place de
 * l'utilisateur). Le telephone envoie donc sa question ici, ce serveur
 * fait le travail sensible, et ne renvoie que la reponse texte au
 * telephone.
 *
 * Ce fichier implemente 2 des "agents" du systeme decrits pour
 * l'utilisateur :
 *
 *  - L'AGENT MEMOIRE : `findRelevantArchiveEntries()` va chercher, dans
 *    l'archive Firestore de l'utilisateur (chaque reçu/relevé scanne y
 *    est deja enregistre par l'app, voir financial_advisor_service.dart
 *    cote Flutter), les documents les plus pertinents pour la question
 *    posee. C'est une recherche simple par mots-cles (pas d'IA, pas de
 *    cout supplementaire) : suffisante pour un historique personnel de
 *    quelques centaines de documents.
 *
 *  - L'AGENT CONSEILLER : `callGroq()` envoie la question + le resume
 *    financier de l'utilisateur + ce que l'agent memoire a retrouve, a un
 *    modele de langage (Groq/Llama), avec pour consigne de jouer le role
 *    d'un conseiller financier personnel. C'est lui qui redige la vraie
 *    reponse.
 *
 * Le 3e agent (l'agent d'ingestion, qui archive chaque document scanne)
 * vit cote application Flutter : voir
 * lib/core/services/financial_advisor_service.dart,
 * methode `archiveScannedDocument`.
 *
 * Ce fichier implemente egalement 3 agents supplementaires, ajoutes pour
 * rendre le systeme proactif (il ne se contente plus de repondre aux
 * questions, il surveille et resume tout seul) :
 *
 *  - L'AGENT ANOMALIES (`detectExpenseAnomaly`) : se declenche automatiquement
 *    a chaque nouvelle depense enregistree, compare son montant a
 *    l'historique de l'utilisateur et signale les depenses inhabituelles ou
 *    les doublons probables.
 *
 *  - L'AGENT RESUME MENSUEL (`monthlySummaryAgent`) : s'execute chaque jour,
 *    et redige automatiquement (via l'IA) un resume du mois precedent des
 *    qu'un nouveau mois commence.
 *
 *  - L'AGENT DE CATEGORISATION (`categorizeTransactions`) : appele par l'app
 *    Flutter juste apres un scan (reçu ou relevé), il utilise l'IA pour
 *    deviner la categorie de chaque transaction a partir de sa description,
 *    en complement (et non en remplacement) de la devinette locale par
 *    mots-cles deja en place.
 *
 * Les 2 premiers agents ne renvoient rien a l'app : ils ecrivent directement
 * un message dans `users/{uid}/advisor_chat` (la meme collection que la
 * conversation avec l'agent conseiller), avec un champ `origin` qui indique
 * quel agent l'a ecrit. C'est le canal choisi plutot que le systeme de
 * notices existant (`meta/tools`), car celui-ci stocke toutes les notices
 * dans UN SEUL document remplace en entier a chaque sauvegarde cote app :
 * un agent serveur qui ecrirait dedans en parallele risquerait d'ecraser ou
 * d'etre ecrase par une sauvegarde du telephone. `advisor_chat` cree un
 * document par message, donc aucun risque de collision.
 */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {defineSecret} = require("firebase-functions/params");
const {setGlobalOptions} = require("firebase-functions/v2");
const logger = require("firebase-functions/logger");
// Depuis firebase-admin v12+, le SDK est "modulaire" : plus d'objet
// global admin.firestore(), on importe directement ce dont on a besoin.
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

initializeApp();
const db = getFirestore();

// Region proche des utilisateurs europeens/maghrebins par defaut ; a
// adapter si besoin (doit rester coherente avec le reste du projet
// Firebase, mais un changement ici n'affecte que cette fonction).
setGlobalOptions({region: "europe-west1"});

// La cle API Groq n'est JAMAIS ecrite dans ce fichier ni dans le depot
// Git : elle est configuree une seule fois via
//   firebase functions:secrets:set GROQ_API_KEY
// et Firebase la fournit a la fonction au moment de l'execution, de
// maniere chiffree. Voir le guide de deploiement fourni a part.
const GROQ_API_KEY = defineSecret("GROQ_API_KEY");

// Modele Groq utilise pour generer les reponses. "versatile" = bon
// compromis qualite/vitesse pour un usage de conseiller financier.
// Alternative plus rapide/moins couteuse si besoin : "llama-3.1-8b-instant".
const GROQ_MODEL = "llama-3.3-70b-versatile";
const GROQ_ENDPOINT = "https://api.groq.com/openai/v1/chat/completions";

// Combien de documents d'archive au maximum sont relus a chaque question
// (pour ne pas surcharger le prompt envoye a l'IA, ni le temps de reponse).
const MAX_ARCHIVE_DOCS_TO_SCAN = 60;
const MAX_ARCHIVE_DOCS_IN_CONTEXT = 5;
const MAX_CHARS_PER_ARCHIVE_ENTRY = 500;

// Categories valides cote app (voir lib/domain/entities/expense.dart,
// enum ExpenseCategory) : l'agent de categorisation ne doit JAMAIS renvoyer
// une valeur en dehors de cette liste, sinon l'app ne saurait pas quoi en
// faire.
const ALLOWED_CATEGORY_KEYS = [
  "food", "transport", "rent", "shopping", "bills", "other",
];

// --- Reglages de l'agent anomalies ---
// Il faut au moins ce nombre de depenses comparables (meme categorie, meme
// compte) avant de calculer une "moyenne habituelle" fiable : en dessous,
// un montant "different" n'est pas forcement une anomalie, juste un debut
// d'historique.
const ANOMALY_MIN_SAMPLES = 4;
// Une depense est jugee inhabituelle si elle depasse la moyenne habituelle
// multipliee par ce facteur.
const ANOMALY_RATIO_THRESHOLD = 2.2;
// Deux depenses de meme montant/categorie a moins de X jours d'ecart sont
// consideres comme un doublon probable (double saisie, scan en double...).
const ANOMALY_DUPLICATE_WINDOW_DAYS = 2;

/**
 * Coupe un texte a une longueur max sans couper un mot au milieu, pour que
 * le contexte envoye a l'IA reste lisible et compact.
 */
function truncate(text, maxLength) {
  if (typeof text !== "string" || text.length <= maxLength) {
    return text || "";
  }
  return `${text.slice(0, maxLength).trim()}...`;
}

/**
 * Normalise un texte pour la comparaison de mots-cles : minuscules,
 * accents simplifies, ponctuation retiree.
 */
function normalize(text) {
  return (text || "")
      .toLowerCase()
      .normalize("NFD")
      .replace(/[̀-ͯ]/g, "") // enleve les accents
      .replace(/[^a-z0-9\s]/g, " ")
      .replace(/\s+/g, " ")
      .trim();
}

// Mots trop frequents pour etre utiles a la recherche (français/anglais
// melanges, puisque l'app est bilingue) : on les ignore pour ne pas
// "matcher" un document juste parce qu'il contient "le" ou "the".
const STOPWORDS = new Set([
  "le", "la", "les", "de", "des", "du", "un", "une", "et", "en", "pour",
  "sur", "dans", "au", "aux", "ce", "cette", "mon", "ma", "mes", "the",
  "and", "for", "with", "this", "that", "have", "has", "how", "what",
  "much", "many", "did", "was", "were", "are", "combien", "quel",
  "quelle", "est", "ai", "j", "je", "tu", "il", "elle",
]);

/**
 * AGENT MEMOIRE : cherche, parmi les documents archives de l'utilisateur,
 * ceux qui partagent le plus de mots avec la question posee. Renvoie les
 * `MAX_ARCHIVE_DOCS_IN_CONTEXT` meilleurs ; si aucun document ne
 * correspond a un mot-cle de la question, renvoie simplement les plus
 * recents (mieux vaut un contexte generique que pas de contexte du tout).
 */
async function findRelevantArchiveEntries(uid, question) {
  const snapshot = await db
      .collection("users")
      .doc(uid)
      .collection("archive")
      .orderBy("importedAt", "desc")
      .limit(MAX_ARCHIVE_DOCS_TO_SCAN)
      .get();

  if (snapshot.empty) {
    return [];
  }

  const questionWords = new Set(
      normalize(question)
          .split(" ")
          .filter((word) => word.length >= 3 && !STOPWORDS.has(word)),
  );

  const scored = snapshot.docs.map((doc) => {
    const data = doc.data();
    const haystack = normalize(`${data.sourceLabel || ""} ${data.rawText || ""}`);
    let score = 0;
    for (const word of questionWords) {
      if (haystack.includes(word)) {
        score += 1;
      }
    }
    return {doc, data, score};
  });

  scored.sort((a, b) => b.score - a.score);

  const withMatches = scored.filter((entry) => entry.score > 0);
  const chosen = (withMatches.length > 0 ? withMatches : scored).slice(
      0,
      MAX_ARCHIVE_DOCS_IN_CONTEXT,
  );

  return chosen.map(({doc, data}) => ({
    id: doc.id,
    type: data.type || "document",
    sourceLabel: data.sourceLabel || "",
    importedAt: data.importedAt && data.importedAt.toDate ?
      data.importedAt.toDate().toISOString() :
      null,
    excerpt: truncate(data.rawText, MAX_CHARS_PER_ARCHIVE_ENTRY),
  }));
}

/**
 * Construit le message systeme envoye a l'IA : son role, les donnees
 * financieres actuelles de l'utilisateur, et ce que l'agent memoire a
 * retrouve dans l'archive. C'est ce prompt qui transforme un modele de
 * langage generique en "conseiller financier de SmartSave".
 */
function buildSystemPrompt(snapshot, archiveEntries) {
  const archiveText = archiveEntries.length === 0 ?
    "(Aucun document archive pour l'instant.)" :
    archiveEntries
        .map((entry, index) => {
          const date = entry.importedAt ?
            new Date(entry.importedAt).toLocaleDateString("fr-FR") :
            "date inconnue";
          return `${index + 1}. [${entry.type} - ${entry.sourceLabel} - ${date}]\n${entry.excerpt}`;
        })
        .join("\n\n");

  return `Tu es "SmartSave Conseiller", l'agent conseiller financier integre a l'application mobile SmartSave. Tu reponds a l'utilisateur de facon precise, bienveillante et actionnable, en te basant UNIQUEMENT sur les donnees fournies ci-dessous (n'invente jamais de chiffre). Reponds toujours dans la meme langue que la question de l'utilisateur (francais, anglais ou arabe). Sois concis (quelques phrases), donne des chiffres concrets quand c'est pertinent, et termine si possible par un conseil actionnable.

=== Resume financier actuel de l'utilisateur (JSON) ===
${JSON.stringify(snapshot)}

=== Extraits pertinents de l'historique de documents importes (archive) ===
${archiveText}
`;
}

/**
 * AGENT CONSEILLER : envoie le prompt a l'API Groq (compatible avec le
 * format "OpenAI Chat Completions") et renvoie le texte de la reponse.
 */
async function callGroq({systemPrompt, question, apiKey}) {
  const response = await fetch(GROQ_ENDPOINT, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: GROQ_MODEL,
      messages: [
        {role: "system", content: systemPrompt},
        {role: "user", content: question},
      ],
      temperature: 0.4,
      max_tokens: 700,
    }),
  });

  if (!response.ok) {
    const errorBody = await response.text().catch(() => "");
    throw new Error(
        `Groq a repondu avec le statut ${response.status}: ${errorBody}`,
    );
  }

  const json = await response.json();
  const reply = json &&
    json.choices &&
    json.choices[0] &&
    json.choices[0].message &&
    json.choices[0].message.content;

  if (!reply || typeof reply !== "string" || reply.trim().length === 0) {
    throw new Error("Reponse Groq vide ou dans un format inattendu.");
  }

  return reply.trim();
}

/**
 * Point d'entree appele depuis l'app Flutter (voir
 * FinancialAdvisorService.ask). C'est ici que les 2 agents serveur sont
 * orchestres l'un apres l'autre : d'abord l'agent memoire (recherche dans
 * l'archive), puis l'agent conseiller (generation de la reponse).
 */
exports.financialAdvisor = onCall(
    {secrets: [GROQ_API_KEY], timeoutSeconds: 30, memory: "256MiB"},
    async (request) => {
      if (!request.auth || !request.auth.uid) {
        throw new HttpsError(
            "unauthenticated",
            "Vous devez etre connecte pour utiliser le conseiller financier.",
        );
      }

      const uid = request.auth.uid;
      const question = (request.data && request.data.question || "").trim();
      const snapshot = (request.data && request.data.snapshot) || {};

      if (!question) {
        throw new HttpsError("invalid-argument", "La question est vide.");
      }
      if (question.length > 2000) {
        throw new HttpsError(
            "invalid-argument",
            "La question est trop longue (2000 caracteres max).",
        );
      }

      try {
        // 1) Agent memoire : que sait-on deja qui soit utile a cette
        //    question precise ?
        const archiveEntries = await findRelevantArchiveEntries(uid, question);

        // 2) Agent conseiller : redige la reponse a partir de tout ca.
        const systemPrompt = buildSystemPrompt(snapshot, archiveEntries);
        const reply = await callGroq({
          systemPrompt,
          question,
          apiKey: GROQ_API_KEY.value(),
        });

        return {reply, archiveEntriesUsed: archiveEntries.length};
      } catch (error) {
        logger.error("financialAdvisor a echoue", error);
        throw new HttpsError(
            "internal",
            "Le conseiller financier n'a pas pu repondre pour le moment.",
        );
      }
    },
);

/**
 * Ecrit un message "proactif" (non demande par l'utilisateur) dans le meme
 * fil de discussion que l'agent conseiller, avec un `origin` qui identifie
 * l'agent a l'origine du message. C'est ainsi que les agents anomalies et
 * resume mensuel "parlent" a l'utilisateur : le chat existant (voir
 * finance_chatbot_page.dart cote Flutter) les affiche comme n'importe quel
 * autre message de l'assistant.
 */
async function pushAgentMessage(uid, content, origin) {
  await db.collection("users").doc(uid).collection("advisor_chat").add({
    role: "assistant",
    content,
    origin,
    timestamp: FieldValue.serverTimestamp(),
  });
}

/**
 * Recupere les depenses "comparables" a une depense donnee : meme
 * categorie, meme compte, en excluant la depense elle-meme. Sert de base
 * aux deux heuristiques de l'agent anomalies ci-dessous.
 */
async function findComparableExpenses(uid, categoryKey, accountId, excludeId) {
  const snapshot = await db
      .collection("users")
      .doc(uid)
      .collection("expenses")
      .where("categoryKey", "==", categoryKey)
      .where("accountId", "==", accountId)
      .orderBy("date", "desc")
      .limit(40)
      .get();

  return snapshot.docs
      .filter((doc) => doc.id !== excludeId)
      .map((doc) => doc.data());
}

function average(numbers) {
  if (numbers.length === 0) {
    return 0;
  }
  return numbers.reduce((sum, n) => sum + n, 0) / numbers.length;
}

/**
 * AGENT ANOMALIES : se declenche automatiquement des qu'une nouvelle
 * depense est enregistree (aucun appel depuis l'app n'est necessaire).
 * Deux heuristiques simples, volontairement sans IA (rapide, gratuit,
 * suffisant pour ce cas d'usage) :
 *
 *  1. Montant inhabituel : si la nouvelle depense depasse largement la
 *     moyenne habituelle de l'utilisateur pour cette categorie/ce compte.
 *  2. Doublon probable : si une depense de meme montant, meme categorie,
 *     existe deja a une date tres proche (souvent le signe d'un double
 *     import ou d'un double scan).
 *
 * Ne renvoie jamais d'erreur a l'appelant (il n'y en a pas : c'est un
 * declenchement automatique) et n'interrompt jamais l'enregistrement de la
 * depense elle-meme, qui a deja eu lieu au moment ou cette fonction
 * s'execute.
 */
exports.detectExpenseAnomaly = onDocumentCreated(
    "users/{uid}/expenses/{expenseId}",
    async (event) => {
      const snap = event.data;
      if (!snap) {
        return;
      }

      const expense = snap.data();
      const uid = event.params.uid;
      const expenseId = event.params.expenseId;

      const amount = Number(expense.amount);
      const categoryKey = expense.categoryKey;
      const accountId = expense.accountId || "main";
      const date = expense.date;

      if (!amount || amount <= 0 || !categoryKey) {
        return; // rien d'exploitable
      }

      try {
        const comparable = await findComparableExpenses(
            uid, categoryKey, accountId, expenseId,
        );

        // --- Heuristique 1 : montant inhabituel pour cette categorie ---
        if (comparable.length >= ANOMALY_MIN_SAMPLES) {
          const amounts = comparable
              .map((e) => Number(e.amount))
              .filter((n) => n > 0);
          const avg = average(amounts);
          if (avg > 0 && amount >= avg * ANOMALY_RATIO_THRESHOLD) {
            const message = `⚠️ Depense inhabituelle detectee : ${amount.toFixed(2)} dans la categorie "${categoryKey}", alors que votre depense habituelle dans cette categorie est plutot autour de ${avg.toFixed(2)}. Verifiez que ce montant est correct.`;
            await pushAgentMessage(uid, message, "anomaly_agent");
            return;
          }
        }

        // --- Heuristique 2 : doublon probable ---
        const possibleDuplicate = comparable.find((e) => {
          if (Number(e.amount) !== amount) {
            return false;
          }
          if (!e.date || !date) {
            return false;
          }
          const d1 = new Date(date).getTime();
          const d2 = new Date(e.date).getTime();
          if (Number.isNaN(d1) || Number.isNaN(d2)) {
            return false;
          }
          const diffDays = Math.abs(d1 - d2) / (1000 * 60 * 60 * 24);
          return diffDays <= ANOMALY_DUPLICATE_WINDOW_DAYS;
        });

        if (possibleDuplicate) {
          const message = `🔁 Possible doublon : une autre depense de ${amount.toFixed(2)} dans la meme categorie a ete enregistree a une date tres proche. Verifiez qu'il ne s'agit pas d'une double saisie.`;
          await pushAgentMessage(uid, message, "anomaly_agent");
        }
      } catch (error) {
        // Un agent en arriere-plan ne doit jamais faire echouer quoi que ce
        // soit d'autre : on journalise et on s'arrete la.
        logger.error("detectExpenseAnomaly a echoue", error);
      }
    },
);

/**
 * Genere (si besoin) le resume du mois precedent pour un utilisateur donne,
 * et l'ecrit dans son fil de discussion. Utilise un document marqueur
 * (`users/{uid}/meta/monthly_summary`) pour ne jamais generer le meme
 * resume deux fois, meme si l'agent est declenche plusieurs fois le meme
 * jour ou redemarre.
 */
async function maybeGenerateMonthlySummary(uid, apiKey) {
  const now = new Date();
  const currentMonthKey =
    `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;

  const markerRef = db
      .collection("users").doc(uid).collection("meta").doc("monthly_summary");
  const markerSnap = await markerRef.get();
  const lastMonth = markerSnap.exists ? markerSnap.data().lastMonth : null;

  if (lastMonth === currentMonthKey) {
    return; // deja traite pour ce mois-ci
  }

  // On marque tout de suite le mois comme traite : meme si la suite
  // echoue ou s'il n'y a rien a resumer, on ne veut jamais reessayer en
  // boucle indefiniment pour le meme utilisateur.
  await markerRef.set(
      {lastMonth: currentMonthKey, updatedAt: FieldValue.serverTimestamp()},
      {merge: true},
  );

  // Le mois a resumer est celui qui vient de se terminer.
  const targetDate = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  const rangeStart = targetDate.toISOString();
  const rangeEnd =
    new Date(targetDate.getFullYear(), targetDate.getMonth() + 1, 1)
        .toISOString();

  const expensesSnap = await db
      .collection("users").doc(uid).collection("expenses")
      .where("date", ">=", rangeStart)
      .where("date", "<", rangeEnd)
      .get();

  if (expensesSnap.empty) {
    return; // rien depense ce mois-la, rien a resumer
  }

  const expenses = expensesSnap.docs.map((doc) => doc.data());
  const total = expenses.reduce((sum, e) => sum + (Number(e.amount) || 0), 0);

  const byCategory = {};
  for (const e of expenses) {
    const key = e.categoryKey || "other";
    byCategory[key] = (byCategory[key] || 0) + (Number(e.amount) || 0);
  }
  const topCategory = Object.entries(byCategory)
      .sort((a, b) => b[1] - a[1])[0];

  const monthLabel = targetDate.toLocaleDateString(
      "fr-FR", {month: "long", year: "numeric"},
  );

  let message;
  try {
    const systemPrompt = `Tu es "SmartSave Conseiller". Redige un court resume mensuel (3 a 4 phrases maximum) des depenses de l'utilisateur pour ${monthLabel}, en francais, sur un ton chaleureux et actionnable, a partir de ces donnees JSON (n'invente aucun autre chiffre) : ${JSON.stringify({
      total,
      byCategory,
      transactionCount: expenses.length,
      topCategory: topCategory ? topCategory[0] : null,
    })}. N'ecris jamais que ce sont des donnees JSON : ecris directement comme si tu parlais a l'utilisateur.`;

    message = await callGroq({
      systemPrompt,
      question: "Redige le resume mensuel.",
      apiKey,
    });
  } catch (error) {
    // Repli sans IA : un resume simple base sur les chiffres suffit mieux
    // que pas de resume du tout.
    logger.warn("monthlySummaryAgent: repli sans IA", error);
    message = `📊 Resume de ${monthLabel} : vous avez depense un total de ${total.toFixed(2)} sur ${expenses.length} transaction(s).` +
      (topCategory ?
        ` Votre plus grosse categorie de depense est "${topCategory[0]}" (${topCategory[1].toFixed(2)}).` :
        "");
  }

  await pushAgentMessage(uid, message, "monthly_summary_agent");
}

/**
 * AGENT RESUME MENSUEL : s'execute chaque jour a 8h (heure de Paris) et
 * verifie, pour chaque utilisateur, si un nouveau mois a commence depuis le
 * dernier resume genere. Si oui, redige et envoie automatiquement un
 * resume du mois qui vient de se terminer. Aucun appel depuis l'app n'est
 * necessaire : c'est un declenchement planifie (Cloud Scheduler).
 */
exports.monthlySummaryAgent = onSchedule(
    {
      schedule: "0 8 * * *",
      timeZone: "Europe/Paris",
      secrets: [GROQ_API_KEY],
    },
    async () => {
      const usersSnap = await db.collection("users").get();
      const apiKey = GROQ_API_KEY.value();

      for (const userDoc of usersSnap.docs) {
        try {
          await maybeGenerateMonthlySummary(userDoc.id, apiKey);
        } catch (error) {
          logger.error(
              `monthlySummaryAgent a echoue pour ${userDoc.id}`, error,
          );
        }
      }
    },
);

/**
 * AGENT DE CATEGORISATION : appele depuis l'app juste apres un scan (reçu
 * ou relevé bancaire), pour ameliorer la categorie devinee localement par
 * mots-cles (voir OcrService._guessCategory cote Flutter) grace a l'IA, qui
 * comprend mieux le contexte d'une description libre qu'une simple liste de
 * mots-cles.
 *
 * Prend une liste de descriptions de transactions, renvoie une liste de
 * meme longueur et dans le meme ordre, avec pour chacune une categorie
 * choisie STRICTEMENT parmi celles que l'app connait (voir
 * ALLOWED_CATEGORY_KEYS) : jamais une categorie inventee que l'app ne
 * saurait pas afficher.
 */
exports.categorizeTransactions = onCall(
    {secrets: [GROQ_API_KEY], timeoutSeconds: 20, memory: "256MiB"},
    async (request) => {
      if (!request.auth || !request.auth.uid) {
        throw new HttpsError(
            "unauthenticated",
            "Vous devez etre connecte pour utiliser cette fonctionnalite.",
        );
      }

      const descriptions = (request.data && request.data.descriptions) || [];
      if (!Array.isArray(descriptions) || descriptions.length === 0) {
        throw new HttpsError(
            "invalid-argument", "La liste de descriptions est vide.",
        );
      }
      if (descriptions.length > 60) {
        throw new HttpsError(
            "invalid-argument",
            "Trop de transactions a categoriser en une seule fois (60 max).",
        );
      }

      const systemPrompt = `Tu categorises des transactions financieres. Pour chaque description fournie, choisis EXACTEMENT une categorie parmi cette liste : ${ALLOWED_CATEGORY_KEYS.join(", ")}. Reponds UNIQUEMENT avec un tableau JSON de chaines de caracteres (une categorie par description, dans le meme ordre, meme longueur que la liste fournie), sans aucun texte autour, par exemple : ["food","transport","other"]. Si une description est ambigue ou ne correspond a aucune categorie evidente, choisis "other".`;

      const question = JSON.stringify(descriptions);

      try {
        const raw = await callGroq({
          systemPrompt,
          question,
          apiKey: GROQ_API_KEY.value(),
        });

        // L'IA repond parfois avec du texte autour du JSON malgre la
        // consigne ; on extrait le premier tableau JSON trouve.
        const match = raw.match(/\[[\s\S]*\]/);
        const parsed = JSON.parse(match ? match[0] : raw);

        if (!Array.isArray(parsed) || parsed.length !== descriptions.length) {
          throw new Error(
              "Reponse de l'IA de longueur inattendue.",
          );
        }

        const categories = parsed.map((value) => {
          const key = String(value).toLowerCase().trim();
          return ALLOWED_CATEGORY_KEYS.includes(key) ? key : "other";
        });

        return {categories};
      } catch (error) {
        logger.error("categorizeTransactions a echoue", error);
        throw new HttpsError(
            "internal",
            "La categorisation automatique n'a pas pu se terminer.",
        );
      }
    },
);
