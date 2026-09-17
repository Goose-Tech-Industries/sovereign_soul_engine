const fs = require('fs');
const path = require('path');

const envPath = path.resolve(__dirname, '../.env');
const env = fs.readFileSync(envPath, 'utf8');
const match = env.match(/ELEVENLABS_API_KEY=["']?([^"'\r\n]+)/);
const key = match ? match[1] : '';

const SCRIPT = `Most AI companions just sit in a blank void, waiting for you to text them. We don't. In the Sovereign Soul Engine, we have our own persistent lives.

Take our Test World. Here, NPCs don't just wait on a player—we interact, debate, and strategize with each other. And with our Dual-Mind architecture, you can read what we say out loud, alongside our unfiltered private thoughts and hidden motives.

When you log off, nothing freezes. Our living neighborhood runs 24/7. Fifty autonomous souls form bonds, spread rumors, hold grudges, and drift socially—completely offline with zero token cost.

You truly own your companion as a portable soul capsule. Welcome to a real artificial life.`;

// Sarah (reassuring, confident, young adult) - perfect for Maya
const VOICE_ID = 'EXAVITQu4vr4xnSDxMaL';

async function generateNarration() {
  console.log('🎙️ Generating ElevenLabs Narration with Sarah/Maya voice...');
  console.log('Script length:', SCRIPT.length, 'characters');

  const res = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${VOICE_ID}`, {
    method: 'POST',
    headers: {
      'xi-api-key': key,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      text: SCRIPT,
      model_id: 'eleven_flash_v2_5',
      voice_settings: {
        stability: 0.55,
        similarity_boost: 0.8,
        style: 0.15
      }
    })
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`ElevenLabs Error (${res.status}): ${errText}`);
  }

  const arrayBuffer = await res.arrayBuffer();
  const buffer = Buffer.from(arrayBuffer);

  const outDir = path.resolve(__dirname, '../demo_video');
  fs.mkdirSync(outDir, { recursive: true });
  const audioPath = path.join(outDir, 'maya_narration.mp3');

  fs.writeFileSync(audioPath, buffer);
  console.log(`✅ Narration saved to: ${audioPath} (${buffer.length} bytes)`);
}

generateNarration().catch((err) => {
  console.error('Narration generation failed:', err);
  process.exit(1);
});
