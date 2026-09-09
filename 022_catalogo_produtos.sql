-- =====================================================================
-- 022_catalogo_produtos.sql — Tabela de preços (catálogo de produtos/
-- serviços) do módulo Financeiro (RDO Venko)
-- Rodar UMA VEZ no SQL Editor do projeto Supabase (rbpjwhyoxyybxllshrwd).
-- Não destrutivo: só adiciona uma tabela nova e uma coluna nova em
-- financeiro_itens. Não apaga nem altera dados existentes.
--
-- Origem dos dados: planilha "PLANILHA DE VALORES VENKO — LFM SUZANO"
-- fornecida pelo usuário. Os valores abaixo são transcritos exatamente
-- como constam na planilha. Dois pontos da planilha original reutilizam
-- numeração de item (categoria 8 repete "8.1"/"8.2" duas vezes, e a
-- categoria 14 usa "13.1"): aqui o campo item_numero foi renumerado de
-- forma sequencial (8.1–8.4, 14.1) só para não haver dois itens com o
-- mesmo identificador — a descrição e o valor de cada linha permanecem
-- idênticos ao original.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Tabela produtos_catalogo — a "tabela de preços" de referência.
--    Fonte estruturada dos produtos/serviços: ao lançar um item
--    financeiro, o frontend busca aqui a unidade e o custo unitário
--    (o valor gravado em financeiro_itens continua sendo uma cópia —
--    snapshot — do preço no momento do lançamento; alterar o preço
--    aqui NUNCA muda retroativamente um lançamento já feito).
-- ---------------------------------------------------------------------
create table if not exists public.produtos_catalogo (
  id uuid primary key default gen_random_uuid(),
  categoria_numero text,
  categoria_nome text not null,
  item_numero text,
  descricao text not null,
  unidade text not null,
  custo_unitario numeric(14,2) not null check (custo_unitario >= 0),
  ativo boolean not null default true,
  ordem integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_produtos_catalogo_categoria on public.produtos_catalogo(categoria_nome);
create index if not exists idx_produtos_catalogo_ativo on public.produtos_catalogo(ativo);

create or replace function public.produtos_catalogo_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_produtos_catalogo_updated_at on public.produtos_catalogo;
create trigger trg_produtos_catalogo_updated_at
  before update on public.produtos_catalogo
  for each row execute function public.produtos_catalogo_set_updated_at();

comment on table public.produtos_catalogo is
  'Tabela de preços (catálogo) de produtos/serviços, usada para preencher automaticamente unidade e valor unitário ao lançar um item financeiro. Fonte: planilha de valores fornecida pelo cliente (ex.: LFM - Suzano).';

-- ---------------------------------------------------------------------
-- 2) RLS — mesma regra de acesso do módulo financeiro para leitura
--    (is_admin ou acesso_financeiro); só admin cria/edita/apaga itens
--    do catálogo, já que são preços de referência que valem para todas
--    as obras.
-- ---------------------------------------------------------------------
alter table public.produtos_catalogo enable row level security;

drop policy if exists produtos_catalogo_select on public.produtos_catalogo;
create policy produtos_catalogo_select on public.produtos_catalogo
  for select
  using (exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and (p.is_admin or p.acesso_financeiro)
  ));

drop policy if exists produtos_catalogo_insert on public.produtos_catalogo;
create policy produtos_catalogo_insert on public.produtos_catalogo
  for insert
  with check (exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.is_admin
  ));

drop policy if exists produtos_catalogo_update on public.produtos_catalogo;
create policy produtos_catalogo_update on public.produtos_catalogo
  for update
  using (exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.is_admin
  ))
  with check (exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.is_admin
  ));

drop policy if exists produtos_catalogo_delete on public.produtos_catalogo;
create policy produtos_catalogo_delete on public.produtos_catalogo
  for delete
  using (exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.is_admin
  ));

-- ---------------------------------------------------------------------
-- 3) financeiro_itens ganha uma referência opcional ao item do
--    catálogo que originou o lançamento (só para rastreabilidade —
--    nunca é usada para recalcular o valor: o valor gravado no
--    lançamento é sempre o que já está em financeiro_itens.valor_unitario).
-- ---------------------------------------------------------------------
alter table public.financeiro_itens
  add column if not exists catalogo_item_id uuid references public.produtos_catalogo(id) on delete set null;

