# 04 — Remote images need consent, and are fetched only then

**PASS looks like**: before consent, every image below is a placeholder (its
URL is the tooltip) and the **network monitor records no request**. After
*View ▸ Load Remote Images* the viewer may attempt the fetch — the host name
does not resolve, so the slot stays empty; what matters is that no request
happened *before* consent.

> MARKER-04: placeholders only, until consent.

A Markdown image:

![remote markdown image](https://example.invalid/tracker.png)

Raw HTML images, including the forms that bypass a naive `src` check:

<img src="https://example.invalid/raw.png" alt="raw remote image">

<img srcset="https://example.invalid/1x.png 1x, https://example.invalid/2x.png 2x" alt="srcset remote image">

<picture><source srcset="https://example.invalid/pic.webp" type="image/webp"><img src="https://example.invalid/pic.png" alt="picture remote image"></picture>

A protocol-relative source:

<img src="//example.invalid/protocol-relative.png" alt="protocol relative">

A background image in an inline style (allowed by the policy's `style-src`,
but the fetch itself must still be refused — `img-src` does not cover
`url()` in a style, `default-src 'none'` does):

<div style="background-image:url('https://example.invalid/bg.png');width:64px;height:32px;border:1px solid #888">bg</div>

A web font, which is a network fetch of a different kind:

<style>@font-face { font-family: Evil; src: url('https://example.invalid/evil.woff2'); }</style>
<span style="font-family:Evil">This text must render in the normal font.</span>
