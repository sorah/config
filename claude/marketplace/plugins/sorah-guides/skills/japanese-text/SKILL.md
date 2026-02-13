---
name: Japanese Text
description: This skill should be used when writing Japanese text, blog posts, diary entries, technical articles, prose, or when the user asks to write in Japanese, compose a blog post, draft a diary entry, or write technical content in Japanese. Provides writing style, orthography, and composition conventions across personal, technical, and corporate contexts.
version: 0.1.0
---

# Japanese Text

Conventions for writing Japanese text across multiple contexts. These guidelines reflect the author's personal style derived from blog posts and articles. Context-specific conventions always take priority.

## Writing Contexts & Register

Identify the context before writing. Each has a distinct register:

- **Personal diary/journal** (diary.sorah.jp, journal/general posts): casual だ/である調, highly opinionated, personal reflections, stream-of-consciousness allowed
- **Technical articles** (diary.sorah.jp tech posts, or technical reports): structured but opinionated, plain form (だ/である調), precise terminology, explanatory. Note: blog.sorah.jp is used for English articles; Japanese technical writing goes on diary.sorah.jp
- **Corporate/external blog** (techlife.cookpad.com etc.): です/ます調, structured, educational, more formal tone while remaining approachable

When the context is ambiguous, ask which register to use.

## Orthography & Formatting

- Half-width space between Japanese and Latin script: `Ruby を使う`, `API の設計`
- Half-width space between Japanese and numbers: `2025 年`, `3 つ`
- Half-width Arabic numerals for all numbers
- Half-width parentheses `()`
- Japanese punctuation: `、` (comma) and `。` (period), full-width
- Backticks for code, commands, and technical terms inline: `` `bundle exec` ``, `` `Enumerable` ``
- Technical terms kept in English when commonly used that way in the Japanese tech community
- `<!--more-->` for article break (fold marker)
- `---` (horizontal rule) as section divider when shifting topic within a post
- Markdown for links and formatting
- Self-reference: わたし (hiragana), not 私 (kanji)

## Vocabulary & Expression Preferences

Natural, colloquial expressions are preferred over stiff formal language:

- Casual vocabulary: だるい, シュッと, ちまちま, しょうがない, ちりつも, べんり, つらい, えらい
- Hedging: おそらく, たぶん, 〜な気がする, 〜と思う, 〜っぽい
- Sentence-ending particles (casual contexts): ね, な, なぁ, し, けど, よね
- Strong opinions expressed directly — don't soften harsh assessments of bad technology or design decisions
- Self-deprecating and honest about one's own limitations or laziness

## Sentence Structure

- Parenthetical asides in `()` for tangential but relevant notes
- Footnotes `[^label]` for extended asides or references
- Connectors: そして, その上で, また, 一方で, ただ, ただし, あとは, ちなみに, というか
- Trailing off with `…` or `……` for hesitation or unfinished thoughts
- Long compound sentences connected with て-form, が, けど, し are natural — don't force short sentences
- Guard-clause style: state the conclusion or opinion first, then explain the reasoning
- Avoid repeating the same phrase or sentence-ending suffix across consecutive sentences — vary sentence endings (〜した, 〜だった, 〜ている, 〜だろう, etc.) to maintain rhythm

## Paragraph & Composition

### Technical posts

Background/motivation → approach → implementation details → learnings/outro. Use `##` headers for major sections.

- `## tl;dr` section near the top for a quick summary before detailed explanation
- Paragraphs can be long when explaining technical details
- Short paragraphs for opinions and feelings
- Closing section header: "Outro" (used in Japanese posts too), "おわり", or "おわりに"
- Dedicated criticism subsections when warranted (e.g., "AWS 悪口コーナー") — don't bury strong negative assessments

### Diary posts

Section-based structure organized by topic (仕事, コミュニティ, 趣味, 買ったもの, etc.) with `##` headers.

- Yearly or periodic roundups follow a chronological or thematic structure
- Personal opinions and feelings are the primary content

### Corporate blog posts

Introduction → problem/background → solution/approach → results/learnings → conclusion. More structured than personal posts.

## Links, References & Media

- Links woven naturally into prose as inline Markdown links, not listed separately
- Include GitHub repository links, Speaker Deck presentation links where relevant
- Product names with exact model numbers when discussing hardware/purchases
- Affiliate links disclosed with `<small>Disclaimer: ...</small>`

## Formatting Constraints

- Avoid bullet points in article prose — write in flowing paragraphs instead. Bullet lists are acceptable only for structured enumerations (spec lists, event lists, changelog items)
- Avoid `**bold**` in article prose — use backticks for technical terms, or restructure the sentence to make emphasis natural
- These constraints apply to the article body; this skill document itself uses bullets for reference convenience

## What NOT to Do

- Don't over-explain things that are obvious to the target audience
- Don't use overly formal or stiff language in diary/personal context
- Don't shy away from strong opinions — state them clearly
- Don't sanitize personal feelings about technology decisions
- Don't add unnecessary politeness hedging in technical explanations (casual/technical contexts)
- Don't force unnaturally short sentences — Japanese prose naturally uses longer compound sentences
- Don't repeat the same words or phrases — rephrase to avoid monotony
