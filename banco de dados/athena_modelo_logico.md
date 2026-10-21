# Projeto Athena — Modelo lógico do banco de dados

SGBD: PostgreSQL (Supabase). Notação: `tabela(campos)` seguida das chaves estrangeiras (`campo → tabela.campo`). A chave primária de cada tabela é o primeiro campo listado (`perfil_id` em `professores` e `alunos`).

## 1. Esquema relacional

```
perfis(id, auth_id, nome_completo, email, tipo_perfil, criado_em)
  auth_id → auth.users.id

professores(perfil_id, cref)
  perfil_id → perfis.id

alunos(perfil_id, professor_id, objetivo)
  perfil_id → perfis.id
  professor_id → professores.perfil_id

fichas_treino(id, aluno_id, professor_id, titulo, ativa, criado_em)
  aluno_id → alunos.perfil_id
  professor_id → professores.perfil_id

exercicios(id, ficha_id, nome, series, repeticoes, ordem,
           tempo_descanso_seg, carga_sugerida)
  ficha_id → fichas_treino.id

historico_execucoes(id, aluno_id, ficha_id, exercicio_id,
                    nome_exercicio, data_execucao, feedback_fadiga)
  aluno_id → alunos.perfil_id
  ficha_id → fichas_treino.id
  exercicio_id → exercicios.id
```

## 2. Cardinalidades

| Relação | Cardinalidade |
|---|---|
| `auth.users` — `perfis` | 1 : 1 |
| `perfis` — `professores` | 1 : 0..1 |
| `perfis` — `alunos` | 1 : 0..1 |
| `professores` — `alunos` | 1 : N |
| `professores` — `fichas_treino` | 1 : N |
| `alunos` — `fichas_treino` | 1 : N |
| `fichas_treino` — `exercicios` | 1 : 1..N |
| `alunos` — `historico_execucoes` | 1 : N |
| `fichas_treino` — `historico_execucoes` | 1 : N |
| `exercicios` — `historico_execucoes` | 1 : N |

## 3. Script SQL (PostgreSQL / Supabase)

```sql
create type tipo_perfil as enum ('professor', 'aluno');

create table perfis (
  id            uuid primary key default gen_random_uuid(),
  auth_id       uuid not null unique references auth.users(id) on delete cascade,
  nome_completo text not null,
  email         text not null unique,
  tipo_perfil   tipo_perfil not null,
  criado_em     timestamptz not null default now()
);

create table professores (
  perfil_id uuid primary key references perfis(id) on delete cascade,
  cref      text not null unique
);

create table alunos (
  perfil_id    uuid primary key references perfis(id) on delete cascade,
  professor_id uuid references professores(perfil_id) on delete set null,
  objetivo     text
);

create table fichas_treino (
  id           uuid primary key default gen_random_uuid(),
  aluno_id     uuid not null references alunos(perfil_id) on delete cascade,
  professor_id uuid not null references professores(perfil_id),
  titulo       text not null,
  ativa        boolean not null default false,
  criado_em    timestamptz not null default now()
);

-- No máximo uma ficha ativa por aluno (RF04)
create unique index uq_ficha_ativa_por_aluno
  on fichas_treino (aluno_id) where ativa;

create table exercicios (
  id                 uuid primary key default gen_random_uuid(),
  ficha_id           uuid not null references fichas_treino(id) on delete cascade,
  nome               text not null,
  series             int  not null check (series > 0),
  repeticoes         text not null,
  ordem              smallint not null,
  tempo_descanso_seg int check (tempo_descanso_seg >= 0),
  carga_sugerida     numeric(6,2) check (carga_sugerida >= 0),
  unique (ficha_id, ordem)
);

create table historico_execucoes (
  id              uuid primary key default gen_random_uuid(),
  aluno_id        uuid not null references alunos(perfil_id) on delete cascade,
  ficha_id        uuid references fichas_treino(id) on delete set null,
  exercicio_id    uuid references exercicios(id) on delete set null,
  nome_exercicio  text not null,
  data_execucao   date not null default current_date,
  feedback_fadiga text,
  unique (aluno_id, exercicio_id, data_execucao)
);
```

## 4. Pontos a definir na implementação

1. **Criação do perfil no cadastro (RF01):** trigger em `auth.users` que insere em `perfis` a partir do `raw_user_meta_data`, ou `insert` feito pelo front após o `signUp`. O trigger é preferível, porque o RNF04 pede que as regras fiquem no banco.
2. **Segurança do `tipo_perfil`:** o RLS deve impedir que o usuário escolha ou altere o próprio tipo de perfil para `professor`.
3. **RLS (RNF04):** as políticas usam `auth.uid()` ligado a `perfis.auth_id`. O aluno lê apenas as próprias fichas e histórico. Somente professor faz `insert`, `update` e `delete` em `fichas_treino` e `exercicios` dos seus alunos.
4. **Padronização de nomes:** o diagrama de classes mistura "Registro" e "Registrar" (`consolidarRegisto()`, `registarExecucao()`). Vale uniformizar.
