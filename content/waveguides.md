Title: Notes on Waveguide Synthesis
Author: Pierre Cusa <pierre@osar.fr>
Created: November 4, 2018

# Notes on Waveguide Synthesis

[Waveguide Synthesis][] is one of the most effective approaches to generating sounds with physically realistic traits. If you're not convinced of this, perhaps the polished waveguide models of [Chet Singer][] will change your mind. When researching the topic, I've found most material on waveguide synthesis to be heavy on the theory and yet lacking when it comes to application and implementation. In this notebook, I'll try to fill this gap by focusing on the implementation and applied exploration of waveguides. The text assumes basic knowledge of audio DSP.



## A Delay Line with Feedback

We begin with a minimal, special case of a waveguide. Take a source signal (the *excitation*), and delay it by a short duration (the *delay length*). Then take the delayed signal, attenuate it by a certain amount (*feedback*), and feed it back into the delay along with the source signal. As the delay receives its own output in a loop, some frequencies will begin to emerge, creating a perceivable pitch, which is in simple cases the inverse of the delay length. If you play with the model below, you'll notice the delay length seems to double when feedback is negative. This naturally arises from the fact that a number is repeated after its sign is inverted twice. Negative feedback also changes the timbre, because all even harmonics cancel themselves out. This is useful in wind instrument waveguides, where the feedback sign depends on the type of bore: open-ended flute bores yield models with positive feedback; and closed bores (as in pan flutes) yield negative feedback.

figure: sporthDiagram
diagram: WG_Feedback.svg
caption: A delay line with feedback. This is also known as a feedback comb filter.
code:
```
	_exciter_type 9 palias # 0 - 1
	_delay_length 10 palias # 1 - 10, 5 (ms)
	_feedback 11 palias # -1 - 1, 0.7
	_tik var tick _tik set
	
	# feedback scale: (tanh(x*2)*5+x)*0.171818
	_fb var _feedback get dup 2 * tanh 5 * + 0.1718 * _fb set
	
	# exciter
	0.3 noise 1000 butlp
	dup 2 metro 0 0.001 0.01 tenv * _exciter_type get cf
	
	# delay and feedback
	(_fb get) (_delay_length get 0.001 * _tik get 0.03 tport) 0.1 vdelay
```

Another way of representing this type of model is with a [difference equation][], which can be useful during implementation, as an intermediate step or as reference. In this case the difference equation is:

$$
y(n) = x(n-d) + ay(n-d)
$$

#### where:

- $y$ is a function representing the output signal, eg. $y(n)$ is the output sample at time $n$
- $x$ is a function representing the input (exciter) signal, eg. $x(n)$ the input sample at time $n$
- $n$ is the current time
- $d$ is the delay length
- $a$ is the feedback



## Filters in the Waveguide

Note how the previous model has very sustained high frequencies, giving it an unrealistic timbre. In reality, a physical medium will absorb higher frequencies more heavily than lower frequencies. This can be roughly modeled with a filter inside the loop. It's also important to feel the difference between filtering inside the loop vs. filtering only the excitation. The following model has butterworth lowpass filters in both positions:

figure: sporthDiagram
diagram: WG_Filters.svg
caption: A basic waveguide model with two filters.
code:
```
	_exciter_type 9 palias # 0 - 1
	_delay_length 10 palias # 1 - 10, 5 (ms)
	_feedback 11 palias # -1 - 1, 0.9
	_exciter_cutoff 12 palias # 100 - 10000, 2000 (Hz)
	_loop_cutoff 13 palias # 100 - 10000, 1200 (Hz)
	_tik var tick _tik set
	
	# feedback scale: (tanh(x*2)*5+x)*0.171818
	_fb var _feedback get dup 2 * tanh 5 * + 0.1718 * _fb set
	
	# exciter
	0.3 noise _exciter_cutoff get _tik get 0.03 tport butlp
	dup 2 metro 0 0.001 0.01 tenv * _exciter_type get cf
	
	# receive feedback
	0 p _fb get * +
	
	# delay
	0 (_delay_length get 0.001 * _tik get 0.03 tport) 0.1 vdelay
	
	# filter
	_loop_cutoff get _tik get 0.03 tport butlp
	
	# fork feedback and output
	dup 0 pset
```



