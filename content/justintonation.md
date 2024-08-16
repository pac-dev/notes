Title: What I Learned Writing an Album in Just Intonation
Title-h1: What I Learned Writing an Album in Just&nbsp;Intonation
Author: Pierre Cusa <pierre@osar.fr>
Created: August 2024
Source: https://github.com/pac-dev/notes/tree/master/content
History: https://github.com/pac-dev/notes/commits/master/content/justintonation.md

<link href="ji.css?version=VER" rel="stylesheet"></link>
<script type="module">
	import { getRampler } from './rampler.js?version=VER';
	import * as ji from './ji.js?version=VER';
	getRampler().addInstruments([{
		name: 'harpsi',
		urlTemplate: 'samples/harpsi/${pitch}.mp3?version=VER',
		// what i wanted: A3, A4, C3, D2, E4, F5
		// what i got:
		zones: [
			{pitch: 'B3'}, {pitch: 'Cs3'}, {pitch: 'Ds5'},
			{pitch: 'E6'}, {pitch: 'Gs4'}, {pitch: 'Gs5'}
		]
	}]);
	const eqSeq = [53, 69, 89, 73, 37, 17, 33, 53];
	const aniron12 = [
		[415.3, 523.3, 622.3], [415.3, 493.9, 622.3],
		[415.3, 523.3, 622.3], [329.6, 493.9, 415.3],
		[415.3, 523.3, 622.3], [493.9, 622.3, 370.0], [370.0, 466.2, 554.4], [554.4, 349.2, 415.3],
		[415.3, 523.3, 622.3], [493.9, 622.3, 370.0], [370.0, 466.2, 554.4], [554.4, 349.2, 415.3],
		[415.3, 523.3, 622.3]
	];
	const anironji1 = [
		[412.5,515.6,618.8],[412.5,618.8,495],
		[412.5,515.6,618.8],[330,412.5,495],
		[412.5,515.6,618.8],[495,618.8,371.2],[371.2,464.1,556.9],[550,343.7,412.5],
		[412.5,515.6,618.8],[495,618.8,371.2],[371.2,464.1,556.9],[550,343.7,412.5],
		[412.5,515.6,618.8]
	];
	const anironji2 = [
		[407.4,509.3,611.1],[407.4,611.1,488.9],
		[407.4,509.3,611.1],[325.9,407.4,488.9],
		[407.4,509.3,611.1],[488.9,611.1,366.7],[366.7,458.3,550],[550,343.7,412.5],
		[412.5,515.6,618.8],[495,618.8,371.2],[371.2,464.1,556.9],[556.9,348,417.7],
		[417.7,522.1,626.4]
	];
	const toc = document.querySelector('.toc');
	if (toc) ji.initToc(toc);
	const trackEls = document.querySelectorAll('.minitrack');
	for (const trackEl of trackEls) ji.initTrack(trackEl);
	const winPromise = new Promise((resolve) => window.addEventListener('load', resolve));
	const ramPromise = getRampler().loadInstruments();
	Promise.all([winPromise, ramPromise]).then(() => {
		ji.ramplize(ji.innerElements('#edo12', '.fnote'), {trigger: '#edo12_play'});
		ji.ramplize(ji.innerElements('#ji_eg', '.fnote'), {trigger: '#ji_eg_play'});
		ji.ramplize(ji.innerElements('#compare', '.seq1'), {trigger: '#compareji_play'});
		ji.ramplize(ji.innerElements('#compare', '.seq2'), {trigger: '#compare12_play'});
		ji.ramplize(ji.innerElements('#keyboard', '.seq1'), {trigger: '#keyboard_play'});
		ji.ramplize(ji.innerElements('#keyboard', '.seq2'));
		ji.ramplize(ji.innerElements('#lattice_intro', '.fnote'), {trigger: '#lattice_intro_play'});
		ji.audiolize(ji.innerElements('#reflecting', '.trigger'));
		const jiEls = ji.innerElements('#lattice_ji_commas', '.fnote');
		ji.initCommaLattice('#lattice_ji_commas', '#lattice_ji_commas_play');
		ji.ramplize(eqSeq.map(i => jiEls[i]), {trigger: '#lattice_ji_commas_play'});
		const edoEls = ji.innerElements('#lattice_12_commas', '.fnote');
		ji.initCommaLattice('#lattice_12_commas', '#lattice_12_commas_play');
		ji.ramplize(eqSeq.map(i => edoEls[i]), {trigger: '#lattice_12_commas_play'});
		ji.ramplize(ji.innerElements('#lattice_12_prog', '.fnote'));
		ji.ramplize(ji.innerElements('#lattice_12_prog', '.fnote'), {trigger: '#lattice_12_prog_play', chords: aniron12});
		ji.ramplize(ji.innerElements('#lattice_ji_prog', '.fnote'));
		ji.ramplize(ji.innerElements('#lattice_ji_prog', '.fnote'), {trigger: '#lattice_ji_prog_play1', chords: anironji1});
		ji.ramplize(ji.innerElements('#lattice_ji_prog', '.fnote'), {trigger: '#lattice_ji_prog_play2', chords: anironji2});
	});
	getRampler().onStopped = () => {
		// this gets called in a setInterval loop but ok
		for (const ele of document.querySelectorAll('.figStop')) {
			ele.classList.add('figRun');
			ele.classList.remove('figStop');
		}
	};
