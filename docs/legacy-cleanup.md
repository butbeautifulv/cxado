# Legacy cleanup

Some pre-migration directories may be owned by root (Docker volumes) and cannot be removed without elevated permissions.

## Manual cleanup (if needed)

```bash
# Root-owned legacy clones under workspace .external/
sudo rm -rf /path/to/cxado/.external

# Desktop duplicate with Docker data
sudo rm -rf ~/Desktop/threat_intelligence
```

After cleanup, use only the cxado meta-repo:

```bash
git clone --recurse-submodules https://github.com/butbeautifulv/cxado.git ~/Desktop/cxado
cd ~/Desktop/cxado && make bootstrap
```
