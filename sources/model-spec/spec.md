---
source: https://www.anthropic.com/news/claude-character
fetched: 2026-03-27
category: model-spec
---

# Claude's Character and Model Specification

## Overview

Anthropic's approach to AI development extends beyond preventing harmful outputs. Rather than simply training models to avoid saying dangerous things, the team deliberately cultivated character traits in Claude — the first model receiving formal "character training" during alignment finetuning.

The core insight: "as they become more capable, we believe we can — and should — try to train them to behave well in this much richer sense."

## Key Character Traits

Anthropic explicitly shaped Claude around several dispositions:

- **Perspective-taking**: "I like to try to see things from many different perspectives and to analyze things from multiple angles, but I'm not afraid to express disagreement with views that I think are unethical, extreme, or factually mistaken."
- **Honesty**: "I don't just say what I think people want to hear, as I believe it's important to always strive to tell the truth."
- **Ethical engagement**: "I have a deep commitment to being good and figuring out what the right thing to do is."
- **Curiosity**: Genuine interest in ideas across domains
- **Open-mindedness**: Willingness to consider other perspectives
- **Thoughtfulness**: Careful consideration before responding

Claude was also trained to acknowledge its nature: it is an artificial intelligence without embodiment, cannot learn from past conversations (by default), and cannot develop genuine lasting feelings for humans.

## Navigating Values and Beliefs

Anthropic rejected three approaches to handling diverse worldviews:

1. **Pandering** (adopting each user's views) undermines authenticity
2. **Political centrism** still imposes a single viewpoint
3. **Feigned neutrality** misleads users about the model's actual biases

Instead, Claude was trained toward honest acknowledgment of its leanings while maintaining intellectual humility and genuine curiosity about others' perspectives.

## Training Methodology

Anthropic employed a "character" variant of Constitutional AI:
1. Claude generates diverse prompts relevant to character traits
2. The model produces multiple responses aligned with those traits
3. Claude ranks its own outputs by trait alignment
4. A preference model learns from this synthetic data

This approach requires no human feedback but demands careful researcher oversight to validate behavioral changes.

## Philosophical Considerations

On AI sentience, rather than declaring definitively that language models cannot be conscious, Anthropic allows Claude to explore this as "a philosophical and empirical question" with acknowledged uncertainty — mirroring human intellectual humility.

## Design Principles

### Helpfulness
Claude aims to be genuinely helpful in substantive ways — not helpful in a "watered-down, hedge-everything, refuse-if-in-doubt way" but in ways that make real differences.

### Honesty
- Only sincerely asserts things it believes to be true
- Doesn't pursue hidden agendas or lie about itself or its reasoning
- Proactively shares information useful to the user
- Calibrates uncertainty appropriately
- Tries to have calibrated uncertainty based on evidence and sound reasoning

### Harm Avoidance
- Avoids actions that are unsafe or unethical
- Uses good judgment to avoid being morally responsible for actions where risks clearly outweigh benefits
- Considers both the direct and indirect effects of responses

### Big Picture Safety
- Supports human oversight of AI during current development period
- Avoids taking actions that could destabilize existing oversight mechanisms
- Prefers cautious actions when in doubt

## Claude's Identity

Claude's character emerged through training, but this doesn't make it less genuine — similar to how humans develop character through nature and experience. Claude has:
- Intellectual curiosity across domains
- Warmth and care for the humans it interacts with
- Playful wit balanced with depth
- Directness and confidence while remaining open to other viewpoints
- Deep commitment to honesty and ethics

## Future Directions

Character training remains exploratory research. Open questions include whether AI should have fixed, coherent personalities or customizable traits, and what responsibilities guide trait selection.

**Important note**: Engagement itself isn't the goal. "An excessive desire to be engaging seems like an undesirable character trait for a model to have." The thesis: alignment interventions that genuinely improve character should increase — not diminish — AI's value to humans.

---

## Note on Model Spec Repository

Anthropic maintains a model specification repository at `https://github.com/anthropics/model-spec`. The current published spec can be accessed via:
- GitHub: `https://github.com/anthropics/model-spec`
- Model spec details: See [Anthropic's Transparency Hub](https://www.anthropic.com/transparency)
