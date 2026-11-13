const SOUND_PREFERENCE_KEY = "terralens.sound.enabled";

let audioContext: AudioContext | null = null;

function getAudioContext(): AudioContext | null {
  if (typeof window === "undefined" || !window.AudioContext) {
    return null;
  }
  try {
    audioContext ??= new window.AudioContext();
    if (audioContext.state === "suspended") {
      void audioContext.resume().catch(() => undefined);
    }
    return audioContext;
  } catch {
    return null;
  }
}

function playTone(
  frequency: number,
  duration: number,
  type: OscillatorType = "sine",
  volume = 0.12,
  offset = 0,
) {
  if (!sound.enabled) {
    return;
  }
  const context = getAudioContext();
  if (!context) {
    return;
  }
  const oscillator = context.createOscillator();
  const gain = context.createGain();
  const start = context.currentTime + offset;
  oscillator.connect(gain);
  gain.connect(context.destination);
  oscillator.type = type;
  oscillator.frequency.setValueAtTime(frequency, start);
  gain.gain.setValueAtTime(volume, start);
  gain.gain.exponentialRampToValueAtTime(0.001, start + duration);
  oscillator.start(start);
  oscillator.stop(start + duration);
}

export function readSoundPreference(): boolean {
  try {
    return window.localStorage.getItem(SOUND_PREFERENCE_KEY) === "true";
  } catch {
    return false;
  }
}

export function setSoundPreference(enabled: boolean) {
  sound.enabled = enabled;
  try {
    window.localStorage.setItem(SOUND_PREFERENCE_KEY, String(enabled));
  } catch {
    // Sound remains available for this session when storage is blocked.
  }
}

export const sound = {
  enabled: false,

  playRadarPing() {
    playTone(1200, 0.18, "sine", 0.1);
  },

  playSuccessChime() {
    [659.25, 783.99, 987.77, 1318.5].forEach((frequency, index) => {
      playTone(frequency, 0.18, "triangle", 0.09, index * 0.09);
    });
  },

  playTrophyFanfare() {
    [440, 554.37, 659.25, 880, 1108.73].forEach((frequency, index) => {
      playTone(frequency, 0.14, "square", 0.08, index * 0.07);
    });
  },

  playKeyClick() {
    playTone(720, 0.03, "triangle", 0.07);
  },

  playLaunchFanfare() {
    playTone(960, 0.22, "sine", 0.15);
  },
};

export function playRankUp() {
  [523.25, 659.25, 783.99, 1046.5, 1318.5, 1568].forEach(
    (frequency, index) => {
      playTone(frequency, 0.3, "triangle", 0.1, index * 0.11);
    },
  );
}
