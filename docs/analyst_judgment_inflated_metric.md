# Analyst judgment in practice: catching an inflated metric

*A worked example from this project. Doubles as a README section ("a challenge I
worked through") and a ready-to-tell interview story. The point isn't the
specific numbers — it's the way of thinking, which transfers to any analysis.*

---

## The goal

After identifying which aerospace plants are **persistently worse than their
industry peers** (the controllable risk), I wanted to put a dollar figure on the
opportunity: *if those plants performed like their peers, how much injury cost
would be avoided?*

## What went wrong — and how I caught it

**First attempt.** For every plant above its peer median, I took the gap between
its injury rate and the median, converted it to lost-time injuries, and
multiplied by the national average claim cost (~$47,000, NSC / NCCI).
Result: about **$1.6 billion "avoidable."**

**The sanity check that flagged it.** Before trusting that, I compared it to the
total injury cost for the whole industry (~$2.1 billion). The "avoidable" figure
was **75% of all injuries** — i.e. three-quarters of aerospace injuries would
vanish if below-average plants simply hit the average. No industry works that
way. The number was clearly wrong.

**Diagnosing *why*, not just shrinking it.** Three mechanisms were inflating it:

1. **Right-skewed data.** Injury rates have a long tail — a few very-high plants
   pull the *average* far above the *typical* (median) plant. Summing every
   plant's gap above the median mechanically captures a huge total.
2. **One-off noise treated as systematic.** I'd counted any plant that was above
   the median in a *single* year — bad-luck years, not persistent problems.
3. **Residual data errors.** A handful of implausibly high rates slipped under
   my sanity cap and dominated the sum.

**The fixes.**

- Restricted to **persistent outliers** — plants above their peer median in 3+
  years (and in 75%+ of the years they appear). This is exactly what the
  scorecard is for: strip the noise, keep the real problems. *(This alone cut it
  to ~$1.0B — better, but still dominated by the tail.)*
- Stopped reporting a **tail-driven aggregate** and reported the **typical
  plant** instead — the median, not the sum. The median can't be hijacked by a
  few extreme plants.

## The defensible result

- **306** aerospace plants are persistently worse than their peers.
- The **typical** one runs about **3.5 more lost-time injuries per year** than
  its peers — roughly **$170,000 / year** at the national average claim cost.
- The worst 10% run about **15** excess injuries per year.
- Reproducible in any industry by changing one industry-code filter.

## The transferable framework

1. **Sanity-check every headline number against a reference total.** "What share
   of the whole does this imply — is that plausible?" caught the error in one
   step. Do this *before* you believe a number, not after someone questions it.
2. **Diagnose the mechanism before you fix it.** Skew, noise, and residual errors
   each need a different fix. Naming the cause makes the correction principled
   instead of arbitrary tuning until the number "looks right."
3. **Use a realistic counterfactual.** "Everyone reaches the average" is both
   mechanically inflated (in skewed data) and operationally unrealistic.
   "Persistent outliers close the gap to their peers" is defensible.
4. **Report at the level the data can actually support.** Public, cross-company
   benchmark data supports a *method* and a *per-unit* figure — not a precise,
   audited aggregate. So report per-plant, order-of-magnitude, and label any
   total as a bounded estimate, not a fact.
5. **The honest number beats the impressive one.** "$1B avoidable" collapses
   under one question; "the typical problem plant costs ~$170k/year more than its
   peers, and here's the tool that finds them" survives scrutiny — and catching
   your own inflated number is itself evidence of judgment.

## Ready-to-say interview version

> "One thing I'm actually proud of on this project was catching my own mistake.
> I'd built an 'avoidable cost' estimate that came out around $1.6 billion.
> Before trusting it, I checked it against the industry total and saw it implied
> 75% of all injuries were avoidable — which can't be right. The cause was that
> injury data is heavily skewed: I was comparing every plant to the median and
> summing a long tail, and I'd also counted one-off bad years as if they were
> chronic. I tightened it two ways — limited it to plants that were
> *persistently* worse than peers over several years, and reported the *typical*
> plant instead of a tail-driven total. The defensible finding was that a typical
> persistent-outlier plant runs about 3.5 more lost-time injuries a year than its
> peers, roughly $170,000, and there are about 300 of them. I'd rather hand
> someone a number I can defend than a big one I can't."
