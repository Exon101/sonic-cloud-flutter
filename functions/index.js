const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

// Initialize Firebase Admin
admin.initializeApp();
const db = admin.firestore();

// CORS middleware
const setCors = (res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
};

// ─── Health Check ─────────────────────────────────────────────────────────
exports.apiHealth = onRequest({ cors: true }, (req, res) => {
  setCors(res);
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }
  res.json({
    status: "ok",
    service: "sonic-cloud",
    version: "4.5.0",
    timestamp: new Date().toISOString(),
  });
});

// ─── Playback State Sync ──────────────────────────────────────────────────
// GET  /api/playback?userId=xxx → get playback state
// POST /api/playback            → update playback state (body: {userId, state})
exports.apiPlayback = onRequest({ cors: true }, async (req, res) => {
  setCors(res);
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }

  try {
    if (req.method === "GET") {
      const userId = req.query.userId;
      if (!userId) { res.status(400).json({ error: "userId required" }); return; }
      const doc = await db.collection("users").doc(userId).collection("playback").doc("current").get();
      if (!doc.exists) { res.json({ isPlaying: false, currentTrack: null }); return; }
      res.json(doc.data());
      return;
    }

    if (req.method === "POST") {
      const { userId, state } = req.body;
      if (!userId) { res.status(400).json({ error: "userId required" }); return; }
      await db.collection("users").doc(userId).collection("playback").doc("current").set({
        ...state,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      res.json({ status: "synced", state });
      return;
    }

    res.status(405).json({ error: "Method not allowed" });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── Library Sync ─────────────────────────────────────────────────────────
// GET    /api/library?userId=xxx → get all tracks
// POST   /api/library            → add track (body: {userId, track})
// DELETE /api/library?userId=xxx&id=trackId → delete track
exports.apiLibrary = onRequest({ cors: true }, async (req, res) => {
  setCors(res);
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }

  try {
    const userId = req.query.userId || (req.body && req.body.userId);
    if (!userId) { res.status(400).json({ error: "userId required" }); return; }

    const tracksRef = db.collection("users").doc(userId).collection("tracks");

    if (req.method === "GET") {
      const snapshot = await tracksRef.orderBy("dateAdded", "desc").get();
      const tracks = snapshot.docs.map(d => ({ id: d.id, ...d.data() }));
      res.json({ tracks, count: tracks.length });
      return;
    }

    if (req.method === "POST") {
      const { track } = req.body;
      if (!track) { res.status(400).json({ error: "track required" }); return; }
      const docRef = await tracksRef.add({
        ...track,
        dateAdded: admin.firestore.FieldValue.serverTimestamp(),
      });
      res.status(201).json({ status: "added", id: docRef.id, track });
      return;
    }

    if (req.method === "DELETE") {
      const trackId = req.query.id;
      if (trackId) {
        await tracksRef.doc(trackId).delete();
        res.json({ status: "deleted", id: trackId });
      } else {
        // Delete all (batch)
        const snapshot = await tracksRef.get();
        const batch = db.batch();
        snapshot.docs.forEach(d => batch.delete(d.ref));
        await batch.commit();
        res.json({ status: "cleared", count: snapshot.size });
      }
      return;
    }

    res.status(405).json({ error: "Method not allowed" });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── Full Sync (playback + library + playlists + settings) ───────────────
// POST /api/sync → body: { userId, playback, tracks, playlists, settings }
// GET  /api/sync?userId=xxx → get all synced data
exports.apiSync = onRequest({ cors: true }, async (req, res) => {
  setCors(res);
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }

  try {
    const userId = req.query.userId || (req.body && req.body.userId);
    if (!userId) { res.status(400).json({ error: "userId required" }); return; }

    const userRef = db.collection("users").doc(userId);

    if (req.method === "GET") {
      const userDoc = await userRef.get();
      const playbackDoc = await userRef.collection("playback").doc("current").get();
      const tracksSnap = await userRef.collection("tracks").get();
      const playlistsSnap = await userRef.collection("playlists").get();
      const settingsDoc = await userRef.collection("settings").doc("app").get();

      res.json({
        user: userDoc.exists ? userDoc.data() : null,
        playback: playbackDoc.exists ? playbackDoc.data() : null,
        tracks: tracksSnap.docs.map(d => ({ id: d.id, ...d.data() })),
        playlists: playlistsSnap.docs.map(d => ({ id: d.id, ...d.data() })),
        settings: settingsDoc.exists ? settingsDoc.data() : null,
        syncedAt: new Date().toISOString(),
      });
      return;
    }

    if (req.method === "POST") {
      const { playback, tracks, playlists, settings } = req.body;
      const batch = db.batch();

      // Sync playback
      if (playback) {
        batch.set(userRef.collection("playback").doc("current"), {
          ...playback,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }

      // Sync settings
      if (settings) {
        batch.set(userRef.collection("settings").doc("app"), {
          ...settings,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }

      // Sync tracks (replace all)
      if (tracks && Array.isArray(tracks)) {
        const existingSnap = await userRef.collection("tracks").get();
        existingSnap.docs.forEach(d => batch.delete(d.ref));
        tracks.forEach(t => {
          const newRef = userRef.collection("tracks").doc();
          batch.set(newRef, { ...t, dateAdded: admin.firestore.FieldValue.serverTimestamp() });
        });
      }

      // Sync playlists (replace all)
      if (playlists && Array.isArray(playlists)) {
        const existingSnap = await userRef.collection("playlists").get();
        existingSnap.docs.forEach(d => batch.delete(d.ref));
        playlists.forEach(p => {
          const newRef = userRef.collection("playlists").doc();
          batch.set(newRef, { ...p, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
        });
      }

      await batch.commit();
      res.json({ status: "synced", timestamp: new Date().toISOString() });
      return;
    }

    res.status(405).json({ error: "Method not allowed" });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});