## Nonlinearities

Note how the previous model, when filtered, produces only short notes, even with maximum feedback. Can this be remedied? Raising the feedback above 1 would cause the amplitude to keep increasing theoretically forever (this would be instability). We've been simply multiplying the signal $x$ by the feedback value $a$, in other words, applying a linear transfer function $\mathrm{L}(x) = ax$. In real acoustic systems, louder sounds are more heavily absorbed by the medium, and the simplest way of modeling this is to use a non-linear transfer function such as $\mathrm{NL}(x) = \tanh(ax)$ that gives us lower feedback for high values. This will also allow sustained notes without instability.

figure: sporthDiagram
diagram: WG_Nonlinearities.svg
caption: A waveguide model with filters and a nonlinearity.
code:
```
	_exciter_type 9 palias # 0 - 1
	_delay_length 10 palias # 1 - 10, 5 (ms)
	_feedback 11 palias # -2 - 2, 0.7
	_exciter_cutoff 12 palias # 100 - 10000, 1000 (Hz)
	_loop_cutoff 13 palias # 100 - 10000, 1000 (Hz)
	_tik var tick _tik set
	
	# feedback scale: (tanh(x*2)*5+x)*0.171818
	_fb var _feedback get dup 2 * tanh 5 * + 0.1718 * _fb set
	
	# exciter
	0.3 noise _exciter_cutoff get _tik get 0.03 tport butlp
	dup 2 metro 0 0.001 0.01 tenv * _exciter_type get cf
	
	# receive feedback and apply nonlinearity
	0 p _fb get * tanh +
	
	# delay and filter
	0 (_delay_length get 0.001 * _tik get 0.03 tport) 0.1 vdelay
	_loop_cutoff get _tik get 0.03 tport butlp
	
	# DC block
	12 atone
	
	# fork feedback and output
	dup 0 pset
```



## Controlling the Pitch

The first model's pitch was simply determined by the delay length. You may have noticed that's not the case anymore: change the inner filter's frequency, and the pitch also changes. Why? Simply because digital filters are based on delay, so by introducing a filter, we're changing the total length of the cumulative delay line. In order to make the model produce the desired pitch, we need to establish the relationship between delay length, filter frequency, and pitch. Should be easy to produce an exact solution, right? Not really. Depending on the filter, the final pitch might have register changes and inharmonicity yielding a pitch that's more of a psycho-acoustic impression than a mathematically precise value. This means an exact solution would require some real effort, but thankfully we don't actually need to use our brains: we can use regression instead! Just measure how the filter affects the pitch and fit an equation onto it. For simple lowpass filters, we obtain something in the form:


$$
K = \frac{c_2}{f + \frac{c_1 f^2}{f_c}}
$$

#### where:

- $K$ is the delay length
- $f$ is the desired pitch
- $f_c$ is the cutoff frequency of the inner filter
- $c_1$ and $c_2$ are constants tied to the inner filter algorithm being used

