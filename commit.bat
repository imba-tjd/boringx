git add .
git log -1 --oneline
wsl git commit --amend --no-edit --date "$(date -R)"
git push -f
