const fs = require('fs');

const env = fs.readFileSync('.env', 'utf8');
const match = env.match(/ELEVENLABS_API_KEY=["']?([^"'\r\n]+)/);
const key = match ? match[1] : '';

console.log('Testing ElevenLabs key (prefix):', key.substring(0, 10));

async function check() {
  const res = await fetch('https://api.elevenlabs.io/v1/user/subscription', {
    headers: { 'xi-api-key': key }
  });
  const data = await res.json();
  console.log('Subscription status:', res.status, data);
}

check().catch(console.error);
