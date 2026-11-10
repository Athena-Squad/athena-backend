-- Execute after creating the tables in the public schema.
-- Teacher accounts and student-teacher assignments must be provisioned by a
-- trusted server or the Supabase SQL Editor, never by the client.

alter table public.perfis enable row level security;
alter table public.professores enable row level security;
alter table public.alunos enable row level security;
alter table public.fichas_treino enable row level security;
alter table public.exercicios enable row level security;
alter table public.historico_execucoes enable row level security;

-- Remove broad table grants; RLS alone does not restrict table operations or
-- which columns a user can update.
revoke all on table
  public.perfis,
  public.professores,
  public.alunos,
  public.fichas_treino,
  public.exercicios,
  public.historico_execucoes
from public, anon, authenticated;

grant select on table
  public.perfis,
  public.professores,
  public.alunos,
  public.fichas_treino,
  public.exercicios,
  public.historico_execucoes
to authenticated;

grant insert (auth_id, nome_completo, email, tipo_perfil)
  on table public.perfis to authenticated;
grant insert (perfil_id, professor_id, objetivo)
  on table public.alunos to authenticated;
grant update (nome_completo) on table public.perfis to authenticated;
grant update (objetivo) on table public.alunos to authenticated;
grant insert (aluno_id, professor_id, titulo, ativa)
  on table public.fichas_treino to authenticated;
grant update (titulo, ativa) on table public.fichas_treino to authenticated;
grant delete on table public.fichas_treino to authenticated;
grant insert (
  ficha_id, nome, series, repeticoes, ordem,
  tempo_descanso_seg, carga_sugerida
) on table public.exercicios to authenticated;
grant update (
  nome, series, repeticoes, ordem,
  tempo_descanso_seg, carga_sugerida
) on table public.exercicios to authenticated;
grant delete on table public.exercicios to authenticated;
grant insert (
  aluno_id, ficha_id, exercicio_id,
  nome_exercicio, data_execucao, feedback_fadiga
) on table public.historico_execucoes to authenticated;
grant update (feedback_fadiga) on table public.historico_execucoes to authenticated;

drop policy if exists perfis_select_own on public.perfis;
create policy perfis_select_own
on public.perfis for select to authenticated
using (auth_id = (select auth.uid()));

drop policy if exists perfis_insert_own_student on public.perfis;
create policy perfis_insert_own_student
on public.perfis for insert to authenticated
with check (
  auth_id = (select auth.uid())
  and tipo_perfil = 'aluno'
);

drop policy if exists perfis_update_own_name on public.perfis;
create policy perfis_update_own_name
on public.perfis for update to authenticated
using (auth_id = (select auth.uid()))
with check (auth_id = (select auth.uid()));

drop policy if exists professores_select_own on public.professores;
create policy professores_select_own
on public.professores for select to authenticated
using (
  exists (
    select 1
    from public.perfis p
    where p.id = professores.perfil_id
      and p.auth_id = (select auth.uid())
      and p.tipo_perfil = 'professor'
  )
);

drop policy if exists alunos_select_own_or_linked_teacher on public.alunos;
create policy alunos_select_own_or_linked_teacher
on public.alunos for select to authenticated
using (
  exists (
    select 1
    from public.perfis p
    where p.id = alunos.perfil_id
      and p.auth_id = (select auth.uid())
      and p.tipo_perfil = 'aluno'
  )
  or exists (
    select 1
    from public.professores pr
    join public.perfis p on p.id = pr.perfil_id
    where pr.perfil_id = alunos.professor_id
      and p.auth_id = (select auth.uid())
      and p.tipo_perfil = 'professor'
  )
);

drop policy if exists alunos_insert_own_unassigned on public.alunos;
create policy alunos_insert_own_unassigned
on public.alunos for insert to authenticated
with check (
  professor_id is null
  and exists (
    select 1
    from public.perfis p
    where p.id = alunos.perfil_id
      and p.auth_id = (select auth.uid())
      and p.tipo_perfil = 'aluno'
  )
);