</script>

**Just intonation (JI)** today falls under the umbrella of microtonal music, because it involves playing "between the notes" of the 12-tone scale we're used to. As I type <span class=spell>microtonal</span>, my spellchecker decorates it with a sad squiggle, confirming I've drifted (again) into a topic that's not even in its dictionary. But JI is often described as *the way music should naturally sound*. So which one is it, an obscure deviation from the norm, or an ideal we should return to?

This post contains all the notes I want to keep after writing [an album][] in JI, specifically using a very uncompromising method called freestyle JI. The album itself isn't the focus here, but it allowed me to get a practical perspective on a topic that's often described more theoretically. This practical perspective is exactly what you'll find here.

[TOC]

## Basics of Just Intonation

In order to understand JI, first you have to "empty your cup". Most people's cup is occupied by **12-tone equal temperament (12TET)**, which defines the notes we're typically allowed to play. To understand 12TET, start with the octave: going up or down one octave means multiplying or dividing the frequency by 2. Then, divide this octave into 12 equally spaced semitones. This "space between semitones" is actually a specific irrational number: 𝒔&nbsp;$=\sqrt[12]{2}$. Multiplying by this number 12 times is equivalent to a single multiplication by 2 (the octave):

<div class="runnable figure">
	<div class="figDiagram"><object data="edo12.svg?version=VER" type="image/svg+xml" id="edo12"></object></div>
	<div class="figSubPanel"><div class="figRun" id="edo12_play"></div></div>
</div>
<div class="figCaption">
	12-tone equal temperament. Circles contain approximate frequencies in Hertz.
	<br><i>𝒔</i>&nbsp;$=\sqrt[12]{2} \approx 1.0595...$
</div>

Just intonation is a broader system which does not equally divide the octave in any way. In JI, you take your reference pitch, then multiply or divide its frequency by any whole number to get playable tones as desired. In other words, all intervals in JI are natural ratios, while in 12TET, this is only the case for the octave.

<div class="runnable figure">
	<div class="figDiagram">
	<object data="ji_example.svg?version=VER" type="image/svg+xml" id="ji_eg" style="max-width: min(100%,600px);"></object>
	</div>
	<div class="figSubPanel"><div class="figRun" id="ji_eg_play"></div></div>
</div>
<div class="figCaption">
	Example of JI intervals. Circles contain approximate frequencies in Hertz.
</div>

In psychoacoustics, it's generally accepted that our perception of harmony relies on the interpretation of intervals as natural ratios. Simplifying a bit, this means JI is an exact representation of the way we perceive harmony, while 12TET gets harmonic significance from the fact that **it contains intervals that are good approximations of JI intervals**:

<div class="runnable figure">
	<div class="figDiagram">
	<object data="compare.svg?version=VER" type="image/svg+xml" id="compare" style="max-width: min(100%, 580px);"></object>
	</div>
	<div class="figSubPanel">
		JI: <div class="figRun" id="compareji_play"></div> &nbsp; &nbsp; &nbsp; 
		12TET: <div class="figRun" id="compare12_play"></div>
	</div>
