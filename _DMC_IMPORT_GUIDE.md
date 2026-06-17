# Do-Me-Coding v0.1 Import Guide

이 zip은 repo root에 바로 풀어 넣는 overlay scaffold입니다.

## Safe install

```bash
cd /path/to/your/repo
git checkout -b dmc-v0.1-scaffold

[ -f CLAUDE.md ] && cp CLAUDE.md CLAUDE.md.before-dmc
[ -f AGENTS.md ] && cp AGENTS.md AGENTS.md.before-dmc
[ -d .claude ] && cp -R .claude .claude.before-dmc
[ -d .harness ] && cp -R .harness .harness.before-dmc

unzip do-me-coding-v0.1-scaffold.zip -d .
chmod +x .claude/hooks/*.sh

git status --short
```

## If existing CLAUDE.md / AGENTS.md exists

Do not blindly overwrite useful repo knowledge. Merge the Do-Me-Coding rules into the existing files.

## Next step

Paste `_DMC_CODEX_PROMPT_AFTER_UNZIP.md` into Codex after unzipping.

## First Claude Code test

```text
/dmc-plan-hard add a tiny README section explaining the local Do-Me-Coding workflow. Do not modify product code yet.
```
