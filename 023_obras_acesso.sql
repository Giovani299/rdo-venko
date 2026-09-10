-- =====================================================================
-- 023_obras_acesso.sql — Restrição opcional de acesso à aba "Obras"
-- Rodar UMA VEZ no SQL Editor do projeto Supabase (rbpjwhyoxyybxllshrwd).
-- Não destrutivo: só adiciona uma coluna nova em profiles, com valor
-- padrão true — nenhum usuário existente perde acesso a nada.
--
-- Contexto: perfis de campo (ex.: engenheiro de obra) devem continuar
-- enxergando a obra dentro de "Nova RDO" (para escolher em qual obra
-- está lançando o relatório) e no Painel, mas NÃO devem ter acesso à
-- aba "Obras" em si (cadastro/edição de obras, serviços contratados,
-- excluir/concluir obra). Por isso esta é apenas uma restrição de
-- NAVEGAÇÃO (aba escondida no frontend) — a tabela "obras" continua
-- de leitura liberada para qualquer usuário autenticado, exatamente
-- como já era antes, pois "Nova RDO" depende disso.
-- =====================================================================

alter table public.profiles
  add column if not exists acesso_obras boolean not null default true;

comment on column public.profiles.acesso_obras is
  'Libera a aba "Obras" (cadastro/edição de obras e serviços contratados) para este usuário. Default true — não afeta usuários existentes. Diferente de acesso_financeiro/is_admin, esta coluna só RESTRINGE (nunca eleva privilégio), então não precisa do mesmo trigger de proteção: o próprio usuário pode receber este valor já no cadastro, definido por quem o está criando.';

-- =====================================================================
-- Fim da migration. Depois de rodar, confirme com:
--   select column_name, column_default from information_schema.columns
--     where table_name='profiles' and column_name='acesso_obras';
-- =====================================================================
