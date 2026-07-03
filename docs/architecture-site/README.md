# Architecture site

Static architecture landing for cxado / Egregore (RU, Mermaid UML diagrams).

## Local preview

```bash
cd docs/architecture-site
python3 -m http.server 8765
# open http://127.0.0.1:8765
```

## k3s offline deploy

```bash
./scripts/k8s/k3s-sync-arch-docs-credentials.sh   # pull secrets → js/credentials.js
./scripts/k8s/k3s-offline-bundle-arch-docs.sh --remote
```

URL: `https://<k3s-node>:30080`

## Content SSOT

- Outline: [CONTENT.md](CONTENT.md)
- Doc gaps: [GAPS.md](GAPS.md)
- Diagram sources: [diagrams/](diagrams/) (`.mmd` files)
- Credentials: `js/credentials.js` (gitignored, test lab only)

## Notes

- Mermaid is vendored in `js/mermaid.min.js` (~3.5 MB) for offline rendering.
- k8s uses **hostPath** `/home/bbv/cxado/arch-docs`; sync via `k3s-offline-bundle-arch-docs.sh`.