</div>
<div class="figCaption">
	A simple melody in both JI and 12TET.
</div>

The theory, so far, tells us that JI should be more consonant than 12TET, but the above examples don't show this convincingly. This is where "writing an album" comes in. To me, making music is the goal of researching it, but it also guides and informs the research, giving a means to judge subjectively whether the results are useful. Below, we'll get to deeper theory, with examples of things that worked noticeably better in JI, but also things that fundamentally don't work in JI.

But before composing in JI, it's necessary to have tools that allow it, and this is more challenging than it might seem. Even simple JI intervals inside a single octave can actually result in an infinity of possible tones, so it seems like we should somehow narrow down the possibilities.

## The "Boring" Solution: Scales

Music-making tools, both digital and physical, often assume you want to work with a limited set of predefined tones. This clashes with "raw" JI and its infinite level of detail. The most common solution, both ancient and modern, is to use a subset of JI with 12 tones per octave. Assuming a modern mindset, this effectively turns JI into an alternative tuning for a familiar musical system.

<div class="runnable figure">
	<div class="figDiagram">
	<object data="keyboard.svg?version=VER" type="image/svg+xml" id="keyboard"></object>
	</div>
	<div class="figSubPanel"><div class="figRun" id="keyboard_play"></div></div>
</div>
<div class="figCaption">
	Example of a 12-tone tuning based on JI: the Pythagorean tuning.
	<br>Circles contain approximate frequencies in Hertz.
</div>

I won't dwell too long on the creation of just-intoned, general-purpose scales, but it's important to understand that this approach is central to the history of music[^1]. There are still some situations where it might make sense to use such scales, but I'll venture to say that in the common case, it's not a great idea. The results easily end up more dissonant than 12TET when the wrong intervals are played, and it's surprisingly hard to avoid the "wrong intervals", something I'll detail further down.

A more creative approach is to experiment with alternative sets of tones that don't attempt to mimic 12TET. These might not have a fixed number of tones per octave, and are often laid out with more consonant tones closer together, which takes some of the edge off the problem mentioned above. These alternative layouts are especially useful to bring physical instruments closer to just intonation.

figure: image
image: ji_instruments.jpg
caption: Not so boring: some instrument layouts focusing on just intonation. Left: [Harry Partch's diamond marimba][], Right: [Jim Snow's JI keyboard][].

## The Far-Out Solution: Freestyle JI

So far, we've bent to the common view that JI can't be used directly, and that you need to narrow it down to a chosen scale or tuning. But what if we don't want to use a predefined set of tones at all? This is what I've been calling "raw" JI, and it's actually an existing approach called freestyle JI, which means you have to be ready to give each note its individual frequency, with all frequencies being natural ratios of each other. This also has the reputation of being terribly impractical, which is always a selling point for me.

Let's see how freestyle JI can make an interesting composition. Imagine the composition moves through a few chords. In a system of fixed tones, you would look at your context (the current chord, maybe the overall key, etc.) and pick the best-matching tones from your predefined set. My approach to freestyle JI was to **redefine which tones are available** whenever the context changes, or in fact, at arbitrary moments.

Here's an example of two successive chords which have their "bespoke" tones defined individually:

<div class=bc_chords>
	<div class=minitrack data-start="41.4%">
		<audio src="02.reflecting_strings.mp3?version=VER" preload="metadata"></audio>
		<a class="mt_album" href="https://purecode.bandcamp.com/album/a-walk-through-the-ambient-garden">
			A Walk through the Ambient Garden
		</a>
		<mt-artist>by Pure Code</mt-artist>
		<mt-track>2. reflecting_strings</mt-track>
	</div>
	<object data="reflecting.svg?version=VER" type="image/svg+xml" id="reflecting"></object>
	<audio src="chord1_12tet.mp3?version=VER" preload="metadata"></audio>
	<audio src="chord1_ji.mp3?version=VER" preload="metadata"></audio>
	<audio src="chord2_12tet.mp3?version=VER" preload="metadata"></audio>
	<audio src="chord2_ji.mp3?version=VER" preload="metadata"></audio>
