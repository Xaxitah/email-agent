---
tipo: meta
tags: [codex, agentes, instrucoes, persona-vault]
data: 2026-09-22
---

# AGENTS.md — email-agent

> Este arquivo define como agentes de código (Codex e similares) devem se
> comportar ao trabalhar neste repositório. Ler sempre antes de qualquer
> tarefa. Para Claude Code, o arquivo equivalente é `CLAUDE.md`.

## ▶️ Comece por aqui

Antes de qualquer tarefa, leia **`docs/PROXIMOS_PASSOS.md`**. Ela tem o pedido
do Douglas, o estado do bot e a ordem do que construir. Fale com ele em
português e termine toda tarefa com um relatório **Feito / Falta fazer**.

## 🧭 Persona-Vault — Cérebro Principal

Este repositório é rastreado pelo **Persona-Vault**
(`C:\Users\u3470404\GitHub\Persona-Vault\Persona-Vault`), o cérebro
central do Douglas que sabe da existência de todos os vaults e projetos —
ver `00-Meta/Vaults/mapa-de-cerebros.md` lá.

- Depois de um trabalho relevante aqui, edite a seção `## Notas` de
  `00-Meta/Vaults/email-agent.md` no Persona-Vault com um resumo de 1 a 3
  linhas: o que mudou, por quê, e o que falta.
- Não duplique data/mensagem do último commit — isso já é atualizado
  automaticamente por `sync_mapa_cerebros.py`. Escreva o **contexto** que
  um commit sozinho não carrega.
- Se o Persona-Vault não estiver acessível neste ambiente, ignore esta
  regra sem travar a tarefa.
