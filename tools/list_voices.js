const fs = require('fs');

const env = fs.readFileSync('.env', 'utf8');
const match = env.match(/ELEVENLABS_API_KEY=["']?([^"'\r\n]+)/);
const key = match ? match[1] : '';

async function listVoices() {
  const res = await fetch('https://api.elevenlabs.io/v1/voices', {
    headers: { 'xi-api-key': key }
  });
  const data = await res.json();
  console.log('Available voices:', (data.voices || []).map(v => ({ id: v.voice_id, name: v.name, category: v.category, labels: v.labels })).slice(0, 10));
}

listVoices().catch(console.error);
