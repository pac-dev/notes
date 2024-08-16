import { getRampler } from './rampler.js?version=VER';

// Create a DOM node with specified properties
const addDom = (tagName, attrs={}) => {
    const ret = document.createElement(tagName);
    for (const [key, val] of Object.entries(attrs)) {
        ret[key] = val;
    }
    return ret;
};

// Get results from inside an embedded <object>
export const innerElements = (outSel, inSel) => [
    ...document.querySelector(outSel).contentDocument.querySelectorAll(inSel)
];

// Make the table of contents nicer
export const initToc = (tocEl) => {
    const list = tocEl.querySelector('ul');
    const details = addDom('details', { open: true });
    details.append(addDom('summary', { innerText: 'Contents' }));
    tocEl.replaceChildren(details);
    details.append(list);
};

// Create a playable track widget
export const initTrack = (trackEl) => {
    let iniPos = 0, iniAttr = trackEl.getAttribute('data-start');
    if (iniAttr) iniPos = parseFloat(iniAttr)/100;
    const play = trackEl.appendChild(addDom('div', {
        className: 'mt_play'
    }));
    const seekbar = trackEl.appendChild(addDom('div', {
        className: 'mt_seekbar'
    }));
    const seekrange = seekbar.appendChild(addDom('div', {
        className: 'mt_seekrange'
    }));
    const seekhand = seekrange.appendChild(addDom('div', {
        className: 'mt_seekhand'
    }));
    seekhand.style.left = (iniPos*100) + '%';
    const time = trackEl.appendChild(addDom('div', {
        className: 'mt_time',
        innerText: '00:00 / 00:00'
    }));
    const icon = trackEl.appendChild(addDom('div', {
        className: 'mt_icon'
    }));
    let dragging, dragOriginX, dragOriginP;

    const audio = trackEl.querySelector('audio');
    let playState = 'play';
    play.onclick = () => {
        if(playState === 'play') {
            audio.play();
            trackEl.classList.add('playing');
            playState = 'pause';
        } else {
            audio.pause();
            trackEl.classList.remove('playing');
            playState = 'play';
        }
    };
    const fmt = (pos) => {
        const minutes = Math.floor(pos / 60);
        const seconds = Math.floor(pos % 60);
        const padSeconds = seconds < 10 ? `0${seconds}` : `${seconds}`;
        return `${minutes}:${padSeconds}`;
    };
    const showTime = (t=audio.currentTime) => {
        time.innerText = `${fmt(t)} / ${fmt(audio.duration)}`;
    };
    audio.addEventListener('timeupdate', () => {
        if (dragging) return;
        seekhand.style.left = (Math.round(audio.currentTime/audio.duration*10000)/100) + '%';
        showTime();
    });
    if (audio.readyState > 0) {
        audio.currentTime = iniPos*audio.duration;
        showTime();
    } else {
        audio.addEventListener('loadedmetadata', () => {
            audio.currentTime = iniPos*audio.duration;
            showTime();
        });
    }
    
    const getPos = (event) => {
        const pDif = (event.clientX - dragOriginX) / seekrange.clientWidth;
        const pSum = dragOriginP + pDif;
        return Math.min(1, Math.max(0, Math.round(pSum*10000)/10000));
    };
    const dragStart = (event) => {
        if (event.button !== 0) return;
        dragOriginX = event.clientX;
        dragging = true;
        dragOriginP = (parseFloat(seekhand.style.left) || 0)/100;
        seekhand.setPointerCapture(event.pointerId);
    };
    const dragEnd = (event) => {
        if (!dragging) return;
        dragging = false;
        const pos = getPos(event);
        if (audio.readyState > 0) {
            audio.currentTime = pos*audio.duration;
        } else {
            iniPos = pos;
        }
    };
    const dragMove = (event) => {
        if (!dragging) return;
        const pos = getPos(event);
        seekhand.style.left = (pos*100) + '%';
        showTime(pos*audio.duration);
    };
    seekhand.addEventListener('pointerdown', dragStart);
    seekhand.addEventListener('pointerup', dragEnd);
    seekhand.addEventListener('pointercancel', dragEnd);
    seekhand.addEventListener('pointermove', dragMove)
    seekhand.addEventListener('touchstart', (e) => e.preventDefault());
};