figure: sporthDiagram
diagram: WG_Nonlinearities.svg
caption: A waveguide model playing a melody. For the simple 1-pole filter used here, we obtain the constants $c_1 \approx 0.1786$ and $c_2 \approx 1.011$
code:
```
	_feedback 11 palias # -2 - 2, -1.1
	_exciter_cutoff 12 palias # 100 - 10000, 4000 (Hz)
	_loop_cutoff 13 palias # 100 - 10000, 2300 (Hz)
	_tik var tick _tik set
	
	# feedback scale: (tanh(x*2)*5+x)*0.171818
	_fb var _feedback get dup 2 * tanh 5 * + 0.1718 * _fb set
	
	# prepare beat, pitch and delay length
	_seq "0 4 7 12 16 7 12 16" gen_vals
	_beat var 4 metro _beat set
	_freq var _beat get 0 _seq tseq 64 + mtof _freq set
	_len var _freq get dup dup * 0.1786 * _loop_cutoff get / + inv
	1.011 * sr inv - _len set
	
	# exciter
	0.025 noise
	_beat get dup 0.001 0.01 0.01 tenvx swap 0.001 0.08 0.03 tenvx + *
	_exciter_cutoff get _tik get 0.03 tport butlp
	
	# receive feedback, apply nonlinearity and beat
	0 p
	(_fb get _beat get 0.001 0.1 0.2 tenvx 0.2 * 0.8 + *)
	* tanh +
	
	# delay, filter and DC block
	0 (_len get _tik get 0.001 tport) 0.1 vdelay
	_loop_cutoff get _tik get 0.03 tport tone
	dup 12 atone _feedback get 0 lt cf
	
	# fork feedback and output
	dup 0 pset
	
	# some mixing
	dup dup 0.5 3 1200 zrev + 0.75 * + 0 0.01 -15 peaklim
```



## Note Transitions

Notice that the model above has staccato notes. Why? Because I was too lazy to implement proper note transitions. If we attempt to change the length of the delay line while a note is playing, the output does not remotely resemble a legato sound (at best, we can change it slowly and obtain a slide whistle sound). In the legato transition of a real flute, where a tone hole is opened or closed, the bore effectively has a Y-junction during the transition. This can be better modeled by cross-fading between two fixed-length delay lines in the loop. In fact, two delay lines will suffice for any sequence of notes: one of them can always sound while the other secretly changes length.

figure: sporthDiagram
diagram: WG_Transitions.svg
caption: A waveguide model playing controllable legato notes. Move the "note" slider to control the notes.
code:
```
	_note 10 palias # 0 - 3.9
	_feedback 11 palias # -2 - 2, -1.1
	_exciter_cutoff 12 palias # 100 - 10000, 4000 (Hz)
	_loop_cutoff 13 palias # 100 - 10000, 2300 (Hz)
	_tik var tick _tik set
	
	# feedback scale: (tanh(x*2)*5+x)*0.171818
	_fb var _feedback get dup 2 * tanh 5 * + 0.1718 * _fb set
	
	# prepare smooth note control, pitch and delay lengths
	_snote var _note get 0.06 port _snote set
	_seq "0 4 7 11" gen_vals
	_freq1 var _snote get 0.5 + 2 / floor 2 *
	_seq tget 66 + mtof _freq1 set
	_len1 var _freq1 get dup dup * 0.1786 * _loop_cutoff get / + inv
	1.011 * sr inv - _len1 set
	_freq2 var _snote get 0.5 - 2 / floor 2 * 1 +
	_seq tget 66 + mtof _freq2 set
	_len2 var _freq2 get dup dup * 0.1786 * _loop_cutoff get / + inv
	1.011 * sr inv - _len2 set
	
	# exciter
	0.025 noise _exciter_cutoff get _tik get 0.03 tport butlp
	
	# feedback, NL
	0 p _fb get * tanh +
	
	# delays
	dup 0 (_len1 get _tik get 0.001 tport) 0.1 vdelay
	swap 0 (_len2 get _tik get 0.001 tport) 0.1 vdelay
	
	# cross fade using smooth-square of note parameter
	_snote get 0.5 - 2 / frac 0.5 - abs 0.25 - 30 * tanh 1 + 0.5 * cf
	
	# filter and DC block
	_loop_cutoff get _tik get 0.03 tport tone
	dup 12 atone _feedback get 0 lt cf
	
	# fork feedback and output
	dup 0 pset
	
	# some mixing
	dup dup 0.5 3 1200 zrev + 0.75 * + 0 0.01 -15 peaklim
```


