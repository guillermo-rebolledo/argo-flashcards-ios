> **Copied from the Android repo** — `guillermo-rebolledo/argo-flashcards`, `docs/adr/0005-a-page-is-read-by-the-model-not-by-the-app.md`.
> The decision was made there and still binds here.
>
> Copied rather than linked: a cross-repo link is a broken link waiting to happen, and a
> copy makes a future divergence visible as an edit to one side rather than a silent change
> to both. **The body below is unchanged from the original.**
>
> The client is hand-written against the Messages API on both platforms, so this one carries across with no mechanics to translate.

# A page is read by the model, not by the app

Generating a Deck from a URL sends the address to Anthropic and declares the `web_fetch` tool. The page is retrieved server-side and becomes the material for the same Generation pasted text would have produced. The device makes exactly one request, to the same endpoint it already used, and never speaks to the page's host at all.

The prototype did the opposite: an HTTP client on the device, a redirect and encoding policy, an HTML parser, and a readability pass to get from a page of markup to the prose worth making Cards from. That is a lot of code to own, and all of it is the boring, wrong-most-of-the-time kind — every site is a new way for a heuristic extractor to pick the cookie banner over the article. It also puts the user's IP and headers in front of whatever they paste, which a bring-your-own-key app with no server has no reason to do.

Letting the model fetch collapses that to a tool declaration. The extraction problem stops being ours: the model reads the whole page and decides what in it is worth remembering, which is the same judgement it is already making on pasted text.

## Consequences

- **Pages that only exist after JavaScript runs cannot be read.** The tool fetches; it does not render. This is a real hole — a single-page app's article is invisible to it — and it is why `PAGE_UNREADABLE` offers pasting the text rather than only apologising.
- **A page can fail to arrive in two different ways, and only one of them is an error.** A 404 or a blocked host comes back as a tool result carrying an error code instead of a document, inside an otherwise successful HTTP 200 — read before anything the model went on to say, or a page that never arrived surfaces as material that produced nothing. A paywall, a consent wall, or a browser-only shell fetches perfectly and arrives as a page about signing in; nothing but the model can tell that from thin material, so the schema carries an `unreadable` flag for it to say so. Both land on the same failure, because the user's way out of them is the same.
- Every fetch must have failed for the first of those to count. The tool is allowed one retry, and a page that arrived on the second attempt is a page that was read.
- Page content is capped with `max_content_tokens`. Generation is billed to the user's own key, and a URL is a much bigger blank cheque than a paste — a book behind one address would otherwise be a request the user did not know they were making.
- The fetch tool is offered only when the Source is a URL, so a paste that happens to mention a link cannot turn into a page request nobody asked for. The tool will not fetch an address it has composed itself either — only ones already in the conversation.
- The basic `web_fetch_20250910` is what is declared rather than a filtering version. Filtering trims a fetched page to what a question needs; here the whole page is the question, and the cap is what bounds it.
