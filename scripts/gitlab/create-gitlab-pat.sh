#!/usr/bin/env bash
# Create av.popov personal access token via LDAP web session (corp GitLab).
# Use when project bot token lacks create_runner or other scopes.
#
# Usage:
#   ./scripts/gitlab/create-gitlab-pat.sh cxado-runner-setup api,create_runner
# Prints JSON with new_token (save to deploy/.secrets/cxado-k3s.env as GITLAB_PAT_RUNNER).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SECRETS="${ROOT}/deploy/.secrets/cxado-k3s.env"
[[ -f "${SECRETS}" ]] && source "${SECRETS}"

NAME="${1:-cxado-runner-setup}"
SCOPES_CSV="${2:-api,create_runner}"
EXPIRES="${3:-2027-07-08}"
SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-bbv-p30-wifi}"
GITLAB_URL="${GITLAB_URL:-https://gitlab.svo.aero}"

if [[ -z "${GITLAB_USER:-}" || -z "${GITLAB_PASSWORD:-}" ]]; then
  echo "missing GITLAB_USER / GITLAB_PASSWORD in ${SECRETS}" >&2
  exit 2
fi

IFS=',' read -r -a SCOPES <<< "${SCOPES_CSV}"

ssh "${SSH_HOST}" "export GL_USER='${GITLAB_USER}' GL_PASS='${GITLAB_PASSWORD}' GITLAB_URL='${GITLAB_URL}' PAT_NAME='${NAME}' PAT_EXPIRES='${EXPIRES}'
SCOPES='${SCOPES_CSV}'
python3 <<'PY'
import json, re, subprocess, urllib.parse, os

gl_user = os.environ['GL_USER']
gl_pass = os.environ['GL_PASS']
gitlab_url = os.environ['GITLAB_URL']
name = os.environ['PAT_NAME']
expires = os.environ['PAT_EXPIRES']
scopes = os.environ['SCOPES'].split(',')

subprocess.run(['rm', '-f', '/tmp/gl-cookies'], check=False)
subprocess.run(['curl', '-sk', '-c', '/tmp/gl-cookies', '-b', '/tmp/gl-cookies',
                f'{gitlab_url}/users/sign_in', '-o', '/tmp/gl-signin.html'], check=True)
html = open('/tmp/gl-signin.html').read()
m = re.search(r'data-testid=\"new_ldap_user\".*?authenticity_token\" value=\"([^\"]+)\"', html, re.S)
ldap_token = m.group(1)
subprocess.run(['curl', '-sk', '-c', '/tmp/gl-cookies', '-b', '/tmp/gl-cookies', '-L', '-X', 'POST',
                f'{gitlab_url}/users/auth/ldapmain/callback',
                '-d', f'authenticity_token={ldap_token}&username={gl_user}&password={gl_pass}'],
               check=True, stdout=subprocess.DEVNULL)
subprocess.run(['curl', '-sk', '-b', '/tmp/gl-cookies',
                f'{gitlab_url}/-/user_settings/personal_access_tokens', '-o', '/tmp/gl-pat.html'], check=True)
html = open('/tmp/gl-pat.html').read()
csrf = re.search(r'name=\"csrf-token\" content=\"([^\"]+)\"', html).group(1)
auth = re.search(r'name=\"csrf-param\" content=\"authenticity_token\" />\s*<meta name=\"csrf-token\" content=\"([^\"]+)\"', html)
if not auth:
    auth = re.search(r'name=\"authenticity_token\" value=\"([^\"]+)\"', html)
auth_token = auth.group(1) if auth else ''
fields = [('authenticity_token', auth_token), ('personal_access_token[name]', name),
          ('personal_access_token[expires_at]', expires)]
for s in scopes:
    fields.append(('personal_access_token[scopes][]', s.strip()))
body = urllib.parse.urlencode(fields)
out = subprocess.run(['curl', '-sk', '-b', '/tmp/gl-cookies', '-X', 'POST',
                      f'{gitlab_url}/-/user_settings/personal_access_tokens',
                      '-H', f'X-CSRF-Token: {csrf}',
                      '-H', 'X-Requested-With: XMLHttpRequest',
                      '-H', 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8',
                      '-d', body], capture_output=True, text=True, check=True)
print(out.stdout)
PY
"
