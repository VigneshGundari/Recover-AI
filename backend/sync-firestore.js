const neo4j = require('neo4j-driver');
require('dotenv').config();

// Verify required env variables
const NEO4J_URI = process.env.NEO4J_URI;
const NEO4J_USER = process.env.NEO4J_USER;
const NEO4J_PASSWORD = process.env.NEO4J_PASSWORD;
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;

if (!NEO4J_URI || !NEO4J_USER || !NEO4J_PASSWORD) {
  console.error('❌ Error: Missing Neo4j database credentials in environment (.env)');
  process.exit(1);
}

if (!GEMINI_API_KEY) {
  console.warn('⚠️ Warning: GEMINI_API_KEY is not defined in backend .env. Active ingredients will default to raw medication names.');
}

const PROJECT_ID = 'recover-ai-49f0d';
const FIRESTORE_BASE_URL = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

// Helper to convert Firestore typed JSON structure to standard JS objects
function parseFirestoreFields(fields) {
  const obj = {};
  if (!fields) return obj;
  for (const [key, val] of Object.entries(fields)) {
    if ('stringValue' in val) {
      obj[key] = val.stringValue;
    } else if ('booleanValue' in val) {
      obj[key] = val.booleanValue;
    } else if ('integerValue' in val) {
      obj[key] = parseInt(val.integerValue, 10);
    } else if ('doubleValue' in val) {
      obj[key] = val.doubleValue;
    } else if ('timestampValue' in val) {
      obj[key] = val.timestampValue;
    } else if ('arrayValue' in val) {
      obj[key] = (val.arrayValue.values || []).map(v => parseFirestoreFields({ temp: v }).temp);
    } else if ('mapValue' in val) {
      obj[key] = parseFirestoreFields(val.mapValue.fields);
    } else if ('nullValue' in val) {
      obj[key] = null;
    }
  }
  return obj;
}

// Extract active ingredients using Gemini REST API
async function extractActiveIngredients(medicationName) {
  if (!GEMINI_API_KEY) {
    return [medicationName];
  }

  const prompt = `You are a strict pharmacology expert mapping medications for a Medical Knowledge Graph.
Extract the core active pharmacological ingredients from the commercial drug name provided.
RETURN ONLY A STRICT JSON ARRAY OF STRINGS representing the generic chemical names.
Do NOT use markdown. Do NOT explain. 
Example Input: Tylenol Cold & Flu
Example Output: ["Acetaminophen", "Dextromethorphan", "Guaifenesin", "Phenylephrine"]

Input: ${medicationName}`;

  try {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }]
        })
      }
    );

    if (!response.ok) {
      throw new Error(`Gemini API returned status ${response.status}`);
    }

    const data = await response.json();
    const rawText = data?.candidates?.[0]?.content?.parts?.[0]?.text || '[]';
    const cleanText = rawText.replace(/```json/g, '').replace(/```/g, '').trim();
    
    const parsed = JSON.parse(cleanText);
    if (Array.isArray(parsed)) {
      return parsed;
    }
    return [medicationName];
  } catch (error) {
    console.warn(`⚠️ [Gemini Fallback] Could not extract ingredients for "${medicationName}", using raw name: ${error.message}`);
    return [medicationName];
  }
}

// Fetch all documents under a Firestore path
async function fetchFirestorePath(path) {
  const url = `${FIRESTORE_BASE_URL}/${path}`;
  const response = await fetch(url);
  if (response.status === 404) {
    return [];
  }
  if (!response.ok) {
    throw new Error(`Firestore REST API returned ${response.status} for path ${path}`);
  }
  const data = await response.json();
  return data.documents || [];
}

async function runSync() {
  console.log('📡 Initializing Neo4j driver connection...');
  // Use neo4j+ssc:// scheme if SSL errors persist on local machines
  const driver = neo4j.driver(NEO4J_URI, neo4j.auth.basic(NEO4J_USER, NEO4J_PASSWORD));
  
  try {
    await driver.verifyConnectivity();
    console.log('✅ Connected to Neo4j database successfully!');
  } catch (err) {
    console.error('❌ Connectivity test failed. If this is a TLS handshake issue, check your NEO4J_URI protocol (try changing neo4j+s:// to neo4j+ssc://).');
    console.error('Error details:', err.message);
    process.exit(1);
  }

  try {
    console.log('\n📥 Fetching users from Firestore...');
    const userDocs = await fetchFirestorePath('users');
    console.log(`👤 Found ${userDocs.length} users in Firestore.`);

    let totalSyncedMeds = 0;

    for (const userDoc of userDocs) {
      const userId = userDoc.name.split('/').pop();
      console.log(`\n⏳ Fetching medications for user ID: ${userId}...`);
      
      const medDocs = await fetchFirestorePath(`users/${userId}/medications`);
      const medications = medDocs.map(doc => parseFirestoreFields(doc.fields));
      
      const activeMeds = medications.filter(m => !m.isDeleted);
      console.log(`📦 Found ${medications.length} medications (${activeMeds.length} active).`);

      for (const med of activeMeds) {
        const medName = med.medicationName;
        if (!medName) continue;

        console.log(` -> Processing medication: "${medName}"`);
        const ingredients = await extractActiveIngredients(medName);
        console.log(`    Ingredients: [${ingredients.join(', ')}]`);

        // Sync to Neo4j
        const session = driver.session();
        try {
          const cypherQuery = `
            MERGE (p:Patient {uid: $patientId})
            MERGE (m:Medication {name: $medicationName})
            MERGE (p)-[:TAKES]->(m)
            WITH m
            UNWIND $ingredients AS ingredient
            MERGE (a:ActiveIngredient {name: ingredient})
            MERGE (m)-[:CONTAINS]->(a)
          `;

          await session.run(cypherQuery, {
            patientId: userId,
            medicationName: medName.toLowerCase().trim(),
            ingredients: ingredients.map(i => i.toLowerCase().trim())
          });
          totalSyncedMeds++;
        } catch (dbErr) {
          console.error(` ❌ Error writing "${medName}" to Neo4j:`, dbErr.message);
        } finally {
          await session.close();
        }
      }
    }

    console.log(`\n🎉 Synchronization finished! Synced ${totalSyncedMeds} active medication pathways into Neo4j.`);
  } catch (error) {
    console.error('❌ Sync process failed with critical error:', error);
  } finally {
    await driver.close();
    console.log('🔌 Neo4j connection closed.');
  }
}

runSync();
