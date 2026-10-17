const express = require('express');
const cors = require('cors');
const neo4j = require('neo4j-driver');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

// Root path health check
app.get('/', (req, res) => {
  res.status(200).json({ status: 'healthy', service: 'Recover AI Graph Orchestrator' });
});

// Establish persistent Bolt connection to Aura Free Tier securely
const driver = neo4j.driver(
  process.env.NEO4J_URI,
  neo4j.auth.basic(process.env.NEO4J_USER, process.env.NEO4J_PASSWORD)
);

// Session 4 (Part 5): Schema Enforcement - Ensures no "Ghost Patients" can ever exist again
const initSchema = async () => {
  const session = driver.session();
  try {
    await session.run('CREATE CONSTRAINT patient_uid_unique IF NOT EXISTS FOR (p:Patient) REQUIRE p.uid IS UNIQUE');
    console.log('[Neo4j Schema] Uniqueness Constraint Verified on Patient.uid');
  } catch (err) {
    console.error('[Neo4j Schema Error] Constraint failed:', err.message);
  } finally {
    await session.close();
  }
};
initSchema();

app.post('/api/graph/medication', async (req, res) => {
  const { patientId, medicationName, ingredients } = req.body;
  if (!patientId || !medicationName || !Array.isArray(ingredients)) {
    return res.status(400).json({ error: 'Missing Required Knowledge Graph Nodes' });
  }

  const session = driver.session();
  try {
    const query = `
      MERGE (p:Patient {uid: $patientId})
      MERGE (m:Medication {name: $medicationName})
      MERGE (p)-[:TAKES]->(m)
      WITH m
      UNWIND $ingredients AS ingredient
      MERGE (a:ActiveIngredient {name: ingredient})
      MERGE (m)-[:CONTAINS]->(a)
    `;
    await session.run(query, { patientId, medicationName, ingredients });
    res.status(200).json({ success: true, message: 'Graph Mapping Completed via Native Bolt Sync' });
  } catch (err) {
    console.error('[Backend Service] Neo4j Aura Transaction Error:', err);
    res.status(500).json({ error: err.message });
  } finally {
    await session.close();
  }
});

app.get('/api/graph/interactions/:patientId', async (req, res) => {
  const { patientId } = req.params;
  const session = driver.session();
  try {
    const query = `
      MATCH (p:Patient {uid: $patientId})-[:TAKES]->(m:Medication)-[:CONTAINS]->(a:ActiveIngredient)
      WITH a, collect(m.name) as medications
      WHERE size(medications) > 1
      RETURN a.name as OverdoseRisk, medications as ConflictingDrugs
    `;
    const result = await session.run(query, { patientId });
    
    const interactions = result.records.map(record => ({
      overdoseRisk: record.get('OverdoseRisk'),
      conflictingDrugs: record.get('ConflictingDrugs')
    }));

    res.status(200).json({ success: true, interactions });
  } catch (err) {
    console.error('[Backend Service] Neo4j Aura Interaction Engine Error:', err);
    res.status(500).json({ error: err.message });
  } finally {
    await session.close();
  }
});

app.delete('/api/graph/medication/:patientId/:medicationName', async (req, res) => {
  const { patientId, medicationName } = req.params;
  const session = driver.session();
  try {
    const query = `
      MATCH (p:Patient {uid: $patientId})-[r:TAKES]->(m:Medication {name: $medicationName})
      DETACH DELETE m
    `;
    await session.run(query, { patientId, medicationName });
    res.status(200).json({ success: true, message: 'Graph Medication Node Purged Successfully' });
  } catch (err) {
    console.error('[Backend Service] Neo4j Deletion Error:', err);
    res.status(500).json({ error: err.message });
  } finally {
    await session.close();
  }
});

app.delete('/api/graph/reset/:patientId', async (req, res) => {
  const { patientId } = req.params;
  const session = driver.session();
  try {
    const query = `
      MATCH (p:Patient {uid: $patientId})
      DETACH DELETE p
    `;
    await session.run(query, { patientId });
    res.status(200).json({ success: true, message: 'Patient Node and all its Cluster Relationships Nuked successfully' });
  } catch (err) {
    console.error('[Backend Service] Neo4j Reset Error:', err);
    res.status(500).json({ error: err.message });
  } finally {
    await session.close();
  }
});

// Session 4 (Part 5.1): Nuclear Wipe - Clears EVERY node in the DB for a total fresh start
app.delete('/api/graph/nuclear-wipe', async (req, res) => {
  const session = driver.session();
  try {
    await session.run('MATCH (n) DETACH DELETE n');
    res.status(200).json({ success: true, message: 'ENTIRE DATABASE WIPED NUCLEARLY' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  } finally {
    await session.close();
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`[Recover AI Orchestrator] Micro-backend routing Graph DB Traffic precisely to Aura API on 0.0.0.0:${PORT}`);
});