</div>

In the example above, you can compare the same chords in JI and in their closest possible 12TET approximation[^2]. I'll just say that our habituation to 12TET makes things difficult to judge, but to me, a listening test reveals two things that work better in JI: first, "chord 2" is noticeably more consonant and understandable in JI. This is partly because it contains more [7-limit] intervals, which are more difficult to reproduce in 12TET. Second, the transition between the two chords flows better in JI than in 12TET. I attribute this to keeping shared tones equal, but constructing other tones directly from the shared ones.

This brings us to the variety of tones *between* chords, which becomes more obvious when composing. Throwing all the tones into a single tuning or scale would hardly make sense, with tiny sub-semitone intervals like the one between `9/5` in the first chord and `15/8` in the second. More awkward, arbitrary intervals would appear as more chords are added.

By avoiding any global scale or tuning, tones between chords are allowed to become unrelated, and tend to become even more unrelated between non-adjacent chords. This is exactly what happens throughout the album in question: the harmony is consonant and continuous, but if you take a global view, the album actually contains over 40 distinct tones in a single octave. Could I have built a 40-tone scale and used it to compose the whole thing? Not really: there would be no way to predict which ones are required in advance!

## Building Chords and Composing in Freestyle JI

This is not a guide on composing in JI, the objective is more to understand the value of JI and to see where it fits. That said, it would be rich to write all this without even giving a hint of the *how*. Since the examples focus on complex chords, you might ask right away: how do you build these chords?

Chords and transient scales in JI can be built using variants of James Tenney's harmonic crystal growth technique[^3]. It sounds fancy, but it's a natural process: you take a small number of "seed" tones (in the examples above and below, 2 seed tones were used for each chord), and you "grow" the set by finding tones that are most consonant with all the starting points. In this context, Tenney gives a precise definition of consonance in the form of [harmonic distance][], but different definitions can and should be experimented with. Tenney also describes this process as iterative, where each addition uses the entire previous set as reference, but I prefer to measure distance from nothing but the seeds.

This method can produce a huge variety of chords, especially when slightly modified or constrained in different ways. The relationship between the seeds is perhaps the main determinant for the "feel" of the final chord.

<div class=bc_chords>
	<div class=minitrack data-start="26.2%">
		<audio src="06.occultation.mp3?version=VER" preload="metadata"></audio>
		<a class="mt_album" href="https://purecode.bandcamp.com/album/a-walk-through-the-ambient-garden">
			A Walk through the Ambient Garden
		</a>
		<mt-artist>by Pure Code</mt-artist>
		<mt-track>6. occultation</mt-track>
	</div>
	<object data="occultation.svg?version=VER" type="image/svg+xml" id="occultation"></object>
</div>

The example above is representative of crystal growth, and shows another interesting aspect of this technique: it gives you a direct measure of which tones are central to the chord, and which ones are more peripheral. This can be exploited in composition: do you start with misleading tones, only to reveal the true nature of the chord later on? Or do need to make an impact and state the chord's root immediately? The "order of growth" makes it easy to find this balance, something which is used in this example.

If you think this approach seems impractical to do "by hand", you're completely right. The broader question of which tools suit freestyle JI is a tough one. In my case, I somewhat sidestepped this issue by writing everything in code, for which there's currently no better documentation than [the source code itself][]. That said, nothing in this post is specific to algorithmic music, and I believe that programming should not be necessary to compose in freestyle JI.

The topic of tools, and of deeper practical music theory for composing in this system, is something I would love to dive into, but that's firmly for another day (or lifetime, but we'll get there!) What's really missing here is the counterbalance: I've praised the light side of JI, so all that's left now is to **complain about the dark side**.

## Dissonance in JI: The Devil's Bargain

!!! warning "Rollercoaster Warning"
    I'm now going to argue the complete opposite of everything written above.

It's sometimes said that 12TET, or even temperaments in general, are mostly "vestigial" when composing digitally. After all, computers shouldn't be limited to a fixed number of keys, holes or frets like physical instruments. So in theory, one can imagine that JI offers strictly more freedom and consonance than 12TET. This is, of course, quite wrong, and in a way that has nothing to do with ease-of-use or tools.

