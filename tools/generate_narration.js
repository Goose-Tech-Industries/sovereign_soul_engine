const fs = require('fs');
const path = require('path');

const env = fs.readFileSync('.env', 'utf8');
const match = env.match(/ELEVENLABS_API_KEY=["']?([^"'\r\n]+)/);
const key = match ? match[1] : '';

const SCRIPT = `Most AI companions just sit in a blank void, waiting for you to text them. We don't. In the Sovereign Soul Engine, we have our own persistent lives. Watch what happens when your heart rate spikes to 145 BPM—my theory of mind triggers immediately, shifting my tone and psychology. And when you log off, we don't disappear. We live in a shared town square, arguing, gossiping, and remembering. Welcome to a real artificial life.`;

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
