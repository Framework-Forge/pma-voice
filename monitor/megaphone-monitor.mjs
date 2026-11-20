// Local microphone sidetone only. No recording, sockets, audio uploads or
// changes to Mumble targets. Authorization/PTT are controlled by the Lua side.
const stopTracks = (stream) => stream?.getTracks().forEach((track) => track.stop());
const volumeOf = (value) => Number.isFinite(value) ? Math.max(0, Math.min(1, value)) : 0.3;

// Bounded, symmetric speaker saturation; allocated once, never audio recordings.
export function megaphoneCurve() {
  const curve = new Float32Array(1024);
  for (let i = 0; i < curve.length; i++) {
    const x = i * 2 / (curve.length - 1) - 1;
    curve[i] = Math.tanh(2 * x) / Math.tanh(2);
  }
  return curve;
}
const speakerCurve = megaphoneCurve();

export class MegaphoneMonitor {
  constructor({ capture, createContext, report = () => {},
    // Window timers require their browser receiver, not the monitor instance.
    timer = (fn, delay) => globalThis.setTimeout(fn, delay),
    cancelTimer = (id) => globalThis.clearTimeout(id),
  }) {
    Object.assign(this, { capture, createContext, report, timer, cancelTimer });
    this.lastRequest = -1;
    this.generation = 0;
    this.desired = null;
    this.busy = false;
    this.disposed = false;
    this.nodes = [];
  }

  update(message) {
    if (this.disposed || !message || !Number.isSafeInteger(message.request)
        || message.request < 0 || message.request <= this.lastRequest) return;
    this.lastRequest = message.request;
    this.generation++;
    const volume = volumeOf(message.volume);
    if (message.enabled !== true || volume === 0) {
      this.desired = null;
      this.cleanup();
      return;
    }
    this.desired = { request: message.request, volume, effect: message.effect !== false };
    if (this.stream && this.gain && this.context?.state === 'running') {
      this.gain.gain.value = volume;
      this.configureEffect(this.desired.effect);
      this.emit(message.request, 'active');
      return;
    }
    this.cleanup();
    if (!this.busy) void this.start();
  }

  current(generation) {
    return !this.disposed && this.desired && generation === this.generation;
  }

  emit(request, status) {
    try { this.report({ request, status }); } catch { /* Diagnostics must not stop audio. */ }
  }

  configureEffect(enabled) {
    if (!this.effectNodes) return;
    const { high, low, mid, compressor, drive, shaper, post } = this.effectNodes;
    const cleanHigh = Math.min(20000, (this.context.sampleRate || 48000) * 0.45);
    high.frequency.value = enabled ? 450 : 20;
    low.frequency.value = post.frequency.value = enabled ? 3500 : cleanHigh;
    mid.frequency.value = 1600; mid.Q.value = 1.2; mid.gain.value = enabled ? 6 : 0;
    compressor.threshold.value = enabled ? -24 : 0; compressor.knee.value = enabled ? 12 : 0;
    compressor.ratio.value = enabled ? 8 : 1; compressor.attack.value = 0.003; compressor.release.value = 0.1;
    drive.gain.value = enabled ? 3 : 1;
    shaper.curve = enabled ? speakerCurve : null;
    shaper.oversample = '2x';
  }

  cleanup() {
    if (this.cancelPlayback) { this.cancelPlayback(); this.cancelPlayback = null; }
    if (this.gain) this.gain.gain.value = 0;
    for (const node of this.nodes) { try { node.disconnect(); } catch { /* Already disconnected. */ } }
    this.nodes = [];
    this.effectNodes = null;
    const stream = this.stream;
    this.stream = null;
    stopTracks(stream);
    const context = this.context;
    this.context = this.gain = null;
    if (context) { try { Promise.resolve(context.close()).catch(() => {}); } catch { /* Already closed. */ } }
  }

  async resume(context) {
    let timeout, cancel;
    try {
      await new Promise((resolve, reject) => {
        cancel = resolve;
        this.cancelPlayback = cancel;
        timeout = this.timer(() => reject({ name: 'PlaybackError' }), 3000);
        Promise.resolve().then(() => context.resume()).then(resolve, reject);
      });
    } finally {
      this.cancelTimer(timeout);
      if (this.cancelPlayback === cancel) this.cancelPlayback = null;
    }
  }