drop policy if exists alunos_update_own_or_linked_teacher on public.alunos;
create policy alunos_update_own_or_linked_teacher
on public.alunos for update to authenticated
using (
  exists (
    select 1
    from public.perfis p
    where p.id = alunos.perfil_id
      and p.auth_id = (select auth.uid())
      and p.tipo_perfil = 'aluno'
  )
  or exists (
    select 1
    from public.professores pr
    join public.perfis p on p.id = pr.perfil_id
    where pr.perfil_id = alunos.professor_id
      and p.auth_id = (select auth.uid())
      and p.tipo_perfil = 'professor'
  )
)
with check (
  exists (
    select 1
    from public.perfis p
    where p.id = alunos.perfil_id
      and p.auth_id = (select auth.uid())
      and p.tipo_perfil = 'aluno'
  )
  or exists (
    select 1
    from public.professores pr
    join public.perfis p on p.id = pr.perfil_id
    where pr.perfil_id = alunos.professor_id
      and p.auth_id = (select auth.uid())
      and p.tipo_perfil = 'professor'
  )
);

drop policy if exists fichas_select_own_or_linked_teacher on public.fichas_treino;
create policy fichas_select_own_or_linked_teacher
on public.fichas_treino for select to authenticated
using (
  exists (
    select 1
    from public.alunos a
    join public.perfis p on p.id = a.perfil_id
    where a.perfil_id = fichas_treino.aluno_id
      and p.auth_id = (select auth.uid())
      and p.tipo_perfil = 'aluno'
  )
  or (
    exists (
      select 1
      from public.professores pr
      join public.perfis p on p.id = pr.perfil_id
      where pr.perfil_id = fichas_treino.professor_id
        and p.auth_id = (select auth.uid())
        and p.tipo_perfil = 'professor'
    )
    and exists (
      select 1
      from public.alunos a
      where a.perfil_id = fichas_treino.aluno_id
        and a.professor_id = fichas_treino.professor_id
    )
  )
);

drop policy if exists fichas_insert_linked_teacher on public.fichas_treino;
create policy fichas_insert_linked_teacher
on public.fichas_treino for insert to authenticated
with check (
  exists (
    select 1
    from public.professores pr
    join public.perfis p on p.id = pr.perfil_id
    join public.alunos a on a.professor_id = pr.perfil_id
    where pr.perfil_id = fichas_treino.professor_id
      and a.perfil_id = fichas_treino.aluno_id
      and p.auth_id = (select auth.uid())
      and p.tipo_perfil = 'professor'
  )
);

drop policy if exists fichas_update_linked_teacher on public.fichas_treino;
create policy fichas_update_linked_teacher
on public.fichas_treino for update to authenticated
using (
  exists (
    select 1
    from public.professores pr
    join public.perfis p on p.id = pr.perfil_id
    join public.alunos a on a.professor_id = pr.perfil_id
    where pr.perfil_id = fichas_treino.professor_id
      and a.perfil_id = fichas_treino.aluno_id
      and p.auth_id = (select auth.uid())
      and p.tipo_perfil = 'professor'
  )
)
with check (
  exists (
    select 1
    from public.professores pr
    join public.perfis p on p.id = pr.perfil_id
    join public.alunos a on a.professor_id = pr.perfil_id
    where pr.perfil_id = fichas_treino.professor_id
      and a.perfil_id = fichas_treino.aluno_id
      and p.auth_id = (select auth.uid())
      and p.tipo_perfil = 'professor'
  )
);

drop policy if exists fichas_delete_linked_teacher on public.fichas_treino;
create policy fichas_delete_linked_teacher
on public.fichas_treino for delete to authenticated
using (
  exists (
    select 1
    from public.professores pr
    join public.perfis p on p.id = pr.perfil_id
    join public.alunos a on a.professor_id = pr.perfil_id
    where pr.perfil_id = fichas_treino.professor_id
      and a.perfil_id = fichas_treino.aluno_id
      and p.auth_id = (select auth.uid())
      and p.tipo_perfil = 'professor'
  )
);

drop policy if exists exercicios_select_own_or_linked_teacher on public.exercicios;
create policy exercicios_select_own_or_linked_teacher
on public.exercicios for select to authenticated
using (
  exists (
    select 1
    from public.fichas_treino f
    where f.id = exercicios.ficha_id
  )
);

