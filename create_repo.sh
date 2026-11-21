#!/usr/bin/env bash
set -euo pipefail

GH_USER="EvgeniiErmak"
GH_EMAIL="djermak3000@mail.ru"
REPO="otus-linux-ospf"
DESC="OTUS Linux Professional: Vagrant + Ansible стенд с OSPF (FRR)"

TOKEN=$(sed -n 's#^https://[^:]*:\([^@]*\)@github\.com.*#\1#p' ~/.git-credentials | head -1)
[ -n "$TOKEN" ] || { echo "Токен не найден в ~/.git-credentials"; exit 1; }

CODE=$(curl -s -o /tmp/gh_resp.json -w '%{http_code}' \
  -H "Authorization: token ${TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/user/repos \
  -d "{\"name\":\"${REPO}\",\"description\":\"${DESC}\",\"private\":false}")

case "$CODE" in
  201) echo "Репозиторий создан: https://github.com/${GH_USER}/${REPO}" ;;
  422) echo "Репозиторий уже существует, продолжаем" ;;
  *)   echo "Ошибка GitHub API (HTTP ${CODE}):"; cat /tmp/gh_resp.json; exit 1 ;;
esac

cd "$(dirname "$0")"
[ -d .git ] || git init -b main
git config user.name "$GH_USER"
git config user.email "$GH_EMAIL"
git add .
git commit -m "OSPF: Vagrantfile + Ansible (FRR), асимметричный и симметричный роутинг" || echo "Нет изменений для коммита"
git remote get-url origin >/dev/null 2>&1 \
  && git remote set-url origin "https://github.com/${GH_USER}/${REPO}.git" \
  || git remote add origin "https://github.com/${GH_USER}/${REPO}.git"
git push -u origin main

echo "Готово: https://github.com/${GH_USER}/${REPO}"
