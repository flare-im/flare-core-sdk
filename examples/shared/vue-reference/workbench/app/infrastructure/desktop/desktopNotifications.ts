/**
 * The app's message sound for desktop and web hosts. Which message alerts, and whether it rings, is the engine's call
 * (`notification.present` with `sound`); the hosts play this when it asks.
 */
export type DesktopNotificationKind = "message" | "call";

let audioContext: AudioContext | undefined;

export async function playDesktopNotificationSound(kind: DesktopNotificationKind): Promise<void> {
  if (typeof window === "undefined") return;
  const audioWindow = window as Window & typeof globalThis & {
    webkitAudioContext?: typeof AudioContext;
  };
  const AudioContextCtor = audioWindow.AudioContext ?? audioWindow.webkitAudioContext;
  if (!AudioContextCtor) return;
  audioContext ??= new AudioContextCtor();
  const context = audioContext;
  if (context.state === "suspended") {
    await context.resume();
  }

  const pattern = kind === "call"
    ? [
      { start: 0, frequency: 740, duration: 0.16 },
      { start: 0.22, frequency: 980, duration: 0.18 },
      { start: 0.48, frequency: 740, duration: 0.16 },
    ]
    : [
      { start: 0, frequency: 660, duration: 0.09 },
      { start: 0.12, frequency: 880, duration: 0.1 },
    ];
  const base = context.currentTime;
  for (const tone of pattern) {
    playTone(context, base + tone.start, tone.frequency, tone.duration);
  }
}

function playTone(context: AudioContext, start: number, frequency: number, duration: number): void {
  const oscillator = context.createOscillator();
  const gain = context.createGain();
  oscillator.type = "sine";
  oscillator.frequency.setValueAtTime(frequency, start);
  gain.gain.setValueAtTime(0.0001, start);
  gain.gain.exponentialRampToValueAtTime(0.16, start + 0.012);
  gain.gain.exponentialRampToValueAtTime(0.0001, start + duration);
  oscillator.connect(gain);
  gain.connect(context.destination);
  oscillator.start(start);
  oscillator.stop(start + duration + 0.03);
}
