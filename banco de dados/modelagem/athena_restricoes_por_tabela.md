# Projeto Athena — Restrições por tabela

Documento de apoio ao modelo de dados (PostgreSQL / Supabase). A tabela `auth.users` é gerenciada pelo Supabase Auth e é apenas referenciada; todas as tabelas de negócio ficam no schema `public`.

## Decisões de modelagem

- **Ligação com a autenticação:** `perfis.auth_id` referencia `auth.users(id)` com `ON DELETE CASCADE`. A relação é 1:1, garantida por `UNIQUE`. O `id` próprio de `perfis` foi mantido porque o diagrama de classes tem `id` e `auth_id` como atributos separados.
- **Herança `Perfil` → `Professor` / `Aluno`:** uma tabela por subtipo. A PK de cada subtipo é também FK para `perfis`. Isso permite `cref NOT NULL` para professores sem deixar colunas nulas para alunos.
- **`alunos.professor_id` é opcional:** o aluno se cadastra sozinho (RF01) e só depois é vinculado por um professor (RF02).
- **Uma única ficha ativa por aluno:** índice único parcial em `fichas_treino (aluno_id) WHERE ativa`. Dá suporte direto ao RF04.
- **Histórico no nível do exercício:** o diagrama de atividades marca "concluído" exercício a exercício (RF05). A frequência (RF06) sai de `COUNT(DISTINCT data_execucao)`.
- **Preservação do histórico:** se uma ficha for excluída (RF03), `ficha_id` e `exercicio_id` do histórico viram `NULL` (`ON DELETE SET NULL`) e `nome_exercicio` guarda uma cópia do nome.

## perfis

| Campo | Tipo | NOT NULL | UNIQUE | FK |
|---|---|---|---|---|
| `id` | uuid | sim (PK) | sim | — |
| `auth_id` | uuid | sim | sim | `auth.users(id)` |
| `nome_completo` | text | sim | — | — |
| `email` | text | sim | sim | — |
| `tipo_perfil` | enum (`professor`, `aluno`) | sim | — | — |
| `criado_em` | timestamptz | sim (default `now()`) | — | — |

## professores

| Campo | Tipo | NOT NULL | UNIQUE | FK |
|---|---|---|---|---|
| `perfil_id` | uuid | sim (PK) | sim | `perfis(id)` |
| `cref` | text | sim | sim | — |

## alunos

| Campo | Tipo | NOT NULL | UNIQUE | FK |
|---|---|---|---|---|
| `perfil_id` | uuid | sim (PK) | sim | `perfis(id)` |
| `professor_id` | uuid | não | — | `professores(perfil_id)` |
| `objetivo` | text | não | — | — |

## fichas_treino

| Campo | Tipo | NOT NULL | UNIQUE | FK |
|---|---|---|---|---|
| `id` | uuid | sim (PK) | sim | — |
| `aluno_id` | uuid | sim | — | `alunos(perfil_id)` |
| `professor_id` | uuid | sim | — | `professores(perfil_id)` |
| `titulo` | text | sim | — | — |
| `ativa` | boolean | sim (default `false`) | só uma `true` por aluno | — |
| `criado_em` | timestamptz | sim (default `now()`) | — | — |

## exercicios

| Campo | Tipo | NOT NULL | UNIQUE | FK |
|---|---|---|---|---|
| `id` | uuid | sim (PK) | sim | — |
| `ficha_id` | uuid | sim | `(ficha_id, ordem)` | `fichas_treino(id)` |
| `nome` | text | sim | — | — |
| `series` | int (`> 0`) | sim | — | — |
| `repeticoes` | text | sim | — | — |
| `ordem` | smallint | sim | `(ficha_id, ordem)` | — |
| `tempo_descanso_seg` | int | não (Could Have) | — | — |
| `carga_sugerida` | numeric(6,2) | não | — | — |

`repeticoes` é texto para aceitar tanto "12" quanto "30s", conforme o RF03 (repetições/tempo).

## historico_execucoes

| Campo | Tipo | NOT NULL | UNIQUE | FK |
|---|---|---|---|---|
| `id` | uuid | sim (PK) | sim | — |
| `aluno_id` | uuid | sim | `(aluno_id, exercicio_id, data_execucao)` | `alunos(perfil_id)` |
| `ficha_id` | uuid | não | — | `fichas_treino(id)` |
| `exercicio_id` | uuid | não | `(aluno_id, exercicio_id, data_execucao)` | `exercicios(id)` |
| `nome_exercicio` | text | sim | — | — |
| `data_execucao` | date | sim (default `current_date`) | `(aluno_id, exercicio_id, data_execucao)` | — |
| `feedback_fadiga` | text | não (Should Have) | — | — |

A restrição `UNIQUE` composta impede o aluno de marcar o mesmo exercício duas vezes no mesmo dia.

## Resumo das chaves estrangeiras

| Tabela | Campo | Referencia | ON DELETE |
|---|---|---|---|
| `perfis` | `auth_id` | `auth.users(id)` | CASCADE |
| `professores` | `perfil_id` | `perfis(id)` | CASCADE |
| `alunos` | `perfil_id` | `perfis(id)` | CASCADE |
| `alunos` | `professor_id` | `professores(perfil_id)` | SET NULL |
| `fichas_treino` | `aluno_id` | `alunos(perfil_id)` | CASCADE |
| `fichas_treino` | `professor_id` | `professores(perfil_id)` | NO ACTION |
| `exercicios` | `ficha_id` | `fichas_treino(id)` | CASCADE |
| `historico_execucoes` | `aluno_id` | `alunos(perfil_id)` | CASCADE |
| `historico_execucoes` | `ficha_id` | `fichas_treino(id)` | SET NULL |
| `historico_execucoes` | `exercicio_id` | `exercicios(id)` | SET NULL |