This point is best illustrated using an odd but very useful representation: harmonic lattices.

<div class="runnable figure">
	<div class="figDiagram">
	<object data="lattice_intro.svg?version=VER" type="image/svg+xml" id="lattice_intro"></object>
	</div>
	<div class="figSubPanel"><div class="figRun" id="lattice_intro_play"></div></div>
</div>
<div class="figCaption">
	A harmonic lattice in just intonation.
	<br>Values inside the cells are relative to some base frequency, in this case, 440Hz.
</div>

To be precise, this is a piece of the infinite *5-limit pitch class lattice* (a variant of the [tonnetz][]). Our reference pitch is in the middle. Moving right is equivalent to multiplying the current frequency by 3. Similarly, moving up is a multiplication by 5. All of the results are automatically transposed into a single octave. While more dimensions could be added, this choice of factors is good at representing "mainstream" harmony, and at placing more consonant tones closer together.

Let's zoom out a bit to reveal the most important pattern on the lattice:

<div class="runnable figure">
	<div class="figDiagram lattice">
	<object data="lattice_ji_commas.svg?version=VER" type="image/svg+xml" id="lattice_ji_commas"></object>
	</div>
	<div class="figSubPanel"><div class="figRun" id="lattice_ji_commas_play"></div></div>
</div>
<div class="figCaption">
	Similar tones in just intonation.
</div>

Playing on the lattice reveals an inevitable fact: some tones are very similar to each other. Clicking on a tone above highlights the most similar tones. These small intervals are *commas*, and they make composition in JI difficult, because we don't hear the harmonic relationship that defines them, instead, they appear to us as out-of tune versions of the same tone.

Things get interesting when we represent tempered systems on the lattice. I mentioned that 12TET gets its harmonic significance from the way it approximates JI intervals. This can be heard and visualized by comparing the JI lattice against its corresponding 12TET approximation:

<div class="runnable figure">
	<div class="figDiagram lattice">
	<object data="lattice_12_commas.svg?version=VER" type="image/svg+xml" id="lattice_12_commas"></object>
	</div>
	<div class="figSubPanel"><div class="figRun" id="lattice_12_commas_play"></div></div>
</div>
<div class="figCaption">
	Exactly equal tones in 12TET.
</div>

In the 12TET lattice, those similar tones are now exactly equal, in other words, the commas are tempered. In fact, the 12 tones of 12TET are now repeated infinitely across the grid. **This is a tiling**, which opens up different possibilities for composition: you can harmoniously move in any direction, and magically end up back at your starting point. Let's look at this exact technique being used in the *Aníron* chord progression from Howard Shore's soundtrack to The Lord of the Rings. Here, the chords are projected onto the 12TET lattice:

<div class="runnable figure">
	<div class="figDiagram lattice">
	<object data="lattice_12_prog.svg?version=VER" type="image/svg+xml" id="lattice_12_prog"></object>
	</div>
	<div class="figSubPanel"><div class="figRun" id="lattice_12_prog_play"></div></div>
</div>
<div class="figCaption">
	The "Aníron" chord progression, from Howard Shore's soundtrack to The Lord of the Rings
</div>

Above, you can see how harmonic motion in one direction "magically" returns to its starting point, thanks to 12TET's tiling. If you try to replicate this in JI, you're now fighting with commas:

<div class="runnable figure">
	<div class="figDiagram lattice">
	<object data="lattice_ji_prog.svg?version=VER" type="image/svg+xml" id="lattice_ji_prog"></object>
	</div>
	<div class="figSubPanel">
		Solution 1 (drift): <div class="figRun" id="lattice_ji_prog_play2"></div><br>
		Solution 2 (jump): <div class="figRun" id="lattice_ji_prog_play1"></div>
	</div>
</div>
<div class="figCaption">
	Attempting and failing to play the Aníron chord progression in JI.
</div>

There are two ways of adapting this chord progression to JI:

- Keep moving in one direction, and become out of tune with your starting point. The result is somewhere between *unsatisfying* and *jarring* ("Solution 1" above).

