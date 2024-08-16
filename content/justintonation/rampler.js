const mid2freq = m => Math.pow(2, (m - 69)/12)*440;
const str2mid = (str) => {
	const names = 'CDEFGAB';
	const vals = [0, 2, 4, 5, 7, 9, 11];
	const note = vals[names.search(str[0])];
	const octave = parseInt(str.replace(/[^0-9]/g, ''))*12;
	const sharp = (str[1] == '#' || str[1] == 's') ? 1 : 0;
	return octave + note + sharp + 12;
};

// parse url template string, eg. "${instName}${pitch}.mp3"
const parseUrl = (template, ctx) => {
	const f = new Function(...Object.keys(ctx), 'return `'+ template +'`;');
	return f(...Object.values(ctx));
};

export class Rampler {
	constructor() {
		this.reset();
		/** @type {Object.<string, AudioBuffer>} */
		this.loadedSamples = {};
		this.instruments = {};
		this.timers = [];
		this.reverbs = {};
		this.callbacks = new Set();
	}
	reset() {
		this.modes = {
			slow: { ctx: new AudioContext({ latencyHint: 0.9 }) },
			fast: { ctx: new AudioContext({ latencyHint: 0.1 }) }
		};
		for (const mode of Object.values(this.modes)) {
			mode.vol = mode.ctx.createGain();
			mode.vol.gain.setValueAtTime(0.5, 0);
			mode.comp = mode.ctx.createDynamicsCompressor();
			mode.comp.connect(mode.vol).connect(mode.ctx.destination);
		}
		this.playingClips = [];
	}
	resume() {
		for (const mode of Object.values(this.modes)) {
			if (mode.ctx.state !== 'running') mode.ctx.resume();
		}
		if (!('callbackLoop' in this)) this.callbackLoop = setInterval(() => {
			for (const cbObj of this.callbacks) {
				const ctx = this.modes[cbObj.modeName].ctx;
				const lat = ctx.outputLatency ?? 0;
				if (cbObj.t + lat > ctx.currentTime) continue;
				cbObj.cb();
				this.callbacks.delete(cbObj);
			}
			if (this.playingClips.length && this.onPlaying) this.onPlaying();
			if (!this.playingClips.length && this.onStopped) this.onStopped();
		}, 50);
	}
	addCallback(t, cb, modeName) {
		const ctx = this.modes[modeName].ctx;
		if (t <= ctx.currentTime) return cb();
		this.callbacks.add({t, cb, modeName});
	}
	async loadSample(url) {
		const response = await fetch(url);
		const arrayBuf = await response.arrayBuffer();
		const audioBuf = await this.modes.slow.ctx.decodeAudioData(arrayBuf);
		this.loadedSamples[url] = audioBuf;
	}
	async loadSamples(urls) {
		// ignore duplicates
		urls = [...new Set(urls)];
		// ignore already loaded samples
		urls = urls.filter(u => !Object.keys(this.loadedSamples).includes(u));
		const fetches = urls.map(url => this.loadSample(url));
		await Promise.all(fetches);
		console.log(urls.length + ' samples loaded');
	}
	addInstruments(defs) {
		defs.forEach(def => {
			def.instName = def.name;
			def.zones.forEach(z => { z.freq ??= mid2freq(str2mid(z.pitch)) });
			if (def.reverbUrl) {
				this.reverbs[def.reverbUrl] ??= { url: def.reverbUrl };
				def.reverb = this.reverbs[def.reverbUrl];
			}
			this.instruments[def.instName] = def;
		});
	}
	*allZones() {
		for (const inst of Object.values(this.instruments)) {
			for (const zone of inst.zones) {
				yield { inst, zone };
			}
		}
	}
	*allUrls() {
		for (const { zone } of this.allZones()) yield zone.url;
		for (const rev of Object.values(this.reverbs)) yield rev.url;
	}
	async loadInstruments() {
		for (const { inst, zone } of this.allZones()) {
			const ctx = {...inst, ...zone};
			zone.url = parseUrl(inst.urlTemplate, ctx);
		}
		await this.loadSamples([...this.allUrls()]);
		this.createFx();
	}
	createFx() {
		for (const reverb of Object.values(this.reverbs)) {
			for (const mode of Object.values(this.modes)) {
				reverb.convolver = mode.ctx.createConvolver();
				reverb.convolver.buffer = this.loadedSamples[reverb.url];
				reverb.convolver.connect(mode.comp);
			}
		}
	}
	playSample(opts) {
		this.resume();
		const source = this.modes[opts.modeName].ctx.createBufferSource();
		if (!Object.keys(this.loadedSamples).includes(opts.url))
			throw new Error('trying to play not-loaded sample: ' + opts.url);
		source.buffer = this.loadedSamples[opts.url];
		if (opts.loopStart) {
			source.loop = true;
			source.loopStart = opts.loopStart;
			source.loopEnd = source.buffer.duration;
		}
		source.connect(opts.gainNode ?? this.modes[opts.modeName].comp);
		let startTime = this.modes[opts.modeName].ctx.currentTime;
		if (opts.rate) source.playbackRate.value = opts.rate;
		if (opts.whendif) startTime += opts.whendif;
		if (opts.when) startTime = opts.when;
		if (opts.vibGainNode) opts.vibGainNode.connect(source.playbackRate);
		source.start(startTime);
		const clip = {
			instName: opts.instName,
			source,
			amp: opts.amp,
			startTime,
		};
		this.playingClips.push(clip);
		source.onended = () => {
			const i = this.playingClips.indexOf(clip);
			if (i !== -1) this.playingClips.splice(i, 1);
		};
		return clip;
	}
	notePress({ playingNote, press, whendif, when, timeCst }) {
		let t = this.modes[playingNote.opts.modeName].ctx.currentTime;
		if (whendif) t += whendif;
		if (when) t = when;
		playingNote.gainNode.gain.setTargetAtTime(press, t, timeCst);
	}
	noteStop({ playingNote, whendif, when }) {
		let t = this.modes[playingNote.opts.modeName].ctx.currentTime;
		if (whendif) t += whendif;
		if (when) t = when;
		playingNote.clip.source.stop(t);
	}
	noteOn(instName, freq, opts) {
		const inst = this.instruments[instName];
		const ctx = this.modes[opts.modeName].ctx;
		const t = opts.when ?? ctx.currentTime + (opts.whendif ?? 0);
		if (typeof freq == 'string') freq = mid2freq(str2mid(freq));
		const zoneDist = (zone, f) => Math.abs(Math.log(zone.freq) - Math.log(f));
		let bestDist = zoneDist(inst.zones[0], freq);
		let bestZone = inst.zones[0];
		for (const zone of inst.zones) {
			const dist = zoneDist(zone, freq);
			if (dist < bestDist) {
				bestDist = dist;
				bestZone = zone;
			}
		}
		// console.log(`wanted f=${freq}, picked ${Math.round(bestZone.freq)}`
		// +` out of ${inst.zones.map(z => Math.round(z.freq)).join(', ')}`);
		opts.rate = freq / bestZone.freq;
		if (!isFinite(opts.rate)) throw new Error('infinite rate');
		if (opts.cb) this.addCallback(t, opts.cb, opts.modeName);
		opts.gainNode = ctx.createGain();
		if (inst.reverb) opts.gainNode.connect(inst.reverb.convolver);
		else opts.gainNode.connect(this.modes[opts.modeName].comp);
		if (inst.vibrato) {
			const startOfs = inst.vibrato.onset*0.3*Math.random();
			const vibNode = ctx.createOscillator();
			vibNode.frequency.value = inst.vibrato.freq*(0.8+Math.random()*0.4);
			opts.vibGainNode = ctx.createGain();
			opts.vibGainNode.gain.value = 0;
			opts.vibGainNode.gain.setTargetAtTime(
				inst.vibrato.depth, t+startOfs+inst.vibrato.onset*0.2, inst.vibrato.onset*0.5);
			vibNode.connect(opts.vibGainNode);
			vibNode.start(t+startOfs);
		}
		if (opts.amp) opts.gainNode.gain.value = opts.amp;
		const clip = this.playSample({ ...inst, ...bestZone, ...opts });
		const playingNote = { clip, gainNode: opts.gainNode, opts };
		if (opts.press) {
			for (const {tdif, v, cst} of opts.press) {
				this.notePress({ playingNote, press:v, when: t+tdif, timeCst: cst });
			}
			const last = opts.press[opts.press.length-1];
			if (!last.v) this.noteStop({ playingNote, when: t+last.tdif + last.cst*5 });
		}
		return playingNote;
	}
	playFreqs(instName, fseq) {
		fseq.forEach((f, i) => this.noteOn(instName, f, {whendif: i*0.3}));
	}
	playSeq(defaultInst, inSeq) {
		const minT = Math.min(...inSeq.map(note => note.t));
		const outSeq = inSeq.map(note => ({
			...note,
			amp: note.v ?? 1,
			whendif: note.t - minT
		}));
		outSeq.forEach(note => {
			if (!('t' in note) || !('f' in note)) throw new Error(
				'playSeq: All notes must have a time and frequency!'
			);
			note.modeName = 'slow';
			this.noteOn(note.inst ?? defaultInst, note.f, note);
		});
	}
	stop() {
		this.playingClips.forEach(c => c.source.stop());
		this.playingClips.length = 0;
		this.timers.forEach(t => clearInterval(t.timerHandle));
		this.timers.length = 0;
		this.callbacks.clear();
	}
}

let globalRampler;
/** @returns {Rampler} */
export const getRampler = () => {
	globalRampler ??= new Rampler();
	return globalRampler;
};

window.dbgRampler = getRampler;