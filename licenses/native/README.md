# Native notice supplements

The published `mp4parse 0.10.1` and `realfft 3.5.0` crates omit license bodies.
The collector uses `supplements.json` only for these exact package versions,
SPDX declarations and registry source. Unknown omissions still fail collection.

`mp4parse-0.10.1-MPL-2.0.txt` is its release's repository-root license file.
`MIT-standard.txt` is the standardized SPDX MIT text supplied alongside RealFFT's
actual author and MIT declaration. It is explicitly **not** presented as a
RealFFT-authored license file; its placeholders remain unchanged. No copyright
year or notice has been invented.

The manifest records pinned source/declaration URLs, revisions and SHA-256
digests of UTF-8 text with LF line endings. The collector normalizes CRLF before
checking hashes so Windows Git checkouts produce the same notices. Collection
uses these reviewed local files and makes no network requests.