- Jump back to your starting point when you get near a tone that's roughly similar. This introduces an out-of-tune transition and defeats the consonance of JI ("Solution 2" above).

12TET naturally merges these small out-of-tune intervals, while distributing any required dissonance evenly over multiple tones. This property exists in other temperaments as well, but 12TET happens to be very good at it. This harmonic technique of "traveling through" 12TET's tiling is neither rare not advanced, it's something that musicians and composers do constantly without even thinking about it. Not only that, but it's common to use single chords that connect tiles together, which would also be impossible in JI. That's why a good part of the music that we know and love does not have any equivalent in JI.

The more you compose in JI, the more you realize the extent of this problem. Even in some very simple chord progressions, our perception of harmony relies on multiple ambiguous connections between tones in different harmonic directions. JI creates perfect intervals for a single interpretation of how tones are connected, but we still hear the other possible interpretations, and they're now more dissonant than with 12TET!

As a consequence, composing in JI is a bit like navigating a minefield. Hidden dissonant intervals are everywhere, and if you don't deliberately avoid them, you're almost guaranteed to simply make things worse than with 12TET. Once you've got a solid intuition for this, then yes, composing in JI can become harmonically rich and varied while remaining consonant.

## Thinking in Different Tunings

This article started off with "JI is better than 12TET", then completely reversed positions. I'll cap off this shameless "thesis/antithesis/synthesis" structure by saying that tuning systems are like artistic construction tools: they all do different things, and while 12TET is great, it's a bit like a hammer that's currently being used for *everything*.

There's also a finer point that underlies this entire article: just intonation is often used as an alternative tuning, but it's more interesting to see it as an entirely different way of composing. Most pieces written in 12TET do not convert well to JI. Similarly, you can do things in JI that don't map well to 12TET. This article gives examples of both.

Music software often offers a "tuning" setting, and then lets you compose using the same old interface. This is interesting to play with, but it's not a good representation of the possibilities of JI, which really call for different ways of representing and reasoning about harmony. 

## Further reading: It's a tone-eat-tone world out there

- [The Xenharmonic Wiki](https://en.xen.wiki/w/Main_Page) is a community of mad scientists focusing on alternative tunings. If you think this entire article is a false dichotomy between two arbitrarily chosen ways of tuning, you can go there to get your fill of additional tunings.
- [Joe Monzo's "bingo-card lattice" page](http://tonalsoft.com/enc/b/bingo.aspx) is the closest thing I've found to this article. His other articles and software are closely related to this topic, and are worth looking into.
- [William A. Sethares' Adaptive Tuning](https://sethares.engr.wisc.edu/papers/adaptun.html) should be mentioned as a technique that can offer consonance and variety similar to freestyle JI, even while composing in a simpler system.

[an album]: https://www.cusamusic.com/album/walk/
[Harry Partch's diamond marimba]: https://en.wikipedia.org/wiki/Instruments_by_Harry_Partch
[Jim Snow's JI keyboard]: https://jsnow.bootlegether.net/jik/keyboard.html
[7-limit]: https://en.xen.wiki/w/7-limit
[crystal growth]: https://www.plainsound.org/pdfs/CrystalGrowthJTeng.pdf
[harmonic distance]: https://en.xen.wiki/w/Tenney_height
[the source code itself]: https://github.com/pac-dev/AmbientGardenAlbum
[tonnetz]: https://en.wikipedia.org/wiki/Tonnetz

[^1]: The topic of scales based on JI, including their history, is explored in glorious geeky detail by John Baez in his "[Just Intonation](https://johncarlosbaez.wordpress.com/2023/10/30/just-intonation-part-1/)" series. He takes a different approach to topics that are very close to this article.
[^2]: A JI composition can be "converted" to 12TET using a [mapping](https://en.xen.wiki/w/Mapping) which is fairly consistent as long as we remain under the 11-limit.
[^3]: The canonical source for the crystal growth technique is James Tenney's posthumously published *From Scratch: Writings in Music Theory*. The most relevant chapter is also currently hosted separately on [Plainsound Music Edition](https://www.plainsound.org/pdfs/CrystalGrowthJTeng.pdf).