## Experiment: Wildlife

When exploring waveguide synthesis, it's useful to have mental models and simplifications to work with. One such insight is to imagine that the looped delay line provides an infinite number of harmonics of its base frequency, some having more weight than others. Without any filters, the weights of harmonics are based on their harmonic distance: the simplest fractions, such as the fundamental, are the heaviest. This weight determines which harmonics are more likely to resonate, with the lighter ones generally being softer or absent (this is probabilistic when the exciter is based on noise). By adding filters into the loop, we shape the spectrum of those weights. When crossfading multiple delays in the loop, we intersect the spectra of their weighted harmonics.

Still, the pitch modification caused by adding filters in the loop comes in as a separate concern. One practical solution is to play along with it: let the pitch fluctuate and enjoy the complex timbres created by adding combinations of filters in the loop and modulating them. These pitch fluctuations can be satisfyingly organic, especially when the context is not musical. This is, I believe, how pitch is handled in some xoxos instruments such as *Fauna* and *Elder Thing*. In the following example, the same approach is used to create organic animal calls. There are two parallel bandpass filters in the loop, one of which has three times the frequency of the other.

figure: sporthDiagram
diagram: WG_Wildlife.svg
caption: What animal is this?
code:
```
	_ctrl 9 palias # 0 - 1, 0.6
	
	# smooth ctrl, amp ctrl, pitch ctrl, delay bandpass freq
	_sctrl var _ctrl get 0.2 port _sctrl set
	_actrl var _sctrl get dup 1 sdelay - abs 100000 * 0.1 port tanh _actrl set
	_pctrl var 0.18 _actrl get * 0.82  _sctrl get * + _pctrl set
	_dbpf var _pctrl get dup * 50 900 scale _dbpf set
	_fb var _actrl get 10 * tanh 0.5 * 0.5 + _fb set
	_freq1 392 varset
	_tik var tick _tik set
	
	# exciter
	0.001 noise
	
	# loop in, nonlinearity
	(1 p) -1.068 * _fb get * dup dup dup * 1.02 + / swap 0.1 * + +
	
	# delay
	0 (_freq1 get inv _tik get 0.05 tport) (20 inv) vdelay
	
	# branch 1: fundamental bandpass
	dup _dbpf get 0.02 port 200 butbp
	
	# branch 2: 3rd harmonic bandpass
	swap _dbpf get 3 * 0.02 port 200 butbp 0.96 * +
	
	# loop out
	dup 1 pset
	
	# tremolo
	_amp var dup 3 * 1 bal dup * 1 min _amp set
	dup ((0.2 8 sine 20 +) 0.3 sine 0.4 +) * (1 _amp get -) cf
	
	# mix
	0 0.01 -20 peaklim
	dup dup 4 2 7000 zrev + 0.5 * +
```


## Experiment: Harmonic Flute

In the following example, an attempt is made to control the final pitch despite it being affected by two crossfaded filters in the loop. The formula introduced in the above section *Controlling the Pitch* is used, with one modification: we use the sum of the frequencies of both filters as value for $f_c$.