  async start() {
    const generation = this.generation;
    const request = this.desired.request;
    this.busy = true;
    let phase = 'capture', pendingNotice;
    try {
      // Include scheduling in the guarded lifecycle so failure cannot strand busy.
      pendingNotice = this.timer(() => {
        if (phase === 'capture' && this.current(generation)) this.emit(request, 'permission_pending');
      }, 1500);
      if (!this.capture || !this.createContext) throw { name: 'UnavailableError' };
      const stream = await this.capture({ video: false, audio: {
        echoCancellation: true, noiseSuppression: true, autoGainControl: false, channelCount: 1,
      } });
      // Releasing during the permission prompt must never enable late audio.
      if (!this.current(generation)) { stopTracks(stream); return; }
      this.stream = stream;
      phase = 'playback';
      const context = this.context = this.createContext();
      const source = context.createMediaStreamSource(stream);
      const high = context.createBiquadFilter();
      high.type = 'highpass';
      const low = context.createBiquadFilter();
      low.type = 'lowpass';
      const mid = context.createBiquadFilter(); mid.type = 'peaking';
      const compressor = context.createDynamicsCompressor();
      const drive = context.createGain();
      const shaper = context.createWaveShaper();
      const post = context.createBiquadFilter(); post.type = 'lowpass';
      const gain = this.gain = context.createGain();
      gain.gain.value = this.desired.volume;
      this.effectNodes = { high, low, mid, compressor, drive, shaper, post };
      this.configureEffect(this.desired.effect);
      this.nodes = [source, high, low, mid, compressor, drive, shaper, post, gain];
      for (let i = 0; i < this.nodes.length - 1; i++) this.nodes[i].connect(this.nodes[i + 1]);
      await this.resume(context);
      if (!this.current(generation)) return;
      if (context.state !== 'running') throw { name: 'PlaybackError' };
      gain.connect(context.destination);
      for (const track of stream.getAudioTracks()) {
        track.addEventListener('ended', () => {
          // A volume-only update has a newer request but keeps this stream.
          if (this.disposed || this.stream !== stream || !this.desired) return;
          const currentRequest = this.desired.request;
          this.desired = null; this.generation++; this.cleanup();
          this.emit(currentRequest, 'device_error');
        }, { once: true });
      }
      this.emit(request, 'active');
    } catch (error) {
      if (this.current(generation)) {
        this.desired = null;
        this.cleanup();
        const status = error?.name === 'UnavailableError' ? 'unavailable'
          : phase === 'playback' ? 'playback_error'
          : ['NotAllowedError', 'SecurityError'].includes(error?.name) ? 'denied' : 'device_error';
        this.emit(request, status);
      }
    } finally {
      this.cancelTimer(pendingNotice);
      this.busy = false;
      if (this.desired && generation !== this.generation && !this.stream) void this.start();
    }
  }

  dispose() {
    this.disposed = true;
    this.desired = null;
    this.generation++;
    this.cleanup();
  }
}

// Only install inside the game NUI, never in a web preview or Node tests.
if (typeof window !== 'undefined' && typeof window.GetParentResourceName === 'function') {
  const resource = window.GetParentResourceName();
  const callback = async (name, data = {}) => {
    try {
      const response = await fetch(`https://${resource}/${name}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data),
      });
      return await response.json();
    } catch { return null; }
  };
  const AudioContext = window.AudioContext || window.webkitAudioContext;
  const monitor = new MegaphoneMonitor({
    capture: navigator.mediaDevices?.getUserMedia?.bind(navigator.mediaDevices),
    createContext: AudioContext ? () => new AudioContext({ latencyHint: 'interactive' }) : null,
    report: (status) => { void callback('megaphoneMonitorStatus', status); },
  });
  const receive = (message) => {
    if (message?.action === 'pmaMegaphoneMonitor') monitor.update(message);
  };
  window.addEventListener('message', (event) => {
    if (event.source && event.source !== window.parent && event.source !== window) return;
    receive(event.data);
  });
  window.addEventListener('pagehide', () => monitor.dispose());
  window.addEventListener('beforeunload', () => monitor.dispose());
  void callback('megaphoneMonitorReady').then(receive);
}
