-- =====================================================================
-- 021_financeiro.sql — Módulo Financeiro por Obra (RDO Venko)
-- Rodar UMA VEZ no SQL Editor do projeto Supabase (rbpjwhyoxyybxllshrwd).
-- Não destrutivo: só adiciona colunas/tabelas/políticas novas. Não apaga
-- nem altera dados existentes em profiles, obras, rdos, equipamentos,
-- equipes, colaboradores ou departamentos.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Permissão de acesso financeiro em profiles
--    Reaproveita exatamente o mesmo modelo do is_admin já existente:
--    um booleano em profiles, protegido por um trigger que só deixa um
--    admin (is_admin=true) alterar essa coluna — nunca o próprio usuário.
-- ---------------------------------------------------------------------
alter table public.profiles
  add column if not exists acesso_financeiro boolean not null default false;

comment on column public.profiles.acesso_financeiro is
  'Libera o módulo Financeiro para este usuário. Só pode ser alterado por um admin (ver trigger trg_protect_acesso_financeiro) — nunca pelo próprio usuário via frontend/API.';

-- Trigger de proteção (BEFORE UPDATE): bloqueia qualquer UPDATE que mude
-- acesso_financeiro a menos que quem está executando já seja admin.
-- Isso funciona em conjunto com a policy profiles_update_self_or_admin já
-- existente (que permite o próprio usuário atualizar nome/cargo etc. do
-- seu próprio perfil) — o trigger fecha a brecha de coluna que a policy,
-- por ser em nível de linha, não cobre sozinha.
create or replace function public.protect_acesso_financeiro()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.acesso_financeiro is distinct from old.acesso_financeiro then
    if not exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.is_admin
    ) then
      raise exception 'Somente administradores podem alterar a permissão de acesso financeiro.';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_protect_acesso_financeiro on public.profiles;
create trigger trg_protect_acesso_financeiro
  before update on public.profiles
  for each row execute function public.protect_acesso_financeiro();

-- Fecha a mesma brecha no INSERT: recria profiles_insert_self preservando
-- exatamente a regra de bootstrap já existente (o primeiro usuário do
-- sistema pode se auto-cadastrar como admin, quando a tabela profiles
-- ainda está vazia) e adicionando a exigência de que ninguém consegue se
-- auto-cadastrar já com acesso_financeiro=true.
drop policy if exists profiles_insert_self on public.profiles;
create policy profiles_insert_self on public.profiles
  for insert
  with check (
    auth.uid() = id
    and (is_admin = false or not exists (select 1 from public.profiles))
    and acesso_financeiro = false
  );

-- ---------------------------------------------------------------------
-- 2) Tabela financeiro_itens
--    Uma linha por item comprado/lançado (produto, material ou serviço)
--    vinculado a uma obra. Não existe hoje nenhuma tabela de compras ou
--    produtos no banco — rdos.materiais é um campo jsonb legado, só com
--    nome/quantidade/unidade, sem valores. Esta é uma tabela nova.
--
--    Categoria e fornecedor ficam como texto livre (sem tabela de
--    cadastro própria): a estrutura atual não tem nada equivalente a uma
--    categoria de produto/serviço, e criar um cadastro fixo (só editável
--    por um lugar específico) seria uma estrutura nova incompatível com
--    o resto do sistema, que hoje não tem esse conceito em lugar nenhum.
--    Texto livre + sugestões (datalist) no frontend, no mesmo espírito do
--    campo "Outro (digitar)" já usado em Equipamentos dentro da RDO.
-- ---------------------------------------------------------------------
create table if not exists public.financeiro_itens (
  id uuid primary key default gen_random_uuid(),
  obra_id uuid not null references public.obras(id) on delete cascade,
  numero_compra text,
  fornecedor text,
  categoria text,
  produto_servico text not null,
  descricao text,
  unidade text not null,
  quantidade numeric(14,3) not null check (quantidade >= 0),
  valor_unitario numeric(14,2) not null check (valor_unitario >= 0),
  valor_total numeric(14,2) generated always as (round(quantidade * valor_unitario, 2)) stored,
  data date,
  observacoes text,
  exemplo boolean not null default false,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_financeiro_itens_obra on public.financeiro_itens(obra_id);
create index if not exists idx_financeiro_itens_categoria on public.financeiro_itens(categoria);
create index if not exists idx_financeiro_itens_data on public.financeiro_itens(data);

create or replace function public.financeiro_itens_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_financeiro_itens_updated_at on public.financeiro_itens;
create trigger trg_financeiro_itens_updated_at
  before update on public.financeiro_itens
  for each row execute function public.financeiro_itens_set_updated_at();

comment on table public.financeiro_itens is
  'Itens financeiros (produtos/materiais/serviços comprados ou lançados) vinculados a uma obra. Base do módulo Financeiro.';

-- ---------------------------------------------------------------------
-- 3) RLS — a parte que realmente importa para a segurança pedida.
--    Diferente das outras tabelas do sistema (que hoje liberam qualquer
--    usuário autenticado com "using (true)"), aqui a leitura e a escrita
--    exigem is_admin OU acesso_financeiro no profiles de quem está
--    autenticado. Isso bloqueia a tabela mesmo que alguém chame a API
--    REST do Supabase diretamente (com a mesma anon key pública que o
--    frontend usa) — a policy nega no banco, não só no frontend.
-- ---------------------------------------------------------------------
alter table public.financeiro_itens enable row level security;

drop policy if exists financeiro_itens_select on public.financeiro_itens;
create policy financeiro_itens_select on public.financeiro_itens
  for select
  using (exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and (p.is_admin or p.acesso_financeiro)
  ));

drop policy if exists financeiro_itens_insert on public.financeiro_itens;
create policy financeiro_itens_insert on public.financeiro_itens
  for insert
  with check (exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and (p.is_admin or p.acesso_financeiro)
  ));

drop policy if exists financeiro_itens_update on public.financeiro_itens;
create policy financeiro_itens_update on public.financeiro_itens
  for update
  using (exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and (p.is_admin or p.acesso_financeiro)
  ))
  with check (exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and (p.is_admin or p.acesso_financeiro)
  ));

drop policy if exists financeiro_itens_delete on public.financeiro_itens;
create policy financeiro_itens_delete on public.financeiro_itens
  for delete
  using (exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and (p.is_admin or p.acesso_financeiro)
  ));

-- =====================================================================
-- Fim da migration. Depois de rodar, confirme com:
--   select column_name from information_schema.columns
--     where table_name='profiles' and column_name='acesso_financeiro';
--   select count(*) from public.financeiro_itens;
-- =====================================================================