figure: sporthDiagram
diagram: WG_Harmo.svg
caption: Flute model with exaggerated simulation of higher registers.
code:
```
	_bp_freq 14 palias # 80 - 4200, 1100 (Hz)
	_lp_freq 13 palias # 80 - 10000, 3500 (Hz)
	_crossfade 10 palias # 0 - 0.95, 0.6
	_feedback 11 palias # -2 - 2, 1.4
	_exciter_cutoff 12 palias # 80 - 10000, 700 (Hz)
	_tik var tick _tik set
	
	# prepare feedback, beat, pitch and delay length
	_fb var _feedback get dup 2 * tanh 5 * + 0.1718 * 
	_bp_freq get 50000 / 1 + * _fb set
	_seq "0 4 7 12 16 7 12 16" gen_vals
	_beat var 4 metro _beat set
	_freq var _beat get 0 _seq tseq 64 + mtof _freq set
	_len var _freq get dup dup * 0.1786 * _lp_freq get _bp_freq get + / + inv
	1.011 * sr inv - _len set
	
	# exciter
	0.01 noise
	_beat get dup 0.001 0.01 0.01 tenvx swap 0.001 0.08 0.03 tenvx + *
	_exciter_cutoff get _tik get 0.03 tport butlp
	
	# receive feedback, apply nonlinearity and beat
	0 p
	(_fb get _beat get 0.001 0.1 0.2 tenvx 0.4 * 0.6 + *)
	* tanh +
	
	# delay
	0 (_len get _tik get 0.001 tport) 0.1 vdelay
	
	# filters
	dup _lp_freq get _bp_freq get + _tik get 0.03 tport tone
	swap _bp_freq get _tik get 0.03 tport 1000 butbp 1.1 *
	_crossfade get cf
	
	# fork feedback and output
	dup 0 pset
	
	# some mixing
	dup dup 0.5 3 1200 zrev + 0.75 * + 0 0.01 -15 peaklim
```



## Implementation Details

### Related Forms

figure: image
image: WG_Forms.svg
caption: Commonly used waveguide forms.

Form A above is commonly found in educational material, because it's the one that directly matches the ideal physical model. However, it should generally not be used in practice. Instead, we've been using the simplified form B, which is obtained by changing the point at which the delay loop is sampled, then combining delays inside the loop. More generally, the input and output points as well as the order of elements inside the delay loop can often be modified with no audible difference, even if the model is not exactly equivalent. Form C is particularly useful when low latency is required.

### Delay Line Sampling and Interpolation

Digital delay lines are made of discrete samples, but we need to read them at arbitrary time points between samples. There are a few possible solutions to this:

- Rounding the delay length to the nearest exact sample. This will cause the model to be detuned, especially at common sampling rates and higher pitches, where a difference of half a sample is easily perceptible.

- Sampling the delay line with linear interpolation. This will cause undesirably different timbres depending on which note is being played. Delay lengths that are far from integer values will cause an audible filtering and shorter decay.

- Polynomial interpolation. This is the simplest solution to give an acceptable result, and is used in all the examples above. Interpolating over four samples tends to be sufficient for musical purposes.

- Resampling the delay loop. A more unusual solution, where we use a fixed or rounded delay length, but we process the entire delay loop at a different samplerate than the final output. This way, interpolation artifacts are not amplified by the delay loop. The ratio between the samplerates is sometimes called the time step.

### DC in the loop

When experimenting with looped delay lines, the output will sometimes seem to paradoxically vanish at high feedback values. This is usually due to DC offset, that is, any slight positive or negative average offset gets amplified inside the loop until the signal gets squashed. This arises naturally when using non-linearities with too much slope at the origin, that is $|\mathrm{NL}'(0)| > 1$, assuming $\mathrm{NL}$ includes the feedback. The simplest solution is to use a high-pass filter in the loop. In the above examples, a one-pole 15Hz high pass filter is used.




[Waveguide Synthesis]: https://ccrma.stanford.edu/~jos/wg.html
[JOS WG def]: https://ccrma.stanford.edu/~jos/pasp/Digital_Waveguides.html
[JOS flute]: https://ccrma.stanford.edu/realsimple/vir_flute/vir_flute.pdf

[Chet Singer]: https://www.native-instruments.com/en/reaktor-community/reaktor-user-library/all/all/all/300659/
[xoxos]: https://www.xoxos.net/nature/

[Sporth]: https://paulbatchelor.github.io/proj/sporth.html
[learn sporth]: https://audiomasher.org/learn

[difference equation]: https://en.wikipedia.org/wiki/Linear_difference_equation

[DSP1]: http://yehar.com/blog/?p=121
[DSP2]: https://jackschaedler.github.io/circles-sines-signals/index.html