drop policy if exists exercicios_insert_linked_teacher on public.exercicios;
create policy exercicios_insert_linked_teacher
on public.exercicios for insert to authenticated
with check (
  exists (
    select 1
    from public.fichas_treino f
    join public.professores pr on pr.perfil_id = f.professor_id
    join public.perfis p on p.id = pr.perfil_id
    join public.alunos a
      on a.perfil_id = f.aluno_id
     and a.professor_id = f.professor_id
    where f.id = exercicios.ficha_id
      and p.auth_id = (select auth.uid())
      and p.tipo_perfil = 'professor'
  )
);

drop policy if exists exercicios_update_linked_teacher on public.exercicios;
create policy exercicios_update_linked_teacher
on public.exercicios for update to authenticated
using (
  exists (
    select 1
    from public.fichas_treino f
    join public.professores pr on pr.perfil_id = f.professor_id
    join public.perfis p on p.id = pr.perfil_id
    join public.alunos a
      on a.perfil_id = f.aluno_id
     and a.professor_id = f.professor_id
    where f.id = exercicios.ficha_id
      and p.auth_id = (select auth.uid())
      and p.tipo_perfil = 'professor'
  )
)
with check (
  exists (
    select 1
    from public.fichas_treino f
    join public.professores pr on pr.perfil_id = f.professor_id
    join public.perfis p on p.id = pr.perfil_id
    join public.alunos a
      on a.perfil_id = f.aluno_id
     and a.professor_id = f.professor_id
    where f.id = exercicios.ficha_id
      and p.auth_id = (select auth.uid())
      and p.tipo_perfil = 'professor'
  )
);

drop policy if exists exercicios_delete_linked_teacher on public.exercicios;
create policy exercicios_delete_linked_teacher
on public.exercicios for delete to authenticated
using (
  exists (
    select 1
    from public.fichas_treino f
    join public.professores pr on pr.perfil_id = f.professor_id
    join public.perfis p on p.id = pr.perfil_id
    join public.alunos a
      on a.perfil_id = f.aluno_id
     and a.professor_id = f.professor_id
    where f.id = exercicios.ficha_id
      and p.auth_id = (select auth.uid())
      and p.tipo_perfil = 'professor'
  )
);

drop policy if exists historico_select_own on public.historico_execucoes;
create policy historico_select_own
on public.historico_execucoes for select to authenticated
using (
  exists (
    select 1
    from public.alunos a
    join public.perfis p on p.id = a.perfil_id
    where a.perfil_id = historico_execucoes.aluno_id
      and p.auth_id = (select auth.uid())
      and p.tipo_perfil = 'aluno'
  )
);

drop policy if exists historico_insert_own_exercise on public.historico_execucoes;
create policy historico_insert_own_exercise
on public.historico_execucoes for insert to authenticated
with check (
  ficha_id is not null
  and exercicio_id is not null
  and exists (
    select 1
    from public.alunos a
    join public.perfis p on p.id = a.perfil_id
    join public.fichas_treino f on f.aluno_id = a.perfil_id
    join public.exercicios e
      on e.ficha_id = f.id
     and e.id = historico_execucoes.exercicio_id
    where a.perfil_id = historico_execucoes.aluno_id
      and f.id = historico_execucoes.ficha_id
      and e.nome = historico_execucoes.nome_exercicio
      and p.auth_id = (select auth.uid())
      and p.tipo_perfil = 'aluno'
  )
);

drop policy if exists historico_update_own on public.historico_execucoes;
create policy historico_update_own
on public.historico_execucoes for update to authenticated
using (
  exists (
    select 1
    from public.alunos a
    join public.perfis p on p.id = a.perfil_id
    where a.perfil_id = historico_execucoes.aluno_id
      and p.auth_id = (select auth.uid())
      and p.tipo_perfil = 'aluno'
  )
)
with check (
  exists (
    select 1
    from public.alunos a
    join public.perfis p on p.id = a.perfil_id
    where a.perfil_id = historico_execucoes.aluno_id
      and p.auth_id = (select auth.uid())
      and p.tipo_perfil = 'aluno'
  )
);