// Highlight a played element
const highlight = (ele, on=true) => {
    ele.classList.toggle('glowing', on);
    if (on) setTimeout(() => ele.classList.remove('glowing'), 100);
};

const highlightAll = (eles, freq) => {
    for (const e of eles) {
        if (freq === parseFloat(e.getAttribute('data-fq'))) {
            highlight(e);
        }
    }
};

window.clog = [];
window.tlog = [];

/**
 * Make `elements` clickable to play them.
 * 
 * @param {Array.<HTMLDivElement>} elements
 * @param {Object} args
 * @param {String} [args.trigger] - optional trigger selector to play the elements in sequence
 * @param {String} [args.chords] - optional chord sequence for the trigger
 */
export const ramplize = (elements, {trigger, chords}={}) => {
    const noteCtrls = [];
    for (const ele of elements) {
        const freq = parseFloat(ele.getAttribute('data-fq'));
        noteCtrls.push({ ele, freq });
        // hack: don't replace this with addEventListener.
        // (multiple `ramplize` calls can be used to add sequence triggers)
        ele.onclick = () => {
            window.tlog.push(freq);
            if (window.tlog.length === 3) {
                window.clog.push(window.tlog.slice());
                window.tlog.length = 0;
            }
            getRampler().noteOn('harpsi', freq, { modeName: 'fast' });
            highlight(ele);
        };
    }
    let noteSeq = noteCtrls.map((c, i) => ({
        f: c.freq, t: i*0.4, cb: () => highlight(c.ele)
    })).filter(n => n.f);
    if (chords) {
        chords = chords.map(ch => {
            const root = ch[0];
            ch.sort((a, b) => a - b);
            return [root/2, ...ch, ch[0]*2];
        });
        noteSeq = chords.map((ch, chi) => ch.map((f, fi) => ({
            f, t: chi*1.7+fi*0.1,
            cb: () => highlightAll(elements, f)
        }))).flat();
    }
    if (trigger) {
        trigger = document.querySelector(trigger);
        const playSeq = () => {
            getRampler().playSeq('harpsi', noteSeq);
            trigger.classList.remove('figRun');
            trigger.classList.add('figStop');
        };
        const stopSeq = () => getRampler().stop();
        trigger.onclick = () => {
            if (trigger.classList.contains('figRun')) playSeq();
            else stopSeq();
        };
    }
};

/**
 * Make `triggers` play audio specified by their `data-tgt` attribute
 * 
 * @param {Array.<HTMLDivElement>} triggers 
 */
export const audiolize = (triggers) => {
    const audios = {};
    for (const ele of document.querySelectorAll('audio')) {
        const baseName = new URL(ele.src).pathname.split('/').pop();
        audios[baseName] = ele;
    }
    for (let trig of triggers) {
        const url = trig.attributes['data-tgt'].value;
        const audio = audios[url];
        const txtNode = trig.querySelector('text');
        const playTxt = txtNode.textContent;
        audio.addEventListener('pause', () => {
            txtNode.textContent = playTxt;
            audio.currentTime = 0;
        });
        trig.onclick = () => {
            if (audio.paused) {
                audio.play();
                txtNode.textContent = 'stop';
            } else {
                audio.pause();
            }
        };
    }
};

export const initCommaLattice = (latticeSel, reset) => {
    const cells = innerElements(latticeSel, '.fnote');
    ramplize(cells);
    const fNotes = innerElements(latticeSel, '.fnote');
    const commaGroup = innerElements(latticeSel, '#commas')[0];
    for (const fNote of fNotes) {
        fNote.addEventListener('click', () => {
            const fx = parseFloat(fNote.attributes.x.value);
            const fy = parseFloat(fNote.attributes.y.value);
            commaGroup.style.transform = `translate(${fx - 50}px, ${fy - 40}px)`;
        });
    }
    reset = document.querySelector(reset);
    reset.addEventListener('click', () => {
        commaGroup.style.transform = '';
    });
};