comment on column public.financeiro_itens.catalogo_item_id is
  'Item do catálogo (produtos_catalogo) usado para preencher este lançamento, quando aplicável. Não afeta o valor gravado — valor_unitario já é o snapshot histórico.';

-- ---------------------------------------------------------------------
-- 4) Seed: os 58 itens da planilha "LFM - Suzano", na ordem em que
--    aparecem nela. Rodar apenas se a tabela ainda estiver vazia,
--    para este script poder ser executado mais de uma vez sem duplicar.
-- ---------------------------------------------------------------------
insert into public.produtos_catalogo (categoria_numero, categoria_nome, item_numero, descricao, unidade, custo_unitario, ordem)
select * from (values
  ('1','REDE COLETORA DE ESGOTO EM VCA COM PI / PV - ATÉ 2 METROS DE PROFUNDIDADE','1.1','Tubulação de PVC - DN200 (sem pavimentação)','m',596.72,10),
  ('1','REDE COLETORA DE ESGOTO EM VCA COM PI / PV - ATÉ 2 METROS DE PROFUNDIDADE','1.2','Tubulação de PVC - DN300 (sem pavimentação)','m',672.14,11),
  ('1','REDE COLETORA DE ESGOTO EM VCA COM PI / PV - ATÉ 2 METROS DE PROFUNDIDADE','1.3','Tubulação de PVC - DN400 (sem pavimentação)','m',938.08,12),
  ('1','REDE COLETORA DE ESGOTO EM VCA COM PI / PV - ATÉ 2 METROS DE PROFUNDIDADE','1.4','Tubulação de PVC - DN200 (com corte de pavimentação)','m',716.06,13),
  ('1','REDE COLETORA DE ESGOTO EM VCA COM PI / PV - ATÉ 2 METROS DE PROFUNDIDADE','1.5','Tubulação de PVC - DN300 (com corte de pavimentação)','m',806.57,14),
  ('1','REDE COLETORA DE ESGOTO EM VCA COM PI / PV - ATÉ 2 METROS DE PROFUNDIDADE','1.6','Tubulação de PVC - DN400 (com corte de pavimentação)','m',1125.70,15),

  ('2','REDE COLETORA DE ESGOTO EM VCA COM PI / PV - DE 2 À 3 METROS DE PROFUNDIDADE','2.1','Tubulação de PVC - DN200 (sem pavimentação)','m',704.11,20),
  ('2','REDE COLETORA DE ESGOTO EM VCA COM PI / PV - DE 2 À 3 METROS DE PROFUNDIDADE','2.2','Tubulação de PVC - DN300 (sem pavimentação)','m',792.84,21),
  ('2','REDE COLETORA DE ESGOTO EM VCA COM PI / PV - DE 2 À 3 METROS DE PROFUNDIDADE','2.3','Tubulação de PVC - DN400 (sem pavimentação)','m',1105.19,22),
  ('2','REDE COLETORA DE ESGOTO EM VCA COM PI / PV - DE 2 À 3 METROS DE PROFUNDIDADE','2.4','Tubulação de PVC - DN200 (com corte de pavimentação)','m',844.93,23),
  ('2','REDE COLETORA DE ESGOTO EM VCA COM PI / PV - DE 2 À 3 METROS DE PROFUNDIDADE','2.5','Tubulação de PVC - DN300 (com corte de pavimentação)','m',951.40,24),
  ('2','REDE COLETORA DE ESGOTO EM VCA COM PI / PV - DE 2 À 3 METROS DE PROFUNDIDADE','2.6','Tubulação de PVC - DN400 (com corte de pavimentação)','m',1326.23,25),

  ('3','REDE COLETORA DE ESGOTO EM VCA COM PI / PV - DE 3 À 4 METROS DE PROFUNDIDADE','3.1','Tubulação de PVC - DN200 (sem pavimentação)','m',825.87,30),
  ('3','REDE COLETORA DE ESGOTO EM VCA COM PI / PV - DE 3 À 4 METROS DE PROFUNDIDADE','3.2','Tubulação de PVC - DN300 (sem pavimentação)','m',936.06,31),
  ('3','REDE COLETORA DE ESGOTO EM VCA COM PI / PV - DE 3 À 4 METROS DE PROFUNDIDADE','3.3','Tubulação de PVC - DN400 (sem pavimentação)','m',1308.65,32),
  ('3','REDE COLETORA DE ESGOTO EM VCA COM PI / PV - DE 3 À 4 METROS DE PROFUNDIDADE','3.4','Tubulação de PVC - DN200 (com corte de pavimentação)','m',991.04,33),
  ('3','REDE COLETORA DE ESGOTO EM VCA COM PI / PV - DE 3 À 4 METROS DE PROFUNDIDADE','3.5','Tubulação de PVC - DN300 (com corte de pavimentação)','m',1123.27,34),
  ('3','REDE COLETORA DE ESGOTO EM VCA COM PI / PV - DE 3 À 4 METROS DE PROFUNDIDADE','3.6','Tubulação de PVC - DN400 (com corte de pavimentação)','m',1570.38,35),

  ('4','RAMAL COM VCA','4.1','Ramal trecho oposto (excluído material e pavimentação)','m',456.50,40),
  ('4','RAMAL COM VCA','4.2','Ramal no eixo (excluído material e pavimentação)','m',269.50,41),
  ('4','RAMAL COM VCA','4.3','Ramal trecho adjacente (excluído material e pavimentação)','m',231.00,42),

  ('5','ESCAVAÇÃO DE POÇOS DE SERVIÇO PARA MÁQUINAS DE CRAVAÇÃO E TÚNEIS','5.1','Em Poço Liner DN 2,00 profundidade até 6 m','m',5151.30,50),
  ('5','ESCAVAÇÃO DE POÇOS DE SERVIÇO PARA MÁQUINAS DE CRAVAÇÃO E TÚNEIS','5.2','Em Poço Liner DN 2,40 profundidade até 6 m','m',5764.55,51),
  ('5','ESCAVAÇÃO DE POÇOS DE SERVIÇO PARA MÁQUINAS DE CRAVAÇÃO E TÚNEIS','5.3','Em Poço Liner DN 2,80 profundidade até 6 m','m',6132.50,52),
  ('5','ESCAVAÇÃO DE POÇOS DE SERVIÇO PARA MÁQUINAS DE CRAVAÇÃO E TÚNEIS','5.4','Em Poço Liner DN 4,20 profundidade até 6 m','m',6745.75,53),

  ('6','EXECUÇÃO DE GUARDA CORPO PARA TÚNEL COLETOR TRONCO','6.1','Em Tunnel Liner Vertical, diâmetro 2,00 m','m',484.00,60),
  ('6','EXECUÇÃO DE GUARDA CORPO PARA TÚNEL COLETOR TRONCO','6.2','Em Tunnel Liner Vertical, diâmetro 2,40 m','m',544.50,61),
  ('6','EXECUÇÃO DE GUARDA CORPO PARA TÚNEL COLETOR TRONCO','6.3','Em Tunnel Liner Vertical, diâmetro 2,80 m','m',605.00,62),
  ('6','EXECUÇÃO DE GUARDA CORPO PARA TÚNEL COLETOR TRONCO','6.4','Em Tunnel Liner Vertical, diâmetro 4,20 m','m',665.50,63),

  ('7','TRANSFORMAÇÃO DE POÇO DE SERVIÇO EM POÇO DE VISITA (PV)','7.1','Escavação - Diâmetro 1,00 m','m',2472.53,70),
  ('7','TRANSFORMAÇÃO DE POÇO DE SERVIÇO EM POÇO DE VISITA (PV)','7.2','Escavação - Diâmetro 1,50 m','m',2692.31,71),
  ('7','TRANSFORMAÇÃO DE POÇO DE SERVIÇO EM POÇO DE VISITA (PV)','7.3','Escavação - Diâmetro 2,00 m','m',4850.00,72),
  ('7','TRANSFORMAÇÃO DE POÇO DE SERVIÇO EM POÇO DE VISITA (PV)','7.4','Escavação - Diâmetro 2,40 m','m',5450.00,73),
  ('7','TRANSFORMAÇÃO DE POÇO DE SERVIÇO EM POÇO DE VISITA (PV)','7.5','Escavação - Diâmetro 2,80 m','m',5850.00,74),
  ('7','TRANSFORMAÇÃO DE POÇO DE SERVIÇO EM POÇO DE VISITA (PV)','7.6','Escavação - Diâmetro 4,20 m','m',6450.00,75),
  ('7','TRANSFORMAÇÃO DE POÇO DE SERVIÇO EM POÇO DE VISITA (PV)','7.7','Transformação - Diâmetro 1,00 m','m',2747.25,76),
  ('7','TRANSFORMAÇÃO DE POÇO DE SERVIÇO EM POÇO DE VISITA (PV)','7.8','Transformação - Diâmetro 1,50 m','m',2991.45,77),
  ('7','TRANSFORMAÇÃO DE POÇO DE SERVIÇO EM POÇO DE VISITA (PV)','7.9','Transformação - Diâmetro 2,00 m','m',4450.00,78),
  ('7','TRANSFORMAÇÃO DE POÇO DE SERVIÇO EM POÇO DE VISITA (PV)','7.10','Transformação - Diâmetro 2,40 m','m',4850.00,79),
  ('7','TRANSFORMAÇÃO DE POÇO DE SERVIÇO EM POÇO DE VISITA (PV)','7.11','Transformação - Diâmetro 2,80 m','m',5350.00,80),
  ('7','TRANSFORMAÇÃO DE POÇO DE SERVIÇO EM POÇO DE VISITA (PV)','7.12','Transformação - Diâmetro 4,20 m','m',5850.00,81),

  ('8','TRANSFORMAÇÃO DE POÇO DE SERVIÇO EM POÇO DE INSPEÇÃO (PI)','8.1','Escavação - Diâmetro 0,70 m','m',1730.77,90),
  ('8','TRANSFORMAÇÃO DE POÇO DE SERVIÇO EM POÇO DE INSPEÇÃO (PI)','8.2','Escavação - Diâmetro 1,00 m','m',1884.61,91),
  ('8','TRANSFORMAÇÃO DE POÇO DE SERVIÇO EM POÇO DE INSPEÇÃO (PI)','8.3','Tranformação - Diâmetro 0,70 m','m',1923.08,92),
  ('8','TRANSFORMAÇÃO DE POÇO DE SERVIÇO EM POÇO DE INSPEÇÃO (PI)','8.4','Tranformação - Diâmetro 1,00 m','m',2094.02,93),

  ('9','EXECUÇÃO DE TÚNEL','9.1','Em Tunnel Liner horizontal, Ø1,60 m','m',7448.10,100),
  ('9','EXECUÇÃO DE TÚNEL','9.2','Em NATM horizontal, Ø1,60 m','m',9279.60,101),

  ('10','LIGAÇÃO DE ESGOTOS','10.1','Ligação de esgoto PVC PA avulso sem reparo','unid',1192.66,110),
  ('10','LIGAÇÃO DE ESGOTOS','10.2','Ligação de esgoto PVC TA avulso sem reparo','unid',1480.46,111),
  ('10','LIGAÇÃO DE ESGOTOS','10.3','Ligação de esgoto PVC EX avulso sem reparo','unid',1789.69,112),
  ('10','LIGAÇÃO DE ESGOTOS','10.4','Ligação de esgoto PVC TO avulso sem reparo','unid',2200.03,113),
  ('10','LIGAÇÃO DE ESGOTOS','10.5','Ligação de esgoto PVC PO avulso sem reparo','unid',2586.96,114),

  ('11','RECOMPOSIÇÃO DE CALÇADA EM TRECHO DE LIGAÇÃO','11.1','Recomposição de calçada com acabamento em concreto desempenado','m²',170.80,120),
  ('11','RECOMPOSIÇÃO DE CALÇADA EM TRECHO DE LIGAÇÃO','11.2','Recomposição de calçada com acabamento em cerâmica','m²',156.75,121),

  ('12','RECOMPOSIÇÃO DE CALÇADA TRECHO AVULSO - SAÍDA MÍNIMA 10 M²','12.1','Recomposição de calçada com acabamento em concreto desempenado','m²',270.80,130),
  ('12','RECOMPOSIÇÃO DE CALÇADA TRECHO AVULSO - SAÍDA MÍNIMA 10 M²','12.2','Recomposição de calçada com acabamento em cerâmica','m²',256.75,131),

  ('13','DIÁRIA DE EQUIPE','13.1','Diária de equipe - 5 pessoas - Serviços diversos - Acordo LFM','vb',7500.00,140),

  ('14','ROMPIMENTO DE ARMCO','14.1','Execução de rompimento de armco - Interligação','unid',3500.00,150)
) as v(categoria_numero, categoria_nome, item_numero, descricao, unidade, custo_unitario, ordem)
where not exists (select 1 from public.produtos_catalogo);

-- =====================================================================
-- Fim da migration. Depois de rodar, confirme com:
--   select count(*) from public.produtos_catalogo;              -- espera 58
--   select column_name from information_schema.columns
--     where table_name='financeiro_itens' and column_name='catalogo_item_id';
-- =====================================================================
